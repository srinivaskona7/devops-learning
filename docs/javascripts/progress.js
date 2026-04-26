/* progress.js — per-page lab progress tracker
 * Finds H2 headings containing "Lab", "Apply", or "Walkthrough",
 * adds checkboxes, persists to localStorage, shows a floating bubble.
 */
(function () {
  'use strict';

  const KEY = 'dl-progress:' + location.pathname;
  const RX  = /\b(Lab|Apply|Walkthrough)\b/i;

  function load() {
    try { return JSON.parse(localStorage.getItem(KEY) || '{}'); }
    catch (e) { return {}; }
  }
  function save(state) {
    try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) {}
  }

  function init() {
    const state = load();
    const heads = Array.from(document.querySelectorAll('article h2, .md-content h2'))
      .filter(h => RX.test(h.textContent || ''));
    if (!heads.length) return;

    let done = 0;
    heads.forEach((h, i) => {
      const id = h.id || ('lab-' + i);
      const cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.className = 'prog';
      cb.dataset.key = id;
      cb.setAttribute('aria-label', 'Mark complete: ' + h.textContent);
      if (state[id]) { cb.checked = true; done++; }
      cb.addEventListener('change', () => {
        const s = load();
        if (cb.checked) s[id] = 1; else delete s[id];
        save(s);
        updateBubble();
      });
      h.insertBefore(cb, h.firstChild);
    });

    const bubble = document.createElement('div');
    bubble.className = 'dl-progress-bubble';
    bubble.title = 'Folder progress (Shift+P to reset this page)';
    bubble.innerHTML = '<span class="ring"></span><span class="txt"></span>';
    document.body.appendChild(bubble);

    function updateBubble() {
      const s = load();
      const total = heads.length;
      const cur = heads.filter(h => s[h.id || '']).length;
      const pct = total ? Math.round((cur / total) * 100) : 0;
      bubble.querySelector('.ring').style.setProperty('--p', pct);
      bubble.querySelector('.txt').textContent = 'Labs: ' + cur + ' / ' + total;
    }
    updateBubble();

    // Shift+P resets
    document.addEventListener('keydown', (e) => {
      if (e.shiftKey && (e.key === 'P' || e.key === 'p') && !e.metaKey && !e.ctrlKey && !e.altKey) {
        const tag = (e.target && e.target.tagName) || '';
        if (/INPUT|TEXTAREA/.test(tag)) return;
        try { localStorage.removeItem(KEY); } catch (err) {}
        document.querySelectorAll('input.prog').forEach(c => { c.checked = false; });
        updateBubble();
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else { init(); }

  // Re-init on Material instant-nav
  if (window.document$ && typeof window.document$.subscribe === 'function') {
    window.document$.subscribe(() => {
      document.querySelectorAll('.dl-progress-bubble').forEach(b => b.remove());
      init();
    });
  }
})();
