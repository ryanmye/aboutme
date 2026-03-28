---
layout: album-editor
title: "Album Editor"
permalink: /album-editor/
---

{% if site.local_editor and jekyll.environment == "development" %}
Manage photo albums for your blog posts.
{% else %}
<p>Album editor is only available in development mode.</p>
{% endif %}
