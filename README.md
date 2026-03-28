# Personal Website — Ryan Ye

A clean, fast personal website built with [Jekyll 3.8](https://jekyllrb.com) and hosted on [GitHub Pages](https://pages.github.com). Includes a blog, photo gallery, project showcase, research section, CV, and a local editor with Sinatra API.

---

## Running Locally

### Prerequisites

- Ruby ≥ 3.0
- Bundler (`gem install bundler`)

### Setup

```bash
bundle install

# Serve with live reload (local dev mode — enables editor)
bundle exec jekyll serve --livereload --baseurl ""

# In a separate terminal: start the blog editor API (port 4001)
bundle exec ruby scripts/local_editor_server.rb
```

Visit `http://localhost:4000` in your browser.

### Production build

```bash
bundle exec jekyll build --config _config.yml,_config_prod.yml
```

---

## Local Blog Editor

The site includes a local-only web editor for creating and editing blog posts:

- Visit `http://localhost:4000/editor` to write posts with a WYSIWYG editor (Toast UI)
- Visit `http://localhost:4000/album-editor` to manage photo albums
- The editor server (`scripts/local_editor_server.rb`) handles file I/O, image uploads, and draft management
- Editor features are disabled in production builds (`_config_prod.yml`)

---

## Photo Gallery

- Blog posts can have photo albums — images are stored in post frontmatter
- Create standalone albums (not tied to a blog post) via the album editor
- Visit `/gallery` to see all albums; standalone albums have dedicated pages at `/albums/:slug/`

---

## GitHub Pages Deployment

1. Push to GitHub and go to **Settings → Pages**
2. Set source to branch `main`, folder `/ (root)`, click **Save**
3. Site will be live at `https://<username>.github.io/<repo-name>/`

Update `url` and `baseurl` in `_config.yml` to match your repository before deploying.

---

## Repository Structure

```
/
├── _config.yml              # Jekyll config (local_editor: true)
├── _config_prod.yml         # Production overrides (disables editor)
├── robots.txt               # Blocks AI training crawlers
├── ai.txt                   # AI opt-out (Spawning.ai standard)
├── _posts/                  # Blog posts (YYYY-MM-DD-slug.md)
├── _drafts/                 # Unpublished drafts (gitignored)
├── _albums/                 # Standalone photo albums (Jekyll collection)
├── _layouts/
│   ├── default.html         # Base layout
│   ├── post.html            # Blog post (with album grid)
│   ├── album.html           # Standalone album detail page
│   ├── editor.html          # Post editor (dev-only)
│   └── album-editor.html    # Album editor (dev-only)
├── _includes/
│   ├── head.html            # <head> with anti-AI meta tags on every page
│   ├── navbar.html          # Navigation + theme switcher
│   └── footer.html
├── _data/                   # YAML data files (profile, projects, research, etc.)
├── assets/
│   ├── css/styles.css       # Single stylesheet (25+ sections)
│   ├── js/
│   │   ├── theme.js         # 5-theme color system
│   │   ├── editor.js        # Post editor UI
│   │   └── album-editor.js  # Album editor UI
│   └── images/
│       ├── posts/           # Published post images
│       ├── drafts/          # Draft images (gitignored)
│       └── albums/          # Standalone album images
└── scripts/
    ├── local_editor_server.rb  # Sinatra REST API (port 4001)
    └── ...
```

See `CLAUDE.md` for a full codebase index (intended for LLM context).

---

## Anti-AI Policy

This site opts out of AI training data collection at every available layer:
- `robots.txt` blocks 20+ known AI crawlers by User-Agent
- Every page includes `<meta name="robots" content="noai, noimageai">`
- Every page includes `<meta name="tdm-reservation" content="1">` (W3C TDM protocol)
- `ai.txt` declares a site-wide opt-out (Spawning.ai standard)

---

## License

MIT — feel free to use this as a template for your own site.
