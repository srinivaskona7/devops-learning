/* killercoda.js — lazy iframe embeds for killercoda scenarios.
 * Usage: <div data-killercoda="some-author/some-scenario"></div>
 */
(function () {
  'use strict';

  function init() {
    const nodes = document.querySelectorAll('div[data-killercoda]:not([data-kc-loaded])');
    if (!nodes.length || !('IntersectionObserver' in window)) {
      nodes.forEach(load);
      return;
    }
    const io = new IntersectionObserver((entries) => {
      entries.forEach(en => {
        if (en.isIntersecting) {
          load(en.target);
          io.unobserve(en.target);
        }
      });
    }, { rootMargin: '200px' });
    nodes.forEach(n => io.observe(n));
  }

  function load(node) {
    const path = node.getAttribute('data-killercoda');
    if (!path) return;
    node.dataset.kcLoaded = '1';
    node.classList.add('dl-killercoda');
    const iframe = document.createElement('iframe');
    iframe.src = 'https://killercoda.com/' + path.replace(/^\/+/, '');
    iframe.loading = 'lazy';
    iframe.allow = 'fullscreen';
    iframe.title = 'Killercoda: ' + path;
    node.appendChild(iframe);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else { init(); }
  if (window.document$ && typeof window.document$.subscribe === 'function') {
    window.document$.subscribe(init);
  }
})();
