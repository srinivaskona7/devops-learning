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

```
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

## Code of Conduct

Be kind. Assume good intent. Help others learn.
