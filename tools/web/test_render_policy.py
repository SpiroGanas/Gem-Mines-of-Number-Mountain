from render_policy import render


def test_renders_headings_lists_bold_and_links() -> None:
    page = render("# Title\n\nHello **you** [x](http://a.b)\n\n- one\n- two\n")
    assert "<h1>Title</h1>" in page and "<strong>you</strong>" in page
    assert '<a href="http://a.b">x</a>' in page and page.count("<li>") == 2 and "</ul>" in page


def test_escapes_html() -> None:
    assert "&lt;script&gt;" in render("<script>")


def test_renders_notes_as_blockquotes() -> None:
    page = render("> A note here\n\nBody")
    assert "<blockquote><p>A note here</p></blockquote>" in page and "<p>Body</p>" in page


def test_a_draft_policy_is_named_and_refused_when_strict(tmp_path) -> None:
    """Peer review 05: the release workflow must never publish the draft header or a bracketed fill-in."""
    import subprocess
    import sys
    from pathlib import Path

    from render_policy import draft_problems

    draft = "# Policy\n\n**Policy version:** 1.0 (draft, not yet published)\n**Contact:** [CONTACT EMAIL: Spiro fills in]\n\n> Publishing note (delete this box when publishing): check.\n"
    problems = draft_problems(draft)
    assert any("draft" in line for line in problems) and any("CONTACT EMAIL" in line for line in problems)
    assert draft_problems("# Policy\n\n**Policy version:** 1.0\n**Contact:** help@example.org\n") == []
    source = tmp_path / "policy.md"
    source.write_text(draft, encoding="utf-8")
    script = Path(__file__).with_name("render_policy.py")
    strict = subprocess.run([sys.executable, str(script), str(source), str(tmp_path / "strict.html"), "--strict"], capture_output=True, text=True)
    assert strict.returncode == 1 and not (tmp_path / "strict.html").exists() and "draft" in strict.stderr
    loose = subprocess.run([sys.executable, str(script), str(source), str(tmp_path / "loose.html")], capture_output=True, text=True)
    assert loose.returncode == 0 and (tmp_path / "loose.html").exists() and "draft" in loose.stderr


def test_the_real_policy_is_still_a_draft_or_publishable() -> None:
    """Either way the renderer must agree with the file: no placeholder may slip through unnamed."""
    from pathlib import Path

    from render_policy import draft_problems

    text = Path(__file__).resolve().parents[2].joinpath("docs", "privacy-policy.md").read_text(encoding="utf-8")
    problems = draft_problems(text)
    assert ("[" in text and "Spiro fills in" in text) == bool(problems)
