(function () {
  var apiOrigin = 'http://localhost:4001';

  function $(id) { return document.getElementById(id); }

  var albumFileInput = $('album-image-file');
  var albumAddBtn = $('album-add-image');
  var albumItemsContainer = $('album-items');
  var albumCountEl = $('album-count');
  var albumSaveBtn = $('album-save');
  var albumDeleteBtn = $('album-delete');
  var postList = $('post-list');
  var standaloneList = $('standalone-list');
  var newAlbumBtn = $('new-album');
  var albumTitleInput = $('album-title');
  var albumDescInput = $('album-description');
  var albumDescCounter = $('album-desc-counter');
  var albumDraftInput = $('album-draft');
  var tabPostAlbums = $('tab-post-albums');
  var tabStandaloneAlbums = $('tab-standalone-albums');
  var postAlbumsPane = $('pane-post-albums');
  var standaloneAlbumsPane = $('pane-standalone-albums');
  var standaloneMetaSection = $('standalone-meta');

  if (!postList) return;

  var currentSlug = null;
  var currentKind = null; // 'post', 'draft', or 'album'
  var albumImages = [];
  var bodyImages = [];

  // --- Tab switching ---
  function switchTab(tab) {
    if (tab === 'standalone') {
      tabStandaloneAlbums.classList.add('active');
      tabPostAlbums.classList.remove('active');
      standaloneAlbumsPane.style.display = '';
      postAlbumsPane.style.display = 'none';
    } else {
      tabPostAlbums.classList.add('active');
      tabStandaloneAlbums.classList.remove('active');
      postAlbumsPane.style.display = '';
      standaloneAlbumsPane.style.display = 'none';
    }
  }

  if (tabPostAlbums) {
    tabPostAlbums.addEventListener('click', function () { switchTab('posts'); });
  }
  if (tabStandaloneAlbums) {
    tabStandaloneAlbums.addEventListener('click', function () { switchTab('standalone'); });
  }

  // --- Description character counter ---
  if (albumDescInput && albumDescCounter) {
    albumDescInput.addEventListener('input', function () {
      var len = albumDescInput.value.length;
      albumDescCounter.textContent = len + '/500';
      if (len > 500) {
        albumDescInput.value = albumDescInput.value.slice(0, 500);
        albumDescCounter.textContent = '500/500';
      }
    });
  }

  // --- Rendering ---
  function renderAlbumItems() {
    if (!albumItemsContainer) return;
    var total = bodyImages.length + albumImages.length;
    albumCountEl.textContent = '(' + total + '/25)';
    albumItemsContainer.innerHTML = '';

    bodyImages.forEach(function (img, idx) {
      var row = document.createElement('div');
      row.className = 'editor-album-item';
      row.style.opacity = '0.7';

      var thumb = document.createElement('img');
      thumb.className = 'editor-album-thumb';
      thumb.src = img.src.startsWith('/') ? apiOrigin + img.src : img.src;
      thumb.alt = img.caption || 'Body image ' + (idx + 1);

      var captionSpan = document.createElement('span');
      captionSpan.style.flex = '1';
      captionSpan.style.fontSize = '0.85rem';
      captionSpan.style.color = 'var(--muted)';
      captionSpan.textContent = (img.caption || 'No caption') + ' (from post body)';

      row.appendChild(thumb);
      row.appendChild(captionSpan);
      albumItemsContainer.appendChild(row);
    });

    albumImages.forEach(function (img, idx) {
      var row = document.createElement('div');
      row.className = 'editor-album-item';

      var thumb = document.createElement('img');
      thumb.className = 'editor-album-thumb';
      thumb.src = img.src.startsWith('/') ? apiOrigin + img.src : img.src;
      thumb.alt = img.caption || 'Album image ' + (idx + 1);

      var captionInput = document.createElement('input');
      captionInput.type = 'text';
      captionInput.value = img.caption || '';
      captionInput.placeholder = 'Caption for image ' + (idx + 1);
      captionInput.addEventListener('change', function () {
        albumImages[idx].caption = this.value;
      });

      var removeBtn = document.createElement('button');
      removeBtn.type = 'button';
      removeBtn.textContent = 'Remove';
      removeBtn.addEventListener('click', function () {
        var src = albumImages[idx].src;
        albumImages.splice(idx, 1);
        renderAlbumItems();
        // Delete the image file from disk
        fetch(apiOrigin + '/images/delete', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ src: src })
        }).catch(function (err) {
          console.error('Failed to delete image file', err);
        });
      });

      row.appendChild(thumb);
      row.appendChild(captionInput);
      row.appendChild(removeBtn);
      albumItemsContainer.appendChild(row);
    });
  }

  function showStandaloneMeta(show) {
    if (standaloneMetaSection) {
      standaloneMetaSection.style.display = show ? '' : 'none';
    }
  }

  function clearForm() {
    currentSlug = null;
    currentKind = null;
    albumImages = [];
    bodyImages = [];
    if (albumTitleInput) albumTitleInput.value = '';
    if (albumDescInput) {
      albumDescInput.value = '';
      if (albumDescCounter) albumDescCounter.textContent = '0/500';
    }
    if (albumDraftInput) albumDraftInput.checked = false;
    showStandaloneMeta(false);
    renderAlbumItems();
  }

  // --- Load post album ---
  function loadPostAlbum(post) {
    currentSlug = post.slug;
    currentKind = post.kind || (post.draft ? 'draft' : 'post');
    showStandaloneMeta(false);

    var allImages = (post.images || []).map(function (img) {
      return { src: img.src || '', caption: img.caption || '' };
    });

    var body = post.body || '';
    bodyImages = [];
    albumImages = [];

    allImages.forEach(function (img) {
      if (body.indexOf(img.src) !== -1) {
        bodyImages.push(img);
      } else {
        albumImages.push(img);
      }
    });

    renderAlbumItems();
    highlightSelected(postList, post.slug, currentKind);
    highlightSelected(standaloneList, null, null);
  }

  // --- Load standalone album ---
  function loadStandaloneAlbum(album) {
    currentSlug = album.slug;
    currentKind = 'album';
    bodyImages = [];
    albumImages = (album.images || []).map(function (img) {
      return { src: img.src || '', caption: img.caption || '' };
    });

    showStandaloneMeta(true);
    if (albumTitleInput) albumTitleInput.value = album.title || '';
    if (albumDescInput) {
      albumDescInput.value = album.description || '';
      if (albumDescCounter) albumDescCounter.textContent = (album.description || '').length + '/500';
    }
    if (albumDraftInput) albumDraftInput.checked = !!album.draft;

    renderAlbumItems();
    highlightSelected(standaloneList, album.slug, 'album');
    highlightSelected(postList, null, null);
  }

  function highlightSelected(list, slug, kind) {
    if (!list) return;
    var items = list.querySelectorAll('.editor-post-item');
    items.forEach(function (li) {
      li.style.fontWeight = (slug && li.dataset.slug === slug && li.dataset.kind === kind) ? '600' : '';
    });
  }

  // --- Refresh lists ---
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
          var imgCount = (p.images || []).length;
          li.textContent = (kind === 'draft' ? '[draft] ' : '') + p.title + (imgCount ? ' (' + imgCount + ' photos)' : '');
          li.dataset.slug = p.slug;
          li.dataset.kind = kind;
          li.addEventListener('click', function () {
            fetch(apiOrigin + '/posts/' + encodeURIComponent(kind) + '/' + encodeURIComponent(p.slug))
              .then(function (res) {
                if (!res.ok) throw new Error('HTTP ' + res.status);
                return res.json();
              })
              .then(loadPostAlbum)
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
        postList.innerHTML = '<li class="editor-post-item editor-post-error">Could not load posts. Make sure the editor API is running.</li>';
      });
  }

  function refreshAlbumList() {
    if (!standaloneList) return;
    fetch(apiOrigin + '/albums')
      .then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function (albums) {
        standaloneList.innerHTML = '';
        albums.forEach(function (a) {
          var li = document.createElement('li');
          li.className = 'editor-post-item';
          var imgCount = (a.images || []).length;
          li.textContent = (a.draft ? '[draft] ' : '') + a.title + (imgCount ? ' (' + imgCount + ' photos)' : '');
          li.dataset.slug = a.slug;
          li.dataset.kind = 'album';
          li.addEventListener('click', function () {
            fetch(apiOrigin + '/albums/' + encodeURIComponent(a.slug))
              .then(function (res) {
                if (!res.ok) throw new Error('HTTP ' + res.status);
                return res.json();
              })
              .then(loadStandaloneAlbum)
              .catch(function (err) {
                console.error('Failed to load album', err);
                alert('Failed to load album: ' + (err.message || 'Unknown error'));
              });
          });
          standaloneList.appendChild(li);
        });
      })
      .catch(function (err) {
        console.error('Failed to load album list', err);
        standaloneList.innerHTML = '<li class="editor-post-item editor-post-error">Could not load albums.</li>';
      });
  }

  // --- New standalone album ---
  if (newAlbumBtn) {
    newAlbumBtn.addEventListener('click', function (e) {
      e.preventDefault();
      clearForm();
      currentKind = 'album';
      showStandaloneMeta(true);
      switchTab('standalone');
    });
  }

  // --- Album upload ---
  if (albumAddBtn) {
    albumAddBtn.addEventListener('click', function (e) {
      e.preventDefault();
      if (!albumFileInput.files || !albumFileInput.files.length) {
        albumFileInput.click();
        return;
      }
      var files = Array.prototype.slice.call(albumFileInput.files);
      var remaining = 25 - bodyImages.length - albumImages.length;
      if (remaining <= 0) {
        alert('Album is full (25 images max).');
        return;
      }
      files = files.slice(0, remaining);
      var isAlbum = currentKind === 'album';
      var isDraft = currentKind === 'draft';

      var uploads = files.map(function (file) {
        var formData = new FormData();
        formData.append('image', file);
        if (isAlbum) {
          formData.append('album', 'true');
        } else {
          formData.append('draft', isDraft ? 'true' : 'false');
        }
        return fetch(apiOrigin + '/images', { method: 'POST', body: formData })
          .then(function (res) { return res.json(); })
          .then(function (payload) {
            albumImages.push({ src: payload.url, caption: '' });
          });
      });

      Promise.all(uploads)
        .then(function () {
          renderAlbumItems();
          albumFileInput.value = '';
        })
        .catch(function (err) {
          console.error('Album upload failed', err);
          alert('Failed to upload album image. See console for details.');
        });
    });

    albumFileInput.addEventListener('change', function () {
      if (albumFileInput.files && albumFileInput.files.length) {
        albumAddBtn.click();
      }
    });
  }

  // --- Save ---
  if (albumSaveBtn) {
    albumSaveBtn.addEventListener('click', function (e) {
      e.preventDefault();

      if (currentKind === 'album') {
        // Save standalone album
        var title = albumTitleInput ? albumTitleInput.value.trim() : '';
        if (!title) {
          alert('Title is required for standalone albums.');
          return;
        }
        var description = albumDescInput ? albumDescInput.value.trim().slice(0, 500) : '';
        var draft = albumDraftInput ? albumDraftInput.checked : false;
        var images = albumImages.map(function (img) {
          return { src: img.src, caption: img.caption };
        });
        var method = currentSlug ? 'PUT' : 'POST';
        var url = apiOrigin + '/albums' + (currentSlug ? '/' + encodeURIComponent(currentSlug) : '');

        fetch(url, {
          method: method,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ title: title, description: description, draft: draft, images: images })
        })
          .then(function (res) {
            if (!res.ok) throw new Error('HTTP ' + res.status);
            return res.json();
          })
          .then(function (saved) {
            currentSlug = saved.slug;
            alert('Album saved.');
            refreshAlbumList();
          })
          .catch(function (err) {
            console.error('Failed to save album', err);
            alert('Failed to save album. See console for details.');
          });
      } else {
        // Save post album images
        if (!currentSlug || !currentKind) {
          alert('Select a post first.');
          return;
        }
        var images = albumImages.map(function (img) {
          return { src: img.src, caption: img.caption };
        });
        fetch(apiOrigin + '/posts/' + encodeURIComponent(currentKind) + '/' + encodeURIComponent(currentSlug) + '/images', {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ images: images }),
        })
          .then(function (res) {
            if (!res.ok) throw new Error('HTTP ' + res.status);
            return res.json();
          })
          .then(function (saved) {
            alert('Album saved (' + (saved.images || []).length + ' total images).');
            refreshPostList();
          })
          .catch(function (err) {
            console.error('Failed to save album', err);
            alert('Failed to save album. See console for details.');
          });
      }
    });
  }

  // --- Delete standalone album ---
  if (albumDeleteBtn) {
    albumDeleteBtn.addEventListener('click', function (e) {
      e.preventDefault();
      if (currentKind !== 'album' || !currentSlug) {
        alert('Select a standalone album to delete.');
        return;
      }
      if (!confirm('Delete this album and its images? This cannot be undone.')) return;

      fetch(apiOrigin + '/albums/' + encodeURIComponent(currentSlug), { method: 'DELETE' })
        .then(function (res) {
          if (!res.ok) throw new Error('HTTP ' + res.status);
          clearForm();
          refreshAlbumList();
        })
        .catch(function (err) {
          console.error('Failed to delete album', err);
          alert('Failed to delete album. See console for details.');
        });
    });
  }

  showStandaloneMeta(false);
  renderAlbumItems();
  refreshPostList();
  refreshAlbumList();
})();
