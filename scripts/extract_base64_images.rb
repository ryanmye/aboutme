#!/usr/bin/env ruby

require 'fileutils'
require 'base64'

ROOT = File.expand_path('..', __dir__)
POSTS_DIR = File.join(ROOT, '_posts')
DRAFTS_DIR = File.join(ROOT, '_drafts')
IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'posts')
DRAFT_IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'drafts')

def sanitize_slug(slug)
  slug.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-+|-+$/, '')
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

def split_front_matter(content)
  m = content.match(/\A---\s*\n(.*?)\n---\s*\n(.*)\z/m)
  return [nil, content] unless m
  [m[1], m[2]]
end

def wrap_with_front_matter(front_matter, body)
  return body unless front_matter
  +"---\n#{front_matter}\n---\n\n#{body}"
end

def extract_base64_images(body, slug:, draft:)
  out = body.to_s.dup
  dest_dir = draft ? DRAFT_IMAGES_DIR : IMAGES_DIR
  url_prefix = draft ? '/assets/images/drafts/' : '/assets/images/posts/'
  idx = 0

  re = /!\[(?<alt>[^\]]*)\]\((?<data>data:(?<mime>image\/[^;)\s]+);base64,(?<b64>[^)]+))\)/
  out.gsub!(re) do
    idx += 1
    mime = Regexp.last_match(:mime)
    b64 = Regexp.last_match(:b64)
    ext = ext_for_mime(mime)

    filename_base = "embedded-#{sanitize_slug(slug)}-#{idx}"
    filename = "#{filename_base}.#{ext}"
    dest_path = File.join(dest_dir, filename)
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

paths =
  Dir[File.join(POSTS_DIR, '*.md')].sort +
  Dir[File.join(DRAFTS_DIR, '*.md')].sort

updated_files = 0
extracted_images = 0

paths.each do |path|
  content = File.read(path)
  fm, body = split_front_matter(content)
  slug = if File.dirname(path).end_with?('_drafts')
           File.basename(path, '.md')
         else
           (File.basename(path, '.md').split('-', 4)[3] || File.basename(path, '.md'))
         end

  before = body.dup
  new_body = extract_base64_images(body, slug: slug, draft: File.dirname(path).end_with?('_drafts'))

  next if new_body == before

  extracted_images += before.scan(/data:image\/[^;)\s]+;base64,/).length
  File.write(path, wrap_with_front_matter(fm, new_body))
  updated_files += 1
end

puts "Updated #{updated_files} file(s). Extracted ~#{extracted_images} embedded image(s)."

