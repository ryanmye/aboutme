(function () {
  var themes = {
    warm: {
      '--theme-dot-border': 'transparent',
      '--bg':           '#FAF5EE',
      '--surface':      '#FFFFFF',
      '--border':       '#E6D9C8',
      '--text':         '#2A1F16',
      '--muted':        '#8A7565',
      '--accent':       '#C4785A',
      '--accent-soft':  '#F5E6DC',
      '--accent-dark':  '#9E5A40',
      '--color-code-bg': '#F5E6DC',
      '--color-code-text': '#2A1F16',
    },
    linen: {
      '--theme-dot-border': 'transparent',
      '--bg':           '#F8F5F1',
      '--surface':      '#FFFFFF',
      '--border':       '#DDD6CE',
      '--text':         '#2A2218',
      '--muted':        '#8A7C6E',
      '--accent':       '#5C4F43',
      '--accent-soft':  '#EDE6DC',
      '--accent-dark':  '#3A2E24',
      '--color-code-bg': '#EDE6DC',
      '--color-code-text': '#2A2218',
    },
    pure: {
      '--theme-dot-border': 'transparent',
      '--bg':           '#F7F7F7',
      '--surface':      '#FFFFFF',
      '--border':       '#E0E0E0',
      '--text':         '#111111',
      '--muted':        '#888888',
      '--accent':       '#111111',
      '--accent-soft':  '#EBEBEB',
      '--accent-dark':  '#333333',
      '--color-code-bg': '#EBEBEB',
      '--color-code-text': '#111111',
    },
    barely: {
      '--theme-dot-border': 'transparent',
      '--bg':           '#242220',
      '--surface':      '#2E2B28',
      '--border':       '#383430',
      '--text':         '#EDE8E2',
      '--muted':        '#7A7068',
      '--accent':       '#B89A7D',
      '--accent-soft':  '#35302B',
      '--accent-dark':  '#D4B896',
      '--color-code-bg': '#35302B',
      '--color-code-text': '#EDE8E2',
    },
    'dark-mono': {
      '--bg':           '#181818',
      '--surface':      '#222222',
      '--border':       '#2E2E2E',
      '--text':         '#E8E8E8',
      '--muted':        '#666666',
      '--accent':       '#E8E8E8',
      '--accent-soft':  '#2A2A2A',
      '--accent-dark':  '#AAAAAA',
      '--color-code-bg': '#2A2A2A',
      '--color-code-text': '#E8E8E8',
      '--theme-dot-border': '#555555',
    },
  };

  function setTheme(key) {
    var vars = themes[key];
    var root = document.documentElement;
    Object.keys(vars).forEach(function (prop) {
      root.style.setProperty(prop, vars[prop]);
    });
    localStorage.setItem('theme', key);
    updateToggleUI(key);
  }

  function updateToggleUI(activeKey) {
    var dots = document.querySelectorAll('.theme-dot');
    dots.forEach(function (dot) {
      dot.classList.toggle('active', dot.dataset.theme === activeKey);
    });
  }

  var saved = localStorage.getItem('theme') || 'warm';
  if (themes[saved]) {
    setTheme(saved);
  } else {
    setTheme('warm');
  }

  window.addEventListener('load', function () {
    var current = localStorage.getItem('theme') || 'warm';
    if (themes[current]) {
      requestAnimationFrame(function () {
        updateToggleUI(current);
      });
    }
  });

  document.querySelectorAll('.theme-dot').forEach(function (dot) {
    dot.addEventListener('click', function () {
      setTheme(dot.dataset.theme);
    });
  });
})();
