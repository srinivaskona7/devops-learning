# Redesign Plan — "Best Teacher" DevOps Learning Platform

**Decisions locked in:** roadmap.sh-style experience · enhance the existing Vite + React SPA
(no migration, stays on GitHub Pages) · optimize for pedagogy + interview prep + interactive +
visual polish.

---

## 1. What we borrow from the best learning sites

| Site | What we steal | Where it lands |
|------|---------------|----------------|
| **roadmap.sh** | Visual interactive roadmap (DAG), "mark as done", progress % | Home page |
| **Brilliant / Khan** | First-principles + analogy + "check yourself" after every idea | Lesson pedagogy layers |
| **Codecademy / educative** | Split lesson + runnable panel, streaks, XP | Lesson page + progress store |
| **KodeKloud / Katacoda** | Embedded terminal per concept | Execution stage (already have `InteractiveTerminal`) |
| **Exercism** | Practice track, spaced repetition | Flashcards / practice page |
| **LeetCode / Pramp** | Question bank + timed mock mode | Interview prep |
| **GitBook / Docusaurus** | ⌘K search, clean TOC, deep-linking | Cross-cutting |

---

## 2. The experience — three surfaces + cross-cutting

### A. Roadmap (home) — the hook
- Full interactive DAG rendered with **`reactflow`**. Nodes = topics, edges = prerequisites.
- Nodes colored by level (beginner/intermediate/advanced/expert), show a ✓ when completed,
  a ◐ when in progress. A progress ring shows overall % + current streak.
- "Continue where you left off" CTA. Click a node → lesson page.
- Graph is **derived from topic frontmatter** (`prereqs: [...]`) at build time — no hand-maintained edges.

### B. Lesson page — "the best teacher"
Three-column: **module tree (left)** · **content (center)** · **on-this-page TOC + progress (right)**.

Each concept is taught in **layered depth** with a toggle:

```
[ ELI10 ]  [ Standard ]  [ Deep dive ]      ← difficulty toggle
```

Content sections per concept (extends the existing 6-stage pattern):

| Section | Purpose |
|---------|---------|
| 🎣 **Hook** | One sentence: the pain / incident |
| 🧒 **ELI10** | Analogy a beginner gets instantly |
| 🧠 **Mental model** | First-principles + Mermaid diagram |
| 🧭 Reason · 🧠 Thinking · ⚡ Execution · 🔮 Simulation · ✅ Output · 🌍 Use-case | the current 6-stage core |
| ⚠️ **Gotchas** | Common mistakes, "what breaks in prod" |
| 🎓 **Deep dive** | Internals + what senior engineers know (hidden until toggled) |
| 📋 **Cheat sheet** | Command/flag table |
| ✅ **Check yourself** | 3–5 question quiz |
| 💼 **Interview questions** | Topic-scoped Q&A (links to interview bank) |

Interactive bits: embedded terminal on Execution, copy buttons, live **Mermaid** rendering,
KaTeX math, code highlight.

### C. Interview prep — dedicated surface
- Searchable **question bank**, filter by topic / difficulty / "system-design vs trivia".
- Each Q: collapsible model answer, a whiteboard Mermaid, difficulty + tags.
- **Mock mode**: timed, answer hidden → reveal → self-rate → feeds spaced repetition.

### D. Cross-cutting
- **Progress + XP + streaks** in `localStorage` via **`zustand`** (no backend, GitHub Pages friendly).
- **⌘K command palette** (`cmdk` + `fuse.js`) searching concepts *and* interview Qs from a
  build-time JSON index.
- **Spaced-repetition flashcards** (Leitner boxes persisted locally).
- Dark/light, full a11y, Lighthouse ≥ 95.

---

## 3. Content model (authoring stays sane)

Per topic folder, alongside `README.md`:

```
NN-topic/
  README.md          # lesson body + frontmatter (see below)
  meta.json          # { quiz:[…], interview:[…], flashcards:[…] }
```

`README.md` frontmatter drives the graph, search, and metadata:

```yaml
---
id: k8s-rolling-updates
title: Rolling Updates
module: 03-kubernetes
level: intermediate          # beginner | intermediate | advanced | expert
est_minutes: 25
prereqs: [k8s-deployments, k8s-pods]
tags: [deployments, availability, strategy]
---
```

`meta.json` shape:

```json
{
  "quiz": [{ "q": "…", "choices": ["…"], "answer": 1, "explain": "…" }],
  "interview": [{ "q": "…", "difficulty": "mid", "answer": "…", "diagram": "graph LR; …" }],
  "flashcards": [{ "front": "…", "back": "…" }]
}
```

A build script (`scripts/build-index.mjs`) walks all topics → emits:
- `public/data/roadmap.json` (nodes + edges from `prereqs`)
- `public/data/search-index.json` (concepts + interview Qs)
- `public/data/interview.json` (aggregated bank)

---

## 4. Tech additions to the current Vite SPA

| Package | Use |
|---------|-----|
| `reactflow` | Interactive roadmap DAG |
| `zustand` (persist) | Progress / XP / streak / flashcard state → localStorage |
| `cmdk` + `fuse.js` | ⌘K search palette |
| `mermaid` | Render diagrams inside markdown |
| (have) `react-markdown`, `remark-gfm/math`, `rehype-katex`, `highlight.js`, `framer-motion` | keep |

### Routes

```
/                    → roadmap home
/learn/:topicId      → lesson page
/interview           → interview bank
/interview/:topicId  → topic-filtered questions
/practice            → flashcards + quiz review (spaced repetition)
/about
```

---

## 5. Visual design — extend the Stitch system

Keep the glassmorphic Stitch look (30px blur, cyan glows) but add a proper design-token layer:
- CSS variables for color/space/type scales; light + dark themes.
- Node/level color legend reused across roadmap, module cards, difficulty badges.
- Motion budget: entrance + hover only; respects `prefers-reduced-motion`.
- Reading typography for lesson body (measure ~70ch, generous line-height).

---

## 6. Phased implementation

| Phase | Deliverable | Notes |
|------:|-------------|-------|
| **0** | Content model + `scripts/build-index.mjs` + frontmatter on all topics | unblocks everything |
| **1** | Roadmap home (`reactflow`) + `zustand` progress store | the signature screen |
| **2** | Lesson page: layered sections, difficulty toggle, Mermaid, terminal, TOC | core teaching UX |
| **3** | Quiz + flashcards engine + XP/streak/"continue" | retention loop |
| **4** | Interview bank + mock mode + ⌘K search | interview surface |
| **5** | Pedagogy rewrite of content (Hook/ELI10/Gotchas/Deep dive per concept) | large; parallelizable across modules |
| **6** | Polish: dark/light, a11y, Lighthouse, SEO/meta | ship quality |

**Phases 0–4 are the engine** (build once). **Phase 5 is the long tail** — 15 modules of
content upgrade; best done module-by-module (and a strong candidate for a multi-agent
fan-out if you want to opt into that).

---

## 7. Acceptance criteria (definition of done)

- [ ] Home renders the full topic graph from frontmatter; nodes reflect saved progress.
- [ ] Every topic has a lesson page with working difficulty toggle, terminal, Mermaid, quiz.
- [ ] Progress/XP/streak persist across reloads; "continue" resumes the last topic.
- [ ] Interview bank is searchable & filterable; mock mode times and reveals answers.
- [ ] ⌘K searches concepts + interview Qs.
- [ ] Lighthouse ≥ 95 (perf/a11y/best-practices/SEO); works in light & dark.
- [ ] Still deploys to GitHub Pages from `dist/` with base `/devops-learning/`.

---

## 8. Design skills to apply (already installed — invoke on demand)

These are Claude Code skills already available on this machine; no install needed. Ranked
for *this* project (React + Tailwind + Framer Motion, glassmorphic "Stitch" aesthetic,
learning-content site).

| Rank | Skill | Why for us | When to invoke |
|-----:|-------|-----------|----------------|
| 1 | **`frontend-design`** (Anthropic official) | Gold standard for distinctive, production-grade web UI — aesthetic direction, typography, restraint. Auto-triggers on UI work. | Every UI build/reshape |
| 2 | **`frontend-ui-dark-ts`** | Dark React + **Tailwind + Framer Motion + glassmorphism** — literally our stack. | Building components |
| 3 | **`antigravity-design-expert`** | Interactive/spatial/glass UI with GSAP + 3D CSS — matches Stitch glows. | Roadmap + hero motion |
| 4 | **`ui-ux-pro-max`** | Comprehensive color/typography/component design guide + review checklist. | Design-system decisions |
| 5 | **`web-design-guidelines`** | Reviews files against Web Interface Guidelines (a11y, interaction quality). | QA / review gate |
| 6 | **HIG family** (`hig-foundations`, `hig-patterns`, `hig-inputs`, `hig-components-*`) | Apple **Human Interface Guidelines** — the "human type" design system: interaction patterns, accessibility, layout. Web-applicable subset. | Interaction/a11y patterns |
| — | **`humanizer`** | Not visual — makes the *teaching prose* read human (no AI-slop), key for the "best teacher" voice. | Phase 5 content rewrite |

**Workflow:** at the start of any UI phase, invoke `frontend-design` (direction) → build with
`frontend-ui-dark-ts` / `antigravity-design-expert` → gate with `web-design-guidelines`.
For content, run `humanizer` over rewritten lessons.
