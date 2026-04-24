(function () {
  'use strict';

  function init() {
    var triggers = Array.prototype.slice.call(
      document.querySelectorAll('.album-photo-trigger')
    );
    if (triggers.length === 0) return;

    var photos = triggers.map(function (btn) {
      return {
        trigger: btn,
        src: btn.getAttribute('data-full-src') || '',
        caption: btn.getAttribute('data-caption') || ''
      };
    });

    var overlay = document.createElement('div');
    overlay.className = 'album-lightbox';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Photo viewer');
    overlay.hidden = true;
    if (photos.length <= 1) overlay.setAttribute('data-single', 'true');

    overlay.innerHTML = [
      '<button type="button" class="album-lightbox-close" aria-label="Close photo viewer">&times;</button>',
      '<button type="button" class="album-lightbox-prev" aria-label="Previous photo">&larr;</button>',
      '<img class="album-lightbox-img" alt="">',
      '<figcaption class="album-lightbox-caption"></figcaption>',
      '<div class="album-lightbox-counter" aria-live="polite"></div>',
      '<button type="button" class="album-lightbox-next" aria-label="Next photo">&rarr;</button>'
    ].join('');

    document.body.appendChild(overlay);

    var imgEl = overlay.querySelector('.album-lightbox-img');
    imgEl.decoding = 'async';
    if ('fetchPriority' in imgEl) imgEl.fetchPriority = 'high';
    var captionEl = overlay.querySelector('.album-lightbox-caption');
    var counterEl = overlay.querySelector('.album-lightbox-counter');
    var closeBtn = overlay.querySelector('.album-lightbox-close');
    var prevBtn = overlay.querySelector('.album-lightbox-prev');
    var nextBtn = overlay.querySelector('.album-lightbox-next');

    var currentIndex = -1;
    var previousFocus = null;
    var previousBodyOverflow = '';

    function preload(src) {
      if (!src) return;
      var im = new Image();
      im.decoding = 'async';
      im.src = src;
    }

    function preloadNeighbors(i) {
      var total = photos.length;
      if (total < 2) return;
      preload(photos[(i + 1) % total].src);
      preload(photos[(i - 1 + total) % total].src);
    }

    function showAt(i) {
      var total = photos.length;
      var idx = ((i % total) + total) % total;
      currentIndex = idx;
      var photo = photos[idx];
      imgEl.src = photo.src;
      imgEl.alt = photo.caption || '';
      captionEl.textContent = photo.caption || '';
      captionEl.style.display = photo.caption ? '' : 'none';
      counterEl.textContent = (idx + 1) + ' / ' + total;
      preloadNeighbors(idx);
    }

    function open(index) {
      previousFocus = document.activeElement;
      previousBodyOverflow = document.body.style.overflow;
      document.body.style.overflow = 'hidden';
      overlay.hidden = false;
      showAt(index);
      setTimeout(function () {
        closeBtn.focus();
      }, 0);
    }

    function close() {
      overlay.hidden = true;
      imgEl.src = '';
      document.body.style.overflow = previousBodyOverflow;
      if (previousFocus && typeof previousFocus.focus === 'function') {
        previousFocus.focus();
      }
    }

    function next() { showAt(currentIndex + 1); }
    function prev() { showAt(currentIndex - 1); }

    triggers.forEach(function (btn, i) {
      btn.addEventListener('click', function (e) {
        e.preventDefault();
        open(i);
      });
    });

    closeBtn.addEventListener('click', close);
    nextBtn.addEventListener('click', next);
    prevBtn.addEventListener('click', prev);

    overlay.addEventListener('click', function (e) {
      if (e.target === overlay) close();
    });

    document.addEventListener('keydown', function (e) {
      if (overlay.hidden) return;
      switch (e.key) {
        case 'Escape':
          e.preventDefault();
          close();
          break;
        case 'ArrowRight':
          if (photos.length > 1) {
            e.preventDefault();
            next();
          }
          break;
        case 'ArrowLeft':
          if (photos.length > 1) {
            e.preventDefault();
            prev();
          }
          break;
        case 'Tab':
          trapFocus(e);
          break;
      }
    });

    function trapFocus(e) {
      var focusables = Array.prototype.slice.call(
        overlay.querySelectorAll('button')
      ).filter(function (el) {
        return !el.disabled && el.offsetParent !== null;
      });
      if (focusables.length === 0) return;
      var first = focusables[0];
      var last = focusables[focusables.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
