---
layout: default
title: "Blog"
permalink: /blog/
---

<div class="page-header">
  <div class="section-header">
    <h1>Blog</h1>
    <a href="{{ '/gallery' | relative_url }}">gallery &rarr;</a>
  </div>
  <p class="subtitle">Notes, tutorials, and life updates.</p>
</div>

{% if site.posts.size > 0 %}
<table class="news-table post-preview-table">
  <thead>
    <tr>
      <th scope="col">Date</th>
      <th scope="col">Post</th>
    </tr>
  </thead>
  <tbody>
  {% for post in site.posts %}
  <tr>
    <td class="news-date">
      <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%b %-d, %Y" }}</time>
    </td>
    <td class="news-content">
      <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
      {% if post.excerpt %}
      <span class="post-preview-text"> — {{ post.excerpt | strip_html | truncate: 80 }}</span>
      {% endif %}
    </td>
  </tr>
  {% endfor %}
  </tbody>
</table>
{% else %}
<p class="news-empty">No posts yet — check back soon!</p>
{% endif %}
