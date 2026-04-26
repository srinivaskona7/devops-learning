/* copy-yaml.js — adds "Copy + apply" button to YAML code blocks. */
(function () {
  'use strict';

  function showToast(msg) {
    const t = document.createElement('div');
    t.className = 'dl-toast';
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(() => { t.style.opacity = '0'; t.style.transition = 'opacity 240ms'; }, 1800);
    setTimeout(() => t.remove(), 2100);
  }

  function buildCmd(yaml) {
    return "cat <<'EOF' | kubectl apply -f -\n" + yaml.replace(/\s+$/,'') + "\nEOF\n";
  }

  function decorate(code) {
    const pre = code.closest('pre');
    if (!pre) return;
    const wrap = pre.closest('.highlight') || pre.parentElement;
    if (!wrap || wrap.dataset.kubectlReady) return;
    wrap.dataset.kubectlReady = '1';
    if (getComputedStyle(wrap).position === 'static') wrap.style.position = 'relative';

    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'dl-copy-yaml';
    btn.textContent = 'Copy + apply';
    btn.title = 'Copy as kubectl apply heredoc';
    btn.addEventListener('click', async (e) => {
      e.preventDefault();
      e.stopPropagation();
      const yaml = code.innerText;
      const cmd = buildCmd(yaml);
      try {
        await navigator.clipboard.writeText(cmd);
        showToast('Copied — paste in your terminal');
      } catch (err) {
        // fallback
        const ta = document.createElement('textarea');
        ta.value = cmd;
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand('copy'); showToast('Copied — paste in your terminal'); }
        catch (e2) { showToast('Copy failed'); }
        ta.remove();
      }
    });
    wrap.appendChild(btn);
  }

  function init() {
    const blocks = document.querySelectorAll('pre code.language-yaml, pre code.language-yml');
    blocks.forEach(decorate);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else { init(); }
  if (window.document$ && typeof window.document$.subscribe === 'function') {
    window.document$.subscribe(init);
  }
})();
