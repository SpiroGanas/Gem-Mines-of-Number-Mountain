"""Independent re-derivation of the FractionGenerator problems (Zone 7 skills fraction.*).

Every answer is recomputed with Python's fractions.Fraction (exact rational arithmetic), never with a
float and never by porting the GDScript. A fraction answer is compared by value, and must also be
written in lowest terms with a positive denominator (the canonical form of the exported answer). Each
wrong answer is rebuilt from the plain-language description of the mistake it names."""
from __future__ import annotations

from fractions import Fraction

from .common import is_int

SYMBOLS = {-1: "<", 0: "=", 1: ">"}
TAP_SHARDS = 12  # the most shards a crystal the child taps may have


def as_fraction(value: object) -> Fraction | None:
    """The exact value of an exported fraction {num, den} or mixed number {whole, num, den}."""
    if isinstance(value, dict) and set(value) == {"num", "den"} and is_int(value["num"]) and is_int(value["den"]) and value["den"] != 0:
        return Fraction(value["num"], value["den"])
    if isinstance(value, dict) and set(value) == {"whole", "num", "den"} and value["den"] > 0:
        return value["whole"] + Fraction(value["num"], value["den"])
    return None


def lowest_terms(value: object) -> bool:
    """{num, den} with den > 0 and no common factor (Fraction normalizes, so compare against it)."""
    exact = as_fraction(value)
    return exact is not None and value["den"] > 0 and (value["num"], value["den"]) == (exact.numerator, exact.denominator)


def order(a: Fraction, b: Fraction) -> int:
    return (a > b) - (a < b)


def by_name(problem: dict) -> dict[str, object]:
    return {entry["misconception"]: entry["value"] for entry in problem["distractors"]}


def _check_wrong_answers(problem: dict, wanted: dict[str, object]) -> list[str]:
    """Each named wrong answer is the expected value (equal in value), unless that value is the right
    answer (then the generator must have dropped it)."""
    errors: list[str] = []
    right = as_fraction(problem["answer"])
    got = by_name(problem)
    for name, value in wanted.items():
        exact = as_fraction(value)
        is_right = (exact is not None and right is not None and exact == right) or value == problem["answer"]
        if is_right:
            if name in got:
                errors.append(f"{name} would be a right answer ({value}) but is offered as wrong")
            continue
        if name not in got:
            errors.append(f"missing the {name} wrong answer {value}")
        elif exact is not None and as_fraction(got[name]) != exact:
            errors.append(f"{name} should be {exact}, got {got[name]}")
        elif exact is None and got[name] != value:
            errors.append(f"{name} should be {value!r}, got {got[name]!r}")
    for name in got:
        if name not in wanted:
            errors.append(f"unexpected wrong answer {name}")
    for entry in problem["distractors"]:
        value = as_fraction(entry["value"])
        if value is not None and right is not None and value == right:
            errors.append(f"wrong answer {entry['value']} equals the answer {right}")
    return errors


def _miscount(problem: dict, num: int, den: int, low: int = 0) -> tuple[list[str], dict | None]:
    """The off_by_one_numerator wrong answer: num one more or one fewer over den (the generator picks
    which). It may be missing only when a miscount would repeat another wrong answer or the answer."""
    got = by_name(problem).get("off_by_one_numerator")
    if got is not None:
        if got["den"] != den or abs(got["num"] - num) != 1 or got["num"] < low:
            return [f"off_by_one_numerator should miscount {num}/{den} by one, got {got}"], None
        return [], got
    taken = [as_fraction(problem["answer"])] + [as_fraction(e["value"]) for e in problem["distractors"]]
    if not any(Fraction(candidate, den) in taken for candidate in (num - 1, num + 1) if candidate >= low):
        return [f"off_by_one_numerator is missing though neither miscount of {num}/{den} repeats another answer"], None
    return [], None


def _crystals(picture: dict) -> list[tuple[int, int, int]]:
    return [(c["den"], c["lit"], c.get("second", 0)) for c in picture.get("crystals", [])]


def check(problem: dict) -> list[str]:
    mode = problem["params"].get("mode")
    checker = {
        "unit": _unit, "part": _part, "number_line": _number_line, "equivalent": _equivalent,
        "compare": _compare, "add": _add, "mixed": _mixed,
    }.get(mode)
    if checker is None:
        return [f"unknown fraction mode {mode!r}"]
    errors = checker(problem)
    answer = problem["answer"]
    if isinstance(answer, dict) and set(answer) == {"num", "den"} and not lowest_terms(answer):
        errors.append(f"the answer {answer} is not in lowest terms with a positive denominator")
    return errors


def _max_den(problem: dict, default: int) -> int:
    return problem["params"].get("max_den", default)


def _unit(problem: dict) -> list[str]:
    den = problem["prompt_params"]["den"]
    errors = []
    if problem["prompt_line_id"] != "z7.unit.prompt" or not 2 <= den <= _max_den(problem, 12):
        errors.append(f"a unit fraction of {den} shards is out of range")
    if as_fraction(problem["answer"]) != Fraction(1, den):
        errors.append(f"one of {den} shards is 1/{den}, not {problem['answer']}")
    errors += _check_wrong_answers(problem, {"inverted": {"num": den, "den": 1}, "counted_shaded_as_denominator": {"num": 1, "den": den - 1}})
    if problem["representation"] != "abstract" and _crystals(problem["visual"]) != [(den, 1, 0)]:
        errors.append("the picture should be one crystal of den shards with one lit")
    if _crystals(problem["hint_steps"][1]["visual"]) != [(den, 1, 0)]:
        errors.append("the rung 2 model should be the crystal with one shard lit")
    example = problem["hint_steps"][2]["example"]
    if example["answer_line_id"] != "z7.hint.example_unit" or as_fraction(example["answer"]) != Fraction(1, example["answer_params"]["den"]):
        errors.append("the worked example does not show its own unit fraction")
    return errors


def _part(problem: dict) -> list[str]:
    shown = problem["meta"]["shown"]
    num, den = shown["num"], shown["den"]
    errors = []
    limit = TAP_SHARDS if problem["representation"] == "concrete" else _max_den(problem, 12)
    if not (1 <= num < den <= min(limit, _max_den(problem, 12))):
        errors.append(f"{num}/{den} is out of range")
    if as_fraction(problem["answer"]) != Fraction(num, den):
        errors.append(f"{num} of {den} shards is {Fraction(num, den)}, not {problem['answer']}")
    rep = problem["representation"]
    expected_line = {"concrete": "z7.part.prompt_light", "pictorial": "z7.part.prompt_read", "abstract": "z7.part.prompt_words"}[rep]
    if problem["prompt_line_id"] != expected_line:
        errors.append(f"a {rep} problem should use {expected_line}")
    if rep == "concrete" and problem["meta"].get("crystal", {}).get("den") != den:
        errors.append("the crystal to light should have den shards")
    if rep == "pictorial" and _crystals(problem["visual"]) != [(den, num, 0)]:
        errors.append("the picture should be the crystal with num shards lit")
    problems, miscount = _miscount(problem, num, den)
    errors += problems
    wanted = {"unshaded_count": {"num": den - num, "den": den}, "inverted": {"num": den, "den": num}}
    if miscount is not None:
        wanted["off_by_one_numerator"] = miscount
    errors += _check_wrong_answers(problem, wanted)
    if _crystals(problem["hint_steps"][1]["visual"]) != [(den, num, 0)]:
        errors.append("the rung 2 model should be the crystal with num shards lit")
    return errors + _example_part(problem)


def _example_part(problem: dict) -> list[str]:
    example = problem["hint_steps"][2]["example"]
    params = example["answer_params"]
    if example["answer_line_id"] != "z7.hint.example_part" or as_fraction(example["answer"]) != Fraction(params["num"], params["den"]):
        return ["the worked example does not show its own fraction"]
    return []


def _number_line(problem: dict) -> list[str]:
    line = problem["visual"]
    den = line["den"]
    marker = line["marker"]
    errors = []
    if problem["prompt_line_id"] != "z7.line.prompt" or problem["prompt_params"] != {"den": den}:
        errors.append("the prompt should be z7.line.prompt with {den}")
    if not 2 <= den <= _max_den(problem, 8) or line["wholes"] != 1 or line["ticks"] != den + 1:
        errors.append(f"a 0-to-1 line cut into {den} parts has {den + 1} ticks, got {line['ticks']}")
    if marker["den"] != den or not 1 <= marker["num"] < den:
        errors.append(f"the gem {marker} is not on a tick inside the line")
    if as_fraction(problem["answer"]) != Fraction(marker["num"], den):
        errors.append(f"the gem marks {Fraction(marker['num'], den)}, not {problem['answer']}")
    errors += _check_wrong_answers(problem, {"counted_ticks_not_gaps": {"num": marker["num"], "den": den + 1}, "inverted": {"num": den, "den": marker["num"]}})
    if problem["hint_steps"][1]["visual"] != line:
        errors.append("the rung 2 model should be the line itself")
    return errors + _example_part(problem)


def _equivalent(problem: dict) -> list[str]:
    e = problem["meta"]["equiv"]
    a, b, k = e["a"], e["b"], e["k"]
    c, m = b * k, a * k
    errors = []
    if not (1 <= a < b and k >= 2 and Fraction(a, b).denominator == b and c <= _max_den(problem, 24)):
        errors.append(f"{a}/{b} times {k} is out of range or not in lowest terms")
    line = problem["prompt_line_id"]
    if line == "z7.equiv.prompt_match":
        if problem["representation"] != "concrete" or problem["meta"]["crystal"] != {"den": c, "match": {"num": a, "den": b}} or c > TAP_SHARDS:
            errors.append("the crystal to light should have b * k shards (12 at most) and show a/b to match")
        if as_fraction(problem["answer"]) != Fraction(a, b):
            errors.append(f"matching {a}/{b} means the answer {Fraction(a, b)}")
        errors += _check_wrong_answers(problem, {"added_to_both": {"num": a + c - b, "den": c}, "copied_numerator": {"num": a, "den": c}})
    elif line == "z7.equiv.prompt_num":
        if problem["prompt_params"] != {"a": a, "b": b, "c": c} or problem["answer"] != m:
            errors.append(f"{a}/{b} = ?/{c} has the top {m}")
        errors += _check_wrong_answers(problem, {"added_to_both": a + c - b, "copied_numerator": a})
    elif line == "z7.equiv.prompt_den":
        if problem["prompt_params"] != {"a": a, "b": b, "m": m} or problem["answer"] != c:
            errors.append(f"{a}/{b} = {m}/? has the bottom {c}")
        errors += _check_wrong_answers(problem, {"added_to_both": b + m - a, "scaled_numerator_only": b})
    else:
        errors.append(f"unknown equivalent prompt {line}")
    if line != "z7.equiv.prompt_match" and Fraction(a, b) != Fraction(m, c):
        errors.append("the two fractions are not equivalent")
    if _crystals(problem["hint_steps"][1]["visual"]) != [(b, a, 0), (c, m, 0)]:
        errors.append("the rung 2 model should show a/b beside m/c")
    example = problem["hint_steps"][2]["example"]
    p = example["answer_params"]
    if example["answer_line_id"] != "z7.hint.example_equiv" or Fraction(p["a"], p["b"]) != Fraction(p["m"], p["c"]) or p["m"] != p["a"] * p["k"] or p["c"] != p["b"] * p["k"]:
        errors.append("the worked example is not an equivalent pair")
    return errors


def _compare(problem: dict) -> list[str]:
    p = problem["prompt_params"]
    a, b, c, d = p["a"], p["b"], p["c"], p["d"]
    like = problem["params"].get("like_den", True)
    left, right = Fraction(a, b), Fraction(c, d)
    errors = []
    if problem["prompt_line_id"] != "z7.compare.prompt":
        errors.append("the prompt should be z7.compare.prompt")
    if left == right and not problem["params"].get("allow_equal", False):
        errors.append(f"{a}/{b} and {c}/{d} are equal")
    if (b == d) != like or not (1 <= a < b and 1 <= c < d and max(b, d) <= _max_den(problem, 12)):
        errors.append(f"{a}/{b} and {c}/{d} do not fit the skill")
    wanted_symbol = SYMBOLS[order(left, right)]
    if problem["answer"] != wanted_symbol:
        errors.append(f"{a}/{b} {wanted_symbol} {c}/{d}, but the answer is {problem['answer']}")
    if like:
        wanted = {"compared_denominators": "=", "reversed_symbol": SYMBOLS[-order(left, right)]}
        errors += _check_wrong_answers(problem, wanted)
    else:
        got = by_name(problem)
        top_symbol = SYMBOLS[(a > c) - (a < c)]
        bottom_symbol = SYMBOLS[(b > d) - (b < d)]
        wanted = {}
        if top_symbol != wanted_symbol:
            wanted["compared_numerators_only"] = top_symbol
        if bottom_symbol != wanted_symbol and bottom_symbol not in wanted.values():  # one button per symbol
            wanted["bigger_denominator_bigger"] = bottom_symbol
        if not wanted:  # neither mistake changes the answer: the generator offers the other symbol
            wanted["compared_numerators_only"] = SYMBOLS[-order(left, right)]
        if set(got) != set(wanted) or any(got[name] != wanted[name] for name in got):
            errors.append(f"the wrong symbols should be {wanted}, got {got}")
    model = problem["hint_steps"][1]["visual"]
    if _crystals(model) != [(b, a, 0), (d, c, 0)] or model.get("shape") != "bar":
        errors.append("the rung 2 model should be two bars, a/b and c/d")
    if problem["representation"] == "pictorial" and problem["visual"] != model:
        errors.append("a pictorial problem shows the bars from the start")
    example = problem["hint_steps"][2]["example"]
    q = example["answer_params"]
    if q.get("symbol") != SYMBOLS[order(Fraction(q["a"], q["b"]), Fraction(q["c"], q["d"]))]:
        errors.append("the worked example's symbol is wrong")
    return errors


def _add(problem: dict) -> list[str]:
    p = problem["prompt_params"]
    a, b, c, d = p["a"], p["b"], p["c"], p["d"]
    like = problem["params"].get("like_den", True)
    total = Fraction(a, b) + Fraction(c, d)
    errors = []
    if problem["prompt_line_id"] != "z7.add.prompt":
        errors.append("the prompt should be z7.add.prompt")
    if (b == d) != like or not (1 <= a < b and 1 <= c < d):
        errors.append(f"{a}/{b} + {c}/{d} does not fit the skill")
    if not problem["params"].get("allow_improper", False) and total >= 1:
        errors.append(f"{a}/{b} + {c}/{d} = {total} is not below one whole")
    if as_fraction(problem["answer"]) != total:
        errors.append(f"{a}/{b} + {c}/{d} = {total}, not {problem['answer']}")
    common = b * d // _gcd(b, d)
    if not like and common > 2 * _max_den(problem, 12):
        errors.append(f"the common denominator {common} is too big to draw")
    wanted: dict[str, object] = {"added_denominators": {"num": a + c, "den": b + d}}
    got = by_name(problem)
    if like:
        problems, miscount = _miscount(problem, a + c, b)
        errors += problems
        if miscount is not None:
            wanted["off_by_one_numerator"] = miscount
        if _crystals(problem["hint_steps"][1]["visual"]) != [(b, a, c)]:
            errors.append("the rung 2 model should be one crystal with a and c shards lit")
    else:
        wanted["added_numerators_only"] = {"num": a + c, "den": max(b, d)}
        if _crystals(problem["hint_steps"][1]["visual"]) != [(common, a * common // b, 0), (common, c * common // d, 0)]:
            errors.append("the rung 2 model should show both fractions cut into same-size shards")
    errors += _check_wrong_answers(problem, wanted)
    example = problem["hint_steps"][2]["example"]
    q = example["answer_params"]
    if as_fraction(q["sum"]) != Fraction(q["a"], q["b"]) + Fraction(q["c"], q["d"]) or as_fraction(example["answer"]) != as_fraction(q["sum"]):
        errors.append("the worked example's sum is wrong")
    return errors


def _gcd(x: int, y: int) -> int:
    while y:
        x, y = y, x % y
    return x


def _mixed(problem: dict) -> list[str]:
    m = problem["meta"]["mixed"]
    whole, num, den = m["whole"], m["num"], m["den"]
    value = whole + Fraction(num, den)
    errors = []
    if not (1 <= whole <= problem["params"].get("max_whole", 5) and 1 <= num < den <= _max_den(problem, 8) and Fraction(num, den).denominator == den):
        errors.append(f"{whole} {num}/{den} is out of range")
    line = problem["prompt_line_id"]
    if line == "z7.mixed.prompt_to_improper":
        if problem["prompt_params"] != {"w": whole, "num": num, "den": den}:
            errors.append("the prompt should give the mixed number")
        if as_fraction(problem["answer"]) != value or set(problem["answer"]) != {"num", "den"}:
            errors.append(f"{whole} {num}/{den} is {value}, not {problem['answer']}")
        errors += _check_wrong_answers(problem, {"dropped_whole": {"num": num, "den": den}, "added_whole_to_numerator": {"num": whole + num, "den": den}})
    elif line == "z7.mixed.prompt_to_mixed":
        if problem["prompt_params"] != {"top": value.numerator * (den // value.denominator), "den": den}:
            errors.append("the prompt should give the improper fraction over den")
        if problem["answer"] != {"whole": whole, "num": num, "den": den}:
            errors.append(f"{whole * den + num}/{den} is {whole} {num}/{den}, not {problem['answer']}")
        wanted: dict[str, object] = {"dropped_whole": {"whole": 0, "num": num, "den": den}}
        if num != whole and whole < den:
            wanted["swapped_quotient_remainder"] = {"whole": num, "num": whole, "den": den}
        if whole + num < den:
            wanted["added_whole_to_numerator"] = {"whole": whole, "num": whole + num, "den": den}
        errors += _check_wrong_answers(problem, wanted)
    else:
        errors.append(f"unknown mixed prompt {line}")
    model = problem["hint_steps"][1]["visual"]
    if _crystals(model) != [(den, num, 0)] or model.get("wholes") != whole:
        errors.append("the rung 2 model should be the wholes and the leftover crystal")
    example = problem["hint_steps"][2]["example"]
    q = example["answer_params"]
    if q["parts"] != q["w"] * q["den"] or q["top"] != q["parts"] + q["num"]:
        errors.append("the worked example's arithmetic is wrong")
    return errors
