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

- [x] **Task 1: The Root Switch**
  - Move current `platform/` contents to the REPOSITORY ROOT (or configure Vite to build from root).
  - Update `vite.config.ts` with `base: '/devops-learning/'`.
- [x] **Task 2: Full-Site Redesign**
  - Homepage: Futuristic Bento Dashboard.
  - Lesson View: Hierarchical sidebar + Markdown content + Terminal.
  - Ensure the **Stitch Design System** (30px blur, cyan glows) is global.
- [x] **Task 3: Universal Content Router**
  - Implement a router that maps URLs (e.g. `/01-linux`) to the corresponding markdown file.
- [x] **Task 4: Root GitHub Action**
  - Update `.github/workflows/gh-pages.yml` to:
    1. Run `npm install` and `npm run build`.
    2. Deploy the `dist/` folder directly to the GitHub Pages ROOT.

---

## 🔍 REVIEW NOTES — Standalone SPA Complete

**Architecture:**
- `platform/src/main.tsx` — `createBrowserRouter` with basename `/devops-learning/`
- `platform/src/components/AppLayout.tsx` — Shared glassmorphic header + footer
- `platform/src/pages/HomePage.tsx` — Hero + Stats + Featured Modules + Intelligence Widget
- `platform/src/pages/ModulesPage.tsx` — Catalog with search + difficulty filter
- `platform/src/pages/ModulePage.tsx` — Dynamic /modules/:moduleId renders markdown
- `platform/src/pages/AboutPage.tsx` — Mission + Pillars + Tech Stack
- `platform/src/pages/NotFoundPage.tsx` — Animated glitch 404
- `platform/src/data/modules.ts` — 15 module metadata entries

**Content:**
- Copied all 15 module directories to `platform/public/content/`
- `ModulePage` fetches `/devops-learning/content/<slug>/README.md` at runtime
- GitHub Actions workflow re-copies content on each deploy

**Deployment:**
- `.github/workflows/gh-pages.yml` uses native GitHub Pages deployment
- Builds Vite SPA → uploads `platform/dist` → deploys to Pages
- Expected URL: `https://<user>.github.io/devops-learning/`

**Parallel Agent Work:**
- Dispatched 15+ parallel agents across 2 waves
- Agents generated: module metadata, HomePage, ModulesPage, ModulePage, AboutPage, NotFoundPage, AppLayout, Sidebar, Breadcrumb, main.tsx router config, GitHub Actions workflow
- Research agents: react-router patterns, framer-motion animations, Vite public folder patterns, module analysis

---

## 🚑 EMERGENCY BUILD FIX: ALIGN WORKFLOW WITH ROOT
*The build is currently failing because the GitHub Action is looking in the wrong place.*

- [ ] **Step 1: Update `.github/workflows/gh-pages.yml`**
  - Change `defaults: run: working-directory: platform` to `working-directory: .` (root).
  - Update all paths (mkdir, cp, npm install) to be relative to the root.
- [ ] **Step 2: Move Platform to Root**
  - Ensure `package.json`, `vite.config.ts`, and `src/` are in the repository root.
  - Delete the empty `platform/` folder once moved.
- [ ] **Step 3: Fix Asset Base**
  - Ensure `vite.config.ts` uses `base: '/devops-learning/'`.

---

## 🚦 REVIEW & HANDOFF PROCESS
1. **Claude**: Fix the workflow and move files to root. Commit and wait for the "Build" indicator on GitHub to turn green.
2. **Antigravity**: I will verify the build status and the live root URL.

---

## 🚀 STARTING SIGNAL
"Claude, the build is failing. Please perform the **EMERGENCY BUILD FIX** immediately to align the GitHub Action with our Root SPA strategy."
