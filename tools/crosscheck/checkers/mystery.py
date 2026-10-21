"""Independent re-derivation of the MysteryGenerator problems (Zone 12, skills mystery.*).

Primes come from a sieve of Eratosthenes built here; every Goldbach pair and every twin pair is found by scanning it.
Nothing here is ported from scripts/generators/mystery.gd."""
from __future__ import annotations

from .common import distractor_pairs, filtered

LIMIT = 300


def _sieve(limit: int) -> list[bool]:
    flags = [True] * (limit + 1)
    flags[0:2] = [False, False]
    for p in range(2, int(limit ** 0.5) + 1):
        if flags[p]:
            for multiple in range(p * p, limit + 1, p):
                flags[multiple] = False
    return flags


PRIME = _sieve(LIMIT)


def pairs(n: int) -> list[tuple[int, int]]:
    return [(p, n - p) for p in range(2, n // 2 + 1) if PRIME[p] and PRIME[n - p]]


def parse(text: str) -> tuple[int, int] | None:
    parts = text.split(" + ")
    if len(parts) != 2 or not all(part.isdigit() for part in parts):
        return None
    return int(parts[0]), int(parts[1])


def check(problem: dict) -> list[str]:
    skill = problem["params"]
    if skill["mode"] == "goldbach":
        return _goldbach(problem, skill)
    return _twin(problem, skill)


def _goldbach(problem: dict, skill: dict) -> list[str]:
    p = problem["prompt_params"]
    if set(p) != {"n"} or problem["prompt_line_id"] != "z12.mystery.prompt_goldbach":
        return ["the prompt should be z12.mystery.prompt_goldbach with {n}"]
    n = p["n"]
    errors: list[str] = []
    if n % 2 or not 4 <= n <= skill["max_n"]:
        errors.append(f"{n} should be even, 4 to {skill['max_n']}")
        return errors
    valid = pairs(n)
    answer = parse(problem["answer"])
    if answer is None or answer[0] > answer[1] or answer not in valid:
        errors.append(f"{problem['answer']!r} is not a pair of primes adding up to {n}")
    if problem["meta"].get("pairs") != [f"{a} + {b}" for a, b in valid]:
        errors.append("meta.pairs should list every pair of primes adding up to n")
    kinds = {"used_composite": 0, "sum_off": 0}
    for name, value in distractor_pairs(problem):
        pair = parse(value)
        if pair is None or pair[0] > pair[1]:
            errors.append(f"{value!r} is not written 'p + q' with p <= q")
            continue
        if pair in valid:
            errors.append(f"wrong answer {value!r} is a real pair for {n}")
        if name == "used_composite" and not (sum(pair) == n and not (PRIME[pair[0]] and PRIME[pair[1]])):
            errors.append(f"{value!r} should add up to {n} with one number not prime")
        if name == "sum_off" and not (PRIME[pair[0]] and PRIME[pair[1]] and sum(pair) != n):
            errors.append(f"{value!r} should be two primes that do not add up to {n}")
        kinds[name] = kinds.get(name, 0) + 1
    if len(problem["distractors"]) < 2:
        errors.append("at least two wrong pairs")
    line = {"type": "number_line", "min": 0, "max": -(-n // 10) * 10, "labeled_every": 10, "markers": [n], "blanks": []}
    if problem["representation"] == "pictorial":
        if problem["visual"] != line:
            errors.append("a pictorial problem shows the number line to n with n marked")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != line:
        errors.append("the rung 2 model is a number line to n with n marked")
    ex = problem["hint_steps"][2]["example"]
    pair = parse(ex["answer"])
    if pair is None or pair not in pairs(ex["prompt_params"]["n"]) or ex["answer_params"] != {"p": pair[0], "q": pair[1], "n": ex["prompt_params"]["n"]}:
        errors.append("the worked example should show a real pair")
    return errors


def _twin(problem: dict, skill: dict) -> list[str]:
    prompt = problem["prompt_params"]
    if set(prompt) != {"p"} or problem["prompt_line_id"] != "z12.mystery.prompt_twin":
        return ["the prompt should be z12.mystery.prompt_twin with {p}"]
    p = prompt["p"]
    errors: list[str] = []
    if not 2 <= p <= skill["max_p"]:
        return [f"{p} is outside 2..{skill['max_p']}"]
    twins = [q for q in range(p + 1, LIMIT - 2) if PRIME[q] and PRIME[q + 2]]
    if problem["answer"] != twins[0]:
        errors.append(f"the next twin primes after {p} start at {twins[0]}, not {problem['answer']!r}")
    cousins = [q for q in range(p + 1, LIMIT - 4) if PRIME[q] and PRIME[q + 4]]
    fakes = [q for q in range(p + 1, LIMIT - 2) if not PRIME[q] and q > 1 and PRIME[q + 2]]
    wanted = filtered(problem["answer"], [("gave_larger_prime", problem["answer"] + 2), ("gap_not_two", cousins[0]), ("not_both_prime", fakes[0])])
    if distractor_pairs(problem) != wanted:
        errors.append(f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}")
    if problem["meta"] != {"pad_digits": 3}:
        errors.append("the pad takes 3 digits")
    ex = problem["hint_steps"][2]["example"]
    eq = ex["answer"]
    ep = ex["prompt_params"]["p"]
    first = [q for q in range(ep + 1, LIMIT - 2) if PRIME[q] and PRIME[q + 2]][0]
    if eq != first or ex["answer_params"] != {"q": eq, "r": eq + 2}:
        errors.append("the worked example should name its twin primes")
    model = problem["hint_steps"][1]["visual"]
    if model.get("markers") != [p, problem["answer"], problem["answer"] + 2]:
        errors.append("the rung 2 model marks p and the twin pair")
    if problem["representation"] == "pictorial":
        wanted_picture = dict(model, markers=[p])
        if problem["visual"] != wanted_picture:
            errors.append("a pictorial problem shows the model's number line with only p marked")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    return errors
