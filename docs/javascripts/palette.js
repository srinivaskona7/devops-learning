/* palette.js — Cmd/Ctrl+K command palette over MkDocs search index. */
(function () {
  'use strict';

  let INDEX = null;
  let LOADING = false;
  let overlay = null;
  let active = 0;
  let results = [];

  async function loadIndex() {
    if (INDEX || LOADING) return INDEX;
    LOADING = true;
    // MkDocs Material default: site/search/search_index.json
    const base = (document.querySelector('link[rel="canonical"]')
      ? new URL('.', document.querySelector('link[rel="canonical"]').href).href
      : '/');
    const candidates = [
      'search/search_index.json',
      '../search/search_index.json',
      '../../search/search_index.json',
      base + 'search/search_index.json',
    ];
    for (const url of candidates) {
      try {
        const r = await fetch(url);
        if (r.ok) {
          INDEX = await r.json();
          break;
        }
      } catch (e) { /* try next */ }
    }
    LOADING = false;
    return INDEX;
  }

  function score(text, q) {
    if (!text) return 0;
    const t = text.toLowerCase();
    const ql = q.toLowerCase();
    const idx = t.indexOf(ql);
    if (idx === -1) {
      // try token match
      const toks = ql.split(/\s+/).filter(Boolean);
      let s = 0;
      for (const tok of toks) {
        const i = t.indexOf(tok);
        if (i === -1) return 0;
        s += 10 - Math.min(10, i / 20);
      }
      return s;
    }
    return 100 - Math.min(80, idx);
  }

  function search(q) {
    if (!INDEX || !q) return [];
    const docs = INDEX.docs || [];
    const out = [];
    for (const d of docs) {
      const titleScore = score(d.title, q) * 2;
      const textScore  = score(d.text, q);
      const total = titleScore + textScore;
      if (total > 0) out.push({ doc: d, s: total });
    }
    out.sort((a, b) => b.s - a.s);
    return out.slice(0, 30).map(x => x.doc);
  }

  function render(q) {
    const ul = overlay.querySelector('ul');
    results = search(q);
    active = 0;
    if (!q) {
      ul.innerHTML = '<div class="dl-palette-empty">Type to search the docs…</div>';
      return;
    }
    if (!results.length) {
      ul.innerHTML = '<div class="dl-palette-empty">No matches.</div>';
      return;
    }
    ul.innerHTML = '';
    results.forEach((r, i) => {
      const li = document.createElement('li');
      if (i === 0) li.classList.add('active');
      li.dataset.i = i;
      const title = document.createElement('div');
      title.textContent = r.title || r.location;
      const sub = document.createElement('small');
      sub.textContent = (r.text || '').slice(0, 110);
      li.appendChild(title);
      li.appendChild(sub);
      li.addEventListener('click', () => go(i));
      ul.appendChild(li);
    });
  }

  function go(i) {
    const r = results[i];
    if (!r) return;
    close();
    const base = document.querySelector('base')?.href || location.origin + '/';
    location.href = new URL(r.location, base).href;
  }

  function setActive(delta) {
    if (!results.length) return;
    const items = overlay.querySelectorAll('li');
    items[active]?.classList.remove('active');
    active = (active + delta + results.length) % results.length;
    const next = items[active];
    next?.classList.add('active');
    next?.scrollIntoView({ block: 'nearest' });
  }

  async function open() {
    if (overlay) return;
    overlay = document.createElement('div');
    overlay.className = 'dl-palette-overlay';
    overlay.innerHTML = '<div class="dl-palette"><input type="text" placeholder="Search docs…" autocomplete="off" spellcheck="false"><ul></ul></div>';
    overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
    document.body.appendChild(overlay);
    const input = overlay.querySelector('input');
    input.focus();
    render('');
    input.addEventListener('input', () => render(input.value.trim()));
    input.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowDown') { e.preventDefault(); setActive(1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(-1); }
      else if (e.key === 'Enter') { e.preventDefault(); go(active); }
      else if (e.key === 'Escape') { e.preventDefault(); close(); }
    });
    await loadIndex();
    if (input.value) render(input.value.trim());
    else render('');
  }

  function close() {
    if (!overlay) return;
    overlay.remove();
    overlay = null;
  }

  document.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && (e.key === 'k' || e.key === 'K')) {
      e.preventDefault();
      if (overlay) close(); else open();
    }
  });
})();
