---
layout: default
title: "Gallery"
permalink: /gallery/
description: "Photo gallery from Ryan Ye's blog — campus life, travel, and events."
album_lightbox: true
---

<div class="page-header">
  <h1>Gallery</h1>
</div>

{% assign has_post_albums = false %}
{% for post in site.posts %}
  {% if post.images and post.images.size > 0 %}
    {% assign has_post_albums = true %}
    {% break %}
  {% endif %}
{% endfor %}

{% assign has_standalone_albums = false %}
{% for album in site.albums %}
  {% unless album.draft %}
    {% if album.images and album.images.size > 0 %}
      {% assign has_standalone_albums = true %}
      {% break %}
    {% endif %}
  {% endunless %}
{% endfor %}

{% if has_post_albums or has_standalone_albums %}

<div class="content-section">
  <h2 class="section-title">Albums</h2>
  <div class="gallery-grid">
    {% for post in site.posts %}
      {% if post.images and post.images.size > 0 %}
      <a href="{{ post.url | relative_url }}" class="gallery-album-card">
        <div class="gallery-album-cover">
          <img src="{{ post.images[0].src | relative_url }}" alt="{{ post.title }}" loading="lazy">
        </div>
        <div class="gallery-album-info">
          <h2 class="gallery-album-title">{{ post.title }}</h2>
          <p class="gallery-album-meta">
            <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%b %-d, %Y" }}</time>
            &middot; {{ post.images.size }} photo{% if post.images.size != 1 %}s{% endif %}
          </p>
        </div>
      </a>
      {% endif %}
    {% endfor %}
    {% for album in site.albums %}
      {% unless album.draft %}
        {% if album.images and album.images.size > 0 %}
        <a href="{{ album.url | relative_url }}" class="gallery-album-card">
          <div class="gallery-album-cover">
            <img src="{{ album.images[0].src | relative_url }}" alt="{{ album.title }}" loading="lazy">
          </div>
          <div class="gallery-album-info">
            <h2 class="gallery-album-title">{{ album.title }}</h2>
            <p class="gallery-album-meta">
              {% if album.date %}<time datetime="{{ album.date | date_to_xmlschema }}">{{ album.date | date: "%b %-d, %Y" }}</time> &middot; {% endif %}
              {{ album.images.size }} photo{% if album.images.size != 1 %}s{% endif %}
            </p>
          </div>
        </a>
        {% endif %}
      {% endunless %}
    {% endfor %}
  </div>
</div>

<div class="content-section">
  <h2 class="section-title">All Photos</h2>
  <div class="album-grid">
    {% assign photo_idx = 0 %}
    {% for post in site.posts %}
      {% if post.images and post.images.size > 0 %}
        {% for img in post.images %}
        {% include photo_card.html src=img.src caption=img.caption index=photo_idx fallback_alt=post.title %}
        {% assign photo_idx = photo_idx | plus: 1 %}
        {% endfor %}
      {% endif %}
    {% endfor %}
    {% for album in site.albums %}
      {% unless album.draft %}
        {% if album.images and album.images.size > 0 %}
          {% for img in album.images %}
          {% include photo_card.html src=img.src caption=img.caption index=photo_idx fallback_alt=album.title %}
          {% assign photo_idx = photo_idx | plus: 1 %}
          {% endfor %}
        {% endif %}
      {% endunless %}
    {% endfor %}
  </div>
</div>

{% else %}
<p class="news-empty">No photo albums yet.</p>
{% endif %}
