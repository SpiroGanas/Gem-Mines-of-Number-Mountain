"""Independent re-derivation of the FigurateGenerator problems (Zone 9 skills fig.*).

Triangles are counted row by row (1 + 2 + ... + n with a loop) and squares as n rows of n, never with
the formulas the generator uses."""
from __future__ import annotations


def rows(n: int) -> int:
    total = 0
    for row in range(1, n + 1):
        total += row
    return total


def square(n: int) -> int:
    total = 0
    for _ in range(n):
        total += n
    return total


def by_name(problem: dict) -> dict[str, list]:
    named: dict[str, list] = {}
    for entry in problem["distractors"]:
        named.setdefault(entry["misconception"], []).append(entry["value"])
    return named


def check(problem: dict) -> list[str]:
    mode = problem["params"].get("mode")
    checker = {"triangular": _triangular, "square": _square, "two_triangles": _two_triangles}.get(mode)
    if checker is None:
        return [f"unknown figurate mode {mode!r}"]
    n = problem["prompt_params"]["n"]
    low = 3 if problem["representation"] == "concrete" else 2
    errors = [] if low <= n <= problem["params"].get("max_n", 12) else [f"n = {n} is out of range"]
    return errors + checker(problem, n)


def _wall(problem: dict, n: int, value_of, figure: str) -> list[str]:
    first = max(1, n - 4)
    row = [value_of(index) for index in range(first, n)]
    errors = []
    picture = problem["visual"]
    if picture.get("figure") != figure or picture.get("first_index") != first or picture.get("terms") != row + [value_of(n)]:
        errors.append(f"the wall picture should show {figure}s {first} to {n}")
    wall = problem["meta"].get("pattern_wall", {})
    if wall.get("terms") != row + [None]:
        errors.append(f"the wall should hold {row} and a gap")
    return errors


def _expect(problem: dict, wanted: dict[str, set]) -> list[str]:
    answer = problem["answer"]
    errors = []
    for name, values in by_name(problem).items():
        if name not in wanted or not set(values) <= wanted[name] - {answer}:
            errors.append(f"{name} {values} is not one of {wanted.get(name)}")
    return errors


def _triangular(problem: dict, n: int) -> list[str]:
    errors = []
    if problem["answer"] != rows(n):
        errors.append(f"triangle {n} has {rows(n)} gems, not {problem['answer']}")
    errors += _expect(problem, {"used_square": {square(n)}, "off_by_one_n": {rows(n - 1), rows(n + 1)}})
    if problem["representation"] == "concrete":
        errors += _wall(problem, n, rows, "triangle")
        if problem["prompt_line_id"] != "z9.fig.prompt_triangle_wall":
            errors.append("a wall problem asks with the wall prompt")
    elif problem["visual"] != {"type": "figurate", "kind": "triangle", "n": n}:
        errors.append("the picture should be triangle n")
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if q["t"] != rows(q["n"]):
        errors.append("the worked example's triangle is wrong")
    return errors


def _square(problem: dict, n: int) -> list[str]:
    errors = []
    if problem["answer"] != square(n):
        errors.append(f"square {n} has {square(n)} gems, not {problem['answer']}")
    errors += _expect(problem, {"used_triangular": {rows(n)}, "off_by_one_n": {square(n - 1), square(n + 1)}})
    errors += _wall(problem, n, square, "square")
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if q["t"] != square(q["n"]):
        errors.append("the worked example's square is wrong")
    return errors


def _two_triangles(problem: dict, n: int) -> list[str]:
    errors = []
    if problem["prompt_params"]["m"] != n - 1:
        errors.append("the second staircase is one row shorter")
    together = rows(n) + rows(n - 1)
    if together != square(n) or problem["answer"] != together:
        errors.append(f"staircases {n} and {n - 1} make {together} gems, not {problem['answer']}")
    errors += _expect(problem, {
        "added_same_triangular_twice_wrong_n": {rows(n) + rows(n)},
        "used_triangular": {rows(n)},
        "off_by_one_n": {square(n - 1)},
    })
    if problem["visual"] != {"type": "figurate", "kind": "two_triangles", "n": n, "fitted": False}:
        errors.append("the picture shows the two staircases apart")
    if problem["hint_steps"][1]["visual"].get("fitted") is not True:
        errors.append("the rung 2 model shows them fitted into the square")
    return errors
