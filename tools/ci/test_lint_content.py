"""pytest: the content lint catches what it claims to catch, and the repository passes it."""
from __future__ import annotations

from pathlib import Path

import lint_content as lint
import pytest

GOOD_LINES = "id,text,context,voice_version\nui.title.play,Play,button,0\n"


def make_tree(tmp_path: Path, files: dict[str, str]) -> Path:
    for relative, content in files.items():
        path = tmp_path / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    return tmp_path


def messages(findings: list[lint.Finding]) -> list[str]:
    return [f"{f.rule}:{f.path}:{f.line}" for f in findings]


# ---------------------------------------------------------------------------
# The real repository
# ---------------------------------------------------------------------------


def test_the_repository_passes_every_rule_with_no_warnings() -> None:
    assert [str(f) for f in lint.run(lint.ROOT)] == []


def test_main_exits_zero_on_the_repository_and_one_on_a_bad_tree(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert lint.main([]) == 0
    root = make_tree(tmp_path, {"text/lines.csv": "id,text\nbad,Hello\n"})
    assert lint.main(["--root", str(root)]) == 1
    assert "error" in capsys.readouterr().out


def test_warnings_fail_the_run_only_when_asked(tmp_path: Path) -> None:
    long_line = "id,text,context,voice_version\nui.long.line," + "word " * 14 + "end.,ctx,0\n"
    root = make_tree(tmp_path, {"text/lines.csv": long_line})
    assert lint.main(["--root", str(root)]) == 0
    assert lint.main(["--root", str(root), "--warnings-as-errors"]) == 1


# ---------------------------------------------------------------------------
# Rule 1: hard-coded text
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "code",
    [
        'label.text = "Hello there"',
        "label.text = 'Hello there'",
        'label.text = "Score: %d" % score',
        'node.tooltip_text = "Tap me"',
        'button.set_text("Go")',
        "\ttext = \"Play\"",
    ],
)
def test_rule1_flags_literal_text_in_scripts(tmp_path: Path, code: str) -> None:
    root = make_tree(tmp_path, {"scenes/x.gd": f"func f() -> void:\n\t{code}\n"})
    assert messages(lint.check_hardcoded_text(root)) == ["1:scenes/x.gd:2"]


@pytest.mark.parametrize(
    "code",
    [
        'label.text = Text.get_line(&"ui.title.play")',
        "button.text = str(digit)",
        'label.text = ""',
        'label.text = "\\n".join(lines)',
        'label.text = ", "',
        'var text: String = "x"',
        '# label.text = "commented out"',
        'foo()  # label.text = "trailing comment"',
    ],
)
def test_rule1_allows_text_from_the_table_and_non_text_literals(tmp_path: Path, code: str) -> None:
    root = make_tree(tmp_path, {"scenes/x.gd": f"func f() -> void:\n\t{code}\n"})
    assert lint.check_hardcoded_text(root) == []


def test_rule1_flags_text_properties_in_scenes(tmp_path: Path) -> None:
    scene = '[node name="Title" type="Label"]\ntext = "Gem Mines"\n'
    root = make_tree(tmp_path, {"scenes/shell/title.tscn": scene})
    assert messages(lint.check_hardcoded_text(root)) == ["1:scenes/shell/title.tscn:2"]


def test_rule1_ignores_node_names_and_theme_variations_in_scenes(tmp_path: Path) -> None:
    scene = '[node name="Title" type="Label"]\ntheme_type_variation = &"HeadingLabel"\ntext = ""\n'
    assert lint.check_hardcoded_text(make_tree(tmp_path, {"scenes/a.tscn": scene})) == []


def test_rule1_exempts_the_parent_area_and_the_allowlist(tmp_path: Path) -> None:
    code = 'label.text = "For grown-ups"\n'
    root = make_tree(tmp_path, {
        "scenes/shell/parent_area/dashboard.gd": code,
        "scenes/dev.gd": code,
        "scenes/child.gd": code,
        "tools/ci/lint_allowlist.txt": "# comment\nscenes/dev.gd\n",
    })
    assert messages(lint.check_hardcoded_text(root)) == ["1:scenes/child.gd:1"]


def test_rule1_scans_scripts_and_autoloads_too(tmp_path: Path) -> None:
    code = 'x.text = "Hi"\n'
    root = make_tree(tmp_path, {"scripts/a.gd": code, "autoload/b.gd": code, "tools/c.gd": code})
    assert sorted(messages(lint.check_hardcoded_text(root))) == ["1:autoload/b.gd:1", "1:scripts/a.gd:1"]


# ---------------------------------------------------------------------------
# Rule 2: text fields
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("kind", ["LineEdit", "TextEdit", "CodeEdit", "SpinBox"])
def test_rule2_flags_text_field_nodes_in_scenes_and_scripts(tmp_path: Path, kind: str) -> None:
    root = make_tree(tmp_path, {
        "scenes/a.tscn": f'[node name="Answer" type="{kind}" parent="."]\n',
        "scenes/b.gd": f"var field := {kind}.new()\n",
    })
    assert sorted(messages(lint.check_text_fields(root))) == ["2:scenes/a.tscn:1", "2:scenes/b.gd:1"]


def test_rule2_allows_comments_and_the_parent_area(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {
        "scenes/a.gd": "## Never a LineEdit here.\nvar x: int = 1  # not a TextEdit\n",
        "scenes/shell/parent_area/pin.tscn": '[node name="Pin" type="LineEdit"]\n',
    })
    assert lint.check_text_fields(root) == []


def test_rule2_does_not_match_longer_names(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {"scenes/a.gd": "var x: MyLineEditHelper\n"})
    assert lint.check_text_fields(root) == []


# ---------------------------------------------------------------------------
# Rule 3: banned words
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("word", ["alcohol", "Wine", "CASINO", "smoke", "campfire", "torch", "bee", "cats", "dog", "puppy", "octopus", "shrimp", "oyster", "honeycomb", "fireplace"])
def test_rule3_flags_each_banned_word_in_the_text_table(tmp_path: Path, word: str) -> None:
    root = make_tree(tmp_path, {"text/lines.csv": GOOD_LINES + f"a.b.c,A {word} here.,ctx,0\n"})
    found = lint.check_banned_words(root)
    assert messages(found) == ["3:text/lines.csv:3"]
    assert word.lower() in found[0].message


@pytest.mark.parametrize("text", ["A category of numbers.", "We have been counting.", "Catch the gem.", "Scatter the stones.", "The doge coin", "Crabapple and beeswax only contain a banned word"])
def test_rule3_ignores_words_that_only_contain_a_banned_word(tmp_path: Path, text: str) -> None:
    root = make_tree(tmp_path, {"text/lines.csv": GOOD_LINES + f"a.b.c,{text},ctx,0\n"})
    assert lint.check_banned_words(root) == []


def test_rule3_scans_curriculum_and_the_gdd(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {
        "curriculum/skills/z01_x.json": '{"name": "Count the cats"}\n',
        "docs/gdd.md": "Bolt lights a campfire.\n",
        "docs/other.md": "A dog is mentioned here but this file is not scanned.\n",
    })
    assert sorted(messages(lint.check_banned_words(root))) == ["3:curriculum/skills/z01_x.json:1", "3:docs/gdd.md:1"]


def test_rule3_checks_asset_file_names_but_not_the_credits_text(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {
        "assets/art/rock_cat_icon.png": "x",
        "assets/art/category_card.png": "x",
        "assets/CREDITS.md": "Credits mention a dog photographer.\n",
    })
    assert messages(lint.check_banned_words(root)) == ["3:assets/art/rock_cat_icon.png:0"]


def test_banned_words_in_is_case_insensitive_and_whole_word() -> None:
    assert lint.banned_words_in("Smoke and WINE") == ["smoke", "wine"]
    assert lint.banned_words_in("concatenate") == []


# ---------------------------------------------------------------------------
# Rule 4: the text table
# ---------------------------------------------------------------------------


def lines_findings(tmp_path: Path, csv_text: str) -> list[lint.Finding]:
    return lint.check_line_table(make_tree(tmp_path, {"text/lines.csv": csv_text}))


def test_rule4_accepts_a_good_table(tmp_path: Path) -> None:
    assert lines_findings(tmp_path, GOOD_LINES + 'z1.dig.prompt,"Find {n}, then {m}.",ctx,0\n') == []


def test_rule4_requires_the_exact_header(tmp_path: Path) -> None:
    found = lines_findings(tmp_path, "id,text\na.b.c,Hello\n")
    assert len(found) == 1 and "header" in found[0].message


def test_rule4_reports_a_missing_file(tmp_path: Path) -> None:
    assert len(lint.check_line_table(tmp_path)) == 1


@pytest.mark.parametrize("bad_id", ["ui.play", "UI.title.play", "ui.Title.play", "ui..play", "ui.title.play!", ".a.b", "ui.title"])
def test_rule4_rejects_malformed_ids(tmp_path: Path, bad_id: str) -> None:
    found = lines_findings(tmp_path, f"id,text,context,voice_version\n{bad_id},Hello,ctx,0\n")
    assert any("zone.context.purpose" in f.message for f in found)


def test_rule4_rejects_duplicate_ids(tmp_path: Path) -> None:
    found = lines_findings(tmp_path, GOOD_LINES + "ui.title.play,Again,ctx,0\n")
    assert [f.message for f in found if "duplicate" in f.message] == ["duplicate id 'ui.title.play' (first on line 2)"]


def test_rule4_rejects_empty_text_bad_voice_version_and_bad_braces(tmp_path: Path) -> None:
    found = lines_findings(tmp_path, "id,text,context,voice_version\na.b.c,,ctx,0\nd.e.f,Hi,ctx,x\ng.h.i,{n,ctx,0\nj.k.l,{N} apples,ctx,0\n")
    text = " | ".join(f.message for f in found)
    assert "has no text" in text
    assert "voice_version" in text
    assert "unbalanced" in text
    assert "must be lowercase" in text


def test_rule4_rejects_a_row_whose_unquoted_comma_adds_a_column(tmp_path: Path) -> None:
    found = lines_findings(tmp_path, GOOD_LINES + "a.b.c,Pen 1, finger 2,ctx,0\n" + 'd.e.f,"Pen 1, finger 2",ctx,0\n')
    columns = [f for f in found if "columns" in f.message]
    assert len(columns) == 1 and "a.b.c" in columns[0].message


# ---------------------------------------------------------------------------
# Rule 5: sentence length (warning)
# ---------------------------------------------------------------------------


def test_sentence_word_counts_split_on_sentence_ends() -> None:
    assert lint.sentence_word_counts("One two. Three four five! Six?") == [2, 3, 1]
    assert lint.sentence_word_counts("") == []


def test_rule5_warns_about_long_sentences_only(tmp_path: Path) -> None:
    twelve = " ".join(["w"] * 12) + "."
    thirteen = " ".join(["w"] * 13) + "."
    root = make_tree(tmp_path, {"text/lines.csv": f"id,text,context,voice_version\nok.line.a,{twelve},ctx,0\nlong.line.b,{thirteen},ctx,0\nold.line.c,{thirteen},deprecated,0\n"})
    found = lint.check_sentence_length(root)
    assert [(f.path, f.line, f.severity) for f in found] == [("text/lines.csv", 3, lint.WARNING)]


def test_rule5_counts_each_sentence_separately(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {"text/lines.csv": 'id,text,context,voice_version\na.b.c,"Short one. Another short one. And a third.",ctx,0\n'})
    assert lint.check_sentence_length(root) == []


# ---------------------------------------------------------------------------
# Rule 8: line ids used in code
# ---------------------------------------------------------------------------


def test_rule8_flags_unknown_ids_and_accepts_known_ones(tmp_path: Path) -> None:
    code = 'func f() -> void:\n\tvar a: String = Text.get_line(&"ui.title.play")\n\tvar b: String = Text.get_line(&"ui.no.such")\n\t# Text.get_line(&"ui.also.missing")\n'
    root = make_tree(tmp_path, {"text/lines.csv": GOOD_LINES, "scenes/x.gd": code})
    assert messages(lint.check_line_references(root)) == ["8:scenes/x.gd:3"]


# ---------------------------------------------------------------------------
# Rules 6 and 7 (curriculum) are wired in
# ---------------------------------------------------------------------------


def test_rules_6_and_7_report_curriculum_problems(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {
        "curriculum/vocabulary.json": '{"terms": []}',
        "curriculum/misconceptions.json": '{"misconceptions": {}}',
        "curriculum/bkt_defaults.json": "{}",
        "curriculum/skills/z01_a.json": '{"zone": 1}',
        "text/lines.csv": GOOD_LINES,
    })
    found = lint.check_curriculum(root)
    assert found and all(f.rule == "6-7" for f in found)


# ---------------------------------------------------------------------------
# Rule 9: no network code
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "code",
    [
        "var http: HTTPRequest = HTTPRequest.new()",
        "var peer := StreamPeerTCP.new()",
        "var socket := WebSocketPeer.new()",
        "OS.shell_open(link)",
        'var link: String = "https://example.com"',
    ],
)
def test_rule9_flags_network_code(tmp_path: Path, code: str) -> None:
    root = make_tree(tmp_path, {"autoload/x.gd": f"func f() -> void:\n\t{code}\n"})
    assert messages(lint.check_no_network(root)) == ["9:autoload/x.gd:2"]


def test_rule9_ignores_comments_and_code_outside_the_game(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {
        "scripts/x.gd": "# See https://docs.godotengine.org for HTTPRequest.\nfunc f() -> void:\n\tpass # no HTTPClient here\n",
        "tests/y.gd": "var http := HTTPRequest.new()\n",
        "tools/z.py": "URL = 'https://example.com'\n",
    })
    assert lint.check_no_network(root) == []


def test_rule9_flags_a_network_node_in_a_scene(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {"scenes/a.tscn": '[node name="Fetch" type="HTTPRequest" parent="."]\n'})
    assert messages(lint.check_no_network(root)) == ["9:scenes/a.tscn:1"]
