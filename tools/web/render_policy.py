"""Turns docs/privacy-policy.md into one small HTML page for the web build (standard library only).

  python tools/web/render_policy.py docs/privacy-policy.md build/web/privacy-policy.html [--strict]

Handles what the policy uses: # headings, paragraphs, "- " bullets, "> " notes, **bold**, [text](url) links.
With --strict (the release workflow passes it on a version tag) a policy that is still a draft is refused: a
"draft, not yet published" version line, a bracketed fill-in such as "[CONTACT EMAIL: ...]" or the publishing note,
so the public page can never show them (peer review 05).
"""
from __future__ import annotations

import html
import re
import sys
from pathlib import Path

DRAFT_MARKS = ("draft, not yet published", "Publishing note", "Spiro fills in")
PLACEHOLDER = re.compile(r"\[[A-Z][A-Z ]+:[^\]]*\]")


def draft_problems(markdown: str) -> list[str]:
    """Why the policy is not ready to publish (empty when it is)."""
    found = [f"the policy still says {mark!r}" for mark in DRAFT_MARKS if mark in markdown]
    found += [f"the policy still has the fill-in {match.group(0)!r}" for match in PLACEHOLDER.finditer(markdown)]
    return found


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
        elif line.startswith("> "):
            out.append(f"<blockquote><p>{inline(line[2:])}</p></blockquote>")
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
    args = [arg for arg in sys.argv[1:] if arg != "--strict"]
    strict = "--strict" in sys.argv[1:]
    if len(args) != 2:
        print(__doc__)
        return 2
    markdown = Path(args[0]).read_text(encoding="utf-8")
    problems = draft_problems(markdown)
    if problems:
        for problem in problems:
            print(f"privacy policy: {problem}", file=sys.stderr)
        if strict:
            print("privacy policy: still a draft; not rendered (publish only a finished policy)", file=sys.stderr)
            return 1
    Path(args[1]).write_text(render(markdown), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
