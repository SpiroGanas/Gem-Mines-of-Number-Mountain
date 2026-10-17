"""Independent re-derivation of the SieveGenerator problems (skills sieve.*).

The grid is 1 to `size`. A rock is crossed out when it is 1 or has a divisor other than 1 and itself
(found by trying every number). The answer is every crossed rock when the child presses Done; the
rocks crossed before the child starts (an earlier part of the sieve) must be in every answer and
every wrong board."""
from __future__ import annotations

from .common import distractors_by_name
from .numbers import array_picture, hops, is_prime, smallest_divisor_above_one

COLUMNS = 10
MAX_HOPS = 10


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {"multiples": _multiples, "primes": _primes}.get(mode)
    if handler is None:
        return [f"unknown sieve mode {mode!r}"]
    errors = handler(problem)
    errors += _check_grid(problem)
    if problem["visual"]:
        errors.append("the sieve grid itself is the picture; the problem has no other visual")
    return errors


def _check_grid(problem: dict) -> list[str]:
    errors: list[str] = []
    grid = problem["meta"].get("sieve_grid")
    if not isinstance(grid, dict):
        return ["a sieve problem needs meta.sieve_grid"]
    if grid.get("cols") != COLUMNS or grid.get("size") != problem["prompt_params"]["size"]:
        errors.append(f"the grid should be {COLUMNS} wide and {problem['prompt_params']['size']} rocks long")
    before = grid.get("precrossed", [])
    for value in [problem["answer"]] + [entry["value"] for entry in problem["distractors"]]:
        if value != sorted(set(value)):
            errors.append(f"{value} should be sorted with no repeats")
        if not set(before) <= set(value):
            errors.append(f"{value} un-crosses a rock that was crossed from the start")
        if any(not 1 <= rock <= grid.get("size", 0) for rock in value):
            errors.append(f"{value} has a rock off the grid")
    return errors


# --- multiples ---------------------------------------------------------------------------------


def _multiples(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    prompt = problem["prompt_params"]
    if problem["prompt_line_id"] != "z5.sieve.prompt_multiples" or set(prompt) != {"p", "size"}:
        return ["the prompt should be z5.sieve.prompt_multiples with {p} and {size}"]
    p, size = prompt["p"], prompt["size"]
    if p not in params["primes"] or not is_prime(p):
        errors.append(f"{p} is not one of the skill's primes {params['primes']}")
    if size % COLUMNS != 0 or size < p * p or not params["min_size"] <= size <= params["max_size"]:
        errors.append(f"a grid of {size} rocks is outside the skill's sizes or misses {p} x {p}")
    before = [1] + [n for n in range(2, size + 1) if not is_prime(n) and smallest_divisor_above_one(n) < p]
    if problem["meta"]["sieve_grid"]["precrossed"] != before:
        errors.append(f"the rocks crossed from the start should be 1 and the multiples of primes below {p}")
    mine = [n for n in range(2 * p, size + 1, p)]
    answer = sorted(set(before) | set(mine))
    if problem["answer"] != answer:
        errors.append(f"crossing the multiples of {p} on a {size} grid gives {answer}, not {problem['answer']}")
    newly = [n for n in mine if n not in before]
    expected = {
        "crossed_p_itself": sorted(answer + [p]),
        "missed_p_squared": [n for n in answer if n != p * p],
    }
    if newly and newly[-1] != p * p:
        expected["missed_last_multiple"] = [n for n in answer if n != newly[-1]]
    wrong = distractors_by_name(problem)
    for name, boards in wrong.items():
        if name not in expected or boards != [expected[name]]:
            errors.append(f"{name} should be {expected.get(name)}, got {boards}")
    for name, board in expected.items():
        if name not in wrong:
            errors.append(f"{name} is missing")
    if problem["hint_steps"][1]["visual"] != hops(min(size // p, MAX_HOPS), p):
        errors.append(f"the rung 2 model should be hops of {p}")
    example = problem["hint_steps"][2]["example"]
    e_p = example["prompt_params"]["p"]
    if example["answer_line_id"] != "z5.hint.example_sieve_multiples" or example["answer_params"] != {"p": e_p, "a": 2 * e_p, "b": 3 * e_p, "c": 4 * e_p}:
        errors.append("the worked example should name the first multiples of its prime")
    return errors


# --- primes ------------------------------------------------------------------------------------


def _primes(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    prompt = problem["prompt_params"]
    if problem["prompt_line_id"] != "z5.sieve.prompt_primes" or set(prompt) != {"size", "q"}:
        return ["the prompt should be z5.sieve.prompt_primes with {size} and {q}"]
    size, q = prompt["size"], prompt["q"]
    if size != params["size"] or q not in params["done"]:
        errors.append(f"size {size} and q {q} should come from the skill ({params['size']}, {params['done']})")
    composites = [n for n in range(2, size + 1) if not is_prime(n)]
    before = [n for n in composites if smallest_divisor_above_one(n) <= q]
    if problem["meta"]["sieve_grid"]["precrossed"] != before:
        errors.append(f"the rocks crossed from the start should be the multiples of primes up to {q}")
    answer = [1] + composites
    if problem["answer"] != answer:
        errors.append(f"1 and every composite up to {size} should be crossed, not {problem['answer']}")
    left = [n for n in composites if n not in before]
    squares = [n for n in left if smallest_divisor_above_one(n) ** 2 == n]
    others = [n for n in left if n not in squares]
    wrong = distractors_by_name(problem)
    if wrong.get("one_is_prime") != [[n for n in answer if n != 1]]:
        errors.append("one_is_prime should leave only 1 standing")
    if squares and wrong.get("square_is_prime") != [[n for n in answer if n != max(squares)]]:
        errors.append(f"square_is_prime should leave {max(squares)} standing")
    odd = wrong.get("odd_means_prime", [])
    if others and (len(odd) != 1 or len(set(answer) - set(odd[0])) != 1 or not (set(answer) - set(odd[0])) <= set(others)):
        errors.append(f"odd_means_prime should leave exactly one of {others} standing")
    next_prime = next(n for n in range(q + 1, 2 * q + 2) if is_prime(n))
    if next_prime <= size and wrong.get("crossed_p_itself") != [sorted(answer + [next_prime])]:
        errors.append(f"crossed_p_itself should also cross the prime {next_prime}")
    for name in wrong:
        if name not in ("one_is_prime", "square_is_prime", "odd_means_prime", "crossed_p_itself"):
            errors.append(f"unexpected misconception {name}")
    root = smallest_divisor_above_one(max(squares)) if squares else 2
    if problem["hint_steps"][1]["visual"] != array_picture(root, root, True):
        errors.append(f"the rung 2 model should be the {root} x {root} square")
    example = problem["hint_steps"][2]["example"]
    e_q, e_size = example["prompt_params"]["q"], example["prompt_params"]["size"]
    first = next(n for n in range(4, e_size + 1) if not is_prime(n) and smallest_divisor_above_one(n) > e_q)
    a = smallest_divisor_above_one(first)
    if e_q == q:
        errors.append("the worked example should use another q")
    if example["answer_line_id"] != "z5.hint.example_sieve_primes" or example["answer_params"] != {"n": first, "a": a, "b": first // a}:
        errors.append(f"the worked example should break {first}")
    return errors
