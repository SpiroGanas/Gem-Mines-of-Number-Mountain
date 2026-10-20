"""Turns docs/privacy-policy.md into one small HTML page for the web build (standard library only).

  python tools/web/render_policy.py docs/privacy-policy.md build/web/privacy-policy.html

Handles what the policy uses: # headings, paragraphs, "- " bullets, **bold**, [text](url) links.
"""
from __future__ import annotations

import html
import re
import sys
from pathlib import Path


def inline(text: str) -> str:
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)


def render(markdown: str) -> str:
    out: list[str] = []
    in_list = False
    for raw in markdown.splitlines():
        line = raw.rstrip()
        if in_list and not line.startswith("- "):
            out.append("</ul>")
            in_list = False
        if not line:
            continue
        heading = re.match(r"(#{1,3}) (.*)", line)
        if heading:
            level = len(heading.group(1))
            out.append(f"<h{level}>{inline(heading.group(2))}</h{level}>")
        elif line.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(line[2:])}</li>")
        else:
            out.append(f"<p>{inline(line)}</p>")
    if in_list:
        out.append("</ul>")
    body = "\n".join(out)
    return (
        '<!doctype html>\n<html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        "<title>Privacy policy: Gem Mines of Number Mountain</title>"
        "<style>body{font-family:system-ui,sans-serif;max-width:42rem;margin:2rem auto;padding:0 1rem;line-height:1.5}</style>"
        f"</head><body>\n{body}\n</body></html>\n"
    )


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    Path(sys.argv[2]).write_text(render(Path(sys.argv[1]).read_text(encoding="utf-8")), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
