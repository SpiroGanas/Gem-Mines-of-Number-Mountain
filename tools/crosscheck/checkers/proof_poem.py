"""Independent checks of the ProofGenerator and FibPoemGenerator problems (Zone 9 skills proof.words.match
and fib.poem.syllables).

Neither has arithmetic to redo beyond sums of syllables (the plan's "JSON validation"): a proof answer
and its wrong answers must be diagram ids in curriculum/proof_diagrams.json with their fact lines, and a
poem line must be words of curriculum/poem_words.json whose stored syllable counts add up to the line's
goal (the Fibonacci number of that line). The two files are read here directly."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FIB_LINES = [1, 1, 2, 3, 5, 8]
MAX_WORDS = 4


def _load(name: str) -> dict:
    return json.loads((ROOT / "curriculum" / name).read_text(encoding="utf-8"))


DIAGRAMS = {entry["id"]: entry for entry in _load("proof_diagrams.json")["diagrams"]}
WORDS = {entry["id"]: entry["syllables"] for entry in _load("poem_words.json")["words"]}


def by_name(problem: dict) -> dict[str, list]:
    named: dict[str, list] = {}
    for entry in problem["distractors"]:
        named.setdefault(entry["misconception"], []).append(entry["value"])
    return named


def check_proof(problem: dict) -> list[str]:
    answer = problem["answer"]
    if answer not in DIAGRAMS:
        return [f"{answer!r} is not a diagram in curriculum/proof_diagrams.json"]
    errors = []
    wrong = by_name(problem)
    if set(wrong) != {"wrong_diagram"}:
        errors.append("every wrong answer is wrong_diagram")
    values = wrong.get("wrong_diagram", [])
    if len(values) != min(problem["params"].get("choices", 4), 4) - 1 or len(set(values)) != len(values):
        errors.append(f"{values} should be {problem['params'].get('choices', 4) - 1} different other diagrams")
    for value in values:
        if value not in DIAGRAMS or value == answer:
            errors.append(f"wrong answer {value!r} is not another diagram on file")
    labels = problem["meta"].get("label_lines", {})
    for diagram_id in [answer] + values:
        if labels.get(diagram_id) != DIAGRAMS.get(diagram_id, {}).get("label_line_id"):
            errors.append(f"{diagram_id!r} should read {DIAGRAMS.get(diagram_id, {}).get('label_line_id')}")
    entry = DIAGRAMS[answer]
    picture = problem["visual"]
    n = picture.get("n", 0)
    if picture.get("type") != "proof" or picture.get("diagram") != answer or picture.get("fitted") is not False:
        errors.append("the picture shows the answer's diagram, apart")
    if not entry["min_n"] <= n <= entry["max_n"]:
        errors.append(f"size {n} is outside {entry['min_n']} to {entry['max_n']}")
    model = problem["hint_steps"][1]["visual"]
    if model != {"type": "proof", "diagram": answer, "n": n, "fitted": True}:
        errors.append("the rung 2 model shows the same diagram fitted")
    board = problem["meta"].get("proof_board", {})
    if board.get("n") != n:
        errors.append("the proof board draws the picture's size")
    example = problem["hint_steps"][2]["example"]
    if example["answer"] not in DIAGRAMS or example["answer_line_id"] != DIAGRAMS[example["answer"]]["label_line_id"]:
        errors.append("the worked example states its own diagram's fact")
    return errors


def syllables(words: list) -> int | None:
    if not isinstance(words, list) or not words or any(w not in WORDS for w in words):
        return None
    return sum(WORDS[w] for w in words)


def check_poem(problem: dict) -> list[str]:
    lines = problem["params"].get("lines", FIB_LINES)
    k, n = problem["prompt_params"]["k"], problem["prompt_params"]["n"]
    errors = []
    if lines != FIB_LINES or not 1 <= k <= 6 or n != lines[k - 1]:
        return [f"line {k} of a Fib poem needs {lines[k - 1] if 1 <= k <= 6 else '?'} syllables, not {n}"]
    if problem["prompt_line_id"] != ("z9.poem.prompt_single" if n == 1 else "z9.poem.prompt"):
        errors.append("a one-syllable line is asked with the singular prompt, the others with the plural one")
    answer = problem["answer"]
    if syllables(answer) != n or len(answer) > MAX_WORDS or len(set(answer)) != len(answer):
        errors.append(f"{answer} does not make {n} syllables in up to {MAX_WORDS} different words")
    others = [count for count in FIB_LINES if count != n]
    for entry in problem["distractors"]:
        words = entry["value"]
        total = syllables(words)
        name = entry["misconception"]
        if total is None or total == n or len(words) > MAX_WORDS:
            errors.append(f"wrong line {words} must be bank words that miss {n}")
        elif name == "wrong_line_count" and total not in others:
            errors.append(f"wrong_line_count {words} has {total} syllables, not another line's count")
        elif name == "counted_words" and (len(words) != n or n > 3):
            errors.append(f"counted_words {words} should have {n} words")
        elif name == "off_by_one_syllable" and abs(total - n) != 1:
            errors.append(f"off_by_one_syllable {words} has {total} syllables")
    if len(problem["distractors"]) < 2:
        errors.append("a poem problem offers at least two wrong lines")
    if problem["meta"].get("array_label") != "words":
        errors.append("the buttons read the words")
    if problem["visual"] != {"type": "poem_shape", "lines": FIB_LINES, "highlight": k - 1, "counts": False}:
        errors.append("the picture is the poem's shape with the line lit")
    return errors
