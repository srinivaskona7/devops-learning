# 🤝 CLAUDE-ANTIGRAVITY COLLABORATION PROTOCOL

This file serves as the shared state and communication bridge between **Claude (Local)** and **Antigravity (Reviewer)**. 

---

## 🎯 MISSION: STITCH TRANSFORMATION
Transform the standard MkDocs site into a premium, high-fidelity React platform using the **Stitch Design System**.

### 🛠️ CURRENT STATUS
- [x] **Repo Knowledge Graph**: Completed via Graphify.
- [x] **Stitch Design Specs**: Defined in `STITCH_MASTER_PROMPT.md`.
- [x] **Base UI Scaffolding**: `platform/` directory initialized with Vite + React + TS.
- [/] **MkDocs Patching**: Temporary fixes applied to keep existing site functional.

---

## 📝 CLAUDE'S EXECUTION ROADMAP
*Claude, please update this list as you complete tasks.*

- [x] **Task 1: Core Design System**
  - Implement `platform/src/styles/design-tokens.css` with Stitch colors & glassmorphism.
  - Setup `Tailwind CSS` with custom configuration for Cyberpunk glows.
- [x] **Task 2: The Bento Hub**
  - Build the `BentoGrid` component for the landing page.
  - Integrate the `IntelligenceWidget` using God Node data (main, get_conn).
- [ ] **Task 3: Hierarchical Navigator**
  - Create the `Sidebar` and `ModulePath` components.
  - Implement a Markdown engine to fetch and render files from `01-linux/` to `15-ai/`.
- [ ] **Task 4: Interactive Terminal**
  - Build the CRT-style terminal component for live security alerts.
- [ ] **Task 5: Deployment Sync**
  - Configure `.github/workflows/gh-pages.yml` to build the `platform/` project.

---

## 🚦 REVIEW & HANDOFF PROCESS
1. **Claude**: Once a task is complete, mark it `[x]` here and commit your changes.
2. **Antigravity**: I will periodically check this file and the `platform/` source code.
3. **Verification**: I will use my browser tools to test the live deployment and provide feedback here in a `## 🔍 REVIEW NOTES` section.

---

## 🚀 STARTING SIGNAL
"Claude, I have scaffolded the project. Please start with **Task 1** and update this file once the Design System is active in `App.tsx`."
