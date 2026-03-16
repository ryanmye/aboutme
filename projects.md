---
layout: default
title: "Projects"
permalink: /projects/
---

<div class="page-header">
  <h1>Projects</h1>
  <p class="subtitle">Things I've built, explored, and shipped.</p>
</div>

<div class="card-grid">

{% for project in site.data.projects.projects %}
  <article class="card">
    <h2 class="card-title">
      {% if project.url %}
      <a href="{{ project.url }}" target="_blank" rel="noopener noreferrer">{{ project.title }}</a>
      {% else %}
      {{ project.title }}
      {% endif %}
    </h2>
    {% if project.date %}<p class="card-date">{{ project.date }}</p>{% endif %}
    <p class="card-description">{{ project.description }}</p>
    <div class="tags">
      {% for tag in project.tags %}
      <span class="tag">{{ tag }}</span>
      {% endfor %}
    </div>
    {% if project.bullets.size > 0 %}
    <ul style="font-size:0.875rem;margin-top:0.75rem;color:var(--muted)">
      {% for bullet in project.bullets %}
      <li>{{ bullet }}</li>
      {% endfor %}
    </ul>
    {% endif %}
    {% if project.url %}
    <div class="card-links">
      <a href="{{ project.url }}" target="_blank" rel="noopener noreferrer">GitHub &rarr;</a>
    </div>
    {% endif %}
  </article>
{% endfor %}

</div>
