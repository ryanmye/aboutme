---
layout: default
title: "Home"
---

<section class="hero">
  <p class="hero-greeting">Hi there, I'm</p>
  <h1 class="hero-name">Ryan Mye</h1>
  <p class="hero-title">Computer Science Student &amp; Researcher</p>
  <p class="hero-bio">
    I'm a computer science student passionate about building things, exploring ideas,
    and sharing what I learn along the way. Currently focused on software engineering
    and CS research.
  </p>
  <div class="hero-links">
    <a class="btn btn-primary" href="https://github.com/{{ site.github_username }}" target="_blank" rel="noopener noreferrer">
      GitHub
    </a>
    <a class="btn btn-outline" href="https://linkedin.com/in/{{ site.linkedin_username }}" target="_blank" rel="noopener noreferrer">
      LinkedIn
    </a>
    <a class="btn btn-outline" href="mailto:{{ site.email }}">
      Email
    </a>
    <a class="btn btn-outline" href="{{ '/about' | relative_url }}">
      About Me
    </a>
  </div>
</section>

<section aria-labelledby="recent-posts-heading">
  <div class="section-header">
    <h2 id="recent-posts-heading">Recent Posts</h2>
    <a href="{{ '/blog' | relative_url }}">All posts &rarr;</a>
  </div>

  <ul class="post-list" role="list">
    {% assign recent_posts = site.posts | limit: 3 %}
    {% for post in recent_posts %}
    <li class="post-item">
      <h3 class="post-item-title">
        <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
      </h3>
      <p class="post-item-meta">
        <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%B %-d, %Y" }}</time>
        {% if post.tags and post.tags.size > 0 %}
        &mdash;
        {% for tag in post.tags %}<span class="tag">{{ tag }}</span> {% endfor %}
        {% endif %}
      </p>
      {% if post.excerpt %}
      <p class="post-item-excerpt">{{ post.excerpt | strip_html | truncate: 160 }}</p>
      {% endif %}
    </li>
    {% else %}
    <li class="post-item">
      <p class="post-item-excerpt">No posts yet — check back soon!</p>
    </li>
    {% endfor %}
  </ul>
</section>
