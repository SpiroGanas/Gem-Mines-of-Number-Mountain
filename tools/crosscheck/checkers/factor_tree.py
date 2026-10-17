"""Independent re-derivation of the FactorTreeGenerator and FtaGenerator problems (skills pf.*).

A prime recipe (prime factorization) is found by dividing out the smallest divisor above one again
and again (numbers.prime_recipe). A wrong recipe is judged by what is wrong with it: a composite
left in it with the right product (stopped_at_composite, tree_with_composite_leaf), all primes but the
wrong product (product_mismatch), each prime once (missing_repeated_factor), or a 1 in front
(one_is_prime)."""
from __future__ import annotations

from .common import distractors_by_name
from .numbers import array_picture, hops, is_prime, multiply_all, prime_recipe

LABELS = {"true": "ui.common.yes", "false": "ui.common.no"}
KEYS = ["a", "b", "c", "d"]
MAX_SIDE = 10


def split_model(n: int) -> dict:
    """Rung 2: n's smallest prime times the rest, as an array (both sides up to 10) or hops."""
    p = prime_recipe(n)[0]
    rest = n // p
    if rest == 1:
        return array_picture(1, n) if n <= MAX_SIDE else hops(1, n)
    if p <= MAX_SIDE and rest <= MAX_SIDE:
        return array_picture(p, rest, True)
    return hops(rest, p) if rest <= MAX_SIDE else hops(p, rest)


def recipe_line_ok(example: dict) -> bool:
    n = example["prompt_params"]["n"]
    recipe = prime_recipe(n)
    wanted = {"n": n}
    wanted.update({KEYS[i]: value for i, value in enumerate(recipe)})
    return example["answer_line_id"] == f"z5.hint.example_recipe_{len(recipe)}" and example["answer_params"] == wanted


def in_range(n: int, params: dict, least: int = 2) -> bool:
    count = len(prime_recipe(n))
    return max(params["min"], 4) <= n <= params["max"] and least <= count <= params["max_factors"]


def has_composite(values: list[int]) -> bool:
    return any(value > 1 and not is_prime(value) for value in values)


def check(problem: dict) -> list[str]:
    if "mode" not in problem["params"]:
        return _fta(problem)
    handler = {"tree": _tree, "write": _write, "check": _check}.get(problem["params"]["mode"])
    if handler is None:
        return [f"unknown factor tree mode {problem['params']['mode']!r}"]
    errors = handler(problem)
    if not recipe_line_ok(problem["hint_steps"][2]["example"]):
        errors.append("the worked example should state its number's prime recipe")
    return errors


def _common(problem: dict, line: str) -> tuple[int, list[str]]:
    if problem["prompt_line_id"] != line or set(problem["prompt_params"]) != {"n"}:
        return 0, [f"the prompt should be {line} with {{n}}"]
    n = problem["prompt_params"]["n"]
    errors: list[str] = []
    if problem["answer"] != prime_recipe(n):
        errors.append(f"the prime recipe of {n} is {prime_recipe(n)}, not {problem['answer']}")
    if problem["hint_steps"][1]["visual"] != split_model(n):
        errors.append(f"the rung 2 model for {n} should be {split_model(n)}")
    return n, errors


def _judge(name: str, value: list[int], n: int, recipe: list[int]) -> str | None:
    """Why a wrong recipe of n is the mistake it names, or None if it is."""
    if value != sorted(value):
        return f"{name} {value} should be smallest first"
    if name in ("stopped_at_composite", "tree_with_composite_leaf"):
        if multiply_all(value) != n or not has_composite(value) or len(value) != len(recipe) - 1:
            return f"{name} {value} should join two primes of {recipe} into one composite"
    elif name == "product_mismatch":
        if multiply_all(value) == n or not all(is_prime(v) for v in value) or len(value) != len(recipe):
            return f"{name} {value} should be as many primes as {recipe} with another product"
    elif name == "missing_repeated_factor":
        if value != sorted(set(recipe)) or value == recipe:
            return f"{name} {value} should be each prime of {recipe} once"
    elif name == "one_is_prime":
        if value != [1] + recipe:
            return f"{name} {value} should be 1 and then {recipe}"
    else:
        return f"unexpected misconception {name}"
    return None


def _tree(problem: dict) -> list[str]:
    n, errors = _common(problem, "z5.tree.prompt")
    if errors and not n:
        return errors
    if not in_range(n, problem["params"]) or is_prime(n):
        errors.append(f"{n} should be a composite in range with at most {problem['params']['max_factors']} primes")
    if problem["meta"].get("factor_tree") != {"value": n}:
        errors.append("the tree input should start from n")
    recipe = prime_recipe(n)
    wrong = distractors_by_name(problem)
    if "stopped_at_composite" not in wrong:
        errors.append("a tree needs the stopped_at_composite board")
    if len(set(recipe)) < len(recipe) and "missing_repeated_factor" not in wrong:
        errors.append("a recipe with a repeated prime needs the missing_repeated_factor board")
    for name, values in wrong.items():
        for value in values:
            problem_with = _judge(name, value, n, recipe)
            if problem_with:
                errors.append(problem_with)
    if problem["visual"]:
        errors.append("the tree input is the picture; the problem has no other visual")
    return errors


def _write(problem: dict) -> list[str]:
    n, errors = _common(problem, "z5.pf.prompt_write")
    if errors and not n:
        return errors
    params = problem["params"]
    if not (is_prime(n) and max(params["min"], 2) <= n <= params["max"]) and not in_range(n, params):
        errors.append(f"{n} is outside the skill's range")
    if problem["meta"].get("array_label") != "product":
        errors.append("the answer buttons should read as products")
    recipe = prime_recipe(n)
    wrong = distractors_by_name(problem)
    for name in ("one_is_prime", "product_mismatch") + (("stopped_at_composite",) if len(recipe) >= 2 else ()):
        if name not in wrong:
            errors.append(f"{name} is missing")
    for name, values in wrong.items():
        for value in values:
            problem_with = _judge(name, value, n, recipe)
            if problem_with:
                errors.append(problem_with)
    wanted_visual = split_model(n) if problem["representation"] == "pictorial" else {}
    if problem["visual"] != wanted_visual:
        errors.append("a pictorial problem shows the split model; an abstract one shows nothing")
    return errors


def _check(problem: dict) -> list[str]:
    errors: list[str] = []
    prompt = problem["prompt_params"]
    candidate = problem["meta"].get("candidate", [])
    if not 2 <= len(candidate) <= 4 or problem["prompt_line_id"] != f"z5.pf.prompt_check_{len(candidate)}":
        return [f"a candidate of {len(candidate)} numbers needs z5.pf.prompt_check_{len(candidate)}"]
    wanted_prompt = {"n": prompt.get("n")}
    wanted_prompt.update({KEYS[i]: value for i, value in enumerate(candidate)})
    if prompt != wanted_prompt:
        errors.append(f"the prompt should name n and the candidate {candidate}")
    n = prompt["n"]
    if not in_range(n, problem["params"]):
        errors.append(f"{n} is outside the skill's range")
    recipe = prime_recipe(n)
    right = candidate == recipe
    if problem["answer"] is not right:
        errors.append(f"{candidate} {'is' if right else 'is not'} the recipe of {n}, but the answer is {problem['answer']!r}")
    if right:
        mistake = "no_check_made"
    elif multiply_all(candidate) == n and has_composite(candidate):
        mistake = "stopped_at_composite"
        if _judge(mistake, candidate, n, recipe):
            errors.append(_judge(mistake, candidate, n, recipe))
    else:
        mistake = "product_mismatch"
        if _judge(mistake, candidate, n, recipe):
            errors.append(_judge(mistake, candidate, n, recipe))
    if problem["distractors"] != [{"value": not right, "misconception": mistake}]:
        errors.append(f"the one wrong answer should be {not right} for {mistake}")
    if problem["meta"].get("label_lines") != LABELS:
        errors.append("the buttons should read Yes and No")
    if problem["hint_steps"][1]["visual"] != split_model(n):
        errors.append(f"the rung 2 model for {n} should be {split_model(n)}")
    if problem["visual"]:
        errors.append("an abstract question has no picture")
    return errors


def _fta(problem: dict) -> list[str]:
    n, errors = _common(problem, "z5.fta.prompt")
    if errors and not n:
        return errors
    if not in_range(n, problem["params"], 3):
        errors.append(f"{n} should have 3 to {problem['params']['max_factors']} primes and be in range")
    if problem["meta"].get("array_label") != "product":
        errors.append("the answer buttons should read as products")
    recipe = prime_recipe(n)
    wrong = distractors_by_name(problem)
    if sorted(wrong) != ["product_mismatch", "tree_with_composite_leaf"]:
        errors.append(f"who-is-right needs one composite-leaf recipe and one wrong product, got {sorted(wrong)}")
    for name, values in wrong.items():
        for value in values:
            problem_with = _judge(name, value, n, recipe)
            if problem_with:
                errors.append(problem_with)
    if problem["visual"]:
        errors.append("an abstract question has no picture")
    if not recipe_line_ok(problem["hint_steps"][2]["example"]):
        errors.append("the worked example should state its number's prime recipe")
    return errors
