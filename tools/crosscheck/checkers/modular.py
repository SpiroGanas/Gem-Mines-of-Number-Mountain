"""Independent re-derivation of the ModularGenerator problems (Zone 10, skills mod.*).

The cart is walked one stop at a time around the loop (no % and no division for the answer), and
every named mistake is rebuilt from the numbers in the prompt. Nothing here is ported from
scripts/generators/modular.gd."""
from __future__ import annotations

from .common import distractor_pairs, filtered, is_int

MAX_STATIONS = 12
MAX_STOPS = 99


def ride(n: int, start: int, steps: int, direction: int) -> int:
    """The station after riding `steps` stops one at a time round a loop of n stations."""
    at = start
    for _ in range(steps):
        at += direction
        if at == n:
            at = 0
        elif at < 0:
            at = n - 1
    return at


def laps(a: int, n: int) -> int:
    """Whole laps of n in a, counted by subtracting."""
    count = 0
    while a >= n:
        a -= n
        count += 1
    return count


def track(n: int, start: int, steps: int, direction: int, show_stop: bool, also: int | None = None, orbit: bool = False) -> dict:
    picture = {"type": "clock_track", "n": n, "start": start, "steps": steps, "direction": direction, "show_stop": show_stop}
    if also is not None:
        picture["also"] = also
    if orbit:
        picture["orbit"] = True
    return picture


def cayley(n: int, op: str, wrap: bool, blank: list | None = None, ring: list | None = None, focus: str = "", row: int = -1) -> dict:
    picture = {"type": "cayley", "n": n, "op": op, "wrap": wrap}
    if blank:
        picture["blank"] = blank
    if ring:
        picture["ring"] = ring
    if focus:
        picture["focus"] = focus
    if row >= 0:
        picture["row"] = row
    return picture


def check(problem: dict) -> list[str]:
    handler = {
        "remainder": _remainder, "track": _track, "congruence": _congruence,
        "notation": _notation, "add": _add, "mul": _mul,
    }.get(problem["params"].get("mode"))
    if handler is None:
        return [f"unknown modular mode {problem['params'].get('mode')!r}"]
    return handler(problem)


def _compare_wrong(problem: dict, candidates: list[tuple[str, object]], allow_negative: bool = False) -> list[str]:
    wanted = filtered(problem["answer"], candidates, allow_negative=allow_negative)
    if distractor_pairs(problem) != wanted:
        return [f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}"]
    return []


def _example(problem: dict) -> dict:
    return problem["hint_steps"][2]["example"]


def _remainder(problem: dict) -> list[str]:
    p, skill = problem["prompt_params"], problem["params"]
    if set(p) != {"a", "n"}:
        return ["the prompt should have {a, n}"]
    a, n = p["a"], p["n"]
    errors: list[str] = []
    if not (skill["min_n"] <= n <= skill["max_n"] and n <= MAX_STATIONS and max(skill["min_a"], n) <= a <= min(skill["max_a"], MAX_STOPS)):
        errors.append(f"{a} stops on a loop of {n} is outside the skill's ranges")
    r = ride(n, 0, a, 1)
    if problem["answer"] != r or not 0 <= r < n:
        errors.append(f"{a} stops from 0 on a loop of {n} end at {r}, not {problem['answer']}")
    line = "z10.mod.prompt_remainder" if problem["representation"] == "abstract" else "z10.mod.prompt_remainder_track"
    if problem["prompt_line_id"] != line:
        errors.append(f"the prompt should be {line}")
    candidates = [("gave_quotient", laps(a, n))]
    if a - n >= n:
        candidates.append(("forgot_mod_wrap", a - n))
    candidates.append(("off_by_one", r + 1 if r + 1 < n else r - 1))
    errors += _compare_wrong(problem, candidates)
    if problem["representation"] == "concrete":
        if problem["meta"].get("circular_track") != {"n": n, "start": 0, "steps": a, "direction": 1} or problem["visual"]:
            errors.append("a concrete problem is the circular track, with no other picture")
    elif problem["representation"] == "pictorial":
        if problem["visual"] != track(n, 0, a, 1, False):
            errors.append("a pictorial problem shows the loop with the cart at 0 and the stop hidden")
    elif problem["visual"] or "circular_track" in problem["meta"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != track(n, 0, a, 1, True):
        errors.append("the rung 2 model should show where the cart stops")
    ex = _example(problem)
    ea, en = ex["prompt_params"]["a"], ex["prompt_params"]["n"]
    if ex["answer_line_id"] != "z10.hint.example_remainder" or ex["answer_params"] != {"a": ea, "n": en, "q": laps(ea, en), "r": ride(en, 0, ea, 1)}:
        errors.append("the worked example should name the laps and the remainder")
    return errors


def _track(problem: dict) -> list[str]:
    p, skill = problem["prompt_params"], problem["params"]
    if set(p) != {"n", "s", "k"}:
        return ["the prompt should have {n, s, k}"]
    n, s, k = p["n"], p["s"], p["k"]
    d = skill["direction"]
    errors: list[str] = []
    if not (skill["min_n"] <= n <= min(skill["max_n"], MAX_STATIONS) and 0 <= s < n and skill["min_steps"] <= k <= min(skill["max_steps"], MAX_STOPS)):
        errors.append(f"n {n}, start {s}, steps {k} are outside the skill's ranges")
    line = "z10.mod.prompt_stop" if d == 1 else "z10.mod.prompt_back"
    if problem["prompt_line_id"] != line:
        errors.append(f"the prompt should be {line}")
    r = ride(n, s, k, d)
    if problem["answer"] != r:
        errors.append(f"riding {k} from {s} on a loop of {n} (direction {d}) ends at {r}, not {problem['answer']}")
    if d == 1:
        candidates = [("forgot_mod_wrap", s + k)] if s + k >= n else []
        candidates.append(("counted_start_station", ride(n, s, k - 1, 1)))
        errors += _compare_wrong(problem, candidates)
        if problem["meta"].get("signed"):
            errors.append("only backward problems take a minus sign")
    else:
        errors += _compare_wrong(problem, [("negative_remainder", s - k), ("went_forward_instead", ride(n, s, k, 1))], allow_negative=True)
        if problem["meta"].get("signed") is not True:
            errors.append("backward problems let the pad take a minus sign")
    if problem["representation"] == "concrete":
        if problem["meta"].get("circular_track") != {"n": n, "start": s, "steps": k, "direction": d} or problem["visual"]:
            errors.append("a concrete problem is the circular track, with no other picture")
    elif problem["visual"] != track(n, s, k, d, False):
        errors.append("a pictorial problem shows the loop with the cart and the stop hidden")
    if problem["hint_steps"][1]["visual"] != track(n, s, k, d, True):
        errors.append("the rung 2 model should show where the cart stops")
    ex = _example(problem)
    eq = ex["prompt_params"]
    want = {"s": eq["s"], "k": eq["k"], "n": eq["n"], "r": ride(eq["n"], eq["s"], eq["k"], d)}
    line = "z10.hint.example_stop" if d == 1 else "z10.hint.example_back"
    if ex["answer_line_id"] != line or ex["answer_params"] != want:
        errors.append("the worked example should say where its cart stops")
    return errors


def _congruence(problem: dict) -> list[str]:
    p, skill = problem["prompt_params"], problem["params"]
    if set(p) != {"n", "a", "b"} or problem["prompt_line_id"] != "z10.mod.prompt_congruent":
        return ["the prompt should be z10.mod.prompt_congruent with {n, a, b}"]
    n, a, b = p["n"], p["a"], p["b"]
    errors: list[str] = []
    if a == b or not (skill["min_n"] <= n <= min(skill["max_n"], MAX_STATIONS) and skill["min_a"] <= a <= skill["max_a"] and skill["min_a"] <= b <= skill["max_a"]):
        errors.append(f"{a} and {b} should be different numbers of the skill's range on a loop of {n}")
    same = ride(n, 0, a, 1) == ride(n, 0, b, 1)
    if problem["answer"] is not same:
        errors.append(f"{a} and {b} on a loop of {n}: same station is {same}, not {problem['answer']}")
    wrong = "compared_raw_values" if same else "compared_quotients"
    if distractor_pairs(problem) != [(wrong, not same)]:
        errors.append(f"the one wrong answer should be {(wrong, not same)}")
    if problem["meta"].get("label_lines") != {"true": "ui.common.yes", "false": "ui.common.no"}:
        errors.append("the answer buttons read Yes and No")
    if problem["representation"] == "pictorial":
        if problem["visual"] != track(n, 0, a, 1, False, b):
            errors.append("a pictorial problem shows both carts and hides the stops")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != track(n, 0, a, 1, True, b):
        errors.append("the rung 2 model should show both stops")
    ex = _example(problem)
    ep = ex["prompt_params"]
    ra, rb = ride(ep["n"], 0, ep["a"], 1), ride(ep["n"], 0, ep["b"], 1)
    if example_yes := ex["answer"]:
        want, line = {"a": ep["a"], "b": ep["b"], "r": ra}, "z10.hint.example_congruent_yes"
    else:
        want, line = {"a": ep["a"], "b": ep["b"], "r": ra, "t": rb}, "z10.hint.example_congruent_no"
    if ex["answer_line_id"] != line or ex["answer_params"] != want or example_yes is not (ra == rb):
        errors.append("the worked example should say where both carts stop")
    return errors


def _notation(problem: dict) -> list[str]:
    meta, skill = problem["meta"], problem["params"]
    n, a, b = meta.get("n"), meta.get("a"), meta.get("b")
    if not (is_int(n) and is_int(a) and is_int(b)) or problem["prompt_params"] != {}:
        return ["the notation problem names n, a and b in its meta and has no prompt numbers"]
    errors: list[str] = []
    r = ride(n, 0, a, 1)
    if not (a != b and a > n and b > n and ride(n, 0, b, 1) == r and skill["min_n"] <= n <= min(skill["max_n"], MAX_STATIONS)):
        errors.append(f"{a} and {b} should be different numbers above {n}, on the same station of a loop of {n}")
    card = {"type": "notation", "form": "congruence", "a": a, "b": b, "n": n}
    if problem["visual"] != card or problem["hint_steps"][1]["visual"] != card:
        errors.append("the card a ≡ b (mod n) is the picture")
    if problem["prompt_line_id"] == "z10.mod.prompt_notation_loop":
        errors.append("") if problem["answer"] == n else errors.append(f"the loop has {n} stations, not {problem['answer']}")
        errors += _compare_wrong(problem, [("swapped_mod_and_value", a), ("swapped_mod_and_value", b), ("swapped_mod_and_value", r)])
    elif problem["prompt_line_id"] == "z10.mod.prompt_notation_station":
        errors.append("") if problem["answer"] == r else errors.append(f"both land on station {r}, not {problem['answer']}")
        errors += _compare_wrong(problem, [("read_as_equals", a), ("read_as_equals", b), ("swapped_mod_and_value", n)])
    else:
        errors.append("the prompt should be z10.mod.prompt_notation_loop or _station")
    return [e for e in errors if e]


def _add(problem: dict) -> list[str]:
    p, skill = problem["prompt_params"], problem["params"]
    if set(p) != {"n", "m", "a", "b"} or problem["prompt_line_id"] != "z10.mod.prompt_add":
        return ["the prompt should be z10.mod.prompt_add with {n, m, a, b}"]
    n, m, a, b = p["n"], p["m"], p["a"], p["b"]
    errors: list[str] = []
    if m != n - 1 or not (skill["min_n"] <= n <= min(skill["max_n"], MAX_STATIONS) and 1 <= a < n and 1 <= b < n):
        errors.append(f"the dial of {n} marks, 0 to {m}, turned {a} then {b} is out of range")
    r = ride(n, ride(n, 0, a, 1), b, 1)
    if problem["answer"] != r:
        errors.append(f"turning {a} then {b} on a dial of {n} ends at {r}, not {problem['answer']}")
    candidates = [("forgot_mod_wrap", a + b)] if a + b >= n else []
    candidates.append(("subtracted_instead", ride(n, a, b, -1)))
    errors += _compare_wrong(problem, candidates)
    if problem["representation"] == "concrete":
        if problem["meta"].get("clock_lock") != {"n": n, "turns": [a, b]} or problem["visual"]:
            errors.append("a concrete problem is the clock lock, with no other picture")
    elif problem["visual"] or "clock_lock" in problem["meta"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != track(n, 0, a + b, 1, True):
        errors.append("the rung 2 model should ride a + b stops round the loop")
    ex = _example(problem)
    ep = ex["prompt_params"]
    want = {"a": ep["a"], "b": ep["b"], "t": ep["a"] + ep["b"], "n": ep["n"], "r": ride(ep["n"], 0, ep["a"] + ep["b"], 1)}
    if ex["answer_line_id"] != "z10.hint.example_add" or ex["answer_params"] != want:
        errors.append("the worked example should add and wrap")
    return errors


def _mul(problem: dict) -> list[str]:
    p, skill = problem["prompt_params"], problem["params"]
    if set(p) != {"n", "m", "a", "b"} or problem["prompt_line_id"] != "z10.mod.prompt_mul":
        return ["the prompt should be z10.mod.prompt_mul with {n, m, a, b}"]
    n, m, a, b = p["n"], p["m"], p["a"], p["b"]
    errors: list[str] = []
    if m != n - 1 or not (skill["min_n"] <= n <= min(skill["max_n"], MAX_STATIONS) and 2 <= a < n and 2 <= b < n):
        errors.append(f"{a} times {b} on a dial of {n} marks is out of range")
    r = ride(n, 0, a * b, 1)
    if problem["answer"] != r:
        errors.append(f"{a} × {b} on a dial of {n} is {r}, not {problem['answer']}")
    candidates = [("forgot_mod_wrap", a * b)] if a * b >= n else []
    candidates.append(("added_instead", ride(n, 0, a + b, 1)))
    errors += _compare_wrong(problem, candidates)
    if problem["representation"] == "pictorial":
        if problem["visual"] != cayley(n, "mul", True, [a, b], [a, b]):
            errors.append("a pictorial problem shows the multiplication table with the box blank and ringed")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != cayley(n, "mul", True, [], [a, b]):
        errors.append("the rung 2 model should show the table with the box ringed and filled")
    ex = _example(problem)
    ep = ex["prompt_params"]
    want = {"a": ep["a"], "b": ep["b"], "t": ep["a"] * ep["b"], "n": ep["n"], "r": ride(ep["n"], 0, ep["a"] * ep["b"], 1)}
    if ex["answer_line_id"] != "z10.hint.example_mul" or ex["answer_params"] != want:
        errors.append("the worked example should multiply and wrap")
    return errors
