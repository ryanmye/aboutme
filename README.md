# Personal Website

A clean, fast personal website built with [Jekyll](https://jekyllrb.com) and hosted
on [GitHub Pages](https://pages.github.com). Includes a blog, project showcase,
research section, and resume.

---

## 🚀 Enabling GitHub Pages Deployment

1. Push this repository to GitHub (or fork it).
2. Go to your repository **Settings → Pages**.
3. Under **Source**, select **Deploy from a branch**.
4. Choose branch `main` (or `master`) and folder `/ (root)`, then click **Save**.
5. After a minute, your site will be live at:
   ```
   https://<your-username>.github.io/<repo-name>/
   ```

> **Note:** Update `url` and `baseurl` in `_config.yml` to match your GitHub
> username and repository name before deploying.

---

## ✏️ Adding a New Blog Post

1. Create a new file in the `_posts/` directory following the naming convention:
   ```
   _posts/YYYY-MM-DD-your-post-title.md
   ```
   Example: `_posts/2026-03-15-my-new-post.md`

2. Add front matter at the top of the file:
   ```yaml
   ---
   layout: post
   title: "Your Post Title"
   date: 2026-03-15
   tags: [tag1, tag2, tag3]
   excerpt: "A one-sentence summary shown in post listings."
   ---
   ```

3. Write your post content in Markdown below the front matter.

4. Commit and push — Jekyll will automatically pick up the new post.

---

## 🛠️ Running Locally

### Prerequisites

- Ruby ≥ 3.0
- Bundler (`gem install bundler`)

### Setup

```bash
# Install Jekyll and dependencies
gem install jekyll bundler

# Or with a Gemfile:
bundle install

# Serve locally with live reload
bundle exec jekyll serve --livereload
# (or without Bundler)
jekyll serve --livereload
```

Visit `http://localhost:4000` in your browser.

---

## 📁 Repository Structure

```
/
├── _config.yml          # Jekyll configuration
├── index.md             # Homepage
├── about.md             # About page
├── projects.md          # Projects showcase
├── research.md          # Research & publications
├── blog.md              # Blog post listing
├── resume.md            # Resume / CV
├── _posts/
│   └── YYYY-MM-DD-*.md  # Blog posts (Markdown)
├── _layouts/
│   ├── default.html     # Base layout
│   └── post.html        # Blog post layout
├── _includes/
│   ├── navbar.html      # Navigation bar
│   └── footer.html      # Footer
└── assets/
    ├── css/
    │   └── styles.css   # Styles
    └── images/          # Images
```

---

## ⚙️ Customisation

Edit `_config.yml` to update your name, email, GitHub handle, LinkedIn handle,
and site URL. Content pages are plain Markdown — just edit and commit.

---

## 📄 License

MIT — feel free to use this as a template for your own site.
