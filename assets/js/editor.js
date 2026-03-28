(function () {
  var root = document.getElementById('editor-root');
  var apiOrigin = (root && root.dataset.apiOrigin) || 'http://localhost:4001';

  function $(id) { return document.getElementById(id); }

  var form = $('post-form');
  if (!form) return;

  var titleInput = $('post-title');
  var dateInput = $('post-date');
  var tagsInput = $('post-tags');
  var draftInput = $('post-draft');
  var bodyInput = $('post-body');
  var editorContainer = document.getElementById('post-editor');
  var postList = $('post-list');
  var newBtn = $('new-post');
  var deleteBtn = $('delete-post');
  var publishBtn = $('publish-post');
  var uploadBtn = $('upload-insert-image');
  var imageFileInput = $('image-file');
  var imageCaptionInput = $('image-caption');

  var currentSlug = null;
  var currentKind = 'post';
  var editor = null;

  function toSlug(str) {
    return String(str || '')
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '') || 'post';
  }

  function getBodyValue() {
    var val = editor ? editor.getMarkdown() : bodyInput.value;
    // Strip API origin from image URLs so saved markdown uses relative paths
    return val.split(apiOrigin).join('');
  }

  function setBodyValue(value) {
    if (editor) {
      editor.setMarkdown(value || '');
    } else {
      bodyInput.value = value || '';
    }
  }

  function insertAtCursor(snippet) {
    if (editor) {
      // insertText escapes HTML; append to markdown source directly
      var md = editor.getMarkdown();
      editor.setMarkdown(md + snippet);
      return;
    }
    var start = bodyInput.selectionStart;
    var end = bodyInput.selectionEnd;
    var before = bodyInput.value.substring(0, start);
    var after = bodyInput.value.substring(end);
    bodyInput.value = before + snippet + after;
    var cursor = start + snippet.length;
    bodyInput.selectionStart = bodyInput.selectionEnd = cursor;
    bodyInput.focus();
  }

  function serializeForm() {
    var title = titleInput.value.trim();
    var date = dateInput.value;
    var tags = tagsInput.value.split(',').map(function (t) { return t.trim(); }).filter(Boolean);
    var draft = !!draftInput.checked;
    var body = getBodyValue();
    return { title: title, date: date, tags: tags, draft: draft, body: body, slug: currentSlug || toSlug(title) };
  }

  function formatDateForInput(dateStr) {
    if (!dateStr || typeof dateStr !== 'string') return '';
    var s = dateStr.trim();
    if (!s) return '';
    var datePart = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (!datePart) return s;
    var timePart = s.match(/[T\s](\d{2}):(\d{2})/);
    var h = timePart ? timePart[1] : '00';
    var M = timePart ? timePart[2] : '00';
    return datePart[1] + '-' + datePart[2] + '-' + datePart[3] + 'T' + h + ':' + M;
  }

  function loadPostIntoForm(post) {
    currentSlug = post.slug;
    currentKind = post.kind || (post.draft ? 'draft' : 'post');
    titleInput.value = post.title || '';
    dateInput.value = formatDateForInput(post.date);
    tagsInput.value = (post.tags || []).join(', ');
    draftInput.checked = currentKind === 'draft' || !!post.draft;
    setBodyValue(post.body || '');
  }

  function refreshPostList() {
    fetch(apiOrigin + '/posts')
      .then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function (posts) {
        postList.innerHTML = '';
        posts.forEach(function (p) {
          var li = document.createElement('li');
          li.className = 'editor-post-item';
          var kind = p.kind || (p.draft ? 'draft' : 'post');
          li.textContent = (kind === 'draft' ? '[draft] ' : '') + p.title + ' (' + p.slug + ')';
          li.dataset.slug = p.slug;
          li.dataset.kind = kind;
          li.addEventListener('click', function () {
            fetch(apiOrigin + '/posts/' + encodeURIComponent(kind) + '/' + encodeURIComponent(p.slug))
              .then(function (res) {
                if (!res.ok) throw new Error('HTTP ' + res.status);
                return res.json();
              })
              .then(loadPostIntoForm)
              .catch(function (err) {
                console.error('Failed to load post', err);
                alert('Failed to load post: ' + (err.message || 'Unknown error'));
              });
          });
          postList.appendChild(li);
        });
      })
      .catch(function (err) {
        console.error('Failed to load post list', err);
        postList.innerHTML = '<li class="editor-post-item editor-post-error">Could not load posts. Make sure the editor API is running: <code>bundle exec ruby scripts/local_editor_server.rb</code></li>';
      });
  }

  newBtn.addEventListener('click', function (e) {
    e.preventDefault();
    currentSlug = null;
    currentKind = 'draft';
    form.reset();
    draftInput.checked = true;
    setBodyValue('');
  });

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    var data = serializeForm();
    if (!data.title || !data.body.trim()) {
      alert('Title and body are required.');
      return;
    }
    var method = currentSlug ? 'PUT' : 'POST';
    var url = apiOrigin + '/posts' + (currentSlug ? '/' + encodeURIComponent(currentKind) + '/' + encodeURIComponent(currentSlug) : '');
    fetch(url, {
      method: method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    })
      .then(function (res) { return res.json(); })
      .then(function (saved) {
        currentSlug = saved.slug;
        currentKind = saved.kind || (data.draft ? 'draft' : 'post');
        if (!dateInput.value && saved.date) {
          dateInput.value = saved.date;
        }
        refreshPostList();
      })
      .catch(function (err) {
        console.error('Failed to save post', err);
        alert('Failed to save post. See console for details.');
      });
  });

  deleteBtn.addEventListener('click', function (e) {
    e.preventDefault();
    if (!currentSlug) return;
    if (!confirm('Delete this post? This cannot be undone.')) return;
    fetch(apiOrigin + '/posts/' + encodeURIComponent(currentKind) + '/' + encodeURIComponent(currentSlug), { method: 'DELETE' })
      .then(function (res) { return res.ok; })
      .then(function () {
        currentSlug = null;
        currentKind = 'post';
        form.reset();
        setBodyValue('');
        refreshPostList();
      })
      .catch(function (err) {
        console.error('Failed to delete post', err);
        alert('Failed to delete post. See console for details.');
      });
  });

  if (publishBtn) {
    publishBtn.addEventListener('click', function (e) {
      e.preventDefault();
      if (!currentSlug || currentKind !== 'draft') {
        alert('Load a draft first to publish.');
        return;
      }
      var data = serializeForm();
      if (!data.title || !data.body.trim()) {
        alert('Title and body are required.');
        return;
      }
      fetch(apiOrigin + '/publish/' + encodeURIComponent(currentSlug), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      })
        .then(function (res) { return res.json(); })
        .then(function (saved) {
          currentSlug = saved.slug;
          currentKind = 'post';
          draftInput.checked = false;
          if (saved.date) {
            dateInput.value = saved.date;
          }
          refreshPostList();
        })
        .catch(function (err) {
          console.error('Failed to publish draft', err);
          alert('Failed to publish draft. See console for details.');
        });
    });
  }

  function uploadAndInsertSelectedImage() {
    var file = imageFileInput.files[0];
    if (!file) return;

    var caption = imageCaptionInput.value.trim();
    var formData = new FormData();
    formData.append('image', file);
    formData.append('draft', draftInput.checked ? 'true' : 'false');
    return fetch(apiOrigin + '/images', { method: 'POST', body: formData })
      .then(function (res) { return res.json(); })
      .then(function (payload) {
        var url = payload.url;
        var altText = caption || payload.basename || 'image';
        // Use API origin for immediate display; save relative path for published blog
        var displayUrl = apiOrigin + url;
        // Insert as markdown image + italic caption (styled by CSS :has selector).
        // Avoids <figure> HTML which Toast UI Editor strips during round-trip.
        var snippet = '\n\n![' + altText + '](' + displayUrl + ')';
        if (caption) {
          snippet += '\n\n*' + caption + '*';
        }
        snippet += '\n\n';
        insertAtCursor(snippet);

        imageFileInput.value = '';
        imageCaptionInput.value = '';
      })
      .catch(function (err) {
        console.error('Failed to upload image', err);
        alert('Failed to upload image. See console for details.');
      });
  }

  uploadBtn.addEventListener('click', function (e) {
    e.preventDefault();
    if (!imageFileInput.files[0]) {
      imageFileInput.click();
      return;
    }
    uploadAndInsertSelectedImage();
  });

  imageFileInput.addEventListener('change', function () {
    // If user chose a file via shortcut or button, upload+insert immediately.
    if (imageFileInput.files[0]) {
      uploadAndInsertSelectedImage();
    }
  });

  document.addEventListener('keydown', function (e) {
    var isMac = navigator.platform && /Mac/.test(navigator.platform);
    var key = e.key || '';
    var wantsImage =
      (isMac && e.metaKey && e.shiftKey && (key === 'K' || key === 'k')) ||
      (!isMac && e.ctrlKey && e.shiftKey && (key === 'K' || key === 'k'));
    if (!wantsImage) return;
    e.preventDefault();
    imageFileInput.click();
  });

  // Initialize Toast UI Editor if available
  if (window.toastui && window.toastui.Editor && editorContainer) {
    editor = new window.toastui.Editor({
      el: editorContainer,
      height: '500px',
      initialEditType: 'wysiwyg',
      previewStyle: 'tab',
      usageStatistics: false,
      toolbarItems: [
        ['heading', 'bold', 'italic'],
        ['link', 'image'],
        ['quote', 'code', 'codeblock'],
        ['ul', 'ol'],
        ['hr'],
        ['scrollSync']
      ],
    });

    // Highlight caption elements in the editor. ProseMirror adds trailing <br> inside paragraphs
    // so :only-child never matches — use :first-child instead. We also apply inline styles as a
    // fallback in case CSS injection can't reach the iframe.
    var captionCSS = [
      'p:has(> img) + p > em:first-child {',
      '  display: block !important;',
      '  background: #fff3cd !important;',
      '  border-left: 3px solid #e6a817 !important;',
      '  border-radius: 3px !important;',
      '  padding: 2px 6px !important;',
      '  font-style: italic !important;',
      '}',
      'p:has(> img) + p > em:first-child::before {',
      '  content: "Caption: " !important;',
      '  font-weight: 600;',
      '  font-style: normal;',
      '  font-size: 0.75rem;',
      '  letter-spacing: 0.04em;',
      '  text-transform: uppercase;',
      '  color: #9a6700;',
      '  margin-right: 4px;',
      '}'
    ].join('\n');

    function injectCaptionStylesIntoDoc(doc) {
      if (!doc || !doc.head) return false;
      if (doc.getElementById('caption-indicator-style')) return true; // already done
      var style = doc.createElement('style');
      style.id = 'caption-indicator-style';
      style.textContent = captionCSS;
      doc.head.appendChild(style);
      return true;
    }

    function tryCaptionInjection() {
      // Inject into parent document (in case editor is not in an iframe)
      injectCaptionStylesIntoDoc(document);
      // Inject into every iframe on the page
      var iframes = document.querySelectorAll('iframe');
      iframes.forEach(function(f) {
        try {
          var doc = f.contentDocument || (f.contentWindow && f.contentWindow.document);
          injectCaptionStylesIntoDoc(doc);
        } catch (e) {}
      });
    }

    // Poll until injection succeeds (iframe may load asynchronously)
    var captionPollCount = 0;
    var captionPollTimer = setInterval(function() {
      tryCaptionInjection();
      captionPollCount++;
      if (captionPollCount >= 20) clearInterval(captionPollTimer); // give up after ~10s
    }, 500);

    // Prevent base64 image embedding by intercepting local image insertions.
    if (typeof editor.removeHook === 'function') {
      try { editor.removeHook('addImageBlobHook'); } catch (e) {}
    }
    if (typeof editor.addHook === 'function') {
      editor.addHook('addImageBlobHook', function (blob, callback) {
        var formData = new FormData();
        var filename = (blob && blob.name) ? blob.name : 'image.png';
        formData.append('image', blob, filename);
        formData.append('draft', draftInput.checked ? 'true' : 'false');
        fetch(apiOrigin + '/images', { method: 'POST', body: formData })
          .then(function (res) {
            if (!res.ok) throw new Error('HTTP ' + res.status);
            return res.json();
          })
          .then(function (payload) {
            callback(apiOrigin + payload.url);
          })
          .catch(function (err) {
            console.error('Image upload hook failed', err);
            alert('Image upload failed. See console for details.');
          });
        return false;
      });
    }

  }

  refreshPostList();
})();

