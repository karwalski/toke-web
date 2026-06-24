// Theme toggle: light / dark / auto(follow browser). Global, persisted.
// Pages set a design default (main = dark, docs = light); an explicit choice
// here overrides it across the whole site.
(function () {
  var KEY = 'toke-theme';
  var ORDER = ['auto', 'light', 'dark'];
  var ICON = { auto: '◐', light: '☀', dark: '☾' }; // ◐ ☀ ☾
  var LABEL = { auto: 'Auto', light: 'Light', dark: 'Dark' };

  function stored() { try { return localStorage.getItem(KEY); } catch (e) { return null; } }

  function apply(t) {
    var c = document.body.classList;
    c.remove('theme-light', 'theme-auto');
    if (t === 'light') c.add('theme-light');
    else if (t === 'auto') c.add('theme-auto');
    // 'dark' => no theme class (uses :root dark tokens)
  }

  function render(btn, t) {
    btn.textContent = ICON[t];
    btn.setAttribute('aria-label', 'Theme: ' + LABEL[t] + ' — click to change');
    btn.title = 'Theme: ' + LABEL[t];
  }

  document.addEventListener('DOMContentLoaded', function () {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;
    var cur = stored() || 'auto';
    render(btn, cur);
    btn.addEventListener('click', function () {
      cur = ORDER[(ORDER.indexOf(cur) + 1) % ORDER.length];
      try { localStorage.setItem(KEY, cur); } catch (e) {}
      apply(cur);
      render(btn, cur);
    });
  });
})();
