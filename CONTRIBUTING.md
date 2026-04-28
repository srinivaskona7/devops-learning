# Contributing

Thanks for helping make DevOps Learning Lab better. This repo prioritizes **runnable, reproducible labs** over walls of text.

## How to Add a Lab

1. Pick the right top-level folder (e.g. `03-kubernetes-core`).
2. Create a numbered subfolder: `NN-short-name/` (e.g. `04-configmaps-secrets/`).
3. Each lab folder must contain:
   - `README.md` — objective, prerequisites, steps, expected output, teardown
   - manifest/code files referenced by the README
   - `Makefile` or `run.sh` for one-command execution (optional but encouraged)

## Folder Convention

```bash
NN-topic/
  README.md            # the lab guide
  manifests/           # k8s YAML, terraform, dockerfiles
  scripts/             # helper scripts
  assets/              # diagrams, images
```

## Style Rules

- **Mermaid diagrams are required** for any concept that involves more than ~50 lines of code or more than 3 moving parts. Use `flowchart` or `sequenceDiagram`.
- Code blocks must be language-tagged (` ```bash `, ` ```yaml `, ` ```hcl `).
- Keep READMEs scannable — headings, tables, bullet lists. Prose paragraphs only when needed.
- Labs must work on **kind** or **minikube** unless explicitly cloud-only.
- No secrets in commits. Use `.env.example` files.

## PR Checklist

- [ ] Lab is in the correct top-level folder
- [ ] README has objective, steps, expected output, teardown
- [ ] Mermaid diagram included if needed
- [ ] Tested locally on kind/minikube/Docker Desktop
- [ ] No secrets, kubeconfigs, or `.tfstate` files committed
- [ ] `mkdocs build` passes if you touched docs

## Quality gates

Every PR runs the `.github/workflows/qa.yml` pipeline. Run the same checks locally before pushing:

```bash
./scripts/qa-local.sh
```bash

The script mirrors CI and prints a terraform-style summary (`X passed · Y failed · Z skipped`). Checks performed:

| Check | Tool | Purpose |
|-------|------|---------|
| Docs build | `mkdocs build --strict` | fail on broken nav / internal links |
| Markdown lint | `markdownlint-cli2` | style + structure (config: `.markdownlint.jsonc`) |
| Link check | `lychee` | external + relative links (ignores: `.lycheeignore`) |
| K8s manifests | `kubeconform` | validate against Kubernetes 1.30 schemas |
| Helm charts | `helm lint` | every `Chart.yaml` discovered |
| Terraform | `terraform fmt -check` + `validate` | AWS/GCP example dirs are soft-failed |
| Shell scripts | `shellcheck` | every `*.sh` |

A separate workflow (`.github/workflows/lighthouse.yml`) runs Lighthouse CI against the deployed site after `gh-pages` succeeds and enforces the budgets defined in `lighthouserc.json` (perf >= 0.85, a11y / best-practices / SEO >= 0.95).

Install the local tooling once:

```bash
pip install -r requirements.txt
brew install lychee kubeconform helm terraform shellcheck   # macOS
npm install -g markdownlint-cli2
```

## Quizzes

Drop a self-checking quiz into any page using the `.quiz` block. The component is
pure HTML + CSS — `pymdownx.attr_list` and `md_in_html` are already enabled, so
markdown inside the `<div>` is parsed normally.

```html
<div class="quiz" markdown>
**Q:** What kubectl flag returns events sorted oldest first?
<details><summary>Show answer</summary><strong>A:</strong> <code>--sort-by=.metadata.creationTimestamp</code></details>
</div>
```

For multiple-choice add radios — they share a unique `name`:

```html
<div class="quiz" markdown>
**Q:** Which controller manages stateful workloads?

<label><input type="radio" name="q1"> Deployment</label>
<label><input type="radio" name="q1" data-correct="true"> StatefulSet</label>
<label><input type="radio" name="q1"> DaemonSet</label>

<details><summary>Show answer</summary><strong>A:</strong> StatefulSet — stable identity + ordered rollout.</details>
</div>
```

## Killercoda Embeds

Embed an interactive Killercoda scenario inline. The iframe is lazy-loaded by
`docs/javascripts/killercoda.js` so it costs nothing until scrolled into view.

```html
<div data-killercoda="killercoda/playground"></div>
```

The value is appended to `https://killercoda.com/`, e.g.
`data-killercoda="some-author/some-scenario"`.

## Glossary

Add new terms to `docs/glossary.md` in the `*[term]: definition` format. The
`pymdownx.snippets` `auto_append` config injects the file into every page, so
abbreviations get tooltips automatically.

## Progress Tracker

Any `## Lab`, `## Apply`, or `## Walkthrough` H2 heading automatically gets a
checkbox and contributes to the floating progress bubble. State is per-page in
`localStorage`. Press **Shift+P** to reset the current page.

## Command Palette

Press **Cmd/Ctrl+K** anywhere on the site to fuzzy-search the docs.

## Code of Conduct

Be kind. Assume good intent. Help others learn.
