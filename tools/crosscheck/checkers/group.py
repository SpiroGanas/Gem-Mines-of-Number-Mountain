"""Independent re-derivation of the GroupGenerator problems (Zone 10, skills group.*).

Tables are built box by box with the loop walked one stop at a time; the identity and the undo partner are found by
trying every number, never by formula. Nothing here is ported from scripts/generators/group.gd."""
from __future__ import annotations

from .common import distractor_pairs, filtered, is_int
from .modular import cayley, ride, track

MAX_TABLE = 12
MAX_RAW_TABLE = 9


def raw(a: int, b: int, op: str) -> int:
    return a + b if op == "add" else a * b


def wrapped(a: int, b: int, op: str, n: int) -> int:
    """The mix, wrapped by walking the loop (no % operator)."""
    return ride(n, 0, raw(a, b, op), 1)


def table(n: int, op: str) -> list[list[int]]:
    return [[wrapped(a, b, op, n) for b in range(n)] for a in range(n)]


def do_nothing(n: int, op: str) -> list[int]:
    """Every number e with e mixed with each number leaving it unchanged, from both sides."""
    return [e for e in range(n) if all(wrapped(e, x, op, n) == x and wrapped(x, e, op, n) == x for x in range(n))]


def undo_partners(n: int, a: int) -> list[int]:
    return [b for b in range(n) if wrapped(a, b, "add", n) == 0]


def check(problem: dict) -> list[str]:
    handler = {
        "identity": _identity, "inverse": _inverse, "closure": _closure, "table": _table, "cyclic": _cyclic,
    }.get(problem["params"].get("mode"))
    if handler is None:
        return [f"unknown group mode {problem['params'].get('mode')!r}"]
    return handler(problem)


def _compare_wrong(problem: dict, candidates: list[tuple[str, object]], allow_negative: bool = False) -> list[str]:
    wanted = filtered(problem["answer"], candidates, allow_negative=allow_negative)
    if distractor_pairs(problem) != wanted:
        return [f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}"]
    return []


def _identity(problem: dict) -> list[str]:
    p, skill = problem["prompt_params"], problem["params"]
    spec = problem["meta"].get("mixing_table")
    if set(p) != {"n"} or not isinstance(spec, dict) or set(spec) != {"n", "op"} or spec["n"] != p["n"]:
        return ["an identity problem has {n} and a mixing table of the same n"]
    n, op = p["n"], spec["op"]
    errors: list[str] = []
    if op not in ("add", "mul") or not (max(skill["min_n"], 3) <= n <= min(skill["max_n"], MAX_TABLE)):
        errors.append(f"a {op} table of {n} is out of range")
    line = "z10.group.prompt_identity_add" if op == "add" else "z10.group.prompt_identity_mul"
    if problem["prompt_line_id"] != line:
        errors.append(f"the prompt should be {line}")
    found = do_nothing(n, op)
    if found != [problem["answer"]]:
        errors.append(f"the do-nothing number of the {op} table of {n} is {found}, not {problem['answer']}")
    candidates = [("picked_one_for_add", 1)] if op == "add" else [("picked_zero_for_mul", 0)]
    candidates.append(("picked_last_number", n - 1))
    errors += _compare_wrong(problem, candidates)
    if problem["visual"]:
        errors.append("the mixing table is the picture")
    if problem["hint_steps"][1]["visual"] != cayley(n, op, True, focus="identity"):
        errors.append("the rung 2 model should show the table with the do-nothing row and column lit")
    ex = problem["hint_steps"][2]["example"]
    eop = ex["answer_line_id"].rsplit("_", 1)[-1]
    if ex["answer_line_id"] not in ("z10.hint.example_identity_add", "z10.hint.example_identity_mul") or ex["answer_params"] != {}:
        errors.append("the worked example should name the do-nothing number")
    elif not isinstance(ex["prompt_params"].get("n"), int) or do_nothing(ex["prompt_params"]["n"], eop) != [ex["answer"]]:
        errors.append(f"the worked example's answer {ex['answer']!r} is not the do-nothing number of its {eop} table")
    return errors


def _inverse(problem: dict) -> list[str]:
    p, skill = problem["prompt_params"], problem["params"]
    if set(p) != {"a", "n"} or problem["prompt_line_id"] != "z10.group.prompt_inverse":
        return ["the prompt should be z10.group.prompt_inverse with {a, n}"]
    a, n = p["a"], p["n"]
    errors: list[str] = []
    if not (max(skill["min_n"], 3) <= n <= min(skill["max_n"], MAX_TABLE) and 1 <= a < n):
        errors.append(f"{a} on a loop of {n} is out of range")
    partners = undo_partners(n, a)
    if partners != [problem["answer"]]:
        errors.append(f"the undo partner of {a} on a loop of {n} is {partners}, not {problem['answer']}")
    errors += _compare_wrong(problem, [("gave_negative_raw", -a), ("gave_same_value", a), ("gave_n_minus_one", n - 1)], allow_negative=True)
    if problem["meta"].get("signed") is not True:
        errors.append("the pad takes a minus sign")
    if problem["representation"] == "pictorial":
        if problem["visual"] != cayley(n, "add", True, row=a):
            errors.append("a pictorial problem shows the adding table with row a lit")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != cayley(n, "add", True, focus="identity", row=a):
        errors.append("the rung 2 model should light row a and the do-nothing column")
    ex = problem["hint_steps"][2]["example"]
    ea = ex["prompt_params"]["a"]
    if ex["answer_line_id"] != "z10.hint.example_inverse" or ex["answer_params"] != {"a": ea, "b": ex["answer"]}:
        errors.append("the worked example should name the undo partner")
    elif undo_partners(ex["prompt_params"]["n"], ea) != [ex["answer"]]:
        errors.append(f"the worked example's {ex['answer']!r} is not the undo partner of {ea} on a loop of {ex['prompt_params']['n']}")
    return errors


def _closure(problem: dict) -> list[str]:
    p, skill = problem["prompt_params"], problem["params"]
    visual = problem["visual"]
    if set(p) != {"m"} or visual.get("type") != "cayley":
        return ["a closure problem shows a table and names {m}"]
    n, op, wrap = visual["n"], visual["op"], visual["wrap"]
    errors: list[str] = []
    if p["m"] != n - 1 or not (skill["min_n"] <= n <= min(skill["max_n"], MAX_RAW_TABLE)) or (op == "mul" and n < 3):
        errors.append(f"a {op} table of {n} is out of range")
    line = "z10.group.prompt_closure_add" if op == "add" else "z10.group.prompt_closure_mul"
    if problem["prompt_line_id"] != line:
        errors.append(f"the prompt should be {line}")
    values = [wrapped(a, b, op, n) if wrap else raw(a, b, op) for a in range(n) for b in range(n)]
    closed = all(v < n for v in values)
    if problem["answer"] is not closed:
        errors.append(f"the table is closed: {closed}, not {problem['answer']}")
    if visual != cayley(n, op, wrap):
        errors.append("the table is the picture")
    wrong = "distrusted_wrap" if closed else "missed_value_ge_n"
    if distractor_pairs(problem) != [(wrong, not closed)]:
        errors.append(f"the one wrong answer should be {(wrong, not closed)}")
    if problem["meta"].get("biggest") != max(values) or problem["meta"].get("label_lines") != {"true": "ui.common.yes", "false": "ui.common.no"}:
        errors.append("the meta should hold the biggest answer and the Yes/No labels")
    if problem["hint_steps"][1]["visual"] != visual:
        errors.append("the rung 2 model is the table")
    ex = problem["hint_steps"][2]["example"]
    em = ex["prompt_params"].get("m")
    if not isinstance(em, int) or ex["answer_line_id"] not in ("z10.hint.example_closure_yes", "z10.hint.example_closure_no"):
        errors.append("the worked example should say whether its table stays inside")
    else:
        # The example's line says yes (a wrapped table always stays inside) or no with the biggest raw value, which
        # for a table of em + 1 numbers is 2 × em (adding) or em × em (multiplying); the example's op is not recorded.
        wanted_yes = ex["answer_line_id"].endswith("_yes")
        biggest_raw = {2 * em, em * em}
        if ex["answer"] is not wanted_yes or ex["answer_params"].get("m") != em or (not wanted_yes and ex["answer_params"].get("v") not in biggest_raw):
            errors.append("the worked example's yes or no, m and biggest value should match a table of its own size")
    return errors


def _table(problem: dict) -> list[str]:
    spec, skill = problem["meta"].get("table"), problem["params"]
    if problem["prompt_params"] != {} or not isinstance(spec, dict) or problem["prompt_line_id"] != "z10.group.prompt_table":
        return ["a table problem has no prompt numbers and names its box in meta.table"]
    n, op, r, c = spec["n"], spec["op"], spec["r"], spec["c"]
    errors: list[str] = []
    if op not in ("add", "mul") or not (max(skill["min_n"], 3) <= n <= min(skill["max_n"], MAX_TABLE) and 2 <= r < n and 2 <= c < n):
        errors.append(f"box {r},{c} of the {op} table of {n} is out of range")
        return errors
    t = table(n, op)
    if problem["answer"] != t[r][c]:
        errors.append(f"box {r},{c} of the {op} table of {n} holds {t[r][c]}, not {problem['answer']}")
    candidates = [("forgot_mod_wrap", raw(r, c, op))] if raw(r, c, op) >= n else []
    candidates += [("copied_cell_above", t[r - 1][c]), ("copied_cell_above", t[r][c - 1])]
    errors += _compare_wrong(problem, candidates)
    if problem["visual"] != cayley(n, op, True, [r, c], [r, c]):
        errors.append("the table is the picture, with the box blank and ringed")
    if problem["hint_steps"][1]["visual"] != cayley(n, op, True, ring=[r, c]):
        errors.append("the rung 2 model should show the box filled in")
    ex = problem["hint_steps"][2]["example"]
    es = ex["answer_params"]
    eop = "add" if ex["answer_line_id"].endswith("_add") else "mul"
    ok = (es.get("t") == raw(es["r"], es["c"], eop) and es.get("x") == ex["answer"] and isinstance(es.get("n"), int)
          and ex["answer"] == wrapped(es["r"], es["c"], eop, es["n"]))
    if not ex["answer_line_id"].startswith("z10.hint.example_table_") or not ok:
        errors.append("the worked example should mix the row and column and wrap to its answer")
    return errors


def _cyclic(problem: dict) -> list[str]:
    p, skill = problem["prompt_params"], problem["params"]
    if set(p) != {"n", "g"} or problem["prompt_line_id"] != "z10.group.prompt_cyclic":
        return ["the prompt should be z10.group.prompt_cyclic with {n, g}"]
    n, g = p["n"], p["g"]
    errors: list[str] = []
    if not (max(skill["min_n"], 4) <= n <= min(skill["max_n"], MAX_TABLE) and 2 <= g < n):
        errors.append(f"jumps of {g} on a loop of {n} are out of range")
    jumps, at = 1, ride(n, 0, g, 1)
    while at != 0:
        at = ride(n, at, g, 1)
        jumps += 1
    if problem["answer"] != jumps:
        errors.append(f"jumps of {g} on a loop of {n} return to 0 after {jumps}, not {problem['answer']}")
    errors += _compare_wrong(problem, [("stopped_early", jumps - 1), ("skipped_identity", n), ("used_jump_size", g)])
    if problem["representation"] == "pictorial":
        if problem["visual"] != track(n, 0, g, 1, False, orbit=True):
            errors.append("a pictorial problem shows the hops with the stop hidden")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != track(n, 0, g, 1, True, orbit=True):
        errors.append("the rung 2 model should show the hops")
    ex = problem["hint_steps"][2]["example"]
    ep = ex["prompt_params"]
    if ex["answer_line_id"] != "z10.hint.example_cyclic" or ex["answer_params"] != {"g": ep["g"], "n": ep["n"], "j": ex["answer"]}:
        errors.append("the worked example should say how many jumps")
    else:
        ej, eat = 1, ride(ep["n"], 0, ep["g"], 1)
        while eat != 0:
            eat = ride(ep["n"], eat, ep["g"], 1)
            ej += 1
        if ej != ex["answer"]:
            errors.append(f"the worked example's jumps of {ep['g']} on a loop of {ep['n']} return after {ej}, not {ex['answer']}")
    return errors
