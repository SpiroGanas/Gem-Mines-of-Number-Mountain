"""Independent re-derivation of the SciNotationGenerator problems (Zone 8 sci.notation.*).

Values are exact: decimal.Decimal built from the integer mantissa with an explicit scale (Decimal(34)
.scaleb(-1) is 3.4), multiplied by an integer power of 10 under a context with enough digits, and
compared as integers. Never a float. A written answer must be normalized (1 <= m < 10, one place after
the point, not 0); 34 × 10⁴ is the named mistake, not an equal answer."""
from __future__ import annotations

from decimal import Decimal, localcontext

from .common import distractor_pairs, filtered, is_int, is_normalized_sci


def value(mantissa: int, scale: int, exp: int) -> Decimal:
    """mantissa / 10^scale × 10^exp, exactly."""
    with localcontext() as context:
        context.prec = 50
        return Decimal(mantissa).scaleb(-scale) * (Decimal(10) ** exp)


def as_int(number: Decimal) -> int | None:
    return int(number) if number == number.to_integral_value() else None


def check(problem: dict) -> list[str]:
    mode = problem["params"].get("mode")
    if mode == "read":
        return _read(problem)
    if mode == "write":
        return _write(problem)
    return [f"unknown scientific-notation mode {mode!r}"]


def _expect(problem: dict, candidates: list[tuple[str, object]]) -> list[str]:
    wanted = filtered(problem["answer"], candidates)
    got = distractor_pairs(problem)
    return [] if got == wanted else [f"the wrong answers should be {wanted}, got {got}"]


def _read(problem: dict) -> list[str]:
    card = problem["visual"]
    errors = []
    if card.get("type") != "notation" or card.get("form") != "sci":
        return ["a read problem shows a scientific-notation card"]
    m, scale, e = card["mantissa"], card["scale"], card["exp"]
    low, high = problem["params"]["exp_range"]
    if not (is_normalized_sci({"mantissa": m, "scale": scale, "exp": e}) and scale == 1 and m % 10 != 0 and max(low, 2) <= e <= high):
        errors.append(f"{m}/10 × 10^{e} is not a one-place normalized card with an exponent in range")
    expected = as_int(value(m, scale, e))
    if not is_int(problem["answer"]) or problem["answer"] != expected:
        errors.append(f"{Decimal(m).scaleb(-scale)} × 10^{e} is {expected}, not {problem['answer']}")
    if problem["meta"].get("pad_digits") != max(3, len(str(as_int(value(99, 1, high))))):
        errors.append("the pad should hold the digits of the largest number the skill asks for")
    errors += _expect(problem, [
        ("off_by_one_exponent", as_int(value(m, scale, e - 1))),
        ("counted_digits_not_shift", int(str(m) + "0" * e)),
    ])
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if as_int(value(q["m"]["mantissa"], q["m"]["scale"], q["e"])) != q["n"]:
        errors.append("the worked example's number is wrong")
    return errors


def _write(problem: dict) -> list[str]:
    n = problem["prompt_params"]["n"]
    answer = problem["answer"]
    errors = []
    if not is_normalized_sci(answer) or answer["scale"] != 1 or answer["mantissa"] % 10 == 0:
        return [f"{answer!r} is not normalized with one place after the point"]
    m, e = answer["mantissa"], answer["exp"]
    if value(m, 1, e) != Decimal(n):
        errors.append(f"{m}/10 × 10^{e} is not {n}")
    if not (1 <= e and n <= problem["params"]["max_value"]):
        errors.append(f"{n} is above the maximum or the exponent is below 1")
    if problem["meta"].get("sci_pad", {}).get("max_exp", -1) < e:
        errors.append("the pad cannot hold the exponent")
    candidates = [
        ("mantissa_not_normalized", {"mantissa": m, "scale": 0, "exp": e - 1}),
        ("off_by_one_exponent", {"mantissa": m, "scale": 1, "exp": e + 1}),
    ]
    if e > 1:
        candidates.append(("off_by_one_exponent", {"mantissa": m, "scale": 1, "exp": e - 1}))
    errors += _expect(problem, candidates)
    wrong = dict(distractor_pairs(problem)).get("mantissa_not_normalized")
    if wrong is None or value(wrong["mantissa"], wrong["scale"], wrong["exp"]) != Decimal(n):
        errors.append("mantissa_not_normalized should be equal in value but not normalized")
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if value(q["m"]["mantissa"], q["m"]["scale"], q["e"]) != Decimal(q["n"]):
        errors.append("the worked example's notation is wrong")
    return errors
