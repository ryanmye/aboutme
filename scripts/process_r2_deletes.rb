#!/usr/bin/env ruby
# frozen_string_literal: true

require 'time'
require 'yaml'
require 'aws-sdk-s3'

ROOT = File.expand_path('..', __dir__)
QUEUE_PATH = File.join(ROOT, '_data', 'r2_delete_queue.yml')

def env!(name)
  value = ENV[name].to_s.strip
  abort "error: set #{name}" if value.empty?
  value
end

def r2_endpoint
  explicit = ENV['CLOUDFLARE_R2_S3_ENDPOINT'].to_s.strip
  return explicit unless explicit.empty?
  account_id = env!('CLOUDFLARE_ACCOUNT_ID')
  "https://#{account_id}.r2.cloudflarestorage.com"
end

def s3_client
  @s3_client ||= Aws::S3::Client.new(
    region: 'auto',
    endpoint: r2_endpoint,
    access_key_id: env!('CLOUDFLARE_R2_ACCESS_KEY_ID'),
    secret_access_key: env!('CLOUDFLARE_R2_SECRET_ACCESS_KEY'),
    force_path_style: true
  )
end

def bucket
  env!('CLOUDFLARE_R2_BUCKET')
end

def load_items
  return [] unless File.exist?(QUEUE_PATH)
  data = YAML.safe_load(File.read(QUEUE_PATH), aliases: false) || {}
  items = data['items']
  items.is_a?(Array) ? items : []
rescue StandardError
  []
end

def write_items(items)
  payload = { 'items' => items.sort_by { |i| i['scheduled_delete_at'].to_s } }
  tmp = "#{QUEUE_PATH}.tmp"
  File.write(tmp, payload.to_yaml(line_width: -1))
  File.rename(tmp, QUEUE_PATH)
end

def due?(item, now)
  at = Time.parse(item['scheduled_delete_at'].to_s) rescue nil
  at && at <= now
end

def delete_remote(key)
  return true if key.to_s.strip.empty?
  s3_client.delete_object(bucket: bucket, key: key)
  true
rescue Aws::S3::Errors::NoSuchKey
  true
rescue StandardError => e
  warn "delete failed for #{key}: #{e.message}"
  false
end

now = Time.now.utc
items = load_items
kept = []
deleted = 0

items.each do |item|
  if due?(item, now)
    key = item['r2_key'].to_s
    if delete_remote(key)
      deleted += 1
    else
      kept << item
    end
  else
    kept << item
  end
end

write_items(kept)
puts "deleted_remote: #{deleted}"
puts "remaining_queue: #{kept.length}"
