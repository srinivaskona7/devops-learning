#!/usr/bin/env python3
"""Collapse stacked mermaid:rendered wrappers caused by re-running the renderer
after the lazy-images patcher modified <img/> tags."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Pattern: 1+ stacked openings, then the actual mermaid block, then 1+ closings
STACK = re.compile(
    r'(?:<!-- mermaid:rendered -->\n'
    r'<p align="center"><img[^>]*></p>\n'
    r'\n'
    r'<details><summary>Mermaid source</summary>\n'
    r'\n)+'
    r'(```mermaid\n.*?\n```)\n'
    r'\n'
    r'(?:</details>\n*)+',
    re.DOTALL,
)

# Image tag matcher to pick the LAST img from a stack
IMG_TAG = re.compile(r'<p align="center"><img[^>]*></p>')


def collapse(text: str) -> tuple[str, int]:
    fixes = 0

    def repl(m: re.Match) -> str:
        nonlocal fixes
        full = m.group(0)
        # Count opening markers
        opens = full.count("<!-- mermaid:rendered -->")
        if opens <= 1:
            return full
        fixes += 1
        # Pick the LAST img tag (the one most recently produced)
        imgs = IMG_TAG.findall(full)
        last_img = imgs[-1] if imgs else '<p align="center">[diagram]</p>'
        mermaid_block = m.group(1)
        return (
            "<!-- mermaid:rendered -->\n"
            f"{last_img}\n"
            "\n"
            "<details><summary>Mermaid source</summary>\n"
            "\n"
            f"{mermaid_block}\n"
            "\n"
            "</details>\n"
        )

    new = STACK.sub(repl, text)
    return new, fixes


def main() -> int:
    md_files = []
    for p in ROOT.rglob("*.md"):
        if any(part in {"node_modules", "site", ".git", "assets"} for part in p.parts):
            continue
        md_files.append(p)

    total_fixes = 0
    files_changed = 0
    for md in sorted(md_files):
        text = md.read_text()
        if "<!-- mermaid:rendered -->" not in text:
            continue
        new, fixes = collapse(text)
        if fixes > 0 and new != text:
            md.write_text(new)
            files_changed += 1
            total_fixes += fixes
            print(f"{md.relative_to(ROOT)}: collapsed {fixes} stacks")

    print(f"\nDONE: collapsed {total_fixes} duplicate stacks across {files_changed} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
