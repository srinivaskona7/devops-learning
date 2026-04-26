#!/usr/bin/env python3
"""lazy-images.py — walk every Markdown file and add loading="lazy" to
plain HTML <img> tags that don't already have a loading attribute.

Idempotent. Safe to re-run. Skips images that already have loading=...
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMG_RE = re.compile(r"<img\b([^>]*)>", re.IGNORECASE)
SKIP_DIRS = {".git", "node_modules", "site", ".venv", "venv", "__pycache__"}


def patch_tag(match: re.Match[str]) -> str:
    attrs = match.group(1)
    if re.search(r"\bloading\s*=", attrs, re.IGNORECASE):
        return match.group(0)
    sep = "" if attrs.endswith(" ") or attrs == "" else " "
    return f"<img{attrs}{sep}loading=\"lazy\">"


def process(path: Path) -> bool:
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return False
    new = IMG_RE.sub(patch_tag, text)
    if new != text:
        path.write_text(new, encoding="utf-8")
        return True
    return False


def main() -> int:
    changed = 0
    scanned = 0
    for p in ROOT.rglob("*.md"):
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        scanned += 1
        if process(p):
            changed += 1
            print(f"patched: {p.relative_to(ROOT)}")
    print(f"\n{scanned} markdown files scanned, {changed} updated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
