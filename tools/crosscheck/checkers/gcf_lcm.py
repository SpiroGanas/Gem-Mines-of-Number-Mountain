"""Independent re-derivation of the GcfGenerator and LcmGenerator problems (Zone 6, skills gcf.* and lcm.*).

The greatest common factor and least common multiple come from Python's math.gcd and math.lcm; factor
lists from trying every divisor; prime recipes from numbers.prime_recipe. Every wrong answer is judged
against the mistake it names. Nothing here is ported from scripts/generators/gcf.gd or lcm.gd.
"""
from __future__ import annotations

import math
from collections import Counter

from .common import distractors_by_name
from .numbers import divisors, is_prime, prime_recipe

YES_NO = {"true": "ui.common.yes", "false": "ui.common.no"}
MAX_TILES = 8
MAX_ANSWER = 999


# --- Pictures (written from the visual's definition in scripts/core/problem.gd) ------------------


def lists(kind: str, rows: list[dict], marked: list[int]) -> dict:
    return {"type": "lists", "kind": kind, "rows": rows, "marked": marked}


def factor_lists(a: int, b: int, marked: list[int] | None = None) -> dict:
    return lists("factors", [{"n": a, "items": divisors(a)}, {"n": b, "items": divisors(b)}], list(marked or []))


def multiple_lists(a: int, b: int, upto: int, marked: list[int] | None = None) -> dict:
    rows = [{"n": n, "items": list(range(n, upto + 1, n))} for n in (a, b)]
    return lists("multiples", rows, list(marked or []))


def recipe_lists(a: int, b: int, lit: str) -> dict:
    """Both prime recipes. "shared": in each row the first min(count here, count there) copies of each
    prime are lit. "most": every copy of a prime is lit in the row holding it most often (the first row
    on a tie)."""
    first, second = prime_recipe(a), prime_recipe(b)
    count_first, count_second = Counter(first), Counter(second)

    def shared_positions(row: list[int], other: Counter) -> list[int]:
        seen: Counter = Counter()
        positions = []
        for index, prime in enumerate(row):
            seen[prime] += 1
            if seen[prime] <= other[prime]:
                positions.append(index)
        return positions

    if lit == "shared":
        lit_first, lit_second = shared_positions(first, count_second), shared_positions(second, count_first)
    else:
        lit_first = [i for i, p in enumerate(first) if count_first[p] >= count_second[p]]
        lit_second = [i for i, p in enumerate(second) if count_second[p] > count_first[p]]
    return lists("recipe", [{"n": a, "items": first, "lit": lit_first}, {"n": b, "items": second, "lit": lit_second}], [])


def gears(teeth: list[int]) -> dict:
    return {"type": "gears", "teeth": teeth}


def common_factors(a: int, b: int) -> list[int]:
    return [d for d in divisors(a) if b % d == 0]


def largest_prime(n: int) -> int:
    return max(p for p in divisors(n) if is_prime(p))


def _pair(problem: dict, line: str, keys: tuple[str, ...] = ("a", "b")) -> tuple[int, int, list[str]]:
    params = problem["prompt_params"]
    if problem["prompt_line_id"] != line or set(params) != set(keys):
        return 0, 0, [f"the prompt should be {line} with {sorted(keys)}"]
    a, b = params["a"], params["b"]
    errors = []
    low, high = problem["params"].get("min", 2), problem["params"]["max_n"]
    if not low <= a < b <= high:
        errors.append(f"{a} and {b} should satisfy {low} <= a < b <= {high}")
    return a, b, errors


def _expect(errors: list[str], wrong: dict[str, list], name: str, value, present: bool) -> None:
    """A named wrong answer is there with exactly `value` when `present`, and absent otherwise."""
    got = wrong.get(name)
    if present and got != [value]:
        errors.append(f"{name} should be {value!r}, got {got!r}")
    elif not present and got is not None:
        errors.append(f"{name} should not be offered here (it would be {value!r}), got {got!r}")


def _only(errors: list[str], wrong: dict[str, list], names: set[str]) -> None:
    extra = set(wrong) - names
    if extra:
        errors.append(f"unexpected mistakes {sorted(extra)}")


def _example(problem: dict, line: str, make_params) -> list[str]:
    example = problem["hint_steps"][2]["example"]
    params = example["prompt_params"]
    if example["answer_line_id"] != line or example["answer_params"] != make_params(params["a"], params["b"]):
        return [f"the worked example should be {line} with {make_params(params['a'], params['b'])}"]
    return []


def _model(problem: dict, wanted: dict) -> list[str]:
    if problem["hint_steps"][1]["visual"] != wanted:
        return [f"the rung 2 model should be {wanted}, got {problem['hint_steps'][1]['visual']}"]
    return []


# --- GcfGenerator --------------------------------------------------------------------------------


def check_gcf(problem: dict) -> list[str]:
    handler = {"common_factors": _common_factors, "gcf": _gcf, "factorization": _gcf_recipes, "coprime": _coprime}.get(problem["params"].get("mode"))
    if handler is None:
        return [f"unknown GCF mode {problem['params'].get('mode')!r}"]
    return handler(problem)


def _common_factors(problem: dict) -> list[str]:
    a, b, errors = _pair(problem, "z6.gcf.prompt_common")
    if not a:
        return errors
    shared = common_factors(a, b)
    g = math.gcd(a, b)
    if g == 1:
        errors.append(f"{a} and {b} should share a factor above 1")
    if problem["answer"] != shared:
        errors.append(f"the common factors of {a} and {b} are {shared}, not {problem['answer']}")
    wrong = distractors_by_name(problem)
    _only(errors, wrong, {"included_non_factor", "missed_largest", "factors_of_one_number"})
    for value in wrong.get("included_non_factor", []):
        strangers = [v for v in value if v not in shared]
        if sorted(value) != value or len(value) != len(shared) + 1 or len(strangers) != 1 or not (a % strangers[0] == 0 or b % strangers[0] == 0):
            errors.append(f"included_non_factor {value} should be the common factors plus one factor of only one number")
    one_only = [d for d in sorted(set(divisors(a) + divisors(b))) if d not in shared]
    if bool(one_only) != ("included_non_factor" in wrong):
        errors.append("included_non_factor should be offered exactly when a factor of only one number exists")
    _expect(errors, wrong, "missed_largest", shared[:-1], True)
    _expect(errors, wrong, "factors_of_one_number", divisors(a), divisors(a) != shared and [divisors(a)] != wrong.get("included_non_factor"))
    wanted = {"concrete": gears([a, b]), "pictorial": factor_lists(a, b), "abstract": {}}[problem["representation"]]
    if problem["visual"] != wanted:
        errors.append(f"the {problem['representation']} picture should be {wanted}")
    errors += _model(problem, factor_lists(a, b, shared))
    errors += _example(problem, "z6.hint.example_common", lambda x, y: {"g": math.gcd(x, y)})
    return errors


def _gcf(problem: dict) -> list[str]:
    a, b, errors = _pair(problem, "z6.gcf.prompt_gcf")
    if not a:
        return errors
    g = math.gcd(a, b)
    shared = common_factors(a, b)
    if problem["answer"] != g:
        errors.append(f"the GCF of {a} and {b} is {g}, not {problem['answer']}")
    wrong = distractors_by_name(problem)
    _only(errors, wrong, {"picked_smallest_common", "picked_lcm", "picked_prime_factor_only", "picked_smaller_number"})
    _expect(errors, wrong, "picked_smallest_common", shared[1] if len(shared) > 1 else None, len(shared) > 2)
    # A prime power such as 4 has one prime, the same as its smallest common factor above 1: offered once.
    _expect(errors, wrong, "picked_prime_factor_only", largest_prime(g) if g > 1 else None,
            g > 1 and not is_prime(g) and largest_prime(g) != shared[1])
    _expect(errors, wrong, "picked_lcm", math.lcm(a, b), True)
    _expect(errors, wrong, "picked_smaller_number", a, b % a != 0)
    wanted = factor_lists(a, b) if problem["representation"] == "pictorial" else {}
    if problem["visual"] != wanted:
        errors.append("a pictorial problem shows both factor lists; an abstract one shows nothing")
    errors += _model(problem, factor_lists(a, b, shared))
    errors += _example(problem, "z6.hint.example_gcf", lambda x, y: {"a": x, "b": y, "g": math.gcd(x, y)})
    return errors


def _composite_within(n: int, most: int) -> bool:
    return 2 <= len(prime_recipe(n)) <= most


def _gcf_recipes(problem: dict) -> list[str]:
    a, b, errors = _pair(problem, "z6.gcf.prompt_recipes")
    if not a:
        return errors
    g = math.gcd(a, b)
    most = problem["params"]["max_factors"]
    if g == 1 or not _composite_within(a, most) or not _composite_within(b, most):
        errors.append(f"{a} and {b} should be composites with at most {most} primes that share a prime")
    if problem["answer"] != g:
        errors.append(f"the GCF of {a} and {b} is {g}, not {problem['answer']}")
    wrong = distractors_by_name(problem)
    _only(errors, wrong, {"multiplied_all_primes", "took_union", "picked_prime_factor_only"})
    _expect(errors, wrong, "took_union", math.lcm(a, b), True)
    _expect(errors, wrong, "multiplied_all_primes", a * b, True)
    _expect(errors, wrong, "picked_prime_factor_only", largest_prime(g) if g > 1 else None, g > 1 and not is_prime(g))
    recipes = recipe_lists(a, b, "shared")
    wanted = recipes if problem["representation"] == "pictorial" else {}
    if problem["visual"] != wanted:
        errors.append("a pictorial problem shows both prime recipes with the shared primes lit")
    lit_product = math.prod(recipes["rows"][0]["items"][i] for i in recipes["rows"][0]["lit"])
    if lit_product != g:
        errors.append(f"the lit primes multiply to {lit_product}, not the GCF {g}")
    errors += _model(problem, recipes)
    errors += _example(problem, "z6.hint.example_recipes_gcf", lambda x, y: {"a": x, "b": y, "g": math.gcd(x, y)})
    return errors


def _coprime(problem: dict) -> list[str]:
    a, b, errors = _pair(problem, "z6.gcf.prompt_coprime")
    if not a:
        return errors
    coprime = math.gcd(a, b) == 1
    if problem["answer"] is not coprime:
        errors.append(f"{a} and {b} {'are' if coprime else 'are not'} coprime, but the answer is {problem['answer']!r}")
    if coprime:
        mistake = "assumed_common_factor" if is_prime(a) and is_prime(b) else "assumed_primes_only"
    else:
        mistake = "shared_even_only" if a % 2 == 1 and b % 2 == 1 else "missed_common_factor"
    if problem["distractors"] != [{"value": not coprime, "misconception": mistake}]:
        errors.append(f"the one wrong answer should be {not coprime} for {mistake}")
    if problem["meta"].get("label_lines") != YES_NO:
        errors.append("the buttons should read Yes and No")
    if problem["visual"]:
        errors.append("an abstract question has no picture")
    errors += _model(problem, factor_lists(a, b, common_factors(a, b)))
    example = problem["hint_steps"][2]["example"]
    x, y = example["prompt_params"]["a"], example["prompt_params"]["b"]
    gx = math.gcd(x, y)
    wanted = ("z6.hint.example_coprime_yes", {"a": x, "b": y}) if gx == 1 else ("z6.hint.example_coprime_no", {"a": x, "b": y, "g": gx})
    if (example["answer_line_id"], example["answer_params"]) != wanted:
        errors.append(f"the worked example should be {wanted}")
    return errors


# --- LcmGenerator --------------------------------------------------------------------------------


def check_lcm(problem: dict) -> list[str]:
    handler = {"common_multiples": _common_multiples, "lcm": _lcm, "factorization": _lcm_recipes, "relation": _relation}.get(problem["params"].get("mode"))
    if handler is None:
        return [f"unknown LCM mode {problem['params'].get('mode')!r}"]
    return handler(problem)


def _common_multiples(problem: dict) -> list[str]:
    a, b, errors = _pair(problem, "z6.lcm.prompt_common", ("k", "a", "b"))
    if not a:
        return errors
    k = problem["prompt_params"]["k"]
    if k != min(max(problem["params"].get("count", 3), 2), 4):
        errors.append(f"k should be the skill's count, got {k}")
    l = math.lcm(a, b)
    answer = [l * i for i in range(1, k + 1)]
    if problem["answer"] != answer:
        errors.append(f"the first {k} common multiples of {a} and {b} are {answer}, not {problem['answer']}")
    # The boards in the order the wrong answers are tried; each joins only if the tiles still fit.
    candidates = [
        ("off_by_one_multiple", [l * i for i in range(2, k + 2)]),
        ("multiples_of_one_number", [a * i for i in range(1, k + 1)]),
        ("listed_product_only", [a * b * i for i in range(1, k + 1)]),
    ]
    tiles = set(answer)
    wrong = distractors_by_name(problem)
    _only(errors, wrong, {name for name, _ in candidates})
    for name, board in candidates:
        fits = board != answer and len(tiles | set(board)) <= MAX_TILES
        _expect(errors, wrong, name, board, fits)
        if fits:
            tiles |= set(board)
    board_meta = problem["meta"].get("tile_board", {})
    if sorted(board_meta.get("tiles", [])) != sorted(tiles) or board_meta.get("slots") != k or board_meta.get("ordered") is not False:
        errors.append(f"the tile board should hold {sorted(tiles)} with {k} slots in any order")
    wanted = {"concrete": gears([a, b]), "pictorial": multiple_lists(a, b, l)}.get(problem["representation"], {})
    if problem["visual"] != wanted:
        errors.append(f"the {problem['representation']} picture should be {wanted}")
    errors += _model(problem, multiple_lists(a, b, l, [l]))
    errors += _example(problem, "z6.hint.example_common_multiples", lambda x, y: {"a": x, "b": y, "l": math.lcm(x, y)})
    return errors


def _lcm(problem: dict) -> list[str]:
    a, b, errors = _pair(problem, "z6.lcm.prompt_lcm")
    if not a:
        return errors
    l = math.lcm(a, b)
    if problem["answer"] != l:
        errors.append(f"the LCM of {a} and {b} is {l}, not {problem['answer']}")
    wrong = distractors_by_name(problem)
    _only(errors, wrong, {"picked_product", "picked_gcf", "picked_sum"})
    _expect(errors, wrong, "picked_product", a * b, a * b != l)
    _expect(errors, wrong, "picked_gcf", math.gcd(a, b), True)
    _expect(errors, wrong, "picked_sum", a + b, True)
    wanted = multiple_lists(a, b, l) if problem["representation"] == "pictorial" else {}
    if problem["visual"] != wanted:
        errors.append("a pictorial problem shows both lists of multiples up to the LCM")
    errors += _model(problem, multiple_lists(a, b, l, [l]))
    errors += _example(problem, "z6.hint.example_lcm", lambda x, y: {"a": x, "b": y, "l": math.lcm(x, y)})
    return errors


def _lcm_recipes(problem: dict) -> list[str]:
    a, b, errors = _pair(problem, "z6.lcm.prompt_recipes")
    if not a:
        return errors
    l = math.lcm(a, b)
    most = problem["params"]["max_factors"]
    if math.gcd(a, b) == 1 or l > MAX_ANSWER or not _composite_within(a, most) or not _composite_within(b, most):
        errors.append(f"{a} and {b} should be composites with at most {most} primes, sharing a prime, LCM at most {MAX_ANSWER}")
    if problem["answer"] != l:
        errors.append(f"the LCM of {a} and {b} is {l}, not {problem['answer']}")
    once = math.prod(sorted(set(prime_recipe(l))))
    wrong = distractors_by_name(problem)
    _only(errors, wrong, {"took_intersection", "dropped_highest_power", "picked_product"})
    _expect(errors, wrong, "took_intersection", math.gcd(a, b), True)
    _expect(errors, wrong, "dropped_highest_power", once, once != l and once != math.gcd(a, b))
    _expect(errors, wrong, "picked_product", a * b, True)
    if problem["visual"]:
        errors.append("an abstract question has no picture")
    errors += _model(problem, recipe_lists(a, b, "most"))
    errors += _example(problem, "z6.hint.example_recipes_lcm", lambda x, y: {"a": x, "b": y, "l": math.lcm(x, y)})
    return errors


def _relation(problem: dict) -> list[str]:
    a, b, errors = _pair(problem, "z6.lcm.prompt_relation", ("a", "b", "g"))
    if not a:
        return errors
    g = math.gcd(a, b)
    l = math.lcm(a, b)
    if problem["prompt_params"]["g"] != g:
        errors.append(f"the GCF of {a} and {b} is {g}, not {problem['prompt_params']['g']}")
    if problem["answer"] != l or l * g != a * b:
        errors.append(f"the LCM of {a} and {b} is {l}, not {problem['answer']}")
    wrong = distractors_by_name(problem)
    _only(errors, wrong, {"added_instead_of_multiplied", "picked_product", "picked_gcf"})
    _expect(errors, wrong, "added_instead_of_multiplied", a + b - g, a + b - g != l)
    _expect(errors, wrong, "picked_product", a * b, a * b != l)
    _expect(errors, wrong, "picked_gcf", g, g != l)
    if problem["visual"]:
        errors.append("an abstract question has no picture")
    errors += _model(problem, factor_lists(a, b, common_factors(a, b)))
    errors += _example(problem, "z6.hint.example_relation", lambda x, y: {"a": x, "b": y, "p": x * y, "g": math.gcd(x, y), "l": math.lcm(x, y)})
    return errors
