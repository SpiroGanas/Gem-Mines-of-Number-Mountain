"""Static checks for the curriculum data.

Covers the skill map (curriculum/skills/*.json), vocabulary.json, misconceptions.json
and bkt_defaults.json. Used by pytest (tools/ci/test_curriculum.py) and by
lint_content.py (lint rules 6 and 7). Pure standard library; nothing here ships
in the game.

Every function returns a list of error strings (empty list = OK) so callers can
print all problems at once instead of stopping at the first.
"""
from __future__ import annotations

import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CURRICULUM_DIR = ROOT / "curriculum"
SKILLS_DIR = CURRICULUM_DIR / "skills"
LINES_CSV = ROOT / "text" / "lines.csv"

# topic.subtopic.action, e.g. pv.tens_ones.build or mult.facts.2_5_10
SKILL_ID_RE = re.compile(r"^[a-z][a-z0-9]*\.[a-z0-9_]+\.[a-z0-9_]+$")
SNAKE_RE = re.compile(r"^[a-z][a-z0-9_]*$")
ZONE_FILE_RE = re.compile(r"^z(\d{2})_([a-z0-9_]+)\.json$")

# String check only (Sprint 2): the generator classes planned for Zones 1-4.
# tests/curriculum/test_skill_graph.gd checks real resolution from Sprint 5 on.
KNOWN_GENERATORS = frozenset({
    "CountingGenerator", "CompareGenerator", "PlaceValueGenerator", "RegroupGenerator",
    "AdditionGenerator", "SubtractionGenerator", "FactFamilyGenerator",
    "MissingPartGenerator", "BalanceGenerator",
    "SkipCountGenerator", "ParityGenerator", "ArraysGenerator", "MultiplicationGenerator",
    "MultFactsGenerator", "DivFactsGenerator", "FactorsGenerator", "MultiplesGenerator", "PrimeCompositeGenerator",
})
REPRESENTATIONS = frozenset({"concrete", "pictorial", "abstract"})
# Picture types the game can draw (Problem.VISUAL_TYPES in scripts/core/problem.gd).
WORD_GEM_VISUALS = frozenset({"gem_piles", "ten_frame", "number_line", "balance", "array", "groups", "pairs"})
ANSWER_MODES = frozenset({"tap", "drag", "number_pad", "keyboard", "handwriting"})
BKT_SKILL_TYPES = frozenset({"default", "fact", "procedure", "concept"})
ZONE_STATUSES = frozenset({"detailed", "outline"})
ZONE_COUNT = 12

DETAILED_SKILL_FIELDS = frozenset({
    "id", "name", "prereqs", "generator", "params", "representations", "answer_modes",
    "terms", "bkt_type", "is_fact_skill", "misconceptions",
})
OUTLINE_SKILL_FIELDS = frozenset({"id", "name"})
ZONE_FIELDS = frozenset({"zone", "zone_id", "name", "status", "skills"})


def load_json(path: Path) -> object:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_zone_files(skills_dir: Path = SKILLS_DIR) -> list[tuple[Path, dict]]:
    """Return (path, parsed zone dict) for every curriculum/skills/zNN_*.json, sorted by name."""
    return [(path, load_json(path)) for path in sorted(skills_dir.glob("z*.json"))]


def load_vocabulary(path: Path = CURRICULUM_DIR / "vocabulary.json") -> dict[str, dict]:
    return {term["id"]: term for term in load_json(path)["terms"]}


def load_misconceptions(path: Path = CURRICULUM_DIR / "misconceptions.json") -> dict[str, str]:
    return dict(load_json(path)["misconceptions"])


def load_bkt_defaults(path: Path = CURRICULUM_DIR / "bkt_defaults.json") -> dict:
    return dict(load_json(path))


def load_line_ids(path: Path = LINES_CSV) -> set[str]:
    with path.open(encoding="utf-8", newline="") as handle:
        return {row["id"] for row in csv.DictReader(handle)}


def find_cycle(graph: dict[str, list[str]]) -> list[str] | None:
    """Return one cycle as a list of ids (first == last), or None if the graph is acyclic.

    graph maps a node to the nodes it depends on. Unknown dependencies are ignored here;
    a separate check reports them.
    """
    white, grey, black = 0, 1, 2
    color = {node: white for node in graph}
    stack: list[str] = []

    def visit(node: str) -> list[str] | None:
        color[node] = grey
        stack.append(node)
        for dep in graph[node]:
            if dep not in graph:
                continue
            if color[dep] == grey:
                return stack[stack.index(dep):] + [dep]
            if color[dep] == white:
                found = visit(dep)
                if found:
                    return found
        stack.pop()
        color[node] = black
        return None

    for node in list(graph):
        if color[node] == white:
            found = visit(node)
            if found:
                return found
    return None


def _is_str_list(value: object) -> bool:
    return isinstance(value, list) and all(isinstance(item, str) for item in value)


def check_bkt_defaults(bkt: dict) -> list[str]:
    errors: list[str] = []
    for kind in sorted(BKT_SKILL_TYPES):
        params = bkt.get(kind)
        if not isinstance(params, dict):
            errors.append(f"bkt_defaults: missing skill type '{kind}'")
            continue
        for key in ("prior", "learn", "guess", "slip"):
            value = params.get(key)
            if not isinstance(value, (int, float)) or not 0.0 < value < 1.0:
                errors.append(f"bkt_defaults.{kind}.{key} must be a number strictly between 0 and 1, got {value!r}")
        if kind == "fact":
            fluency = params.get("fluency_ms")
            if not isinstance(fluency, int) or fluency <= 0:
                errors.append("bkt_defaults.fact.fluency_ms must be a positive integer")
        if params.get("guess", 0) + params.get("slip", 0) >= 1.0:
            errors.append(f"bkt_defaults.{kind}: guess + slip must be below 1 (BKT is degenerate otherwise)")
    weight = bkt.get("hint_weight")
    if not isinstance(weight, (int, float)) or not 0.0 <= weight <= 1.0:
        errors.append(f"bkt_defaults.hint_weight must be in [0, 1], got {weight!r}")
    return errors


def check_misconceptions(misconceptions: dict[str, str], line_ids: set[str] | None = None) -> list[str]:
    """Names are snake_case with a parent-facing description; with `line_ids`, each name also has
    Bolt's targeted hint line, bolt.misconception.<name>, in text/lines.csv."""
    errors: list[str] = []
    for name, description in misconceptions.items():
        if not SNAKE_RE.match(name):
            errors.append(f"misconceptions: '{name}' is not snake_case")
        if not isinstance(description, str) or not description.strip():
            errors.append(f"misconceptions: '{name}' needs a parent-facing description")
        if line_ids is not None and f"bolt.misconception.{name}" not in line_ids:
            errors.append(f"misconceptions: '{name}' has no hint line bolt.misconception.{name} in text/lines.csv")
    return errors


def check_vocabulary(vocabulary: dict[str, dict], line_ids: set[str]) -> list[str]:
    errors: list[str] = []
    for term_id, term in vocabulary.items():
        if not SNAKE_RE.match(term_id):
            errors.append(f"vocabulary: '{term_id}' is not snake_case")
        if not isinstance(term.get("zone"), int) or not 1 <= term["zone"] <= ZONE_COUNT:
            errors.append(f"vocabulary: '{term_id}' needs an integer zone 1-{ZONE_COUNT}")
        for key in ("term_line_id", "definition_line_id"):
            line_id = term.get(key)
            if line_id not in line_ids:
                errors.append(f"vocabulary: '{term_id}'.{key} '{line_id}' is not in text/lines.csv")
        if term.get("picture") is not None and not isinstance(term["picture"], str):
            errors.append(f"vocabulary: '{term_id}'.picture must be null or a resource path")
        visual = term.get("visual")
        if visual is not None and (not isinstance(visual, dict) or visual.get("type") not in WORD_GEM_VISUALS):
            errors.append(f"vocabulary: '{term_id}'.visual must be a picture of one of the types {sorted(WORD_GEM_VISUALS)}")
    return errors


def check_skill_map(
    zone_files: list[tuple[Path, dict]],
    vocabulary: dict[str, dict],
    misconceptions: dict[str, str],
    bkt: dict,
) -> list[str]:
    """Schema, uniqueness, prerequisite and cross-reference checks for the whole skill map."""
    errors: list[str] = []
    seen_zones: dict[int, str] = {}
    skills: dict[str, dict] = {}      # id -> skill record
    skill_zone: dict[str, int] = {}
    skill_status: dict[str, str] = {}

    for path, zone_data in zone_files:
        label = path.name
        match = ZONE_FILE_RE.match(path.name)
        if not match:
            errors.append(f"{label}: file name must look like zNN_name.json")
            continue
        if set(zone_data) != ZONE_FIELDS:
            errors.append(f"{label}: top-level keys must be exactly {sorted(ZONE_FIELDS)}, got {sorted(zone_data)}")
            continue
        zone = zone_data["zone"]
        if zone != int(match.group(1)):
            errors.append(f"{label}: zone {zone} does not match the file name prefix")
        if zone_data["zone_id"] != path.stem:
            errors.append(f"{label}: zone_id '{zone_data['zone_id']}' must equal the file name stem")
        if zone in seen_zones:
            errors.append(f"{label}: zone {zone} is also defined in {seen_zones[zone]}")
        seen_zones[zone] = label
        status = zone_data["status"]
        if status not in ZONE_STATUSES:
            errors.append(f"{label}: status must be one of {sorted(ZONE_STATUSES)}")
            continue
        if not isinstance(zone_data["skills"], list) or not zone_data["skills"]:
            errors.append(f"{label}: needs a non-empty skills list")
            continue

        allowed = DETAILED_SKILL_FIELDS if status == "detailed" else OUTLINE_SKILL_FIELDS
        for skill in zone_data["skills"]:
            sid = skill.get("id", "<missing id>")
            where = f"{label}: {sid}"
            if set(skill) != allowed:
                errors.append(f"{where}: keys must be exactly {sorted(allowed)}, got {sorted(skill)}")
                continue
            if not isinstance(sid, str) or not SKILL_ID_RE.match(sid):
                errors.append(f"{where}: id must look like topic.subtopic.action")
            if sid in skills:
                errors.append(f"{where}: duplicate skill id")
            skills[sid] = skill
            skill_zone[sid] = zone
            skill_status[sid] = status
            if not isinstance(skill["name"], str) or not skill["name"].strip():
                errors.append(f"{where}: name must be a non-empty string")

    missing_zones = sorted(set(range(1, ZONE_COUNT + 1)) - set(seen_zones))
    if missing_zones:
        errors.append(f"skill map: missing zone files for zones {missing_zones}")

    # Detailed-skill field checks (outlines carry only id and name).
    for sid, skill in skills.items():
        if skill_status[sid] != "detailed" or set(skill) != DETAILED_SKILL_FIELDS:
            continue
        where = f"skill {sid}"
        if skill["generator"] not in KNOWN_GENERATORS:
            errors.append(f"{where}: unknown generator '{skill['generator']}'")
        if not isinstance(skill["params"], dict):
            errors.append(f"{where}: params must be an object")
        for key, allowed_values in (("representations", REPRESENTATIONS), ("answer_modes", ANSWER_MODES)):
            values = skill[key]
            if not _is_str_list(values) or not values or len(set(values)) != len(values):
                errors.append(f"{where}: {key} must be a non-empty list without duplicates")
            elif not set(values) <= allowed_values:
                errors.append(f"{where}: {key} has unknown values {sorted(set(values) - allowed_values)}")
        if _is_str_list(skill["answer_modes"]) and "handwriting" in skill["answer_modes"] and not (
                {"number_pad", "keyboard"} & set(skill["answer_modes"])):
            errors.append(f"{where}: handwriting replaces the number pad, so the skill must also list number_pad")
        if not _is_str_list(skill["terms"]):
            errors.append(f"{where}: terms must be a list of term ids")
        else:
            for term_id in skill["terms"]:
                if term_id not in vocabulary:
                    errors.append(f"{where}: term '{term_id}' is not in vocabulary.json")
                elif vocabulary[term_id]["zone"] > skill_zone[sid]:
                    errors.append(f"{where}: term '{term_id}' is introduced in zone {vocabulary[term_id]['zone']}, after this skill's zone")
        if skill["bkt_type"] not in BKT_SKILL_TYPES:
            errors.append(f"{where}: bkt_type must be one of {sorted(BKT_SKILL_TYPES)}")
        if not isinstance(skill["is_fact_skill"], bool):
            errors.append(f"{where}: is_fact_skill must be true or false")
        elif skill["is_fact_skill"] and skill["bkt_type"] != "fact":
            errors.append(f"{where}: fact skills must use bkt_type 'fact' (it carries the fluency threshold)")
        if not _is_str_list(skill["misconceptions"]) or not skill["misconceptions"]:
            errors.append(f"{where}: misconceptions must be a non-empty list of names")
        else:
            for name in skill["misconceptions"]:
                if name not in misconceptions:
                    errors.append(f"{where}: misconception '{name}' is not in misconceptions.json")

    # Prerequisites: they exist, point at the same or an earlier zone, and form a DAG.
    graph: dict[str, list[str]] = {}
    for sid, skill in skills.items():
        if skill_status[sid] != "detailed":
            graph[sid] = []
            continue
        prereqs = skill["prereqs"]
        if not _is_str_list(prereqs) or len(set(prereqs)) != len(prereqs):
            errors.append(f"skill {sid}: prereqs must be a list of unique skill ids")
            graph[sid] = []
            continue
        graph[sid] = list(prereqs)
        for dep in prereqs:
            if dep == sid:
                errors.append(f"skill {sid}: lists itself as a prerequisite")
            elif dep not in skills:
                errors.append(f"skill {sid}: prerequisite '{dep}' does not exist")
            elif skill_zone[dep] > skill_zone[sid]:
                errors.append(f"skill {sid}: prerequisite '{dep}' is in a later zone")
            elif skill_status[dep] != "detailed":
                errors.append(f"skill {sid}: prerequisite '{dep}' is only an outline")
    cycle = find_cycle(graph)
    if cycle:
        errors.append("skill map: prerequisite cycle " + " -> ".join(cycle))

    # Every vocabulary term for a detailed zone should be taught by some skill, unless the term says
    # where else it is taught ("taught_by": "workshop" for the crafting bench's "recipe").
    detailed_zones = {zone for sid, zone in skill_zone.items() if skill_status[sid] == "detailed"}
    used_terms = {t for sid, s in skills.items() if skill_status[sid] == "detailed" for t in s["terms"]}
    for term_id, term in vocabulary.items():
        if term["zone"] in detailed_zones and term_id not in used_terms and not term.get("taught_by"):
            errors.append(f"vocabulary: '{term_id}' (zone {term['zone']}) is used by no skill")

    # bkt_type keys must exist in bkt_defaults.json.
    for sid, skill in skills.items():
        if skill_status[sid] == "detailed" and skill.get("bkt_type") in BKT_SKILL_TYPES and skill["bkt_type"] not in bkt:
            errors.append(f"skill {sid}: bkt_type '{skill['bkt_type']}' has no entry in bkt_defaults.json")
    return errors


def check_all(root: Path = ROOT) -> list[str]:
    """Run every curriculum check against the curriculum files under `root`."""
    curriculum = root / "curriculum"
    vocabulary = load_vocabulary(curriculum / "vocabulary.json")
    misconceptions = load_misconceptions(curriculum / "misconceptions.json")
    bkt = load_bkt_defaults(curriculum / "bkt_defaults.json")
    line_ids = load_line_ids(root / "text" / "lines.csv")
    errors = check_bkt_defaults(bkt)
    errors += check_misconceptions(misconceptions, line_ids)
    errors += check_vocabulary(vocabulary, line_ids)
    errors += check_skill_map(load_zone_files(curriculum / "skills"), vocabulary, misconceptions, bkt)
    return errors


if __name__ == "__main__":
    problems = check_all()
    for problem in problems:
        print("ERROR:", problem)
    print(f"curriculum check: {len(problems)} problem(s)")
    raise SystemExit(1 if problems else 0)
