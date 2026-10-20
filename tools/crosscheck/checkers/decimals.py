"""Independent re-derivation of the DecimalGenerator and PercentGenerator problems (Zone 7 skills
decimal.* and percent.*).

Decimals are rebuilt with Python's decimal.Decimal from their digits ("2.75" from 2 ones and 75
hundredths) and fractions with fractions.Fraction; nothing passes through a float, and nothing is
ported from the GDScript. An exported decimal {mantissa, scale} is mantissa / 10**scale and must
have no trailing zero (its canonical form)."""
from __future__ import annotations

from decimal import Decimal
from fractions import Fraction

from .common import is_int

SYMBOLS = {-1: "<", 1: ">"}


def as_decimal(value: object) -> Decimal | None:
    if isinstance(value, dict) and set(value) == {"mantissa", "scale"} and is_int(value["mantissa"]) and is_int(value["scale"]) and value["scale"] >= 0:
        return Decimal(value["mantissa"]).scaleb(-value["scale"])
    return None


def canonical(value: dict) -> bool:
    """No trailing zero after the point (0.5, never 0.50)."""
    return value["scale"] == 0 or value["mantissa"] % 10 != 0


def from_parts(whole: int, part: int, places: int) -> Decimal:
    """whole ones and `part` tenths (places 1) or hundredths (places 2), from the digit string."""
    return Decimal(f"{whole}.{part:0{places}d}")


def by_name(problem: dict) -> dict[str, object]:
    return {entry["misconception"]: entry["value"] for entry in problem["distractors"]}


def _wrong_answers(problem: dict, wanted: dict[str, object], exact) -> list[str]:
    """Each named wrong answer equals the wanted value (in value, via `exact`), unless that value is the
    right answer; nothing else is offered and nothing offered equals the answer."""
    errors: list[str] = []
    got = by_name(problem)
    right = exact(problem["answer"])
    for name, value in wanted.items():
        if exact(value) == right:
            if name in got:
                errors.append(f"{name} ({value}) would be right but is offered as wrong")
            continue
        if name not in got:
            seen = [exact(v) for n, v in got.items()]
            if exact(value) not in seen:
                errors.append(f"missing the {name} wrong answer {value}")
        elif exact(got[name]) != exact(value):
            errors.append(f"{name} should be {exact(value)}, got {got[name]}")
    for name in got:
        if name not in wanted:
            errors.append(f"unexpected wrong answer {name}")
    for entry in problem["distractors"]:
        if exact(entry["value"]) == right:
            errors.append(f"wrong answer {entry['value']} equals the answer")
    return errors


def check(problem: dict) -> list[str]:
    mode = problem["params"].get("mode")
    if problem["skill_id"].startswith("percent."):
        return _percent(problem)
    checker = {"tenths": _tenths, "hundredths": _hundredths, "from_fraction": _from_fraction, "compare": _compare}.get(mode)
    if checker is None:
        return [f"unknown decimal mode {mode!r}"]
    errors = checker(problem)
    if isinstance(problem["answer"], dict) and not canonical(problem["answer"]):
        errors.append(f"the answer {problem['answer']} has a trailing zero")
    return errors


def _grid(picture: dict) -> tuple[int, list[tuple[int, int]]]:
    return picture.get("cells", 0), [(g["wholes"], g["lit"]) for g in picture.get("grids", [])]


def _tenths(problem: dict) -> list[str]:
    w, k = problem["prompt_params"]["w"], problem["prompt_params"]["k"]
    errors = []
    if not (0 <= w <= problem["params"].get("max_whole", 9) and 1 <= k <= 9):
        errors.append(f"{w} ones and {k} tenths is out of range")
    value = from_parts(w, k, 1)
    if as_decimal(problem["answer"]) != value:
        errors.append(f"{w} ones and {k} tenths is {value}, not {problem['answer']}")
    if problem["meta"].get("decimal_places") != 1:
        errors.append("tenths are written with one place")
    lines = {"concrete": "z7.tenths.prompt_crystal", "pictorial": "z7.tenths.prompt_grid", "abstract": "z7.tenths.prompt_words"}
    if problem["prompt_line_id"] != lines[problem["representation"]]:
        errors.append("the prompt does not match the representation")
    digits = w * 10 + k
    errors += _wrong_answers(problem, {"place_shift": {"mantissa": digits, "scale": 2}, "read_as_whole": {"mantissa": digits, "scale": 0}}, as_decimal)
    model = problem["hint_steps"][1]["visual"]
    if model.get("type") != "crystals" or model.get("wholes", 0) != w or [(c["den"], c["lit"]) for c in model["crystals"]] != [(10, k)]:
        errors.append("the rung 2 model should be w whole crystals and one ten-shard crystal with k lit")
    if problem["representation"] == "pictorial" and _grid(problem["visual"]) != (10, [(w, k)]):
        errors.append("the pictorial strip should show w wholes and k tenths")
    return errors + _example(problem, 1)


def _hundredths(problem: dict) -> list[str]:
    w, k = problem["prompt_params"]["w"], problem["prompt_params"]["k"]
    errors = []
    if not (0 <= w <= problem["params"].get("max_whole", 9) and 1 <= k <= 99):
        errors.append(f"{w} ones and {k} hundredths is out of range")
    value = from_parts(w, k, 2)
    if as_decimal(problem["answer"]) != value:
        errors.append(f"{w} ones and {k} hundredths is {value}, not {problem['answer']}")
    if problem["meta"].get("decimal_places") != 2:
        errors.append("hundredths are written with two places")
    digits = w * 100 + k
    wanted = {"place_shift": {"mantissa": digits, "scale": 1}, "read_as_whole": {"mantissa": digits, "scale": 0}}
    if k < 10:
        wanted["dropped_zero"] = {"mantissa": w * 10 + k, "scale": 1}
    errors += _wrong_answers(problem, wanted, as_decimal)
    if _grid(problem["hint_steps"][1]["visual"]) != (100, [(w, k)]):
        errors.append("the rung 2 model should be w whole grids and k lit cells")
    if problem["representation"] == "pictorial" and problem["visual"] != problem["hint_steps"][1]["visual"]:
        errors.append("a pictorial problem shows the grid from the start")
    return errors + _example(problem, 2)


def _example(problem: dict, places: int) -> list[str]:
    example = problem["hint_steps"][2]["example"]
    q = example["answer_params"]
    if as_decimal(q["d"]) != from_parts(q["w"], q["k"], places) or as_decimal(example["answer"]) != as_decimal(q["d"]):
        return ["the worked example's decimal is wrong"]
    return []


def _from_fraction(problem: dict) -> list[str]:
    num, den = problem["prompt_params"]["num"], problem["prompt_params"]["den"]
    errors = []
    if den not in problem["params"]["dens"] or not 1 <= num < den:
        errors.append(f"{num}/{den} is not allowed")
    value = Fraction(num, den)
    if 100 % value.denominator != 0:
        errors.append(f"{num}/{den} is not an exact decimal at two places")
    answer = as_decimal(problem["answer"])
    if answer is None or Fraction(answer) != value:
        errors.append(f"{num}/{den} is {Decimal(num) / Decimal(den)}, not {problem['answer']}")
    # Point one place off: the answer's digits with one place fewer after the point (0.75 as 7.5).
    shifted = {"mantissa": problem["answer"]["mantissa"], "scale": problem["answer"]["scale"] - 1}
    wanted = {"wrote_numerator_as_decimal": {"mantissa": num, "scale": 1 if num < 10 else 2}, "place_shift": shifted}
    errors += _wrong_answers(problem, wanted, as_decimal)
    hundredths = int(value * 100)
    if _grid(problem["hint_steps"][1]["visual"]) != (100, [(0, hundredths)]):
        errors.append("the rung 2 model should light the fraction's hundredths")
    example = problem["hint_steps"][2]["example"]
    q = example["answer_params"]
    if Fraction(q["num"], q["den"]) != Fraction(q["k"], 100) or Fraction(as_decimal(q["d"])) != Fraction(q["num"], q["den"]):
        errors.append("the worked example's conversion is wrong")
    return errors


def _compare(problem: dict) -> list[str]:
    a, b = as_decimal(problem["prompt_params"]["a"]), as_decimal(problem["prompt_params"]["b"])
    errors = []
    if a is None or b is None:
        return ["the prompt should give two decimals"]
    if a == b:
        errors.append(f"{a} and {b} are equal")
    for raw in (problem["prompt_params"]["a"], problem["prompt_params"]["b"]):
        if not canonical(raw) or not 1 <= raw["scale"] <= problem["params"].get("max_scale", 2):
            errors.append(f"{raw} is not a decimal of 1 to max_scale places")
    right = (a > b) - (a < b)
    if problem["answer"] != SYMBOLS.get(right):
        errors.append(f"{a} {SYMBOLS.get(right)} {b}, but the answer is {problem['answer']}")
    got = by_name(problem)
    wanted: dict[str, str] = {}
    scale_a, scale_b = problem["prompt_params"]["a"]["scale"], problem["prompt_params"]["b"]["scale"]
    if scale_a != scale_b:
        longer = (scale_a > scale_b) - (scale_a < scale_b)
        if longer != right:
            wanted["longer_is_bigger"] = SYMBOLS[longer]
    whole_a, whole_b = int(a), int(b)
    if whole_a != whole_b:
        part = (a - whole_a > b - whole_b) - (a - whole_a < b - whole_b)
        if part not in (0, right) and SYMBOLS[part] not in wanted.values():
            wanted["ignored_whole"] = SYMBOLS[part]
    if not wanted:
        wanted["reversed_symbol"] = SYMBOLS[-right]
    if got != wanted:
        errors.append(f"the wrong symbols should be {wanted}, got {got}")
    cells = [(int(x * 100) // 100, int(x * 100) % 100) for x in (a, b)]
    if _grid(problem["hint_steps"][1]["visual"]) != (100, cells):
        errors.append("the rung 2 model should show both decimals as hundredths grids")
    example = problem["hint_steps"][2]["example"]["answer_params"]
    ea, eb = as_decimal(example["a"]), as_decimal(example["b"])
    if example["symbol"] != SYMBOLS.get((ea > eb) - (ea < eb)):
        errors.append("the worked example's symbol is wrong")
    return errors


def _percent(problem: dict) -> list[str]:
    errors = []
    if problem["meta"].get("percent") is not True:
        errors.append("percent answers carry meta.percent")
    answer = problem["answer"]
    if not is_int(answer) or not 1 <= answer <= 99:
        return errors + [f"a percent answer is a whole number from 1 to 99, got {answer!r}"]
    shift = answer * 10 if answer < 10 else answer // 10  # one place off, as the mistake is described
    if problem["params"].get("mode") == "from_fraction":
        num, den = problem["prompt_params"]["num"], problem["prompt_params"]["den"]
        if den not in problem["params"]["dens"] or not 1 <= num < den:
            errors.append(f"{num}/{den} is not allowed")
        if Fraction(answer, 100) != Fraction(num, den):
            errors.append(f"{num}/{den} is {Fraction(num, den) * 100}%, not {answer}%")
        wanted = {"wrote_numerator_as_percent": num, "place_shift": shift}
        example = problem["hint_steps"][2]["example"]["answer_params"]
        if Fraction(example["p"], 100) != Fraction(example["num"], example["den"]):
            errors.append("the worked example's percent is wrong")
    else:
        lit = problem["visual"]["grids"][0]["lit"]
        if _grid(problem["visual"]) != (100, [(0, lit)]) or lit != answer:
            errors.append(f"{lit} of 100 cells lit is {lit}%, not {answer}%")
        wanted = {"counted_unlit": 100 - answer, "place_shift": shift}
        if problem["hint_steps"][2]["example"]["answer_params"]["p"] != problem["hint_steps"][2]["example"]["answer"]:
            errors.append("the worked example's percent is wrong")
    errors += _wrong_answers(problem, wanted, lambda v: v)
    if _grid(problem["hint_steps"][1]["visual"]) != (100, [(0, answer)]):
        errors.append("the rung 2 model should light the percent's cells")
    return errors
