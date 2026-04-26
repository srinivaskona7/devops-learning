#!/usr/bin/env python3
"""Render every ```mermaid block in the repo's .md files to SVG via mmdc,
then replace the fenced block with an <img> + collapsible source.

Run from repo root.  Idempotent: skips files where every block already has
the rendered marker.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets" / "diagrams"
ASSETS.mkdir(parents=True, exist_ok=True)

MERMAID_RE = re.compile(
    r"```mermaid\n(.*?)\n```",
    re.DOTALL,
)

MARKER = "<!-- mermaid:rendered -->"

PUPPETEER_CFG = ROOT / "scripts" / "puppeteer.json"
PUPPETEER_CFG.write_text(json.dumps({
    "executablePath": "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "args": ["--no-sandbox"],
}))


def render(mmd: str, out_svg: Path) -> bool:
    if out_svg.exists():
        return True
    with tempfile.NamedTemporaryFile("w", suffix=".mmd", delete=False) as f:
        f.write(mmd)
        src = f.name
    try:
        cp = subprocess.run(
            [
                "mmdc",
                "-i", src,
                "-o", str(out_svg),
                "-b", "transparent",
                "-p", str(PUPPETEER_CFG),
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if cp.returncode != 0:
            print(f"  ! mmdc failed: {cp.stderr.strip()[:200]}", file=sys.stderr)
            return False
        return out_svg.exists()
    finally:
        os.unlink(src)


def patch_file(md: Path) -> tuple[int, int]:
    """Returns (rendered, total)."""
    text = md.read_text()
    blocks = list(MERMAID_RE.finditer(text))
    if not blocks:
        return (0, 0)

    rel_to_assets = os.path.relpath(ASSETS, md.parent)
    rendered = 0
    out = []
    cursor = 0
    for i, m in enumerate(blocks, 1):
        out.append(text[cursor:m.start()])
        mmd_src = m.group(1)
        # Stable name from path + content hash so reruns are idempotent.
        rel = md.relative_to(ROOT).as_posix().replace("/", "-").replace(".md", "")
        h = hashlib.sha1(mmd_src.encode()).hexdigest()[:8]
        svg_name = f"{rel}-{i}-{h}.svg"
        svg_path = ASSETS / svg_name
        ok = render(mmd_src, svg_path)
        if ok:
            rendered += 1
            img_src = f"{rel_to_assets}/{svg_name}"
            replacement = (
                f"{MARKER}\n"
                f'<p align="center"><img src="{img_src}" alt="diagram" /></p>\n\n'
                f"<details><summary>Mermaid source</summary>\n\n"
                f"```mermaid\n{mmd_src}\n```\n\n"
                f"</details>"
            )
            out.append(replacement)
        else:
            # Render failed — keep original block untouched.
            out.append(m.group(0))
        cursor = m.end()
    out.append(text[cursor:])
    new = "".join(out)
    if new != text:
        md.write_text(new)
    return (rendered, len(blocks))


def main() -> int:
    md_files = []
    for p in ROOT.rglob("*.md"):
        if any(part in {"node_modules", "site", ".git", "assets"} for part in p.parts):
            continue
        md_files.append(p)

    total_rendered = 0
    total_blocks = 0
    files_touched = 0
    for md in sorted(md_files):
        rendered, blocks = patch_file(md)
        if blocks:
            print(f"{md.relative_to(ROOT)}: {rendered}/{blocks}")
            files_touched += 1
            total_rendered += rendered
            total_blocks += blocks
    print(f"\nDONE: {total_rendered}/{total_blocks} blocks across {files_touched} files")
    return 0 if total_rendered == total_blocks else 1


if __name__ == "__main__":
    sys.exit(main())
