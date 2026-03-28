#!/usr/bin/env ruby

require 'yaml'
require 'time'

ROOT = File.expand_path('..', __dir__)
POSTS_DIR = File.join(ROOT, '_posts')
DRAFTS_DIR = File.join(ROOT, '_drafts')

def humanize_slug(slug)
  slug
    .to_s
    .strip
    .gsub(/[-_]+/, ' ')
    .split(/\s+/)
    .reject(&:empty?)
    .map { |w| w[0] ? w[0].upcase + w[1..] : w }
    .join(' ')
end

def slug_from_filename(path)
  base = File.basename(path, '.md')
  if File.dirname(path).end_with?('_drafts')
    base
  else
    base.split('-', 4)[3] || base
  end
end

def parse_front_matter_and_body(content)
  m = content.match(/\A---\s*\n(.*?)\n---\s*\n(.*)\z/m)
  return [nil, nil] unless m
  [m[1], m[2]]
end

def safe_load_yaml(yaml_str)
  parsed = YAML.safe_load(yaml_str, permitted_classes: [Date, Time], aliases: true)
  parsed.is_a?(Hash) ? parsed : {}
rescue StandardError
  {}
end

def dump_yaml(hash)
  # Keep it simple: YAML + trailing newline, then body separated by blank line.
  YAML.dump(hash).sub(/\A---\s*\n/, '').sub(/\n\.\.\.\s*\n\z/, '').strip + "\n"
end

paths =
  Dir[File.join(POSTS_DIR, '*.md')].sort +
  Dir[File.join(DRAFTS_DIR, '*.md')].sort

updated = 0
paths.each do |path|
  content = File.read(path)
  fm, body = parse_front_matter_and_body(content)
  next unless fm && body

  data = safe_load_yaml(fm)
  title = data['title'].to_s.strip
  next unless title.empty?

  slug = slug_from_filename(path)
  data['title'] = humanize_slug(slug)

  new_content = +"---\n"
  new_content << dump_yaml(data)
  new_content << "---\n\n"
  new_content << body

  File.write(path, new_content)
  updated += 1
end

puts "Backfilled titles in #{updated} file(s)."

