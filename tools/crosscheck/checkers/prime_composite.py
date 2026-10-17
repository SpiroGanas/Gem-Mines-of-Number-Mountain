"""Independent re-derivation of the PrimeCompositeGenerator problems (skills prime.*).

A prime is a number with exactly two divisors (so 1 is not one), found by trying every number. The
mistake a wrong yes/no stands for is worked out from the number alone: 2 for two_is_not_prime, a
square for square_is_prime, an odd composite for odd_means_prime, 1 for one_is_prime."""
from __future__ import annotations

from .common import distractors_by_name
from .numbers import array_picture, divisors, hops, is_prime, is_square, number_line, pair_count, smallest_divisor_above_one

MAX_SIDE = 10
SET_SIZE = 6
LABELS = {"true": "ui.common.yes", "false": "ui.common.no"}


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {"single": _single, "set": _set, "pairs": _pairs}.get(mode)
    if handler is None:
        return [f"unknown prime mode {mode!r}"]
    return handler(problem)


def expected_mistake(n: int) -> str:
    """The mistake behind a wrong answer about n."""
    if n == 1:
        return "one_is_prime"
    if is_prime(n):
        return "two_is_not_prime" if n == 2 else "no_check_made"
    if is_square(n):
        return "square_is_prime"
    return "odd_means_prime" if n % 2 == 1 else "no_check_made"


def break_model(n: int) -> dict:
    """The rung 2 picture: a prime's one rectangle, or a composite's smallest-factor rectangle."""
    if n < 2:
        return array_picture(1, 1)
    if is_prime(n):
        return array_picture(1, n) if n <= MAX_SIDE else hops(1, n)
    p = smallest_divisor_above_one(n)
    q = n // p
    return array_picture(p, q, True) if p <= MAX_SIDE and q <= MAX_SIDE else hops(p, q)


def example_line_ok(example: dict, yes_line: str, no_line: str) -> bool:
    n = example["prompt_params"]["n"]
    if n == 1:
        return example["answer"] is False and example["answer_line_id"] == "z4.prime.one_not_prime" and example["answer_params"] == {}
    if example["answer"] is not is_prime(n):
        return False
    if is_prime(n):
        return example["answer_line_id"] == yes_line and example["answer_params"] == {"n": n}
    p = smallest_divisor_above_one(n)
    return example["answer_line_id"] == no_line and example["answer_params"] == {"a": p, "b": n // p, "n": n}


def _check_yes_no(problem: dict, n: int) -> list[str]:
    errors: list[str] = []
    if problem["answer"] is not is_prime(n):
        errors.append(f"{n} {'is' if is_prime(n) else 'is not'} a prime, but the answer is {problem['answer']!r}")
    if problem["meta"].get("label_lines") != LABELS:
        errors.append("the buttons should read Yes and No")
    wanted = {"value": not is_prime(n), "misconception": expected_mistake(n)}
    if problem["distractors"] != [wanted]:
        errors.append(f"the one wrong answer for {n} should be {wanted}, got {problem['distractors']!r}")
    if problem["hint_steps"][1]["visual"] != break_model(n):
        errors.append(f"the rung 2 model for {n} should be {break_model(n)!r}")
    if problem["visual"]:
        errors.append("an abstract question has no picture")
    return errors


# --- single ----------------------------------------------------------------------------------


def _single(problem: dict) -> list[str]:
    params = problem["params"]
    if problem["prompt_line_id"] != "z4.prime.prompt_single" or set(problem["prompt_params"]) != {"n"}:
        return ["the prompt should be z4.prime.prompt_single with {n}"]
    n = problem["prompt_params"]["n"]
    errors = _check_yes_no(problem, n)
    if not max(params["min"], 2) <= n <= params["max"]:
        errors.append(f"n = {n} is outside {max(params['min'], 2)}..{params['max']} (1 is never a candidate here)")
    example = problem["hint_steps"][2]["example"]
    if example["prompt_params"]["n"] == 1 or not example_line_ok(example, "z4.hint.example_prime_yes", "z4.hint.example_prime_no"):
        errors.append("the worked example does not explain its own number")
    return errors


# --- set -------------------------------------------------------------------------------------


def _set(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    prompt = problem["prompt_params"]
    if problem["prompt_line_id"] != "z4.prime.prompt_set" or "k" not in prompt:
        return ["the prompt should be z4.prime.prompt_set with {k}"]
    board = problem["meta"].get("tile_board", {})
    rocks = board.get("tiles", [])
    primes = sorted(rock for rock in rocks if is_prime(rock))
    k = len(primes)
    if len(rocks) != SET_SIZE or len(set(rocks)) != SET_SIZE:
        errors.append(f"there should be {SET_SIZE} different rocks, got {rocks}")
    if not all(max(params["min"], 2) <= rock <= params["max"] for rock in rocks):
        errors.append(f"rocks {rocks} are outside {max(params['min'], 2)}..{params['max']}")
    if k not in (2, 3) or prompt["k"] != k or board.get("slots") != k or board.get("ordered") is not False:
        errors.append(f"the {k} primes among {rocks} should be 2 or 3, named in the prompt, with {k} unordered slots")
    if {key: value for key, value in prompt.items() if key != "k"} != {f"r{i + 1}": value for i, value in enumerate(sorted(rocks))}:
        errors.append("prompt params r1..r6 should be the rocks, smallest first")
    if problem["answer"] != primes:
        errors.append(f"the primes among {rocks} are {primes}, not {problem['answer']}")
    if problem["visual"]:
        errors.append("an abstract question has no picture")
    if not any(not is_prime(rock) and (rock % 2 == 1 or is_square(rock)) for rock in rocks):
        errors.append("a set needs an odd composite or a square composite to trip over")
    if not problem["distractors"]:
        errors.append("a set needs at least one wrong board")
    wrong = distractors_by_name(problem)
    for name in wrong:
        if name not in ("odd_means_prime", "square_is_prime", "two_is_not_prime"):
            errors.append(f"unexpected misconception {name}")
    for name, boards in wrong.items():
        for each in boards:
            wrongly_in = [value for value in each if not is_prime(value)]
            left_out = [value for value in primes if value not in each]
            where = f"{name} {each}"
            if each != sorted(each) or len(each) != k or not set(each) <= set(rocks) or len(set(each)) != k:
                errors.append(f"{where} should be {k} different, sorted rocks from the board")
            if len(wrongly_in) != 1 or len(left_out) != 1:
                errors.append(f"{where} should swap exactly one prime for one composite")
                continue
            if name == "odd_means_prime" and (wrongly_in[0] % 2 != 1 or left_out[0] == 2):
                errors.append(f"{where} should put an odd composite in place of an odd prime")
            if name == "square_is_prime" and (not is_square(wrongly_in[0]) or left_out[0] == 2):
                errors.append(f"{where} should put a square composite in place of an odd prime")
            if name == "two_is_not_prime" and left_out[0] != 2:
                errors.append(f"{where} should leave out the prime 2")
    if 2 not in primes and "two_is_not_prime" in wrong:
        errors.append("two_is_not_prime needs the rock 2")
    composites = [rock for rock in rocks if not is_prime(rock)]
    if problem["hint_steps"][1]["visual"] not in [break_model(rock) for rock in composites]:
        errors.append("the rung 2 model should break one of the composite rocks")
    example = problem["hint_steps"][2]["example"]
    if not example["answer"] or example["answer_line_id"] != "z4.hint.example_prime_yes" \
            or example["answer_params"] != {"n": example["answer"][0]} or not is_prime(example["answer"][0]):
        errors.append("the worked example should say its first prime will not break")
    return errors


# --- pairs -----------------------------------------------------------------------------------


def _pairs(problem: dict) -> list[str]:
    params = problem["params"]
    line = problem["prompt_line_id"]
    if line not in ("z4.prime.prompt_pairs_count", "z4.prime.prompt_pairs_prime") or set(problem["prompt_params"]) != {"n"}:
        return ["the prompt should be z4.prime.prompt_pairs_count or z4.prime.prompt_pairs_prime with {n}"]
    n = problem["prompt_params"]["n"]
    errors: list[str] = []
    if line == "z4.prime.prompt_pairs_count":
        errors += _count(problem, n)
        if not 2 <= n <= params["max"]:
            errors.append(f"n = {n} is outside 2..{params['max']}")
    else:
        errors += _check_yes_no(problem, n)
        if not 1 <= n <= params["max"]:
            errors.append(f"n = {n} is outside 1..{params['max']}")
    example = problem["hint_steps"][2]["example"]
    e_n = example["prompt_params"]["n"]
    if example["prompt_line_id"] == "z4.prime.prompt_pairs_count":
        if example["answer"] != pair_count(e_n) or example["answer_line_id"] != "z4.hint.example_pairs" \
                or example["answer_params"] != {"n": e_n, "c": pair_count(e_n)}:
            errors.append("the worked example does not state its own pair count")
    elif not example_line_ok(example, "z4.hint.example_isprime_yes", "z4.hint.example_isprime_no"):
        errors.append("the worked example does not explain its own number")
    return errors


def _count(problem: dict, n: int) -> list[str]:
    errors: list[str] = []
    pairs = pair_count(n)
    if problem["answer"] != pairs:
        errors.append(f"{n} has {pairs} factor pairs, not {problem['answer']}")
    wrong = distractors_by_name(problem)
    expected = {
        "counted_factors_not_pairs": [len(divisors(n))],
        "missing_one_and_n": [pairs - 1],
        "off_by_one": [pairs + 1],
    }
    for name, values in wrong.items():
        if name not in expected or any(value not in expected[name] for value in values):
            errors.append(f"{name} {values} is not one of {expected.get(name)}")
    shown = [entry["value"] for entry in problem["distractors"]]
    for name, values in expected.items():
        if values[0] != pairs and values[0] >= 0 and values[0] not in shown:
            errors.append(f"{name} should offer {values[0]}")
    if problem["hint_steps"][1]["visual"] != break_model(n):
        errors.append(f"the rung 2 model for {n} should be {break_model(n)!r}")
    if problem["visual"]:
        errors.append("an abstract question has no picture")
    return errors
