# Design System — DevOps Learning Lab

Grounded in two skills: **ui-ux-pro-max** (color/type/UX intelligence) and **Apple HIG —
Human Interface Guidelines** (foundations). This is the source of truth for the redesign UI.

> **North star (HIG #1):** *Content over chrome.* The lesson is the hero. Glass, glow, and
> motion support reading — they never compete with it.

---

## 1. Foundations (from Apple HIG)

| Principle | How we apply it on the web |
|-----------|----------------------------|
| Content over chrome | Subtle 1px separators over heavy borders/cards; generous whitespace; glass used sparingly |
| Accessibility from day one | Every control has a label; keyboard-first; `prefers-reduced-motion`, `prefers-contrast` honored; target **WCAG AA**, **AAA** for body text |
| Semantic, adaptive color | Token layer (`--color-label`, `--color-bg`, …) that flips for light/dark & high-contrast — never hard-code hex in components |
| Consistent icon set | **Lucide** is our "SF Symbols": one set, 24px grid, weight-matched — never emojis as icons |
| Purposeful motion | Animation communicates spatial relationships (node→lesson), not decoration; crossfade fallback under Reduce Motion |
| Clear writing | Sentence case, verbs on buttons ("Start lesson"), specific errors; inclusive, non-gendered language (pairs with `humanizer` for lesson prose) |

## 2. Style

**Base:** Dark Mode (OLED) — WCAG AAA, excellent perf, Tailwind-native.
**Accent:** Glassmorphism (frosted panels, backdrop-blur 12–20px, 1px `rgba(255,255,255,.12)` border) + restrained cyan glow. *Not* full cyberpunk/neon (accessibility-limited).

## 3. Design tokens

```css
:root {
  /* Brand / semantic — dark (default) */
  --color-primary:    #3B82F6;   /* blue-500  */
  --color-primary-cta:#2563EB;   /* blue-600  */
  --color-accent:     #22D3EE;   /* cyan-400 glow, use sparingly */
  --color-bg:         #0F172A;   /* slate-900 */
  --color-surface:    #1E293B;   /* slate-800 (elevated) */
  --color-label:      #F1F5F9;   /* slate-100 primary text */
  --color-label-2:    #94A3B8;   /* slate-400 secondary text (dark only) */
  --color-separator:  rgba(255,255,255,.10);
  --glass-bg:         rgba(30,41,59,.55);
  --glass-border:     rgba(255,255,255,.12);
  --glass-blur:       16px;

  /* Level accents (roadmap nodes + difficulty badges) */
  --level-beginner:     #34D399; /* emerald */
  --level-intermediate: #3B82F6; /* blue    */
  --level-advanced:     #A78BFA; /* violet  */
  --level-expert:       #F472B6; /* pink    */
}

:root[data-theme="light"] {
  --color-bg:        #F8FAFC;
  --color-surface:   #FFFFFF;
  --color-label:     #0F172A;   /* slate-900 */
  --color-label-2:   #475569;   /* slate-600 MIN — never lighter (contrast) */
  --color-separator: #E2E8F0;
  --glass-bg:        rgba(255,255,255,.80); /* NOT /10 — invisible glass is a bug */
  --glass-border:    #E2E8F0;
}
```

**Contrast rule (HIG + ui-ux-pro-max):** body text ≥ 4.5:1; large/heading ≥ 3:1; light-mode
muted text floors at slate-600. Color is never the *only* signal (pair with icon/label).

## 4. Typography

Keep the distinctive Stitch pairing (aligns with `frontend-design`'s "be intentional"),
formalized into a scale. Respect user font-scaling — size in `rem`, never fixed `px` for text.

| Role | Font | Notes |
|------|------|-------|
| Display / headings | **Bricolage Grotesque** | distinctive, high-personality |
| Body | **Instrument Sans** | 16px min, line-height 1.6, measure 65–75ch |
| Serif accent (pull quotes) | **Fraunces** (italic) | sparingly |
| Code / terminal | **JetBrains Mono** | lessons, snippets, terminal |

*Alt (if a more classic dev-docs feel is wanted): **IBM Plex Sans** body + **JetBrains Mono**
("Developer Mono" pairing).*

Type scale (rem): `0.875 · 1 · 1.125 · 1.25 · 1.5 · 1.875 · 2.25 · 3`. Line-height 1.6 body / 1.2 headings.

## 5. Motion

- Micro-interactions **150–300ms**; page/section transitions ≤ 400ms.
- **ease-out** entering, **ease-in** exiting; never `linear` for UI.
- **Max 1–2 animated elements per view** (HIG: purposeful, not decorative).
- Animate **transform/opacity only** (GPU) — never width/height/top.
- `@media (prefers-reduced-motion: reduce)` → replace movement with instant/crossfade.
- Signature motion: roadmap node → lesson uses a shared-element/expand transition to convey hierarchy.

## 6. Spacing, layout, z-index

- 4px base grid; container `max-w-6xl`/`7xl` (pick one, keep consistent).
- Floating nav offset from edges (`top-4`), reserve its height so content isn't hidden.
- Safe reading column: lesson body ~70ch.
- z-index scale: `10` (sticky) · `20` (dropdown) · `30` (overlay) · `50` (modal/palette).
- Responsive breakpoints verified at **375 / 768 / 1024 / 1440**; no horizontal scroll on mobile.

## 7. Components (rules of thumb)

- **Roadmap node:** rounded, level-tinted left border + icon; states: locked / available / in-progress (◐) / done (✓). `cursor-pointer`, hover = subtle border+shadow (no scale that shifts layout).
- **Glass panel:** `--glass-bg` + blur + 1px `--glass-border`; content-over-chrome — no nested heavy borders.
- **Difficulty toggle (ELI10/Standard/Deep):** segmented control, keyboard-operable, `aria-pressed`.
- **Quiz / flashcard:** clear focus rings; correct/incorrect uses icon+color+text (not color alone).
- **Buttons:** verb labels; disable + spinner during async; ≥ 44×44px hit area.

## 8. Pre-delivery checklist (gate every UI PR)

- [ ] No emojis as icons — Lucide SVG only, consistent 24px grid
- [ ] All clickable elements have `cursor-pointer` + visible hover feedback
- [ ] Transitions 150–300ms, transform/opacity only, `prefers-reduced-motion` handled
- [ ] Body contrast ≥ 4.5:1 in **both** themes; glass visible in light mode; separators visible in both
- [ ] Keyboard: visible focus rings, tab order = visual order; icon buttons have `aria-label`
- [ ] Text in `rem`, ≥16px body, scales without breaking layout (Dynamic Type analog)
- [ ] Color never the sole indicator (icon/label accompanies)
- [ ] Responsive at 375 / 768 / 1024 / 1440; no mobile horizontal scroll
- [ ] Run `web-design-guidelines` skill as the review gate before merge

---

*Sources: `ui-ux-pro-max` design intelligence · Apple `hig-foundations`. Build UI with
`frontend-design` + `frontend-ui-dark-ts`; review with `web-design-guidelines`.*
