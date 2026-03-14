---
layout: default
title: "About"
---

<div class="profile-section">
  <div class="profile-left">
    <div class="profile-avatar">RY</div>
    <h1 class="profile-name">Ryan Ye</h1>
    <p class="profile-position">
      Computer Science<br>
      <a href="https://www.cs.cornell.edu/" target="_blank" rel="noopener noreferrer">Cornell University</a>
    </p>
    <div class="profile-social">
      <a href="mailto:rmy43@cornell.edu" title="Email"><i class="fas fa-envelope"></i></a>
      <a href="https://github.com/ryanmye" target="_blank" rel="noopener noreferrer" title="GitHub"><i class="fab fa-github"></i></a>
      <a href="https://www.linkedin.com/in/rmy43/" target="_blank" rel="noopener noreferrer" title="LinkedIn"><i class="fab fa-linkedin"></i></a>
    </div>
  </div>

  <div class="profile-right">
    <p>
      I'm Ryan Ye, an undergraduate in Computer Science at Cornell University. I work on
      computer vision and machine learning in the Sun Lab (PI: Jennifer Sun), currently
      building systems for animal behavior monitoring in agricultural environments. I'm
      currently interested in AI for science and making research tools that augment
      scientist workflows.
    </p>
    <div class="profile-contact-row">
      <span><i class="fas fa-envelope fa-sm"></i> <a href="mailto:rmy43@cornell.edu">rmy43@cornell.edu</a></span>
      <span><i class="fab fa-linkedin fa-sm"></i> <a href="https://www.linkedin.com/in/rmy43/" target="_blank" rel="noopener noreferrer">linkedin.com/in/rmy43</a></span>
      <span><i class="fab fa-github fa-sm"></i> <a href="https://github.com/ryanmye" target="_blank" rel="noopener noreferrer">github.com/ryanmye</a></span>
    </div>
    <p class="spotify-widget">
      <i class="fab fa-spotify" style="color:#1DB954"></i>
      <span id="spotify-now-playing">Loading&hellip;</span>
    </p>
  </div>
</div>

<div class="content-section">
  <h2 class="section-title">About</h2>

  <p>
    I'm an undergraduate at Cornell (College of Engineering) with interests in machine
    learning, computer vision, and AI for scientific discovery. I enjoy working at the
    intersection of AI and real-world systems—especially where better data and automation
    can help researchers scale their work.
  </p>
  <p>
    I conduct research in the Sun Lab, working on a project to develop computer vision
    methods for dairy calf behavior analysis to support veterinary researchers studying
    early indicators of disease and welfare. Outside of academics, I play violin in a
    quartet and serve in Cru as a student leader in worship team.
  </p>
</div>

<div class="content-section">
  <div class="section-header">
    <h2 class="section-title" style="border:none;padding:0;margin:0">Posts</h2>
    <a href="{{ '/blog' | relative_url }}">all posts &rarr;</a>
  </div>

  {% if site.posts.size > 0 %}
  <table class="news-table post-preview-table">
    {% for post in site.posts limit:10 %}
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
  </table>
  {% else %}
  <p class="news-empty">No posts yet — check back soon!</p>
  {% endif %}
</div>

<div class="content-section">
  <div class="section-header">
    <h2 class="section-title" style="border:none;padding:0;margin:0">Research</h2>
    <a href="{{ '/research' | relative_url }}">see more &rarr;</a>
  </div>

  <div class="research-entry">
    <h3>AI for Animal Behavior Monitoring</h3>
    <p class="research-meta">
      <span class="research-role">Undergraduate Researcher</span> &mdash; Sun Lab (PI: Jennifer Sun), Cornell University
    </p>
    <p>
      I work on scalable computer vision systems for analyzing dairy calf behavior in
      agricultural environments, supporting veterinary researchers studying early indicators
      of disease and welfare. Work spans pose classification with self-supervised DINO
      features, YOLO-based object detection on a self-annotated dataset, and evaluation
      of vision-language models for farm settings.
    </p>
    <p style="font-size:0.875rem;color:var(--color-text-muted)">
      Conducted as part of the Bowers Undergraduate Research Experience (BURE) with
      support from a CIDA grant.
    </p>
  </div>
</div>

<script>
(function () {
  /* ── shared utilities ── */
  function timeAgo(isoStr) {
    var d    = new Date(isoStr);
    var now  = new Date();
    var secs = Math.floor((now - d) / 1000);
    if (secs < 60)  return secs + ' second' + (secs === 1 ? '' : 's') + ' ago';
    var mins = Math.floor(secs / 60);
    if (mins < 60)  return mins + ' minute' + (mins === 1 ? '' : 's') + ' ago';
    var hrs  = Math.floor(mins / 60);
    if (hrs  < 24)  return hrs  + ' hour'   + (hrs  === 1 ? '' : 's') + ' ago';
    var days = Math.floor(hrs  / 24);
    return days + ' day' + (days === 1 ? '' : 's') + ' ago';
  }

  function escapeHtml(str) {
    return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
              .replace(/"/g,'&quot;').replace(/'/g,'&#39;');
  }

  /* ── Spotify "recently listened" ── */
  var spotifyEl = document.getElementById('spotify-now-playing');
  if (spotifyEl) {
    fetch('{{ "/assets/data/now-playing.json" | relative_url }}?t=' + Date.now())
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (!data.track) { spotifyEl.textContent = 'No recent tracks.'; return; }
        var t = data.track;
        var artistLinks = t.artists.map(function (a) {
          return '<a href="' + a.url + '" target="_blank" rel="noopener noreferrer">' +
                 escapeHtml(a.name) + '</a>';
        }).join(', ');
        spotifyEl.innerHTML =
          'listened to <a href="' + t.url + '" target="_blank" rel="noopener noreferrer">' +
          escapeHtml(t.name) + '</a> by ' + artistLinks +
          ' <span class="spotify-time">(' + timeAgo(t.played_at) + ')</span>';
      })
      .catch(function () { spotifyEl.textContent = 'Could not load recent track.'; });
  }
})();
</script>
