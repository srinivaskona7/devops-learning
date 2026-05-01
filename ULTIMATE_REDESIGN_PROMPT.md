# 🚀 ULTIMATE REDESIGN PROMPT: THE ROOT SPA TRANSFORMATION

**Objective**: Convert the entire `Devops-learning` repository into a standalone premium React application deployed at the ROOT.

---

## 🎨 DESIGN SYSTEM (STITCH)
- **Visuals**: Full Cyberpunk Glassmorphism.
- **Glass**: `backdrop-filter: blur(30px)`.
- **Glow**: Cyan neon pulses on interactive elements.

---

## 🏗️ THE NEW ARCHITECTURE
1.  **Deployment**: The site must live at `https://srinivaskona7.github.io/devops-learning/`.
2.  **Vite Config**: `base` must be set to `/devops-learning/`.
3.  **Entry Point**: The React app is the only frontend. MkDocs is discontinued.

---

## 🛠️ IMPLEMENTATION STEPS FOR CLAUDE
1.  **Re-Initialize**: If necessary, move the `platform/` files to the root so `package.json` is at the top level.
2.  **Build the Shell**: Use `App.tsx` as the main router.
3.  **Content Bridge**: Build a loader that imports `.md` files from the repo and renders them beautifully with syntax highlighting.
4.  **Intelligence**: Re-implement the **Bento Dashboard** and **Falco Terminal** widgets.

---

## 🏁 YOUR FIRST COMMAND
"Claude, we are building a Standalone SPA at the root. Move the platform files to the repository root, update the Vite base path, and begin building the Main Dashboard using the Stitch Cyberpunk design system. Everything must load at the main GitHub Pages root URL."
