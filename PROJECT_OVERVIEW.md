# DevOps Learning Lab — Project Overview

> Single-file complete picture of this repository: what it is, how it's organized,
> how it's taught, how it's built, and how it deploys.

---

## 1. What this is

A **learn-by-doing DevOps curriculum** — **15 learning modules + 10 end-to-end projects** —
delivered two ways:

1. **Markdown content** (`NN-topic/README.md` per module) — the source of truth.
2. **A standalone Vite + React SPA** (in `src/`) that renders that same markdown as a
   futuristic "Stitch Design" learning platform, deployed to GitHub Pages.

There is also a legacy **MkDocs Material** config (`mkdocs.yml`) that serves the markdown as a
docs site locally. The SPA is the current deployment target; MkDocs remains for local browsing.

- **Live URL:** `https://srinivaskona7.github.io/devops-learning/`
- **License:** MIT © 2026 DevOps Learning Lab Contributors

---

## 2. The teaching pattern (every concept)

Each concept follows the **same six-stage flow**:

| Stage | Meaning |
|-------|---------|
| 🧭 **Reason** | Why it exists; the real production problem it solves |
| 🧠 **Thinking** | Mental model + a Mermaid diagram |
| ⚡ **Execution** | The actual commands / code |
| 🔮 **Simulation** | What happens when you run it |
| ✅ **Output** | Expected result |
| 🌍 **Use-case** | How Netflix / Stripe / Cloudflare etc. use it |

Every **project** ships: a runnable app, an architecture diagram, a `Makefile`
(`make up / test / perf / down`), a QA test plan, and a **k6** performance benchmark.
Projects P05–P10 additionally prove **zero-downtime** upgrades (traffic during rollout, 0% errors).

---

## 3. Curriculum — 15 modules

| # | Folder | Topic | Level | Hours |
|---|--------|-------|-------|------:|
| 01 | `01-linux` | Linux fundamentals, bash, systemd, networking | Beginner | 12 |
| 02 | `02-docker` | Containers, images, Compose, registries, security | Beginner | 10 |
| 03 | `03-kubernetes` | Core + Strategies + Advanced (pods → operators → GitOps) | Intermediate → Expert | 46 |
| 04 | `04-helm` | Charts, templating, releases, helmfile, sealed-secrets | Intermediate | 8 |
| 05 | `05-monitoring` | Prometheus, PromQL, Grafana, Loki, Tempo, OTel, SLOs | Intermediate | 12 |
| 06 | `06-security` | STRIDE, RBAC, PSA, NetworkPolicy, SBOM, cosign, SLSA, OPA/Kyverno, Falco | Advanced | 10 |
| 07 | `07-terraform` | IaC, modules, state, workspaces, drift, testing (terratest, checkov) | Intermediate | 14 |
| 08 | `08-projects` | 10 end-to-end capstone projects | Beginner → Expert | 80+ |
| 09 | `09-interview-prep` | 10 architect-level Q&A scenarios + mock transcripts | Advanced | — |
| 10 | `10-scripting` | Python & Bash — 50 automation examples, DevOps libs | Intermediate | — |
| 11 | `11-devops-tools` | 20 trending tools — basics → PhD, 30 examples each | Intermediate → Expert | — |
| 12 | `12-golang` | Go for DevOps — foundations, client-go, Docker SDK, operators, CLIs | Advanced | — |
| 13 | `13-operators` | Kubernetes Operators & CRDs — 10 operator projects | Advanced → Expert | 20 |
| 14 | `14-policy-as-code` | OPA (Gatekeeper/Rego) & Kyverno — 10 policy projects | Intermediate → Expert | 16 |
| 15 | `15-ai-for-devops` | AIOps, LLMs for IaC, RAG runbooks, platform intelligence | Expert | 16 |

**Module 03 (Kubernetes)** is split into `01-core`, `02-strategies`, `03-advanced`.

---

## 4. The 10 Projects (`08-projects/`)

| ID | Project | Focus |
|----|---------|-------|
| P01 | `01-hello-world-end-to-end` | Static site · Docker |
| P02 | `02-three-tier-app` | Three-tier · Docker Compose |
| P03 | `03-gitops-with-argocd` | GitOps · Argo CD |
| P04 | `04-ci-cd-pipeline` | CI/CD · GitHub Actions |
| P05 | `05-observability-stack` | Observability · OpenTelemetry |
| P06 | `06-prod-grade-cluster-on-aws` | Production EKS · Terraform |
| P07 | `07-disaster-recovery` | DR · Velero |
| P08 | `08-security-hardening-lab` | Security · SLSA |
| P09 | `09-zero-downtime-progressive-delivery` | Zero-downtime · Argo Rollouts |
| P10 | `10-platform-engineering-end-to-end` | Platform Engineering · Backstage |

---

## 5. The SPA (deployment target)

**Stack:** Vite 4 + React 18 + TypeScript + Tailwind CSS 3 + Framer Motion +
`react-router-dom` 7 + `react-markdown` (remark-gfm, remark-math, rehype-katex) + highlight.js.

**Vite base path:** `/devops-learning/` (set in `vite.config.ts`).

### Source layout (`src/`)

```
src/
  main.tsx                    # createBrowserRouter, basename /devops-learning/
  index.css                   # Stitch design system (30px blur, cyan glows)
  data/modules.ts             # 15 module metadata entries
  pages/
    HomePage.tsx              # Hero + Stats + Featured Modules + Intelligence Widget
    ModulesPage.tsx          # Catalog: search + difficulty filter
    ModulePage.tsx           # /modules/:moduleId — fetches & renders markdown at runtime
    AboutPage.tsx            # Mission + Pillars + Tech Stack
    NotFoundPage.tsx         # Animated glitch 404
  components/
    AppLayout.tsx            # Shared glassmorphic header + footer
    Sidebar.tsx  BentoGrid.tsx  HeroCard.tsx  StatCard.tsx
    IntelligenceWidget.tsx  InteractiveTerminal.tsx  LearningJourneyCard.tsx
    index.ts
```

**Content pipeline:** module markdown is copied into `public/content/<slug>/README.md`;
`ModulePage` fetches `/devops-learning/content/<slug>/README.md` at runtime. The GitHub
Actions workflow re-copies content on each deploy.

---

## 6. Build, run & deploy

```bash
# --- SPA (current deployment) ---
npm install
npm run dev        # Vite dev server → http://localhost:5173
npm run build      # tsc -b && vite build → dist/
npm run preview    # preview the production build

# --- MkDocs (local markdown browsing) ---
pip install -r requirements.txt
mkdocs serve       # http://localhost:8000
mkdocs build       # → ./site/

# --- Run any project ---
cd 08-projects/01-hello-world-end-to-end
make up && make test && make perf && make down
```

### CI/CD — `.github/workflows/`

| Workflow | Purpose |
|----------|---------|
| `gh-pages.yml` | `npm install` → `npm run build` → copy content → deploy `dist/` to GitHub Pages root |
| `lighthouse.yml` | Lighthouse CI performance/quality audit (`lighthouserc.json`) |
| `qa.yml` | Quality checks (markdownlint, link check via `.lycheeignore`) |

---

## 7. Repo map (top level)

```
01-linux … 15-ai-for-devops   # 15 curriculum modules (markdown)
08-projects/                   # 10 capstone projects
docs/                          # MkDocs content, _template/, stylesheets/extra.css
overrides/                     # MkDocs Material theme overrides (main.html)
src/                           # Vite + React SPA source
public/                        # SPA static assets + copied module content
dist/                          # SPA production build output
scripts/                       # helper scripts (e.g. render-mermaid.py)
assets/                        # shared images
mkdocs.yml                     # MkDocs Material config (font:false, docs_dir logic)
vite.config.ts                 # Vite config (base /devops-learning/)
package.json / tsconfig*.json  # SPA toolchain
tailwind.config.js postcss.config.js eslint.config.js
requirements.txt               # MkDocs + plugins
README.md CONTRIBUTING.md LICENSE
CLAUDE_COLLABORATION_PROTOCOL.md   # SPA build/deploy protocol
STITCH_MASTER_PROMPT.md / ULTIMATE_REDESIGN_PROMPT.md  # design prompts
```

---

## 8. Key conventions

- **6-stage teaching pattern is mandatory** for every new concept; include a Mermaid diagram.
- All examples must run in **kind / minikube**.
- Mermaid uses raw ```` ```mermaid ```` fences (rendered by the `mermaid2` plugin in MkDocs,
  and by the SPA renderer).
- MkDocs: `font: false` (fonts via CSS `@import`); the `@import` must be the **first** rule in
  `docs/stylesheets/extra.css`; `overrides/main.html` extends `base.html`.
- SPA is the deployment target; keep `vite.config.ts` `base: '/devops-learning/'`.

## 9. Contributing

PRs welcome — see [CONTRIBUTING.md](./CONTRIBUTING.md). Follow the 6-stage pattern, add a
Mermaid diagram per concept, keep everything runnable locally.
