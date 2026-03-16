# Running the Website Locally

This site is built with [Jekyll](https://jekyllrb.com). Use these steps to preview changes locally.

## Prerequisites

- **Ruby** ≥ 3.0
- **Bundler**: `gem install bundler`

## Startup

```bash
# 1. Install dependencies (first time only, or after Gemfile changes)
bundle install

# 2. Start the development server (use --baseurl "" so assets load correctly)
bundle exec jekyll serve --livereload --baseurl ""
```

## View the site

Open **http://localhost:4000/** in your browser.

> **Tip:** Using `--baseurl ""` strips the GitHub Pages base path for local dev, so CSS and assets load correctly at the root. For production-like testing with `/aboutme/` paths, omit it and visit `http://localhost:4000/aboutme/`.

## Live reload

The `--livereload` flag reloads the browser when you edit files. Omit it if you prefer to refresh manually.
