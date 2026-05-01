# CLAUDE MASTER PROMPT: DEVOPS LEARNING PLATFORM STITCH TRANSFORMATION

**Objective**: Rebuild the `Devops-learning` repository frontend as a premium, high-performance web platform that matches the **Stitch Design System** (Project 8920726597652752825) perfectly.

---

## 🎨 DESIGN SYSTEM (STITCH)
- **Background**: `#0f172a` (Slate 900)
- **Primary Accent**: `#22d3ee` (Cyan 400 / Neon Glow)
- **Secondary Accent**: `#4ade80` (Green 400)
- **Surface**: `rgba(30, 41, 59, 0.7)` (Slate 800 + Transparency)
- **Glassmorphism**: `backdrop-filter: blur(30px); border: 1px solid rgba(34, 211, 238, 0.2);`
- **Typography**: Inter (Variable), High Weight Contrast (ExtraBold for Headers).
- **Light Logic**: Every interactive element must "glow" on hover using `box-shadow: 0 0 20px rgba(34, 211, 238, 0.4)`.

---

## 🏗️ ARCHITECTURE & DATA
- **Repo Context**: 762 system files.
- **Graphify Insights**: 
    - **God Nodes**: `main()`, `get_conn()`, `run_migrations()`.
    - **Hidden Link**: `docs/palette.js` connects semantically to backend `run_migrations()`.
- **Content Hierarchy**: Modules `01-linux` through `15-ai-for-devops`.

---

## 🛠️ IMPLEMENTATION ROADMAP (VITE + REACT)

### PHASE 1: SCAFFOLD
1. Create a `platform/` directory.
2. Initialize with **Vite + React + TypeScript**.
3. Install dependencies: `lucide-react`, `framer-motion`, `clsx`, `tailwind-merge`.

### PHASE 2: BENTO DASHBOARD
1. Implement a **Bento Grid** layout for the home page.
2. **Hero Card**: 'The Intelligent DevOps Navigator' with a pulsing neon cursor.
3. **Intelligence Widget**: A mini-graph showing the `main()` -> `get_conn()` -> `run_migrations()` dependency chain.
4. **Learning Journey Cards**: Animated cards for all 15 modules with progress bars.

### PHASE 3: COURSE VIEW
1. **Glassmorphic Sidebar**: Persistent hierarchical navigation.
2. **Markdown Renderer**: Render `.md` files with premium syntax highlighting for YAML/Shell.
3. **Live Terminal Component**: A terminal simulation (CRT scanlines) at the bottom showing Falco security alert streams.

### PHASE 4: GITHUB PAGES DEPLOYMENT
1. Update `.github/workflows/gh-pages.yml` to build from the `platform/` folder.
2. Set the `base` URL for Vite to `/devops-learning/`.

---

## 🚀 YOUR FIRST TASK
"Claude, please begin by creating the `index.css` and `App.tsx` files in the `platform/src` directory. Implement the global **Cyberpunk Glassmorphism** styles and the **Bento Grid** dashboard shell using the tokens provided above."
