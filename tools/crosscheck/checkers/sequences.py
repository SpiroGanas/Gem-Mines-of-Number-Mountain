"""Independent re-derivation of the SequenceGenerator problems (Zone 9 skills seq.*).

An arithmetic sequence is checked by taking differences of the shown terms (they must all be equal and
at least 1, so nothing goes below zero), a geometric one by checking each term is the one before times
the same whole ratio, and the asked term is rebuilt with a loop. Classify decides by those same tests."""
from __future__ import annotations

from .common import is_int

KEYS = ("a", "b", "c", "d", "e")
CLASSIFY_LABELS = {"arithmetic": "z9.classify.adds", "geometric": "z9.classify.multiplies", "neither": "z9.classify.neither"}


def by_name(problem: dict) -> dict[str, list]:
    named: dict[str, list] = {}
    for entry in problem["distractors"]:
        named.setdefault(entry["misconception"], []).append(entry["value"])
    return named


def shown_terms(problem: dict) -> list:
    """The row as the prompt states it, with None at a missing term."""
    p = problem["prompt_params"]
    if problem["prompt_line_id"].startswith(("z9.seq.prompt_missing_", "z9.fib.prompt_missing_")):
        return [p.get(key) for key in KEYS]
    return [p[key] for key in KEYS if key in p]


def constant_step(terms: list[int]) -> int | None:
    steps = {later - earlier for earlier, later in zip(terms, terms[1:])}
    return steps.pop() if len(steps) == 1 else None


def constant_ratio(terms: list[int]) -> int | None:
    if any(t <= 0 for t in terms):
        return None
    ratio = terms[1] // terms[0]
    if all(later == earlier * ratio for earlier, later in zip(terms, terms[1:])) and ratio >= 2:
        return ratio
    return None


def check_wall(problem: dict, row: list) -> list[str]:
    """meta.pattern_wall shows the row with None at the asked term."""
    wall = problem["meta"].get("pattern_wall")
    if wall is None:
        return ["the pattern wall is missing"]
    return [] if wall["terms"] == row else [f"the wall shows {wall['terms']}, not {row}"]


def check(problem: dict) -> list[str]:
    mode = problem["params"].get("mode")
    checker = {"next": _next, "missing": _missing, "rule": _rule, "geometric": _geometric, "classify": _classify}.get(mode)
    if checker is None:
        return [f"unknown sequence mode {mode!r}"]
    return checker(problem)


def _arith_range(problem: dict, start: int, step: int) -> list[str]:
    params = problem["params"]
    errors = []
    if not 1 <= step <= params.get("max_step", 9):
        errors.append(f"the step {step} is out of range")
    if not 1 <= start <= params.get("max_start", 20) + 1:  # rule moves a start equal to the step up by one
        errors.append(f"the start {start} is out of range")
    return errors


def _next(problem: dict) -> list[str]:
    terms = shown_terms(problem)
    step = constant_step(terms)
    if len(terms) != 4 or step is None:
        return [f"{terms} is not four terms of an adding sequence"]
    errors = _arith_range(problem, terms[0], step)
    answer = terms[3]
    for _ in range(step):
        answer += 1
    if problem["answer"] != answer:
        errors.append(f"after {terms} comes {answer}, not {problem['answer']}")
    named = by_name(problem)
    if named.get("repeated_last_term") != [terms[3]]:
        errors.append("repeated_last_term should be the last shown term")
    if not named.get("added_wrong_step") or any(abs(v - answer) != 1 for v in named["added_wrong_step"]):
        errors.append("added_wrong_step should be one away from the answer")
    row = terms + [answer]
    picture = problem["visual"]
    if picture.get("terms") != row or picture.get("blanks") != [4]:
        errors.append("the picture should show the five terms with the last one blank")
    if problem["representation"] == "concrete":
        errors += check_wall(problem, terms + [None])
    elif "pattern_wall" in problem["meta"]:
        errors.append("only concrete problems use the pattern wall")
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if q["e"] != q["d"] + q["s"]:
        errors.append("the worked example's next term is wrong")
    return errors


def _missing(problem: dict) -> list[str]:
    terms = shown_terms(problem)
    if len(terms) != 5 or terms.count(None) != 1:
        return [f"{terms} is not five terms with one gap"]
    blank = terms.index(None)
    if not 1 <= blank <= 3 or problem["prompt_line_id"] != f"z9.seq.prompt_missing_{blank}":
        return [f"the gap at {blank} does not match the prompt"]
    if (terms[4] - terms[0]) % 4:
        return [f"{terms} cannot be an adding sequence"]
    step = (terms[4] - terms[0]) // 4
    full = [terms[0] + step * index for index in range(5)]
    errors = _arith_range(problem, terms[0], step)
    if any(t is not None and t != f for t, f in zip(terms, full)):
        errors.append(f"{terms} does not add the same step")
    if problem["answer"] != full[blank]:
        errors.append(f"the missing term is {full[blank]}, not {problem['answer']}")
    named = by_name(problem)
    if named.get("averaged_neighbors_wrong") != [full[blank - 1] + full[blank + 1]]:
        errors.append("averaged_neighbors_wrong should be the two neighbors added")
    if any(abs(v - full[blank]) != 1 for v in named.get("added_wrong_step", [])):
        errors.append("added_wrong_step should be one away from the answer")
    if problem["representation"] == "pictorial":
        errors += check_wall(problem, terms)
    elif "pattern_wall" in problem["meta"]:
        errors.append("only pictorial problems use the pattern wall")
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if q["s"] < 1:
        errors.append("the worked example's step is wrong")
    return errors


def _rule(problem: dict) -> list[str]:
    terms = shown_terms(problem)
    step = constant_step(terms)
    if len(terms) != 5 or step is None:
        return [f"{terms} is not five terms of an adding sequence"]
    errors = _arith_range(problem, terms[0], step)
    if problem["answer"] != step:
        errors.append(f"the rule adds {step}, not {problem['answer']}")
    if problem["meta"].get("label_line") != "z9.seq.rule_add":
        errors.append("the rule buttons should read z9.seq.rule_add")
    named = by_name(problem)
    if named.get("confused_start_and_step") != [terms[0]]:
        errors.append("confused_start_and_step should be the first term")
    if any(abs(v - step) != 1 for v in named.get("added_wrong_step", [])):
        errors.append("added_wrong_step should be one away from the step")
    if len(problem["distractors"]) < 2:
        errors.append("a rule needs at least two wrong buttons")
    return errors


def _geometric(problem: dict) -> list[str]:
    terms = shown_terms(problem)
    ratio = constant_ratio(terms) if len(terms) >= 3 else None
    if len(terms) not in (3, 4) or ratio is None:
        return [f"{terms} is not three or four terms of a multiplying sequence"]
    errors = []
    if ratio not in problem["params"].get("ratios", [2, 3, 5, 10]) or terms[0] > 9:
        errors.append(f"ratio {ratio} or start {terms[0]} is not allowed")
    answer = 0
    for _ in range(ratio):
        answer += terms[-1]
    if problem["answer"] != answer or answer > problem["params"].get("max_value", 1000):
        errors.append(f"after {terms} comes {answer} (at most max_value), not {problem['answer']}")
    wanted = {
        "added_ratio": terms[-1] + ratio,
        "off_by_one_exponent": answer * ratio,
        "continued_by_adding": terms[-1] + (terms[-1] - terms[-2]),
    }
    named = {name: values[0] for name, values in by_name(problem).items()}
    if named != {name: value for name, value in wanted.items() if value != answer}:
        errors.append(f"the wrong answers should be {wanted}, got {named}")
    if problem["meta"].get("pad_digits") != 4:
        errors.append("the pad takes four digits for a geometric answer")
    if problem["representation"] == "concrete":
        errors += check_wall(problem, terms + [None])
    return errors


def _classify(problem: dict) -> list[str]:
    terms = shown_terms(problem)
    if len(terms) != 4:
        return [f"{terms} should be four terms"]
    step = constant_step(terms)
    ratio = constant_ratio(terms)
    errors = []
    if (step is not None and step >= 1) == (ratio is not None):
        return [f"{terms} must be exactly one of adding or multiplying"]
    kind = "arithmetic" if ratio is None else "geometric"
    if problem["answer"] != kind:
        errors.append(f"{terms} is {kind}, not {problem['answer']}")
    other = "geometric" if kind == "arithmetic" else "arithmetic"
    if by_name(problem) != {"swapped_types": [other], "missed_the_pattern": ["neither"]}:
        errors.append(f"the wrong answers should be {other} and neither")
    if problem["meta"].get("label_lines") != CLASSIFY_LABELS:
        errors.append("the buttons should read the classify lines")
    if not all(is_int(t) and t >= 1 for t in terms):
        errors.append("every term is a whole number of at least 1")
    return errors
