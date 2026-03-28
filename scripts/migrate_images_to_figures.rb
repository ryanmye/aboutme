#!/usr/bin/env ruby

require 'fileutils'

ROOT = File.expand_path('..', __dir__)
POSTS_DIR = File.join(ROOT, '_posts')
DRAFTS_DIR = File.join(ROOT, '_drafts')

def files_to_process
  Dir[File.join(POSTS_DIR, '*.md')].sort + Dir[File.join(DRAFTS_DIR, '*.md')].sort
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

def escape_html(text)
  text.to_s
      .gsub('&', '&amp;')
      .gsub('<', '&lt;')
      .gsub('>', '&gt;')
end

FIGURE_TEMPLATE = <<~HTML.chomp

<figure class="post-image">
  <img src="%<src>s" alt="%<alt>s" />
  <figcaption>%<caption>s</figcaption>
</figure>

HTML

# Convert markdown pattern:
#   ![alt](url)
#   *caption*   (or _caption_)
#
# into a <figure> block. Keeps surrounding text intact.
def convert_markdown_image_captions(body)
  changed = false
  lines = body.lines
  out = []

  i = 0
  while i < lines.length
    line = lines[i]
    img = line.match(/\A!\[(?<alt>[^\]]*)\]\((?<url>[^)\s]+)\)\s*\z/)
    if img
      j = i + 1
      # allow blank lines between image and caption
      j += 1 while j < lines.length && lines[j].strip.empty?
      cap_line = j < lines.length ? lines[j] : nil
      cap =
        if cap_line
          m1 = cap_line.match(/\A\*(?<cap>.+?)\*\s*\z/)
          m2 = cap_line.match(/\A_(?<cap>.+?)_\s*\z/)
          (m1 && m1[:cap]) || (m2 && m2[:cap])
        end

      if cap
        src = img[:url]
        alt = img[:alt].to_s.strip
        caption = cap.to_s.strip
        alt = caption if alt.empty?

        out << FIGURE_TEMPLATE % {
          src: escape_html(src),
          alt: escape_html(alt),
          caption: escape_html(caption)
        }

        changed = true
        # skip image line + any blanks + caption line
        i = j + 1
        next
      end
    end

    out << line
    i += 1
  end

  [out.join, changed]
end

# Normalize existing editor figure blocks to ensure they include figcaption and alt.
# If a file already uses <figure class="post-image">, we leave it as-is.
def already_has_figures?(body)
  body.include?('<figure class="post-image">')
end

updated = 0
files_to_process.each do |path|
  content = File.read(path)
  fm, body = split_front_matter(content)

  # If it already uses figures, don't touch it.
  next if already_has_figures?(body)

  new_body, changed = convert_markdown_image_captions(body)
  next unless changed

  File.write(path, wrap_with_front_matter(fm, new_body))
  updated += 1
end

puts "Migrated #{updated} file(s) to <figure> captions."

