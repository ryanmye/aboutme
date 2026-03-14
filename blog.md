---
layout: default
title: "Blog"
permalink: /blog/
---

<div class="page-header">
  <h1>Blog</h1>
  <p class="subtitle">Notes, tutorials, and life updates.</p>
</div>

{% if site.posts.size > 0 %}
<ul class="post-list" role="list">
  {% for post in site.posts %}
  <li class="post-item">
    <h2 class="post-item-title">
      <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
    </h2>
    <p class="post-item-meta">
      <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%B %-d, %Y" }}</time>
      {% if post.tags and post.tags.size > 0 %}
      &mdash;
      {% for tag in post.tags %}<span class="tag">{{ tag }}</span> {% endfor %}
      {% endif %}
    </p>
    {% if post.excerpt %}
    <p class="post-item-excerpt">{{ post.excerpt | strip_html | truncate: 200 }}</p>
    {% endif %}
  </li>
  {% endfor %}
</ul>
{% else %}
<p>No posts yet — check back soon!</p>
{% endif %}
