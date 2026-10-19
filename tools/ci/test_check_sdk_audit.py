"""pytest: check_sdk_audit.py finds every addon and Android plugin, and the repository's audit is complete."""
from __future__ import annotations

from pathlib import Path

import check_sdk_audit as audit

AUDIT_TABLE = "| Name | Version |\n|---|---|\n| GdUnit4 | 6.2.2 |\n"


def make_tree(tmp_path: Path, audit_text: str, addons: list[str], plugins: list[str], project: str = "") -> Path:
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "sdk-audit.md").write_text(audit_text, encoding="utf-8")
    for name in addons:
        (tmp_path / "addons" / name).mkdir(parents=True)
    for name in plugins:
        (tmp_path / "android" / "plugins" / name).mkdir(parents=True)
    (tmp_path / "project.godot").write_text(project, encoding="utf-8")
    return tmp_path


def test_the_repository_audit_is_complete() -> None:
    assert audit.main(["--root", str(audit.ROOT)]) == 0


def test_a_listed_addon_passes_whatever_its_case(tmp_path: Path) -> None:
    root = make_tree(tmp_path, AUDIT_TABLE, ["gdUnit4"], [])
    assert audit.missing(root) == []


def test_an_unlisted_addon_or_android_plugin_fails(tmp_path: Path) -> None:
    root = make_tree(tmp_path, AUDIT_TABLE, ["gdUnit4", "fancy_ads"], ["tracker"])
    assert audit.missing(root) == [
        "fancy_ads (addons/fancy_ads/) is not in docs/sdk-audit.md",
        "tracker (android/plugins/tracker/) is not in docs/sdk-audit.md",
    ]
    assert audit.main(["--root", str(root)]) == 1


def test_a_plugin_named_only_in_project_godot_counts(tmp_path: Path) -> None:
    project = '[editor_plugins]\n\nenabled=PackedStringArray("res://addons/ghost/plugin.cfg")\n'
    root = make_tree(tmp_path, AUDIT_TABLE, [], [], project)
    assert audit.missing(root) == ["ghost (project.godot) is not in docs/sdk-audit.md"]


def test_a_name_mentioned_outside_a_table_does_not_count(tmp_path: Path) -> None:
    root = make_tree(tmp_path, AUDIT_TABLE + "\nWe once looked at fancy_ads and said no.\n", ["fancy_ads"], [])
    assert len(audit.missing(root)) == 1
