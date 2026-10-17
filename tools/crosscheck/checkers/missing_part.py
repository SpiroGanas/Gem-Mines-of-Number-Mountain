"""Independent re-derivation of the MissingPartGenerator problems (skills eq.missing_addend.to_20
and eq.missing_subtrahend.to_20): "a + ? = c" and "c - ? = a". The missing number is found by
trying every candidate, and each wrong answer must leave the equation false."""
from __future__ import annotations


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {"addend": _addend, "subtrahend": _subtrahend}.get(mode)
    if handler is None:
        return [f"unknown missing-part mode {mode!r}"]
    return handler(problem)


def _part_and_whole(problem: dict) -> tuple[list[str], int, int]:
    errors: list[str] = []
    params = problem["prompt_params"]
    if set(params) != {"a", "c"}:
        errors.append(f"prompt params should be a and c, got {sorted(params)}")
    a, c = params["a"], params["c"]
    if not 1 <= a < c <= problem["params"]["max"]:
        errors.append(f"need 1 <= a < c <= {problem['params']['max']}, got a={a}, c={c}")
    return errors, a, c


def _solutions(c: int, works) -> list[int]:
    return [n for n in range(0, c + 1) if works(n)]


def _addend(problem: dict) -> list[str]:
    errors, a, c = _part_and_whole(problem)
    if problem["prompt_line_id"] != "z2.eq.prompt_missing_addend":
        errors.append("the prompt line should be z2.eq.prompt_missing_addend")
    answer = problem["answer"]
    if _solutions(c, lambda n: a + n == c) != [answer] or answer < 1:
        errors.append(f"{a} + ? = {c}: the answer {answer!r} does not complete the sum")
    for entry in problem["distractors"]:
        if a + entry["value"] == c:
            errors.append(f"wrong answer {entry['value']} completes the sum")
    named = sorted((entry["misconception"], entry["value"]) for entry in problem["distractors"])
    expected = sorted([("added_both", a + c), ("off_by_one", answer - 1), ("off_by_one", answer + 1)])
    if named != expected:
        errors.append(f"the wrong answers should be {expected}, got {named}")
    if problem["visual"] != {"type": "ten_frame", "count": a, "frames": 2}:
        errors.append(f"the picture should show {a} gems in two ten-frames, got {problem['visual']}")
    model = problem["hint_steps"][1]["visual"]
    if model != {"type": "ten_frame", "count": a, "second": c - a, "frames": 2}:
        errors.append(f"the hint should add {c - a} gems of another color to the {a}, got {model}")
    example = problem["hint_steps"][2]["example"]
    said = example["answer_params"]
    if example["answer_line_id"] != "z2.hint.example_missing_addend" or said.get("a", 0) + said.get("n", 0) != said.get("c") \
            or said.get("n") != example["answer"] or {"a": said.get("a"), "c": said.get("c")} != example["prompt_params"]:
        errors.append(f"the worked example does not state a + n = c for its own numbers: {said}")
    return errors


def _subtrahend(problem: dict) -> list[str]:
    errors, a, c = _part_and_whole(problem)
    if problem["prompt_line_id"] != "z2.eq.prompt_missing_subtrahend":
        errors.append("the prompt line should be z2.eq.prompt_missing_subtrahend")
    answer = problem["answer"]
    if _solutions(c, lambda n: c - n == a) != [answer] or answer < 1:
        errors.append(f"{c} - ? = {a}: the answer {answer!r} does not leave {a}")
    for entry in problem["distractors"]:
        if c - entry["value"] == a:
            errors.append(f"wrong answer {entry['value']} leaves {a}")
    named = [(entry["misconception"], entry["value"]) for entry in problem["distractors"]]
    if named != [("added_both", c + a)]:
        errors.append(f"the one wrong answer should be added_both {c + a}, got {named}")
    line = problem["visual"]
    if line.get("type") != "number_line" or sorted(line.get("markers", [])) != sorted([a, c]) or "jumps" in line:
        errors.append(f"the picture should be a number line marking {c} and {a}, with no jump yet: {line}")
    model = problem["hint_steps"][1]["visual"]
    same_window = (model.get("min"), model.get("max")) == (line.get("min"), line.get("max"))
    if model.get("type") != "number_line" or model.get("jumps") != [{"from": c, "to": a}] or not same_window:
        errors.append(f"the hint should jump back from {c} to {a} on the same line, got {model}")
    example = problem["hint_steps"][2]["example"]
    said = example["answer_params"]
    if example["answer_line_id"] != "z2.hint.example_missing_subtrahend" or said.get("c", 0) - said.get("n", 0) != said.get("a") \
            or said.get("n") != example["answer"] or {"a": said.get("a"), "c": said.get("c")} != example["prompt_params"]:
        errors.append(f"the worked example does not state c - n = a for its own numbers: {said}")
    return errors
