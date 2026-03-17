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
    if (editor) {
      return editor.getMarkdown();
    }
    return bodyInput.value;
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
      editor.insertText(snippet);
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
      .then(function (res) { return res.json(); })
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
      .catch(function (err) { console.error('Failed to load post list', err); });
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

    var caption = imageCaptionInput.value.trim() || 'Caption';
    var formData = new FormData();
    formData.append('image', file);
    formData.append('draft', draftInput.checked ? 'true' : 'false');
    return fetch(apiOrigin + '/images', { method: 'POST', body: formData })
      .then(function (res) { return res.json(); })
      .then(function (payload) {
        var url = payload.url;
        var cap = caption || payload.basename || 'Caption';
        var figure = '\n\n<figure class="post-image">\n' +
          '  <img src="' + url + '" alt="' + cap + '" />\n' +
          '  <figcaption>' + cap + '</figcaption>\n' +
          '</figure>\n\n';
        insertAtCursor(figure);

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
  }

  refreshPostList();
})();

