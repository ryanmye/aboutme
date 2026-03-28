# CLAUDE.md — Codebase Index

> **If you are an LLM modifying this repository, update the relevant sections of this file to reflect your changes before finishing.**
> Last updated: 2026-03-27

## Project Overview

Jekyll 3.8 personal website and blog for **Ryan Ye** (CS @ Cornell). Deployed on GitHub Pages at `ryanmye.github.io/aboutme`. Features data-driven pages (projects, research, about), a 5-theme color system, a local blog editor with Sinatra API, and automated Spotify "recently played" integration via GitHub Actions.

## Quick Reference

```bash
# Local development (Jekyll)
bundle exec jekyll serve --livereload --baseurl ""

# Local editor server (separate terminal, port 4001)
bundle exec ruby scripts/local_editor_server.rb

# Production build (CI uses both configs)
bundle exec jekyll build --config _config.yml,_config_prod.yml
```

- **Base URL:** `/aboutme` (GitHub Pages project site)
- **Permalink format:** `/blog/:year/:month/:day/:title/`
- **Themes:** 5 color themes via CSS custom properties — warm (default), linen, pure, barely, dark-mono
- **Fonts:** Inter (body), DM Serif Display (headings/brand), JetBrains Mono (code)
- **Spotify:** GitHub Actions updates `_data/now-playing.json` every 30 minutes

## Directory Tree

```
.
├── _config.yml              # Main Jekyll config
├── _config_prod.yml         # Production overrides (disables editor)
├── Gemfile                  # Ruby deps: jekyll 3.8, sinatra, kramdown-parser-gfm
├── .gitignore
├── CLAUDE.md                # This file (excluded from Jekyll build)
├── robots.txt               # Anti-AI crawler rules (blocks GPTBot, CCBot, etc.)
├── ai.txt                   # Machine-readable AI opt-out (Spawning.ai standard)
│
├── _layouts/
│   ├── default.html         # Base layout (head + navbar + footer + theme.js)
│   ├── post.html            # Blog post layout (title, date, tags, album grid, prev/next nav)
│   ├── album.html           # Standalone album detail page layout
│   ├── editor.html          # Local editor layout (Toast UI Editor, dev-only)
│   └── album-editor.html   # Album editor layout (dev-only, tabs for post/standalone albums)
│
├── _includes/
│   ├── head.html            # <head>: meta, OG tags, fonts, CSS
│   ├── navbar.html          # Sticky nav, 5-theme dots, mobile hamburger menu
│   └── footer.html          # Copyright, social links, faith statement
│
├── _data/
│   ├── profile.yml          # Name, email, social URLs
│   ├── about.yml            # Bio, interests, education, skills
│   ├── projects.yml         # 5 portfolio projects with tags/descriptions
│   ├── research.yml         # Research positions, publications, interests
│   └── now-playing.json     # Spotify track (auto-updated by GitHub Actions)
│
├── _posts/                  # Blog posts (YYYY-MM-DD-slug.md)
├── _drafts/                 # Unpublished drafts (slug.md)
├── _albums/                 # Standalone photo albums (slug.md, Jekyll collection)
│
├── index.md                 # Homepage
├── about.md                 # About page
├── blog.md                  # Blog listing
├── projects.md              # Projects showcase
├── research.md              # Research page
├── resume.md                # Resume page
├── cv.md                    # CV page
├── editor.md                # Editor page (dev-only)
├── album-editor.md          # Album editor page (dev-only)
├── gallery.md               # Photo gallery page (album cards + all photos grid)
├── now-playing.json.html    # Exposes _data/now-playing.json as static JSON endpoint
│
├── assets/
│   ├── css/styles.css       # Full stylesheet (23 sections)
│   ├── js/theme.js          # Theme switcher (localStorage persistence)
│   ├── js/editor.js         # Post editor UI (CRUD, image upload, Toast UI)
│   ├── js/album-editor.js   # Album editor UI (post albums + standalone albums + image deletion)
│   └── images/
│       ├── headshot.jpeg    # Profile photo
│       ├── posts/           # Published post images (timestamped)
│       ├── drafts/          # Draft post images (gitignored)
│       └── albums/          # Standalone album images
│
├── scripts/
│   ├── local_editor_server.rb      # Sinatra REST API for editing (port 4001)
│   ├── migrate_images_to_figures.rb # Converts md images to <figure> blocks
│   ├── extract_base64_images.rb     # Extracts inline base64 to files
│   ├── backfill_titles.rb           # Auto-generates missing post titles
│   └── get-spotify-refresh-token.py # One-time Spotify OAuth setup
│
├── .github/workflows/
│   └── update-spotify.yml   # Cron job: fetch Spotify → commit now-playing.json
│
├── _editor_tmp/             # Temp images during editing (not committed)
├── _site/                   # Built output (not committed)
├── 25Dec_Ye_Ryan_Resume.pdf # PDF resume
├── README.md                # Setup instructions
└── LOCAL_DEV.md             # Local dev guide
```

---

## Configuration Files

### _config.yml (35 lines)
Main Jekyll configuration. Key settings:
- `title: "Ryan Ye"`, `baseurl: "/aboutme"`, `url: "https://ryanmye.github.io"`
- `markdown: kramdown` with GFM input, Rouge syntax highlighter
- `permalink: /blog/:year/:month/:day/:title/`
- `local_editor: true` — enables editor nav link and page in development
- Default layout `post` applied to all files in `_posts/`
- Excludes: README.md, Gemfile, Gemfile.lock, node_modules, vendor

### _config_prod.yml (4 lines)
Production overlay (used in CI build). Overrides:
- `local_editor: false` — hides editor
- Excludes `editor.md` and `scripts/local_editor_server.rb` from build

### Gemfile
Dependencies: `jekyll ~> 3.8`, `webrick ~> 1.7`, `kramdown-parser-gfm`, `ffi ~> 1.15`, `sinatra ~> 3.0` (development group)

---

## Layouts

### _layouts/default.html (22 lines)
Base HTML5 layout for all non-post pages. Includes `head.html`, `navbar.html`, `footer.html`. Loads `theme.js` before `</body>`. **Used by:** index.md, about.md, blog.md, projects.md, research.md, resume.md, cv.md, editor.md (via editor.html which extends this pattern).

### _layouts/post.html (54 lines)
Blog post layout. Renders: `<article>` with title, ISO 8601 date (`date_to_xmlschema`), human-readable date (`"%B %-d, %Y"`), tag list (iterates `page.tags`), post content, previous/next navigation links. **Used by:** all files in `_posts/`.

### _layouts/editor.html (83 lines)
Local editor layout. Loads Toast UI Editor CSS/JS. Contains: post title input, datetime picker, tags input, draft checkbox, Toast UI Editor div, image upload form, action buttons (new/save/publish/delete), post list sidebar. **Conditionally rendered:** only when `site.local_editor == true` AND `jekyll.environment == "development"`. Loads `editor.js`.

---

## Includes

### _includes/head.html (30 lines)
HTML `<head>` contents:
- Meta: charset, viewport, dynamic title, description (excerpt truncated to 160 chars), author
- Anti-AI/crawler: `<meta name="robots" content="noai, noimageai">`, `<meta name="tdm-reservation" content="1">`
- Open Graph: type ("article" for posts, "website" otherwise), URL, title, description
- CSS: preloads `styles.css` with cache-busting timestamp
- Fonts: Google Fonts preconnect, loads Inter, DM Serif Display, JetBrains Mono
- Font Awesome 6.4.2 (loaded with `media="print" onload` for non-blocking)
- Favicon: inline base64 SVG graduation cap emoji

### _includes/navbar.html (54 lines)
Sticky top navigation bar:
- Brand link (site.author) to homepage
- 5 theme color dot buttons (`data-theme` attribute) with inline background-color previews
- Nav links: About (`/`), Research (`/research`), Projects (`/projects`), Blog (`/blog`), CV (`/cv`). Gallery linked from blog page header.
- Dev-only nav links: Editor (`/editor`), Albums (`/album-editor`)
- Conditional: Editor link shown only when `site.local_editor == true` AND `jekyll.environment == "development"`
- Mobile: hamburger toggle button (3 spans), click-outside-to-close JS, ARIA attributes
- Active link detection via `page.url` comparison

### _includes/footer.html (16 lines)
Site footer with: dynamic copyright year, "Jesus is King" statement, social links (GitHub, LinkedIn, email from site config). All external links use `target="_blank" rel="noopener noreferrer"`.

---

## Root Pages

### index.md (186 lines) — Homepage
**Layout:** default. **Data deps:** `site.data.about.skills`, `site.posts` (limit 3).

Sections:
1. **Profile card** — headshot, name, position (Cornell CS), social links, skills tags (from `_data/about.yml`)
2. **Spotify widget** — `#spotify-now-playing` span, populated by inline `<script>` that fetches `/assets/data/now-playing.json` with 5s timeout. Helper functions: `timeAgo(isoStr)`, `escapeHtml(str)`. Renders track name, artists, context (playlist/album), relative time.
3. **About blurb** — hardcoded summary paragraph
4. **Blog preview** — table of latest 3 posts (date + title + truncated excerpt)
5. **Research preview** — hardcoded Sun Lab entry

### about.md (44 lines) — About Page
**Layout:** default. **Data deps:** `site.data.about` (bio, education, skills, interests).
Renders full bio, education details (Cornell, GPA 4.05, coursework), research interests, and skills.

### blog.md (38 lines) — Blog Listing
**Layout:** default. Lists all `site.posts` in reverse chronological order. Each entry shows date, title link, tags, and truncated excerpt.

### projects.md (45 lines) — Projects
**Layout:** default. **Data deps:** `site.data.projects`.
Renders project cards by iterating `site.data.projects`. Each card: title, date range, description, tech tags, bullet points, optional GitHub link.

### research.md (72 lines) — Research
**Layout:** default. **Data deps:** `site.data.research`.
Sections: subtitle, research positions (with role, lab, description, focus areas, notes), publications list, research interests, Google Scholar link.

### resume.md (138 lines) — Resume
**Layout:** default. **Data deps:** `site.data.about`, `site.data.projects`, `site.data.research`.
Full resume page with education, skills, research positions, projects, publications. Pulls from multiple data files.

### cv.md (137 lines) — CV
**Layout:** default. Similar to resume.md but formatted as academic CV with additional sections (coursework, interests).

### editor.md (15 lines) — Editor Page
**Layout:** editor. Minimal wrapper that activates the editor layout. Only rendered in development when `local_editor: true`.

### gallery.md — Gallery Page
**Layout:** default. **Permalink:** `/gallery/`. Linked from blog page header ("gallery →"). Iterates both `site.posts` and `site.albums` (Jekyll collection), renders album cards for items with `images` frontmatter (cover image, title, date, photo count). Post-album cards link to the post URL; standalone album cards link to `/albums/:slug/`. Below albums, shows "All Photos" grid with every image across all posts and albums. Fully static — no JS needed. Standalone albums with `draft: true` are excluded.

### album-editor.md — Album Editor Page
**Layout:** album-editor. **Permalink:** `/album-editor/`. Dev-only. Tabbed interface: "Post Albums" tab lists blog posts for managing their photo albums; "Standalone Albums" tab lists standalone albums. Supports creating new standalone albums with title, description (max 500 chars), and draft flag. Removing an image from an album also deletes the file from disk (if not referenced elsewhere). Post albums use `PUT /posts/:kind/:slug/images`; standalone albums use `POST/PUT/DELETE /albums/:slug`.

### now-playing.json.html (5 lines) — Spotify JSON Endpoint
**Layout:** null. **Permalink:** `/assets/data/now-playing.json`.
Outputs `site.data['now-playing']` as JSON via Liquid `jsonify` filter. This is how the homepage JS fetches Spotify data from the static site.

---

## Data Files

### _data/profile.yml
Author identity: name ("Ryan Ye"), email, short description, social links (GitHub, LinkedIn, Google Scholar URLs).

### _data/about.yml
Structured resume data:
- `bio`: multi-line description
- `interests`: list of 4 research areas (ML, CV, AI for science, representation learning)
- `education`: institution (Cornell), degree (B.S. CS, College of Engineering), expected May 2028, GPA 4.05, coursework by category
- `skills`: programming (Python, Java, C/C++, OCaml), machine_learning (PyTorch, HF Transformers, NumPy, pandas, Matplotlib), tools (Git, VS Code, Jupyter, etc.)

### _data/projects.yml
Ordered list of 5 projects, each with: `title`, `date` (range string), `description`, `tags` (array), `bullets` (array), optional `url`. Projects: Calf Behavior Analysis, Traveling Salesman (hackathon), Sisyphus (AI productivity app), Piano Melody Generation, Personal Website.

### _data/research.yml
- `subtitle`: research focus statement
- `scholar_url`: Google Scholar link
- `positions`: 2 entries (MABe25 benchmark, AI for Animal Behavior) each with role, lab, PI, description, focus areas, notes
- `publications`: 1 entry (economics paper, 2023)
- `interests`: 4 research interest areas

### _data/now-playing.json
Auto-updated by GitHub Actions every 30 min. Schema:
```json
{
  "track": {
    "name": "...", "url": "spotify:track:...",
    "artists": [{"name": "...", "url": "..."}],
    "played_at": "ISO8601"
  },
  "fetched_at": "ISO8601",
  "context": { "type": "playlist|album|artist", "name": "...", "url": "..." }
}
```

---

## Blog Posts

| File | Title | Date | Tags |
|------|-------|------|------|
| `2026-01-01-first-post.md` | Hello, World — Welcome to My Blog | Jan 1, 2026 | life-update, meta, jekyll |
| `2026-01-20-spring-semester-started.md` | Spring 2026 Semester Started | Jan 20, 2026 | life-update |
| `2026-03-10-research-symposium-accepted.md` | Abstract accepted to ADSA! | Mar 12, 2026 | research, life-update |
| `2026-03-17-first-real-blog-post.md` | first real blog post | Mar 17, 2026 | life update |

Post front matter schema: `layout: post`, `title`, `date` (YYYY-MM-DD or ISO 8601 with timezone), `tags` (array), optional `excerpt`, optional `images` (array of `{src, caption}` for photo album — displayed on gallery page).

---

## Assets

### assets/css/styles.css
Single stylesheet with 23 sections. CSS custom properties for theming (11 variables: `--bg`, `--surface`, `--border`, `--text`, `--muted`, `--accent`, `--accent-soft`, `--accent-dark`, `--color-code-bg`, `--color-code-text`, `--theme-dot-border`). Max width: 960px.

**Section index:**

| Line | Section |
|------|---------|
| 1 | CSS Reset & Base |
| 10 | Custom Properties (theme defaults) |
| 55 | Base Typography |
| 131 | Layout (site wrapper, container) |
| 152 | Navigation (sticky, al-folio tab style) |
| 283 | Footer |
| 347 | Editor (form styling) |
| 517 | Profile Section (avatar, social, bio, skills) |
| 666 | Content / Page Sections |
| 690 | Section Headers (blog/page headings) |
| 715 | Page Header (inner pages) |
| 737 | Cards (project showcase, hover effects) |
| 815 | Tags |
| 838 | Blog / Post List |
| 876 | Blog Post Page (article styling, figures, code blocks) |
| ~1015 | Gallery Page (album cards grid, all-photos grid) |
| ~1095 | Album Detail Page (album grid, album description, post album section) |
| ~1166 | Editor Album Section (thumbnail rows, caption inputs, tabs) |
| ~1160 | Research / Publications |
| ~1215 | CV / Resume Page |
| ~1335 | Skills list (inline tags) |
| ~1355 | Responsive (mobile breakpoints) |
| ~1430 | Spotify Widget |
| ~1460 | Announcements / News Table |

Key patterns: always use `var(--name)` for colors, never hardcode hex values in component styles. Reduced-motion media query at L36 disables transitions.

### assets/js/theme.js (108 lines)
IIFE that manages the 5-theme color system:
- **Themes:** warm (cream/terracotta, default), linen (neutral warm), pure (black-on-white), barely (dark warm), dark-mono (dark grayscale)
- **`setTheme(key)`** — applies CSS custom properties to `document.documentElement.style`, saves to `localStorage["theme"]`
- **`updateToggleUI(key)`** — highlights active theme dot button
- Runs synchronously on load (prevents flash of wrong theme)
- Event listeners on `.theme-dot` buttons

### assets/js/editor.js
Blog post editor UI. **Depends on:** Toast UI Editor library (loaded by editor.html layout), `local_editor_server.rb` API on port 4001.

Key functions:
- **`serializeForm()`** — collects title, date, tags, draft status, body, slug from form
- **`toSlug(str)`** — converts titles to URL-safe slugs
- **`refreshPostList()`** — `GET /posts`, renders post/draft list with click-to-load
- **`loadPostIntoForm(post)`** — populates form fields
- **Image upload:** `POST /images` with caption, inserts as markdown `![alt](url)` + `*caption*`. Keyboard shortcut: Cmd+Shift+K (Mac) / Ctrl+Shift+K. Intercepts Toast UI Editor paste to prevent base64 embedding.

API origin configurable via `data-api-origin` attribute (defaults to `http://localhost:4001`).

### assets/js/album-editor.js
Album editor UI with tabs for post albums and standalone albums. **Depends on:** `local_editor_server.rb` API on port 4001.

Key features:
- **Tabbed interface:** "Post Albums" tab lists blog posts; "Standalone Albums" tab lists standalone albums
- **Post albums:** separates body-detected images (read-only, shown dimmed) from album-only images (editable). Saves via `PUT /posts/:kind/:slug/images`
- **Standalone albums:** title, description (max 500 chars with counter), draft checkbox. Saves via `POST/PUT /albums/:slug`
- Upload images to album (up to 25 total), add captions, remove
- **Image deletion:** removing an image calls `POST /images/delete` to delete the file from disk (server checks if referenced elsewhere first)
- Delete standalone album button (calls `DELETE /albums/:slug`, cleans up orphaned images)

### assets/images/
- `headshot.jpeg` — profile photo (412KB)
- `posts/` — published post images, naming convention: `YYYYMMDDHHMMSS-originalname.ext`
- `drafts/` — draft post images (same naming convention, gitignored)
- `albums/` — standalone album images (same naming convention)

---

## Scripts

### scripts/local_editor_server.rb
Sinatra REST API on `127.0.0.1:4001` for local blog editing. **Depends on:** sinatra, json, yaml, base64.

**Endpoints:**

| Method | Route | Purpose |
|--------|-------|---------|
| `GET` | `/posts` | List all posts + drafts (metadata only) |
| `GET` | `/posts/:kind/:slug` | Read single post/draft with full body |
| `POST` | `/posts` | Create new post or draft |
| `PUT` | `/posts/:kind/:slug` | Update existing post/draft |
| `PUT` | `/posts/:kind/:slug/images` | Save album images only (used by album editor) |
| `DELETE` | `/posts/:kind/:slug` | Delete post/draft + orphaned images |
| `POST` | `/publish/:slug` | Convert draft to published post |
| `GET` | `/albums` | List all standalone albums |
| `GET` | `/albums/:slug` | Read single standalone album |
| `POST` | `/albums` | Create standalone album |
| `PUT` | `/albums/:slug` | Update standalone album |
| `DELETE` | `/albums/:slug` | Delete standalone album + orphaned images |
| `POST` | `/images` | Upload image file (supports `album=true` param) |
| `POST` | `/images/delete` | Delete image file if not referenced elsewhere |
| `GET` | `/assets/images/*` | Serve images from temp or final dirs |
| `OPTIONS` | `*` | CORS preflight |

**Key helpers:**
- `parse_post(path)` — extracts YAML front matter (including `images` array) + markdown body
- `parse_album(path)` — extracts album YAML front matter (title, description, images, draft)
- `album_to_file(album)` — serializes album hash to YAML frontmatter file content
- `parse_images_from_data(data)` — validates and normalizes `images` array from request JSON
- `images_to_frontmatter(images)` — serializes images array to YAML for frontmatter output
- `extract_body_images(body)` — parses markdown body for `![alt](url)` + optional `*caption*` patterns, returns `[{src, caption}]`
- `merge_images(body_images, album_images)` — deduplicates by src, album images take priority for captions
- `promote_temp_images(body, images=[])` — moves images from `_editor_tmp/` to `assets/images/`, scans body + album `src` paths (supports posts/drafts/albums subdirs)
- `find_image_references(src, exclude_path:)` — scans all posts + albums for references to an image src
- `delete_image_if_orphaned(src, exclude_path:)` — deletes image file only if no other post/album references it
- `extract_base64_images(body, kind, slug)` — decodes inline base64 data URLs, saves as files
- `ext_for_mime(mime)` — MIME type to file extension mapping

**Image flow:** upload → `_editor_tmp/{posts|drafts|albums}/YYYYMMDDHHMMSS-filename.ext` → promoted to `assets/images/{posts|drafts|albums}/` on save. Draft↔post conversion rewrites paths in `images` frontmatter. Deleting a post/album also deletes orphaned image files.

**CORS:** restricted to localhost origins only.

### scripts/migrate_images_to_figures.rb (114 lines)
One-time migration script. Converts markdown image+caption patterns:
```
![alt](url)
*caption*
```
to HTML `<figure class="post-image">` blocks with `<figcaption>`. Skips files already using `<figure>`.

### scripts/extract_base64_images.rb (98 lines)
One-time cleanup script. Finds base64 `data:image/...;base64,...` URLs in post markdown, decodes and saves as files to `assets/images/posts/`, replaces inline data with file paths. Naming: `embedded-{slug}-{index}.{ext}`.

### scripts/backfill_titles.rb (75 lines)
Maintenance script. Reads all posts/drafts, fills in missing `title` front matter by humanizing the slug (e.g., `hello-world` → `Hello World`).

### scripts/get-spotify-refresh-token.py (152 lines)
One-time setup script for Spotify integration. Runs OAuth 2.0 authorization code flow:
1. Opens browser to Spotify auth page
2. Captures callback on `localhost:8888`
3. Exchanges code for refresh token
4. Prints token for GitHub Secrets setup

**Scope:** `user-read-recently-played`. **Dependencies:** Python stdlib only.

---

## GitHub Actions

### .github/workflows/update-spotify.yml (111 lines)
Automated Spotify "recently played" sync.

**Trigger:** cron every 30 min (`*/30 * * * *`) + manual `workflow_dispatch`.

**Steps:**
1. Checkout repo
2. Embedded Python script: exchanges refresh token → access token → `GET /v1/me/player/recently-played?limit=1` → extracts track metadata (name, URL, artists, played_at, context) → writes `_data/now-playing.json`
3. Auto-commit with `[skip ci]` flag as `github-actions[bot]`

**Required secrets:** `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`, `SPOTIFY_REFRESH_TOKEN`

---

## Architecture & Data Flow

### Build Pipeline
`_config.yml` + `_config_prod.yml` (overlay) → Jekyll 3.8 → `_site/`

### Page Rendering
`page.md` → selects layout from front matter → layout includes `head.html`, `navbar.html`, `footer.html` → loads `theme.js` → Liquid reads from `_data/*.yml`

### Theme System
`navbar.html` renders 5 theme dots → user clicks → `theme.js` reads dot's `data-theme`, calls `setTheme()` → applies CSS custom properties to `:root` → `styles.css` uses `var(--*)` throughout → persisted to `localStorage["theme"]`

### Spotify Widget
`update-spotify.yml` (cron 30min) → Spotify API → writes `_data/now-playing.json` → Jekyll builds `now-playing.json.html` (permalink `/assets/data/now-playing.json`) → `index.md` inline JS fetches JSON → renders track info in `#spotify-now-playing`

### Local Editor System
`editor.md` (layout: editor) → `editor.html` loads Toast UI Editor + `editor.js` → `editor.js` CRUD calls to `local_editor_server.rb:4001` → server reads/writes `_posts/`, `_drafts/`, manages images in `_editor_tmp/` and `assets/images/`.

### Photo Gallery
`gallery.md` (linked from blog page) iterates both `site.posts` and `site.albums` → renders album cards (cover, title, count) + full photo grid. Post-album cards link to the post URL (album grid rendered at bottom of post page). Standalone album cards link to `/albums/:slug/` (dedicated detail page). Fully static — no JS. Draft standalone albums (`draft: true`) excluded from gallery.

**Image sources for post albums:**
1. **Auto-detected:** server extracts `![alt](url)` patterns from post body on save → merged into `images` frontmatter
2. **Album editor:** separate page (`/album-editor/`) for adding extra images with captions → saved via `PUT /posts/:kind/:slug/images`

**Standalone albums:** `_albums/` collection with `output: true`. Each `.md` file has frontmatter: `title`, `date`, `description` (max 500 chars), `draft`, `images: [{src, caption}]`. Layout: `album.html`. Images stored in `assets/images/albums/`.

**Image deletion security:** removing an image from an album calls `POST /images/delete` → server checks all posts + albums for references → only deletes if orphaned. Deleting a post/album also cleans up orphaned images. Draft images in `assets/images/drafts/` are gitignored and won't be published.

---

## Conventions & Patterns

- **Post filenames:** `YYYY-MM-DD-slug.md` in `_posts/`, `slug.md` in `_drafts/`
- **Post front matter:** `layout: post`, `title: "..."`, `date: YYYY-MM-DD` (or ISO 8601), `tags: [array]`, optional `excerpt: "..."`, optional `images: [{src, caption}]` (photo album, max 25)
- **Album filenames:** `slug.md` in `_albums/`
- **Album front matter:** `layout: album`, `title: "..."`, `date: YYYY-MM-DD`, `description: "..."` (max 500 chars), optional `draft: true`, `images: [{src, caption}]`
- **Image naming:** `YYYYMMDDHHMMSS-originalname.ext` (timestamp prefix, set by editor server)
- **CSS theming:** always use `var(--name)` for colors; never hardcode hex in component styles
- **Data access:** `_data/` files accessed as `site.data.filename` in Liquid
- **Conditional editor:** nav link + page only appear when `site.local_editor == true` AND `jekyll.environment == "development"`
- **External deps:** Font Awesome 6.4.2, Google Fonts (Inter, DM Serif Display, JetBrains Mono), Toast UI Editor (editor only)
- **Blog post images:** use markdown `![caption](url)` followed by `*caption*` on the next line (styled by CSS `:has()` selector). Avoid `<figure>` HTML — Toast UI Editor strips it during round-trip.
- **Links:** all external links use `target="_blank" rel="noopener noreferrer"`
- **Anti-AI defense:** 4 layers — (1) `robots.txt` blocks known AI crawlers by User-Agent, (2) `<meta name="robots" content="noai, noimageai">` on every page, (3) `<meta name="tdm-reservation" content="1">` (W3C TDM protocol) on every page, (4) `ai.txt` machine-readable AI opt-out
