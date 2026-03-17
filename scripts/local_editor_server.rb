#!/usr/bin/env ruby
# Local-only blog editor API. Run separately from Jekyll:
#   bundle exec ruby scripts/local_editor_server.rb

require 'sinatra'
require 'json'
require 'fileutils'
require 'time'

set :bind, '127.0.0.1'
set :port, 4001

ROOT = File.expand_path('..', __dir__)
POSTS_DIR = File.join(ROOT, '_posts')
DRAFTS_DIR = File.join(ROOT, '_drafts')
IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'posts')
DRAFT_IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'drafts')

FileUtils.mkdir_p(POSTS_DIR)
FileUtils.mkdir_p(DRAFTS_DIR)
FileUtils.mkdir_p(IMAGES_DIR)
FileUtils.mkdir_p(DRAFT_IMAGES_DIR)

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
      data = {}
      front_matter.each_line do |line|
        if line =~ /\A(\w+):\s*(.*)\z/
          key = Regexp.last_match(1)
          value = Regexp.last_match(2).strip
          data[key] = value
        end
      end
      title = data['title'] || File.basename(path, '.md')
      date = data['date']
      tags = (data['tags'] || '').gsub(/[\[\]]/, '').split(',').map(&:strip).reject(&:empty?)
      draft = (data['draft'].to_s == 'true')
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
end

before do
  headers 'Access-Control-Allow-Origin' => 'http://localhost:4000',
          'Access-Control-Allow-Methods' => 'GET,POST,PUT,DELETE,OPTIONS',
          'Access-Control-Allow-Headers' => 'Content-Type'
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

  front_matter = +"---\n"
  front_matter << "layout: post\n"
  front_matter << "title: \"#{title.gsub('"', '\"')}\"\n"
  front_matter << "date: #{time.iso8601}\n" unless draft
  front_matter << "tags: [#{tags.join(', ')}]\n" unless tags.empty?
  front_matter << "---\n\n"

  if draft
    new_path = File.join(DRAFTS_DIR, "#{slug}.md")
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
  dest = File.join(is_draft ? DRAFT_IMAGES_DIR : IMAGES_DIR, final_name)
  FileUtils.cp(file.path, dest)

  url = is_draft ? "/assets/images/drafts/#{final_name}" : "/assets/images/posts/#{final_name}"
  json({ url: url, basename: basename }, 201)
end

