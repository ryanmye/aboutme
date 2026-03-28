#!/usr/bin/env ruby
# Local-only blog editor API. Run separately from Jekyll:
#   bundle exec ruby scripts/local_editor_server.rb

require 'sinatra'
require 'json'
require 'fileutils'
require 'time'
require 'yaml'
require 'base64'

set :bind, '127.0.0.1'
set :port, 4001

ROOT = File.expand_path('..', __dir__)
POSTS_DIR = File.join(ROOT, '_posts')
DRAFTS_DIR = File.join(ROOT, '_drafts')
IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'posts')
DRAFT_IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'drafts')
TEMP_IMAGES_DIR = File.join(ROOT, '_editor_tmp')

FileUtils.mkdir_p(POSTS_DIR)
FileUtils.mkdir_p(DRAFTS_DIR)
FileUtils.mkdir_p(IMAGES_DIR)
FileUtils.mkdir_p(DRAFT_IMAGES_DIR)
FileUtils.mkdir_p(File.join(TEMP_IMAGES_DIR, 'posts'))
FileUtils.mkdir_p(File.join(TEMP_IMAGES_DIR, 'drafts'))

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
      title = File.basename(path, '.md') if title.empty?

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
      slug = slug_from_path(path)
      {
        'title' => title,
        'date' => date,
        'tags' => tags,
        'draft' => draft,
        'kind' => (File.dirname(path) == DRAFTS_DIR ? 'draft' : 'post'),
        'slug' => slug,
        'body' => body
      }
    else
      nil
    end
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
  def promote_temp_images(body)
    body.scan(%r{/assets/images/(posts|drafts)/([^\s\)"']+)}).each do |subdir, filename|
      temp = File.join(TEMP_IMAGES_DIR, subdir, filename)
      dest = File.join(ROOT, 'assets', 'images', subdir, filename)
      if File.exist?(temp)
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.mv(temp, dest)
      end
    end
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

  body = extract_base64_images(body, slug: slug, draft: draft)
  promote_temp_images(body)

  front_matter = +"---\n"
  front_matter << "layout: post\n"
  front_matter << "title: \"#{title.gsub('"', '\"')}\"\n"
  front_matter << "date: #{time.iso8601}\n" unless draft
  front_matter << "tags: [#{tags.join(', ')}]\n" unless tags.empty?
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

  body = extract_base64_images(body, slug: slug, draft: draft)
  promote_temp_images(body)

  front_matter = +"---\n"
  front_matter << "layout: post\n"
  front_matter << "title: \"#{title.gsub('"', '\"')}\"\n"
  front_matter << "date: #{time.iso8601}\n" unless draft
  front_matter << "tags: [#{tags.join(', ')}]\n" unless tags.empty?
  front_matter << "---\n\n"

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
        end
        body.gsub!("/assets/images/posts/#{filename}", "/assets/images/drafts/#{filename}")
      end
    end
  else
    date_prefix = time.strftime('%Y-%m-%d')
    filename = "#{date_prefix}-#{slug}.md"
    new_path = File.join(POSTS_DIR, filename)
  end

  File.write(new_path, front_matter + body)
  File.delete(existing_path) if File.exist?(existing_path) && existing_path != new_path

  json({ slug: slug, kind: (draft ? 'draft' : 'post'), date: time.strftime('%Y-%m-%dT%H:%M') })
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
  File.delete(path)
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

  # Promote draft images: copy from assets/images/drafts -> assets/images/posts
  # and rewrite URLs in the body.
  body = data['body'].to_s.dup
  draft_image_regex = %r{/assets/images/drafts/([^\s\)]+)}
  body.scan(draft_image_regex).flatten.uniq.each do |filename|
    src = File.join(DRAFT_IMAGES_DIR, filename)
    dest = File.join(IMAGES_DIR, filename)
    if File.exist?(src)
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(src, dest)
      File.delete(src) rescue nil
    end
    body.gsub!("/assets/images/drafts/#{filename}", "/assets/images/posts/#{filename}")
  end

  promote_temp_images(body)

  date_prefix = time.strftime('%Y-%m-%d')
  filename = "#{date_prefix}-#{slug}.md"
  post_path = File.join(POSTS_DIR, filename)

  front_matter = +"---\n"
  front_matter << "layout: post\n"
  front_matter << "title: \"#{title.gsub('"', '\"')}\"\n"
  front_matter << "date: #{time.iso8601}\n"
  front_matter << "tags: [#{tags.join(', ')}]\n" unless tags.empty?
  front_matter << "---\n\n"

  File.write(post_path, front_matter + body)
  File.delete(draft_path)

  json({ slug: slug, kind: 'post', date: time.strftime('%Y-%m-%dT%H:%M') }, 201)
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
  is_draft = params['draft'].to_s == 'true'
  subdir = is_draft ? 'drafts' : 'posts'
  # Write to _editor_tmp/ so Jekyll doesn't detect the change and reload the page.
  # Images are promoted to assets/images/ when the post is saved.
  dest = File.join(TEMP_IMAGES_DIR, subdir, final_name)
  FileUtils.cp(file.path, dest)

  url = "/assets/images/#{subdir}/#{final_name}"
  json({ url: url, basename: basename }, 201)
end

