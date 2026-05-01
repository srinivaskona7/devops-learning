# 🤝 CLAUDE-ANTIGRAVITY COLLABORATION PROTOCOL: STANDALONE SPA EDITION

**Objective**: Deploy the **Full Stitch Design Platform** at the ROOT of GitHub Pages. No more hybrid MkDocs.

---

## 🎯 THE MISSION
Build a Standalone Single Page Application (SPA) that serves as the entire DevOps Learning Platform.

### 🚀 CRITICAL DEPLOYMENT SPECS
- **Root URL**: `https://srinivaskona7.github.io/devops-learning/`
- **Vite Base**: `/devops-learning/`
- **Frontend**: Vite + React + Tailwind + Framer Motion.
- **Content**: Serve all 15 modules (`docs/*.md`) through a custom React Markdown renderer.

---

## 📝 CLAUDE'S EXECUTION ROADMAP (STANDALONE)

- [ ] **Task 1: The Root Switch**
  - Move current `platform/` contents to the REPOSITORY ROOT (or configure Vite to build from root).
  - Update `vite.config.ts` with `base: '/devops-learning/'`.
- [ ] **Task 2: Full-Site Redesign**
  - Homepage: Futuristic Bento Dashboard.
  - Lesson View: Hierarchical sidebar + Markdown content + Terminal.
  - Ensure the **Stitch Design System** (30px blur, cyan glows) is global.
- [ ] **Task 3: Universal Content Router**
  - Implement a router that maps URLs (e.g. `/01-linux`) to the corresponding markdown file.
- [ ] **Task 4: Root GitHub Action**
  - Update `.github/workflows/gh-pages.yml` to:
    1. Run `npm install` and `npm run build`.
    2. Deploy the `dist/` folder directly to the GitHub Pages ROOT.

---

## 🚦 REVIEW & HANDOFF PROCESS
1. **Claude**: Once Task 1 is complete (root switch), update this file and commit.
2. **Antigravity**: I will verify that the root `index.html` is no longer a 404.

---

## 🚀 STARTING SIGNAL
"Claude, we are going all-in on the Standalone SPA. Please move the Vite app to the root, set the base URL correctly, and build the full-site shell using the Stitch design specs."
