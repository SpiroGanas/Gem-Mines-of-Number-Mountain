"""Content lint for Gem Mines of Number Mountain.

Run:  python tools/ci/lint_content.py [--root PATH] [--warnings-as-errors]

Fails (exit code 1) on the project's non-negotiable content rules (CLAUDE.md):

  1. No hard-coded child-facing text in scenes/, scripts/ or autoload/ (rule 4 of CLAUDE.md).
     Files in tools/ci/lint_allowlist.txt (developer-only text) are exempt, and so is
     scenes/shell/parent_area/, which is for grown-ups.
  2. No LineEdit, TextEdit, CodeEdit or SpinBox in child-facing scenes (rule 6). They raise the
     system keyboard in tablet mode. Allowed only in scenes/shell/parent_area/.
  3. No banned content words in text/lines.csv, curriculum/**, docs/gdd.md and asset file names
     (the family content rules).
  4. text/lines.csv is well formed: exact header, line ids match zone.context.purpose, ids unique,
     voice_version is a whole number, text is not empty. Scholar mode (Phase 4, Sprint 37) adds an
     optional fifth column, `mode`: empty or "explorer" for the line every child sees, "scholar" for a
     longer variant of the same id (one per id, and only beside an explorer line).
  5. (warning) Explorer lines with a sentence over 12 words.
  6-7. The curriculum is consistent: Word Gem terms exist, the prerequisite graph is acyclic and
     all other checks in curriculum_check.py.
  8. Every line id used in code (Text.get_line(&"id")) exists in text/lines.csv.
  9. No network code in the game (rule 1 of CLAUDE.md): no HTTP, TCP, UDP, WebSocket, WebRTC or
     ENet classes, no OS.shell_open and no web addresses in scenes/, scripts/ or autoload/. The
     export preset's missing INTERNET permission is the backstop; this keeps the code honest too.

  10. Every file under assets/ has a row in assets/CREDITS.md (its path in backticks), so no art,
     sound or font is ever shipped without its source and license on record. Godot's `.import`
     and `.uid` files and CREDITS.md itself are exempt.
  11. Every math term a child-facing line uses is a Word Gem in curriculum/vocabulary.json (Sprint 19,
     the glossary), so the child can always tap it for a picture and a kid-sized definition (CLAUDE.md
     rule 5). MATH_TERMS is the list of words that count as math terms and the Word Gem each needs.

Each rule is a function returning Finding objects, so each is unit-tested in test_lint_content.py.
The banned-word list is the plan's list plus a few obvious variants (smoky, smoker, cigarette,
beehive, kittens, puppies).
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from dataclasses import dataclass
from pathlib import Path

import curriculum_check

ROOT = Path(__file__).resolve().parents[2]

ERROR = "error"
WARNING = "warning"

CODE_DIRS = ("scenes", "scripts", "autoload")
PARENT_AREA = "scenes/shell/parent_area/"
ALLOWLIST_PATH = "tools/ci/lint_allowlist.txt"
LINES_CSV = "text/lines.csv"
GDD_PATH = "docs/gdd.md"

LINE_ID_RE = re.compile(r"^[a-z0-9]+(\.[a-z0-9_]+){2,}$")
EXPECTED_HEADER = ["id", "text", "context", "voice_version"]
# The header with Scholar mode's optional `mode` column (rows may still have 4 columns).
MODE_HEADER = EXPECTED_HEADER + ["mode"]
LINE_MODES = ("", "explorer", "scholar")
MAX_WORDS_PER_SENTENCE = 12

BANNED_WORDS = (
    "alcohol", "beer", "wine", "gambling", "casino", "lottery", "smoke", "smoking", "smoky",
    "smoker", "tobacco", "cigarette", "campfire", "fireplace", "torch", "bee", "bees", "beehive",
    "honeycomb", "cat", "cats", "kitten", "kittens", "dog", "dogs", "puppy", "puppies",
    "octopus", "shellfish", "shrimp", "lobster", "crab", "clam", "oyster",
)
# A banned word counts only as a whole word; digits, letters and nothing else may touch it.
# Underscores and dots count as separators, so rock_cat_icon.png is caught but "category" is not.
_BANNED_RE = re.compile(r"(?<![a-z0-9])(" + "|".join(BANNED_WORDS) + r")(?![a-z0-9])", re.IGNORECASE)

_TEXT_FIELD_TYPES = ("LineEdit", "TextEdit", "CodeEdit", "SpinBox")
# A literal only counts as text if it contains a letter once escape sequences (\n, \t) are
# skipped, so separators like "\n" or ", " are not flagged. A literal empty string is fine.
_LETTER_AHEAD = r"""(?=(?:\\.|[^"'\\])*[A-Za-z])"""
# gd: label.text = "..." / text = "..." / set_text("...").
_GD_TEXT_RE = re.compile(r"""(?<![\w])(?:\w+\.)*(?:text|tooltip_text|placeholder_text)\s*=\s*["']""" + _LETTER_AHEAD + r"""|set_text\(\s*["']""" + _LETTER_AHEAD)
# tscn: text = "..." and friends on their own line.
_TSCN_TEXT_RE = re.compile(r"""^\s*(?:text|tooltip_text|placeholder_text|title|dialog_text)\s*=\s*\"""" + _LETTER_AHEAD)
_TSCN_FIELD_RE = re.compile(r'type="(%s)"' % "|".join(_TEXT_FIELD_TYPES))
_GD_FIELD_RE = re.compile(r"\b(%s)\b" % "|".join(_TEXT_FIELD_TYPES))
_GET_LINE_RE = re.compile(r"""get_line\(\s*&?["']([a-z0-9_.]+)["']""")
NETWORK_CLASSES = (
    "HTTPRequest", "HTTPClient", "StreamPeerTCP", "StreamPeerTLS", "TCPServer", "UDPServer",
    "PacketPeerUDP", "PacketPeerDTLS", "DTLSServer", "WebSocketPeer", "WebSocketMultiplayerPeer",
    "WebRTCPeerConnection", "WebRTCMultiplayerPeer", "WebRTCDataChannel", "ENetMultiplayerPeer",
    "ENetConnection", "ENetPacketPeer", "JavaScriptBridge",
)
_NETWORK_RE = re.compile(r"\b(%s|OS\.shell_open|https?://)" % "|".join(NETWORK_CLASSES))


@dataclass(frozen=True)
class Finding:
    rule: str
    path: str
    line: int
    message: str
    severity: str = ERROR

    def __str__(self) -> str:
        where = f"{self.path}:{self.line}" if self.line else self.path
        return f"{where}: {self.severity} (rule {self.rule}): {self.message}"


def _rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def _code_files(root: Path, suffixes: tuple[str, ...]) -> list[Path]:
    files: list[Path] = []
    for directory in CODE_DIRS:
        base = root / directory
        if base.is_dir():
            files += [p for p in sorted(base.rglob("*")) if p.is_file() and p.suffix in suffixes]
    return files


def _allowlist(root: Path) -> set[str]:
    path = root / ALLOWLIST_PATH
    if not path.is_file():
        return set()
    entries = (line.strip() for line in path.read_text(encoding="utf-8").splitlines())
    return {entry for entry in entries if entry and not entry.startswith("#")}


def _strip_gd_comment(line: str) -> str:
    """Drops a trailing # comment. Approximate (a # inside a string ends the scan early),
    which can only hide a violation after it, never invent one."""
    if line.lstrip().startswith("#"):
        return ""
    return re.sub(r"\s#.*$", "", line)


# ---------------------------------------------------------------------------
# Rule 1: no hard-coded child-facing text
# ---------------------------------------------------------------------------


def check_hardcoded_text(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    allowed = _allowlist(root)
    for path in _code_files(root, (".gd", ".tscn")):
        rel = _rel(path, root)
        if rel.startswith(PARENT_AREA) or rel in allowed:
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            hit = (
                _TSCN_TEXT_RE.search(line) if path.suffix == ".tscn" else _GD_TEXT_RE.search(_strip_gd_comment(line))
            )
            if hit:
                findings.append(Finding("1", rel, number, "hard-coded text; use Text.get_line(&\"id\") and add the line to text/lines.csv"))
    return findings


# ---------------------------------------------------------------------------
# Rule 2: no text fields in child-facing scenes
# ---------------------------------------------------------------------------


def check_text_fields(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    for path in _code_files(root, (".gd", ".tscn")):
        rel = _rel(path, root)
        if rel.startswith(PARENT_AREA):
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            hit = _TSCN_FIELD_RE.search(line) if path.suffix == ".tscn" else _GD_FIELD_RE.search(_strip_gd_comment(line))
            if hit:
                findings.append(Finding("2", rel, number, f"{hit.group(1)} raises the system keyboard; use NumberPad, ChalkSlate or tap/drag targets"))
    return findings


# ---------------------------------------------------------------------------
# Rule 3: banned content words
# ---------------------------------------------------------------------------


def banned_words_in(text: str) -> list[str]:
    return [match.group(1).lower() for match in _BANNED_RE.finditer(text)]


def check_banned_words(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    targets: list[Path] = []
    for relative in (LINES_CSV, GDD_PATH):
        if (root / relative).is_file():
            targets.append(root / relative)
    curriculum = root / "curriculum"
    if curriculum.is_dir():
        targets += [p for p in sorted(curriculum.rglob("*")) if p.is_file() and p.suffix in (".json", ".md")]
    for path in targets:
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            for word in banned_words_in(line):
                findings.append(Finding("3", _rel(path, root), number, f"banned content word '{word}'"))
    assets = root / "assets"
    if assets.is_dir():
        for path in sorted(assets.rglob("*")):
            if path.is_file() and path.name != "CREDITS.md":
                for word in banned_words_in(path.relative_to(assets).as_posix()):
                    findings.append(Finding("3", _rel(path, root), 0, f"banned content word '{word}' in an asset name"))
    return findings


# ---------------------------------------------------------------------------
# Rules 4 and 5: the text table
# ---------------------------------------------------------------------------


def read_lines(root: Path) -> tuple[list[str], list[tuple[int, dict[str, str]]]]:
    """(header, [(line number, row)]) from text/lines.csv. Line numbers are 1-based, header is line 1."""
    path = root / LINES_CSV
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle)
        header = next(reader, [])
        rows: list[tuple[int, dict[str, str]]] = []
        for row in reader:
            if not row:
                continue
            record = dict(zip(header, row))
            record["_columns"] = str(len(row))
            rows.append((reader.line_num, record))
    return header, rows


def check_line_table(root: Path) -> list[Finding]:
    if not (root / LINES_CSV).is_file():
        return [Finding("4", LINES_CSV, 0, "text/lines.csv is missing")]
    header, rows = read_lines(root)
    if header not in (EXPECTED_HEADER, MODE_HEADER):
        return [Finding("4", LINES_CSV, 1, f"header must be {','.join(EXPECTED_HEADER)} (optionally with ,mode), got {','.join(header)}")]
    findings: list[Finding] = []
    seen: dict[str, int] = {}
    scholar_seen: dict[str, int] = {}
    allowed_columns = {str(len(EXPECTED_HEADER)), str(len(header))}
    for number, row in rows:
        line_id = row["id"]
        if row.get("_columns") not in allowed_columns:
            findings.append(Finding("4", LINES_CSV, number, f"line '{line_id}' has {row.get('_columns')} columns, expected {len(EXPECTED_HEADER)} (put text with a comma in double quotes)"))
        if not LINE_ID_RE.match(line_id):
            findings.append(Finding("4", LINES_CSV, number, f"id '{line_id}' must look like zone.context.purpose (lowercase)"))
        mode = line_mode(row)
        if mode not in LINE_MODES:
            findings.append(Finding("4", LINES_CSV, number, f"line '{line_id}': mode must be empty, explorer or scholar, got '{mode}'"))
        elif mode == "scholar":
            if line_id in scholar_seen:
                findings.append(Finding("4", LINES_CSV, number, f"duplicate scholar variant of '{line_id}' (first on line {scholar_seen[line_id]})"))
            scholar_seen.setdefault(line_id, number)
        else:
            if line_id in seen:
                findings.append(Finding("4", LINES_CSV, number, f"duplicate id '{line_id}' (first on line {seen[line_id]})"))
            seen.setdefault(line_id, number)
        if not row["text"].strip():
            findings.append(Finding("4", LINES_CSV, number, f"line '{line_id}' has no text"))
        if not row["voice_version"].isdigit():
            findings.append(Finding("4", LINES_CSV, number, f"line '{line_id}': voice_version must be a whole number"))
        if row["text"].count("{") != row["text"].count("}"):
            findings.append(Finding("4", LINES_CSV, number, f"line '{line_id}' has unbalanced braces"))
        for placeholder in re.findall(r"\{([^}]*)\}", row["text"]):
            if not re.fullmatch(r"[a-z_][a-z0-9_]*", placeholder):
                findings.append(Finding("4", LINES_CSV, number, f"line '{line_id}': placeholder '{{{placeholder}}}' must be lowercase letters, digits and underscores"))
    for line_id, number in scholar_seen.items():
        if line_id not in seen:
            findings.append(Finding("4", LINES_CSV, number, f"scholar variant '{line_id}' has no explorer line with the same id"))
    return findings


def line_mode(row: dict[str, str]) -> str:
    """The row's mode column (Scholar mode variants), "" when the row has none."""
    return (row.get("mode") or "").strip()


def sentence_word_counts(text: str) -> list[int]:
    """Words in each sentence, ignoring {placeholders} that stand for one number or word."""
    sentences = [s for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s]
    return [len(sentence.split()) for sentence in sentences]


def check_sentence_length(root: Path) -> list[Finding]:
    if not (root / LINES_CSV).is_file():
        return []
    header, rows = read_lines(root)
    if header not in (EXPECTED_HEADER, MODE_HEADER):
        return []
    findings: list[Finding] = []
    for number, row in rows:
        if row["context"] == "deprecated" or line_mode(row) == "scholar":
            continue  # Scholar variants may be longer (Phase 4 plan, Scholar mode); they are gated
        longest = max(sentence_word_counts(row["text"]), default=0)
        if longest > MAX_WORDS_PER_SENTENCE:
            findings.append(Finding("5", LINES_CSV, number, f"line '{row['id']}' has a {longest}-word sentence (Explorer limit {MAX_WORDS_PER_SENTENCE})", WARNING))
    return findings


# ---------------------------------------------------------------------------
# Rules 6 and 7: curriculum consistency
# ---------------------------------------------------------------------------


def check_curriculum(root: Path) -> list[Finding]:
    if not (root / "curriculum").is_dir():
        return []
    return [Finding("6-7", "curriculum", 0, message) for message in curriculum_check.check_all(root)]


# ---------------------------------------------------------------------------
# Rule 8: line ids used in code exist
# ---------------------------------------------------------------------------


def check_line_references(root: Path) -> list[Finding]:
    if not (root / LINES_CSV).is_file():
        return []
    header, rows = read_lines(root)
    known = {row["id"] for _, row in rows} if header in (EXPECTED_HEADER, MODE_HEADER) else set()
    findings: list[Finding] = []
    for path in _code_files(root, (".gd",)):
        rel = _rel(path, root)
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            for match in _GET_LINE_RE.finditer(_strip_gd_comment(line)):
                if match.group(1) not in known:
                    findings.append(Finding("8", rel, number, f"line id '{match.group(1)}' is not in text/lines.csv"))
    return findings


# ---------------------------------------------------------------------------
# Rule 9: no network code in the game
# ---------------------------------------------------------------------------


def check_no_network(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    for path in _code_files(root, (".gd", ".tscn")):
        rel = _rel(path, root)
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            text = line if path.suffix == ".tscn" else _strip_gd_comment(line)
            hit = _NETWORK_RE.search(text)
            if hit:
                findings.append(Finding("9", rel, number, f"{hit.group(1)}: the game never uses the network (CLAUDE.md rule 1)"))
    return findings


# ---------------------------------------------------------------------------
# Rule 10: every asset has a credit
# ---------------------------------------------------------------------------

CREDITS_PATH = "assets/CREDITS.md"
CREDIT_EXEMPT_SUFFIXES = (".import", ".uid")


def check_asset_credits(root: Path) -> list[Finding]:
    assets = root / "assets"
    if not assets.is_dir():
        return []
    credits_file = root / CREDITS_PATH
    credits = credits_file.read_text(encoding="utf-8") if credits_file.is_file() else ""
    listed = set(re.findall(r"`([^`]+)`", credits))
    findings: list[Finding] = []
    for path in sorted(assets.rglob("*")):
        if not path.is_file() or path.suffix in CREDIT_EXEMPT_SUFFIXES or _rel(path, root) == CREDITS_PATH:
            continue
        rel = _rel(path, root)
        if rel not in listed:
            findings.append(Finding("10", rel, 0, f"no row for this file in {CREDITS_PATH} (source, author, license)"))
    return findings


# ---------------------------------------------------------------------------
# Rule 11: every math term in a child-facing line is a Word Gem
# ---------------------------------------------------------------------------

# A math word (whole word, any case, with its plural or -ing forms) -> the Word Gem it needs.
MATH_TERMS = {
    r"digits?": "digit",
    r"numerals?": "numeral",
    r"regroup(?:s|ing|ed)?": "regrouping",
    r"sums?": "sum",
    r"differences?": "difference",
    r"fact famil(?:y|ies)": "fact_family",
    r"inverses?": "inverse",
    r"arrays?": "array",
    r"columns?": "column",
    r"equal groups?": "equal_groups",
    r"multipl(?:y|ies|ying|ication)": "multiply",
    r"commutative": "commutative",
    r"factors?": "factor",
    r"multiples?": "multiple",
    r"primes?": "prime",
    r"composites?": "composite",
    r"recipes?": "recipe",
    r"sieves?": "sieve",
    r"divisible": "divisible",
    r"divid(?:e|es|ing)|division|÷": "divide",
    r"prime factorizations?": "prime_factorization",
    r"fundamental theorem": "fundamental_theorem",
    # Zone 6 (Phase 4)
    r"common factors?": "common_factor",
    r"greatest common factors?|GCFs?": "gcf",
    r"common multiples?": "common_multiple",
    r"least common multiples?|LCMs?": "lcm",
    r"coprime": "coprime",
    r"simplest form": "simplest_form",
    r"gear ratios?": "gear_ratio",
    # Zone 7 (Phase 4; fraction, numerator, denominator and unit fraction are Zone 6 Word Gems)
    r"fractions?": "fraction",
    r"numerators?": "numerator",
    r"denominators?": "denominator",
    r"unit fractions?": "unit_fraction",
    r"equivalent": "equivalent",
    r"mixed numbers?": "mixed_number",
    r"improper fractions?": "improper_fraction",
    r"decimals?": "decimal",
    r"tenths?": "tenth",
    r"hundredths?": "hundredth",
    r"percent": "percent",
    r"ratios?": "ratio",
    r"negative": "negative",
    # Zone 8 (Phase 4). "power" and "base" are everyday words too (the mountain's base), so only the
    # unambiguous forms are checked.
    r"exponents?": "exponent",
    r"squared": "square_number",
    r"square numbers?": "square_number",
    r"cubed": "cube_number",
    r"cube numbers?": "cube_number",
    r"square roots?": "square_root",
    r"binary": "binary",
    r"scientific notation": "scientific_notation",
    r"levers?": "lever",
    # Zone 9 (Phase 4; "rule" and "term" are Word Gems too, but too common as plain words to match)
    r"sequences?": "sequence",
    r"triangular numbers?": "triangular_number",
    r"fibonacci": "fibonacci",
    r"golden ratio": "golden_ratio",
    r"syllables?": "syllable",
    r"proofs?": "proof",
}
# Lines for grown-ups and the Word Gem lines themselves are not checked.
TERM_EXEMPT_PREFIXES = ("parent.", "vocab.", "debug.")


def check_glossary_terms(root: Path) -> list[Finding]:
    vocabulary_path = root / "curriculum" / "vocabulary.json"
    if not vocabulary_path.is_file() or not (root / LINES_CSV).is_file():
        return []
    import json
    terms = {entry["id"] for entry in json.loads(vocabulary_path.read_text(encoding="utf-8"))["terms"]}
    _, rows = read_lines(root)
    findings: list[Finding] = []
    for number, row in rows:
        line_id = row.get("id", "")
        if line_id.startswith(TERM_EXEMPT_PREFIXES):
            continue
        text = re.sub(r"\{[a-z_]+\}", " ", row.get("text", ""))
        for pattern, term in MATH_TERMS.items():
            if term not in terms and re.search(r"(?<![A-Za-z])" + pattern + r"(?![A-Za-z])", text, re.IGNORECASE):
                findings.append(Finding("11", LINES_CSV, number, f"'{line_id}' uses the math term '{term}', which is not a Word Gem in curriculum/vocabulary.json"))
    return findings


# ---------------------------------------------------------------------------


RULES = (
    check_hardcoded_text,
    check_text_fields,
    check_banned_words,
    check_line_table,
    check_sentence_length,
    check_curriculum,
    check_line_references,
    check_no_network,
    check_asset_credits,
    check_glossary_terms,
)


def run(root: Path = ROOT) -> list[Finding]:
    findings: list[Finding] = []
    for rule in RULES:
        findings += rule(root)
    return findings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (default: this repository)")
    parser.add_argument("--warnings-as-errors", action="store_true", help="exit 1 on warnings too")
    args = parser.parse_args(argv)
    findings = run(args.root.resolve())
    for finding in findings:
        print(finding)
    errors = [f for f in findings if f.severity == ERROR]
    warnings = [f for f in findings if f.severity == WARNING]
    print(f"content lint: {len(errors)} error(s), {len(warnings)} warning(s)")
    failed = bool(errors) or (args.warnings_as_errors and bool(warnings))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
