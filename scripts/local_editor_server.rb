#!/usr/bin/env ruby
# Local-only blog editor API. Run separately from Jekyll:
#   bundle exec ruby scripts/local_editor_server.rb

require 'sinatra'
require 'json'
require 'fileutils'
require 'time'
require 'yaml'
require 'base64'

begin
  require 'mini_magick'
  MINI_MAGICK_AVAILABLE = true
rescue LoadError
  MINI_MAGICK_AVAILABLE = false
end

set :bind, '127.0.0.1'
set :port, 4001

ROOT = File.expand_path('..', __dir__)
POSTS_DIR = File.join(ROOT, '_posts')
DRAFTS_DIR = File.join(ROOT, '_drafts')
IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'posts')
DRAFT_IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'drafts')
ALBUM_IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'albums')
ALBUMS_DIR = File.join(ROOT, '_albums')
TEMP_IMAGES_DIR = File.join(ROOT, '_editor_tmp')
IMAGE_META_PATH = File.join(ROOT, '_data', 'image_meta.yml')

THUMB_W = 600
MED_W = 1600
THUMB_Q = 78
MED_Q = 82
VARIANT_EXTS = %w[.png .jpg .jpeg].freeze

FileUtils.mkdir_p(POSTS_DIR)
FileUtils.mkdir_p(DRAFTS_DIR)
FileUtils.mkdir_p(IMAGES_DIR)
FileUtils.mkdir_p(DRAFT_IMAGES_DIR)
FileUtils.mkdir_p(ALBUM_IMAGES_DIR)
FileUtils.mkdir_p(ALBUMS_DIR)
FileUtils.mkdir_p(File.join(TEMP_IMAGES_DIR, 'posts'))
FileUtils.mkdir_p(File.join(TEMP_IMAGES_DIR, 'drafts'))
FileUtils.mkdir_p(File.join(TEMP_IMAGES_DIR, 'albums'))

helpers do
  def json(body, status = 200)
    content_type :json
    halt status, JSON.generate(body)
  end

  def sanitize_slug(slug)
    slug.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-+|-+$/, '')
  end

  def post_files
    Dir[File.join(POSTS_DIR, '*.md')].sort
  end

  def draft_files
    Dir[File.join(DRAFTS_DIR, '*.md')].sort
  end

  def all_post_files
    post_files + draft_files
  end

  def slug_from_path(path)
    return nil unless path
    if File.dirname(path) == DRAFTS_DIR
      File.basename(path, '.md')
    else
      File.basename(path, '.md').split('-', 4)[3] || File.basename(path, '.md')
    end
  end

  def parse_post(path)
    content = File.read(path)
    if content =~ /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m
      front_matter = $1
      body = $2
      data =
        begin
          parsed = YAML.safe_load(front_matter, permitted_classes: [Date, Time], aliases: true)
          parsed.is_a?(Hash) ? parsed : {}
        rescue StandardError
          {}
        end

      title = data['title'].to_s.strip
      if title.empty?
        raw_slug = slug_from_path(path).to_s
        title = raw_slug.gsub(/[-_]+/, ' ').split.map { |w| w[0]&.upcase.to_s + w[1..].to_s }.join(' ')
      end

      date_val = data['date']
      date =
        if date_val.respond_to?(:iso8601)
          date_val.iso8601
        else
          date_val.to_s.strip
        end
      date = nil if date.empty?

      tags_val = data['tags']
      tags =
        case tags_val
        when Array
          tags_val.map { |t| t.to_s.strip }.reject(&:empty?)
        when NilClass
          []
        else
          tags_val.to_s.gsub(/[\[\]]/, '').split(',').map(&:strip).reject(&:empty?)
        end

      draft_val = data['draft']
      draft = (draft_val == true || draft_val.to_s.strip.downcase == 'true')
      images_val = data['images']
      images = case images_val
               when Array
                 images_val.select { |i| i.is_a?(Hash) && i['src'].to_s.strip != '' }.map do |i|
                   { 'src' => i['src'].to_s.strip, 'caption' => i['caption'].to_s.strip }
                 end
               else
                 []
               end

      slug = slug_from_path(path)
      {
        'title' => title,
        'date' => date,
        'tags' => tags,
        'draft' => draft,
        'kind' => (File.dirname(path) == DRAFTS_DIR ? 'draft' : 'post'),
        'slug' => slug,
        'images' => images,
        'body' => body
      }
    else
      nil
    end
  end

  def parse_images_from_data(data)
    Array(data['images'] || []).select { |i| i.is_a?(Hash) && i['src'].to_s.strip != '' }.map do |i|
      { 'src' => i['src'].to_s.strip, 'caption' => i['caption'].to_s.strip }
    end
  end

  # Extract image URLs from markdown body text, returning array of {src, caption} hashes.
  # Detects both `![alt](url)` and `![alt](url)\n\n*caption*` patterns.
  def extract_body_images(body)
    results = []
    lines = body.to_s.lines.map(&:chomp)
    i = 0
    while i < lines.length
      line = lines[i]
      if line =~ /^!\[([^\]]*)\]\(([^)]+)\)\s*$/
        alt = $1.to_s.strip
        src = $2.to_s.strip
        # Look ahead for italic caption: blank line then *caption* or _caption_
        caption = alt
        if i + 2 < lines.length && lines[i + 1].strip.empty? && lines[i + 2] =~ /^\*(.+)\*$|^_(.+)_$/
          caption = ($1 || $2).to_s.strip
          i += 2 # skip blank line and caption line
        end
        results << { 'src' => src, 'caption' => caption } if src =~ %r{/assets/images/}
      end
      i += 1
    end
    results
  end

  # Merge body-extracted images with explicit album images, deduplicating by src.
  def merge_images(body_images, album_images)
    seen = {}
    merged = []
    # Album images take priority (user-curated captions)
    album_images.each do |img|
      key = img['src'].to_s.strip
      next if key.empty? || seen[key]
      seen[key] = true
      merged << img
    end
    body_images.each do |img|
      key = img['src'].to_s.strip
      next if key.empty? || seen[key]
      seen[key] = true
      merged << img
    end
    merged
  end

  def images_to_frontmatter(images)
    return '' if images.empty?
    fm = +"images:\n"
    images.each do |img|
      fm << "  - src: \"#{img['src'].gsub('"', '\\"')}\"\n"
      fm << "    caption: \"#{img['caption'].gsub('"', '\\"')}\"\n" unless img['caption'].to_s.empty?
    end
    fm
  end

  def album_files
    Dir[File.join(ALBUMS_DIR, '*.md')].sort
  end

  def parse_album(path)
    content = File.read(path)
    if content =~ /\A---\s*\n(.*?)\n---\s*\n?(.*)\z/m
      front_matter = $1
      data =
        begin
          parsed = YAML.safe_load(front_matter, permitted_classes: [Date, Time], aliases: true)
          parsed.is_a?(Hash) ? parsed : {}
        rescue StandardError
          {}
        end

      title = data['title'].to_s.strip
      title = File.basename(path, '.md') if title.empty?

      date_val = data['date']
      date =
        if date_val.respond_to?(:iso8601)
          date_val.iso8601
        else
          date_val.to_s.strip
        end
      date = nil if date.empty?

      description = data['description'].to_s.strip
      draft = (data['draft'] == true || data['draft'].to_s.strip.downcase == 'true')

      images_val = data['images']
      images = case images_val
               when Array
                 images_val.select { |i| i.is_a?(Hash) && i['src'].to_s.strip != '' }.map do |i|
                   { 'src' => i['src'].to_s.strip, 'caption' => i['caption'].to_s.strip }
                 end
               else
                 []
               end

      slug = File.basename(path, '.md')
      {
        'title' => title,
        'date' => date,
        'description' => description,
        'draft' => draft,
        'slug' => slug,
        'images' => images
      }
    else
      nil
    end
  end

  def album_to_file(album)
    fm = +"---\nlayout: album\n"
    fm << "title: \"#{album['title'].gsub('"', '\\"')}\"\n"
    fm << "date: #{album['date']}\n" if album['date']
    fm << "description: \"#{album['description'].gsub('"', '\\"')}\"\n" unless album['description'].to_s.empty?
    fm << "draft: true\n" if album['draft']
    fm << images_to_frontmatter(album['images'] || [])
    fm << "---\n"
    fm
  end

  # Find all files (posts, drafts, albums) that reference a given image src.
  # Returns array of file paths.
  def find_image_references(src, exclude_path: nil)
    refs = []
    (all_post_files + album_files).each do |path|
      next if path == exclude_path
      content = File.read(path)
      refs << path if content.include?(src)
    end
    refs
  end

  # Delete an image file from disk if no other posts/albums reference it.
  # Returns true if deleted, false if still in use.
  def delete_image_if_orphaned(src, exclude_path: nil)
    return false if src.to_s.strip.empty?
    refs = find_image_references(src, exclude_path: exclude_path)
    return false unless refs.empty?

    # Resolve to absolute path
    abs = File.join(ROOT, src.sub(%r{^/}, ''))
    deleted = false
    if File.exist?(abs)
      File.delete(abs)
      deleted = true
    end

    # Clean up generated thumbnail variants and manifest entry regardless of
    # whether the source file existed — it may have been removed manually.
    if VARIANT_EXTS.include?(File.extname(abs).downcase) && File.basename(abs) !~ /-(thumb|med)\.jpg\z/i
      %w[thumb med].each do |v|
        variant_abs = variant_abs_path(abs, v)
        File.delete(variant_abs) if File.exist?(variant_abs)
      end
      remove_image_manifest_entry(image_meta_key(abs))
    end

    deleted
  end

  def ext_for_mime(mime)
    m = mime.to_s.downcase
    return 'jpg' if m == 'image/jpeg' || m == 'image/jpg'
    return 'png' if m == 'image/png'
    return 'gif' if m == 'image/gif'
    return 'webp' if m == 'image/webp'
    return 'svg' if m == 'image/svg+xml'
    'bin'
  end

  # Move images from _editor_tmp/ to assets/images/ when a post is saved.
  # Also auto-generates responsive thumbnails + updates the image_meta manifest.
  def promote_temp_images(body, images = [])
    scannable = body.to_s + images.map { |i| " #{i['src']}" }.join
    scannable.scan(%r{/assets/images/(posts|drafts|albums)/([^\s\)"']+)}).each do |subdir, filename|
      temp = File.join(TEMP_IMAGES_DIR, subdir, filename)
      dest = File.join(ROOT, 'assets', 'images', subdir, filename)
      if File.exist?(temp)
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.mv(temp, dest)
        generate_thumbnails_for(dest)
      elsif File.exist?(dest)
        generate_thumbnails_for(dest) unless thumbnails_fresh?(dest)
      end
    end
  end

  # Returns the repo-relative manifest key for an absolute path under
  # assets/images/, e.g. "posts/20260101-foo.png". nil for anything outside.
  def image_meta_key(abs_path)
    prefix = File.join(ROOT, 'assets', 'images') + '/'
    return nil unless abs_path.start_with?(prefix)
    abs_path.sub(prefix, '')
  end

  def variant_abs_path(source_abs, variant)
    dir = File.dirname(source_abs)
    base = File.basename(source_abs, File.extname(source_abs))
    File.join(dir, "#{base}-#{variant}.jpg")
  end

  def thumbnails_fresh?(source_abs)
    thumb_abs = variant_abs_path(source_abs, 'thumb')
    med_abs = variant_abs_path(source_abs, 'med')
    File.exist?(thumb_abs) && File.exist?(med_abs) &&
      File.mtime(thumb_abs) >= File.mtime(source_abs) &&
      File.mtime(med_abs) >= File.mtime(source_abs)
  end

  # Generate thumb + med JPEG variants next to source_abs and update the
  # _data/image_meta.yml manifest. Degrades silently if mini_magick is missing.
  def generate_thumbnails_for(source_abs)
    return unless File.exist?(source_abs)
    return unless VARIANT_EXTS.include?(File.extname(source_abs).downcase)
    base = File.basename(source_abs)
    return if base =~ /-(thumb|med)\.jpg\z/i
    return unless MINI_MAGICK_AVAILABLE

    key = image_meta_key(source_abs)
    return unless key

    thumb_abs = variant_abs_path(source_abs, 'thumb')
    med_abs = variant_abs_path(source_abs, 'med')

    thumb_w, thumb_h, orig_w, orig_h = write_image_variant(source_abs, thumb_abs, THUMB_W, THUMB_Q)
    med_w, med_h, _, _ = write_image_variant(source_abs, med_abs, MED_W, MED_Q)

    update_image_manifest(key) do |entry|
      entry['w'] = orig_w
      entry['h'] = orig_h
      entry['thumb'] = { 'src' => image_meta_key(thumb_abs), 'w' => thumb_w, 'h' => thumb_h }
      entry['med']   = { 'src' => image_meta_key(med_abs),   'w' => med_w,   'h' => med_h }
    end
  rescue StandardError => e
    warn "generate_thumbnails_for(#{source_abs}): #{e.message}"
  end

  def write_image_variant(source_abs, out_abs, max_w, quality)
    img = MiniMagick::Image.open(source_abs)
    orig_w = img.width
    orig_h = img.height
    img.combine_options do |c|
      c.auto_orient
      if File.extname(source_abs).downcase == '.png'
        c.background 'white'
        c.alpha 'remove'
        c.alpha 'off'
      end
      c.strip
      c.resize "#{max_w}x>"
      c.interlace 'Plane'
      c.quality quality.to_s
    end
    img.format 'jpg'
    img.write(out_abs)
    out = MiniMagick::Image.open(out_abs)
    [out.width, out.height, orig_w, orig_h]
  end

  def load_image_manifest
    return {} unless File.exist?(IMAGE_META_PATH)
    data = YAML.safe_load(File.read(IMAGE_META_PATH), aliases: false) || {}
    data.is_a?(Hash) ? data : {}
  rescue StandardError
    {}
  end

  def write_image_manifest(data)
    FileUtils.mkdir_p(File.dirname(IMAGE_META_PATH))
    sorted = data.keys.sort.each_with_object({}) { |k, acc| acc[k] = data[k] }
    header = <<~HEADER
      # Generated by scripts/generate_thumbnails.rb. Do not edit by hand.
      # Each key is a path under assets/images/. `cf_id` (when set) is reserved
      # for Cloudflare Images integration and is preserved on regeneration.
    HEADER
    tmp = "#{IMAGE_META_PATH}.tmp"
    File.write(tmp, header + sorted.to_yaml(line_width: -1))
    File.rename(tmp, IMAGE_META_PATH)
  end

  def update_image_manifest(key)
    manifest = load_image_manifest
    entry = manifest[key] || {}
    preserved_cf = entry['cf_id']
    yield entry
    entry['cf_id'] = preserved_cf if preserved_cf
    manifest[key] = entry
    write_image_manifest(manifest)
  end

  def remove_image_manifest_entry(key)
    return unless key
    manifest = load_image_manifest
    return unless manifest.key?(key)
    manifest.delete(key)
    write_image_manifest(manifest)
  end

  # Promote images from drafts/ to posts/ when publishing. Rewrites URLs in
  # both the body string and the images array. Returns the updated body.
  def promote_draft_images(body, images)
    body = body.to_s.dup
    draft_re = %r{/assets/images/drafts/([^\s\)"']+)}
    body.scan(draft_re).flatten.uniq.each do |filename|
      src = File.join(DRAFT_IMAGES_DIR, filename)
      dest = File.join(IMAGES_DIR, filename)
      if File.exist?(src)
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp(src, dest)
        File.delete(src) rescue nil
        cleanup_draft_variants(filename)
        generate_thumbnails_for(dest)
      end
      body.gsub!("/assets/images/drafts/#{filename}", "/assets/images/posts/#{filename}")
    end
    images.each do |img|
      next unless img['src'].to_s.include?('/assets/images/drafts/')
      fname = img['src'].split('/assets/images/drafts/').last
      src = File.join(DRAFT_IMAGES_DIR, fname)
      dest = File.join(IMAGES_DIR, fname)
      if File.exist?(src)
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp(src, dest)
        File.delete(src) rescue nil
        cleanup_draft_variants(fname)
        generate_thumbnails_for(dest)
      end
      img['src'] = img['src'].gsub('/assets/images/drafts/', '/assets/images/posts/')
    end
    body
  end

  # Remove the draft-side thumb/med JPEGs and manifest entry after a draft
  # image has been promoted to posts/.
  def cleanup_draft_variants(filename)
    draft_abs = File.join(DRAFT_IMAGES_DIR, filename)
    return unless VARIANT_EXTS.include?(File.extname(draft_abs).downcase)
    %w[thumb med].each do |v|
      variant_abs = variant_abs_path(draft_abs, v)
      File.delete(variant_abs) if File.exist?(variant_abs)
    end
    remove_image_manifest_entry(image_meta_key(draft_abs))
  end

  # Extract markdown images that embed base64 data URLs:
  #   ![alt](data:image/png;base64,AAAA...)
  # Writes decoded files under drafts/posts images folder and rewrites URLs.
  def extract_base64_images(body, slug:, draft:)
    out = body.to_s.dup
    dest_dir = draft ? DRAFT_IMAGES_DIR : IMAGES_DIR
    url_prefix = draft ? '/assets/images/drafts/' : '/assets/images/posts/'
    idx = 0

    # Stop at ')' to avoid swallowing the whole file. This matches the common markdown pattern.
    re = /!\[(?<alt>[^\]]*)\]\((?<data>data:(?<mime>image\/[^;)\s]+);base64,(?<b64>[^)]+))\)/
    out.gsub!(re) do
      idx += 1
      mime = Regexp.last_match(:mime)
      b64 = Regexp.last_match(:b64)
      ext = ext_for_mime(mime)
      filename_base = "embedded-#{sanitize_slug(slug)}-#{idx}"
      filename = "#{filename_base}.#{ext}"
      dest_path = File.join(dest_dir, filename)
      # Avoid overwriting if rerun
      n = 1
      while File.exist?(dest_path)
        filename = "#{filename_base}-#{n}.#{ext}"
        dest_path = File.join(dest_dir, filename)
        n += 1
      end

      decoded = Base64.decode64(b64)
      FileUtils.mkdir_p(dest_dir)
      File.binwrite(dest_path, decoded)

      alt = Regexp.last_match(:alt).to_s
      "![#{alt}](#{url_prefix}#{filename})"
    end

    out
  end
end

before do
  h = {
    'Access-Control-Allow-Methods' => 'GET,POST,PUT,DELETE,OPTIONS',
    'Access-Control-Allow-Headers' => 'Content-Type'
  }
  origin = request.env['HTTP_ORIGIN']
  if origin && (origin.start_with?('http://localhost:') || origin.start_with?('http://127.0.0.1:'))
    h['Access-Control-Allow-Origin'] = origin
  end
  headers h
end

options '/posts' do
  200
end

options '/posts/:kind/:slug' do
  200
end

options '/images' do
  200
end

options '/publish/:slug' do
  200
end

options '/posts/:kind/:slug/images' do
  200
end

options '/albums' do
  200
end

options '/albums/:slug' do
  200
end

options '/images/delete' do
  200
end

get '/posts' do
  posts = all_post_files.map { |path| parse_post(path) }.compact
  json(posts.map { |p| p.reject { |k, _| k == 'body' } })
end

get '/posts/:kind/:slug' do
  kind = params[:kind].to_s
  slug = sanitize_slug(params[:slug])
  path =
    if kind == 'draft'
      File.join(DRAFTS_DIR, "#{slug}.md")
    else
      post_files.find { |p| slug_from_path(p) == slug }
    end
  halt 404 unless path && File.exist?(path)
  post = parse_post(path)
  json(post)
end

post '/posts' do
  data = JSON.parse(request.body.read)
  title = data['title'].to_s.strip
  body = data['body'].to_s
  halt 400, 'title required' if title.empty?
  halt 400, 'body required' if body.strip.empty?

  slug = sanitize_slug(data['slug'] || title)
  date_str = data['date'].to_s.strip
  time = if date_str.empty?
           Time.now
         else
           Time.parse(date_str) rescue Time.now
         end
  tags = Array(data['tags'] || []).map { |t| t.to_s.strip }.reject(&:empty?)
  draft = !!data['draft']
  images = parse_images_from_data(data)

  body = extract_base64_images(body, slug: slug, draft: draft)
  promote_temp_images(body, images)
  body = promote_draft_images(body, images) unless draft
  images = merge_images(extract_body_images(body), images)

  front_matter = +"---\n"
  front_matter << "layout: post\n"
  front_matter << "title: \"#{title.gsub('"', '\"')}\"\n"
  front_matter << "date: #{time.iso8601}\n" unless draft
  front_matter << "tags: [#{tags.join(', ')}]\n" unless tags.empty?
  front_matter << images_to_frontmatter(images)
  front_matter << "---\n\n"

  if draft
    path = File.join(DRAFTS_DIR, "#{slug}.md")
  else
    date_prefix = time.strftime('%Y-%m-%d')
    filename = "#{date_prefix}-#{slug}.md"
    path = File.join(POSTS_DIR, filename)
  end

  File.write(path, front_matter + body)

  json({ slug: slug, kind: (draft ? 'draft' : 'post'), date: time.strftime('%Y-%m-%dT%H:%M') }, 201)
end

put '/posts/:kind/:slug' do
  kind = params[:kind].to_s
  orig_slug = sanitize_slug(params[:slug])
  existing_path =
    if kind == 'draft'
      File.join(DRAFTS_DIR, "#{orig_slug}.md")
    else
      post_files.find { |p| p.include?("-#{orig_slug}.md") }
    end
  halt 404 unless existing_path

  data = JSON.parse(request.body.read)
  title = data['title'].to_s.strip
  body = data['body'].to_s
  halt 400, 'title required' if title.empty?
  halt 400, 'body required' if body.strip.empty?

  slug = sanitize_slug(data['slug'] || orig_slug)
  date_str = data['date'].to_s.strip
  time = if date_str.empty?
           Time.now
         else
           Time.parse(date_str) rescue Time.now
         end
  tags = Array(data['tags'] || []).map { |t| t.to_s.strip }.reject(&:empty?)
  draft = !!data['draft']
  images = if data.key?('images')
             parse_images_from_data(data)
           else
             existing_post = parse_post(existing_path)
             (existing_post && existing_post['images']) || []
           end

  body = extract_base64_images(body, slug: slug, draft: draft)
  promote_temp_images(body, images)

  if draft
    new_path = File.join(DRAFTS_DIR, "#{slug}.md")
    # Demote images: copy from posts to drafts when converting post → draft
    if kind == 'post'
      body = body.dup
      post_image_regex = %r{/assets/images/posts/([^\s\)]+)}
      body.scan(post_image_regex).flatten.uniq.each do |filename|
        src = File.join(IMAGES_DIR, filename)
        dest = File.join(DRAFT_IMAGES_DIR, filename)
        if File.exist?(src)
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.cp(src, dest)
          File.delete(src) rescue nil
        end
        body.gsub!("/assets/images/posts/#{filename}", "/assets/images/drafts/#{filename}")
      end
      images.each do |img|
        if img['src'].include?('/assets/images/posts/')
          fname = img['src'].split('/assets/images/posts/').last
          src = File.join(IMAGES_DIR, fname)
          dest = File.join(DRAFT_IMAGES_DIR, fname)
          if File.exist?(src)
            FileUtils.mkdir_p(File.dirname(dest))
            FileUtils.cp(src, dest)
            File.delete(src) rescue nil
          end
          img['src'] = img['src'].gsub('/assets/images/posts/', '/assets/images/drafts/')
        end
      end
    end
  else
    body = promote_draft_images(body, images)
    date_prefix = time.strftime('%Y-%m-%d')
    filename = "#{date_prefix}-#{slug}.md"
    new_path = File.join(POSTS_DIR, filename)
  end

  images = merge_images(extract_body_images(body), images)

  front_matter = +"---\n"
  front_matter << "layout: post\n"
  front_matter << "title: \"#{title.gsub('"', '\"')}\"\n"
  front_matter << "date: #{time.iso8601}\n" unless draft
  front_matter << "tags: [#{tags.join(', ')}]\n" unless tags.empty?
  front_matter << images_to_frontmatter(images)
  front_matter << "---\n\n"

  File.write(new_path, front_matter + body)
  File.delete(existing_path) if File.exist?(existing_path) && existing_path != new_path

  json({ slug: slug, kind: (draft ? 'draft' : 'post'), date: time.strftime('%Y-%m-%dT%H:%M') })
end

# Save only the images array for a post (used by the album editor).
# Reads existing post, replaces images in frontmatter, rewrites file.
put '/posts/:kind/:slug/images' do
  kind = params[:kind].to_s
  slug = sanitize_slug(params[:slug])
  existing_path =
    if kind == 'draft'
      File.join(DRAFTS_DIR, "#{slug}.md")
    else
      post_files.find { |p| slug_from_path(p) == slug }
    end
  halt 404 unless existing_path && File.exist?(existing_path)

  post = parse_post(existing_path)
  halt 404 unless post

  data = JSON.parse(request.body.read)
  album_images = parse_images_from_data(data)
  promote_temp_images('', album_images)

  # Merge: body images auto-detected + explicit album images
  body = post['body'].to_s
  images = merge_images(extract_body_images(body), album_images)

  title = post['title']
  date = post['date']
  tags = post['tags'] || []
  draft = post['kind'] == 'draft'

  front_matter = +"---\n"
  front_matter << "layout: post\n"
  front_matter << "title: \"#{title.gsub('"', '\"')}\"\n"
  front_matter << "date: #{date}\n" if date && !draft
  front_matter << "tags: [#{tags.join(', ')}]\n" unless tags.empty?
  front_matter << images_to_frontmatter(images)
  front_matter << "---\n\n"

  File.write(existing_path, front_matter + body)

  json({ slug: slug, kind: kind, images: images })
end

delete '/posts/:kind/:slug' do
  kind = params[:kind].to_s
  slug = sanitize_slug(params[:slug])
  path =
    if kind == 'draft'
      File.join(DRAFTS_DIR, "#{slug}.md")
    else
      post_files.find { |p| p.include?("-#{slug}.md") }
    end
  halt 404 unless path && File.exist?(path)

  # Collect image srcs before deleting so we can clean up orphans
  post = parse_post(path)
  image_srcs = []
  if post
    image_srcs = (post['images'] || []).map { |i| i['src'] }
    # Also extract body images
    image_srcs += extract_body_images(post['body'].to_s).map { |i| i['src'] }
    image_srcs.uniq!
  end

  File.delete(path)

  # Delete orphaned image files
  image_srcs.each { |src| delete_image_if_orphaned(src, exclude_path: path) }

  status 204
end

post '/publish/:slug' do
  slug = sanitize_slug(params[:slug])
  draft_path = File.join(DRAFTS_DIR, "#{slug}.md")
  halt 404 unless File.exist?(draft_path)

  data = JSON.parse(request.body.read) rescue {}
  title = data['title'].to_s.strip
  body = data['body'].to_s
  halt 400, 'title required' if title.empty?
  halt 400, 'body required' if body.strip.empty?

  date_str = data['date'].to_s.strip
  time = if date_str.empty?
           Time.now
         else
           Time.parse(date_str) rescue Time.now
         end

  tags = Array(data['tags'] || []).map { |t| t.to_s.strip }.reject(&:empty?)
  images = if data.key?('images')
             parse_images_from_data(data)
           else
             existing_draft = parse_post(draft_path)
             (existing_draft && existing_draft['images']) || []
           end

  body = promote_draft_images(body, images)
  promote_temp_images(body, images)
  images = merge_images(extract_body_images(body), images)

  date_prefix = time.strftime('%Y-%m-%d')
  filename = "#{date_prefix}-#{slug}.md"
  post_path = File.join(POSTS_DIR, filename)

  front_matter = +"---\n"
  front_matter << "layout: post\n"
  front_matter << "title: \"#{title.gsub('"', '\"')}\"\n"
  front_matter << "date: #{time.iso8601}\n"
  front_matter << "tags: [#{tags.join(', ')}]\n" unless tags.empty?
  front_matter << images_to_frontmatter(images)
  front_matter << "---\n\n"

  File.write(post_path, front_matter + body)
  File.delete(draft_path)

  json({ slug: slug, kind: 'post', date: time.strftime('%Y-%m-%dT%H:%M') }, 201)
end

# --- Standalone Album CRUD ---

get '/albums' do
  albums = album_files.map { |path| parse_album(path) }.compact
  json(albums)
end

get '/albums/:slug' do
  slug = sanitize_slug(params[:slug])
  path = File.join(ALBUMS_DIR, "#{slug}.md")
  halt 404 unless File.exist?(path)
  album = parse_album(path)
  halt 404 unless album
  json(album)
end

post '/albums' do
  data = JSON.parse(request.body.read)
  title = data['title'].to_s.strip
  halt 400, 'title required' if title.empty?

  slug = sanitize_slug(data['slug'] || title)
  description = data['description'].to_s.strip[0, 500]
  draft = !!data['draft']
  images = parse_images_from_data(data)

  date_str = data['date'].to_s.strip
  time = if date_str.empty?
           Time.now
         else
           Time.parse(date_str) rescue Time.now
         end

  promote_temp_images('', images)

  album = {
    'title' => title,
    'date' => time.iso8601,
    'description' => description,
    'draft' => draft,
    'images' => images
  }

  path = File.join(ALBUMS_DIR, "#{slug}.md")
  File.write(path, album_to_file(album))

  json({ slug: slug, date: time.strftime('%Y-%m-%dT%H:%M') }, 201)
end

put '/albums/:slug' do
  slug = sanitize_slug(params[:slug])
  existing_path = File.join(ALBUMS_DIR, "#{slug}.md")
  halt 404 unless File.exist?(existing_path)

  data = JSON.parse(request.body.read)
  title = data['title'].to_s.strip
  halt 400, 'title required' if title.empty?

  new_slug = sanitize_slug(data['slug'] || slug)
  description = data['description'].to_s.strip[0, 500]
  draft = !!data['draft']
  images = parse_images_from_data(data)

  date_str = data['date'].to_s.strip
  time = if date_str.empty?
           Time.now
         else
           Time.parse(date_str) rescue Time.now
         end

  promote_temp_images('', images)

  album = {
    'title' => title,
    'date' => time.iso8601,
    'description' => description,
    'draft' => draft,
    'images' => images
  }

  new_path = File.join(ALBUMS_DIR, "#{new_slug}.md")
  File.write(new_path, album_to_file(album))
  File.delete(existing_path) if existing_path != new_path && File.exist?(existing_path)

  json({ slug: new_slug, date: time.strftime('%Y-%m-%dT%H:%M') })
end

delete '/albums/:slug' do
  slug = sanitize_slug(params[:slug])
  path = File.join(ALBUMS_DIR, "#{slug}.md")
  halt 404 unless File.exist?(path)

  album = parse_album(path)
  image_srcs = (album ? (album['images'] || []).map { |i| i['src'] } : [])

  File.delete(path)

  # Delete orphaned image files
  image_srcs.each { |src| delete_image_if_orphaned(src, exclude_path: path) }

  status 204
end

# --- Image Deletion ---

# Delete a specific image file if it's not referenced by any post or album.
# Accepts JSON body: { "src": "/assets/images/albums/photo.jpg" }
# Optionally pass "exclude_path" to ignore a specific file (e.g. the one being edited).
post '/images/delete' do
  data = JSON.parse(request.body.read)
  src = data['src'].to_s.strip
  halt 400, 'src required' if src.empty?

  # Optional: caller can specify which post/album to exclude from reference check
  # (because the caller is about to save without this image)
  exclude = data['exclude_path'].to_s.strip
  exclude = nil if exclude.empty?

  refs = find_image_references(src, exclude_path: exclude)
  if refs.empty?
    abs = File.join(ROOT, src.sub(%r{^/}, ''))
    if File.exist?(abs)
      File.delete(abs)
      json({ deleted: true, src: src })
    else
      json({ deleted: false, reason: 'file not found' })
    end
  else
    json({ deleted: false, reason: 'still referenced', references: refs.length })
  end
end

# Serve uploaded images directly so the editor preview works without
# waiting for Jekyll to rebuild. Checks temp dir first, then final location.
get '/assets/images/*' do |path|
  temp_path = File.join(TEMP_IMAGES_DIR, path)
  final_path = File.join(ROOT, 'assets', 'images', path)
  if File.exist?(temp_path)
    send_file temp_path
  elsif File.exist?(final_path)
    send_file final_path
  else
    halt 404
  end
end

post '/images' do
  file = params['image'] && params['image'][:tempfile]
  filename = params['image'] && params['image'][:filename]
  halt 400, 'no image' unless file && filename

  safe = filename.gsub(/[^a-zA-Z0-9.\-]/, '_')
  basename = File.basename(safe, '.*')
  ext = File.extname(safe)
  ts = Time.now.strftime('%Y%m%d%H%M%S')
  final_name = "#{ts}-#{basename}#{ext}"
  is_album = params['album'].to_s == 'true'
  is_draft = params['draft'].to_s == 'true'
  subdir = is_album ? 'albums' : (is_draft ? 'drafts' : 'posts')
  # Write to _editor_tmp/ so Jekyll doesn't detect the change and reload the page.
  # Images are promoted to assets/images/ when the post is saved.
  dest = File.join(TEMP_IMAGES_DIR, subdir, final_name)
  FileUtils.cp(file.path, dest)

  url = "/assets/images/#{subdir}/#{final_name}"
  json({ url: url, basename: basename }, 201)
end

