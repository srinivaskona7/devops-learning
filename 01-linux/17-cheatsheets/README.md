# Linux Cheatsheets — Print & Pin

> "The best engineers don't memorize commands. They memorize where the cheatsheet is."

These pages are designed to be **printed at A4, pinned next to your monitor**, and consulted in the heat of an incident. Each page is single-purpose, dense, visual-first, and ends with a **5-line "if you remember nothing else"** callout.

---

## Index

| # | File | Use when... | Print? |
|---|------|-------------|--------|
| 1 | [01-shortcuts.md](01-shortcuts.md) | Your fingers are slow at the shell | YES |
| 2 | [02-files-permissions.md](02-files-permissions.md) | `chmod`/`find` aren't muscle memory | YES |
| 3 | [03-text-processing.md](03-text-processing.md) | Parsing logs at 2am | YES |
| 4 | [04-systemd.md](04-systemd.md) | Service won't start, journal looks weird | YES |
| 5 | [05-networking.md](05-networking.md) | "Is it the network?" (it usually is) | YES |
| 6 | [06-troubleshooting-flowchart.md](06-troubleshooting-flowchart.md) | System slow — where to look first | YES (color) |
| 7 | [07-process-and-signals.md](07-process-and-signals.md) | Process won't die, jobs misbehaving | YES |

---

## How to use these pages

1. **Read once, end-to-end** — even the parts you "know."
2. **Print pages 1, 2, 4, 6** — they're the highest-frequency.
3. **Don't memorize. Recognize.** The goal is "I've seen this — flip the page."
4. **Annotate them** in pen. The act of writing wires it into your motor cortex.
5. **Replace every 6 months** — your shell habits drift; cheatsheets should too.

---

## Conventions

- `$` = unprivileged shell prompt
- `#` = root prompt
- `<UPPER>` = placeholder you must replace
- `[opt]` = optional argument
- Lines starting with `# ` inside code blocks are explanatory comments

---

## Suggested print order (one A4 each)

```
Desk-left wall:   [01-shortcuts] [02-files-permissions] [07-process-and-signals]
Desk-right wall:  [03-text-processing] [05-networking] [04-systemd]
Above monitor:    [06-troubleshooting-flowchart]   <- the war room poster
```

---

## See also

- `../11-admin-mastery/` — deeper admin patterns
- `../12-troubleshooting-deep/` — the "why" behind the flowchart
- `../18-interview-bank-senior/` — when you want to teach this material
