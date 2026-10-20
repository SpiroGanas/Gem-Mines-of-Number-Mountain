"""pytest: the store listing text (marketing/listing.md) fits Play Console's limits and the family rules.

P3-S26-01. Checks the two blocks Spiro pastes into Play Console: the short description (80 characters
at most) and the full description (4,000 at most); that the full description says what parents need
to know (offline, no ads, no purchases, ages 6 to 12); that nothing promises read-aloud, narration or
an AI voice, which the app does not have (Spiro, 2026-10-19); and that no banned content word from
tools/ci/lint_content.py appears.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

import lint_content

ROOT = Path(__file__).resolve().parents[2]
LISTING = ROOT / "marketing" / "listing.md"
SHORT_MAX = 80
FULL_MAX = 4000
TITLE_MAX = 30
NOT_IN_THE_APP = ("read-aloud", "read aloud", "reads aloud", "narrat", "ai voice", "voice", "text-to-speech", "spoken")


def block(name: str) -> str:
    text = LISTING.read_text(encoding="utf-8")
    match = re.search(rf"<!-- {name}:start -->\n(.*?)\n<!-- {name}:end -->", text, re.DOTALL)
    assert match, f"marketing/listing.md has no {name} block"
    return match.group(1).strip()


def title() -> str:
    match = re.search(r"^\*\*App name \(30 max\):\*\* (.+)$", LISTING.read_text(encoding="utf-8"), re.MULTILINE)
    assert match, "marketing/listing.md has no app name line"
    return match.group(1).strip()


def test_the_title_short_and_full_descriptions_fit() -> None:
    assert 0 < len(title()) <= TITLE_MAX
    assert 0 < len(block("short")) <= SHORT_MAX, f"short description is {len(block('short'))} characters"
    assert 0 < len(block("full")) <= FULL_MAX, f"full description is {len(block('full'))} characters"


def test_the_short_description_is_one_line() -> None:
    assert "\n" not in block("short")


@pytest.mark.parametrize("needle", ["offline", "no ads", "no in-app purchases", "6 to 12"])
def test_the_full_description_tells_parents_the_essentials(needle: str) -> None:
    assert needle in block("full").lower()


@pytest.mark.parametrize("name", ["short", "full"])
def test_nothing_promises_a_feature_the_app_does_not_have(name: str) -> None:
    lowered = block(name).lower()
    assert [phrase for phrase in NOT_IN_THE_APP if phrase in lowered] == []


@pytest.mark.parametrize("name", ["short", "full"])
def test_no_banned_content_word(name: str) -> None:
    assert lint_content.banned_words_in(block(name)) == []
    assert lint_content.banned_words_in(title()) == []


def test_the_feedback_line_matches_the_family_wording() -> None:
    lowered = block("full").lower()
    assert "wrong!" not in lowered
    assert "not quite. let's look again." in lowered
