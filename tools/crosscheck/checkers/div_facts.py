"""Independent re-derivation of the DivFactsGenerator problems (div.sharing.equal_shares, div.facts.*).

The quotient is found by dealing the gems out one at a time into the carts (every cart must end up
with the same number); the multiplied-instead answer is found by adding."""
from __future__ import annotations

from .common import distractors_by_name
from .numbers import number_line, product, share_equally

PROMPT_SHARE = "z4.div.prompt_share"
PROMPT_FACT = "z4.div.prompt_fact"
EXAMPLE_LINE = "z4.hint.example_div"
ONES_ONLY_UP_TO = 30
MAX_WRONG = 999
MAX_SIDE = 10


def gems(total: int) -> dict:
    """The pile of gems to share: single gems up to 30, otherwise hundreds, tens and ones."""
    if total <= ONES_ONLY_UP_TO:
        return {"type": "gem_piles", "piles": [{"hundreds": 0, "tens": 0, "ones": total}]}
    digits = str(total).zfill(3)
    return {"type": "gem_piles", "piles": [{"hundreds": int(digits[0]), "tens": int(digits[1]), "ones": int(digits[2])}]}


def check(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    if set(problem["prompt_params"]) != {"n", "b"}:
        return ["a division prompt needs {n} and {b}"]
    total, carts = problem["prompt_params"]["n"], problem["prompt_params"]["b"]
    share = share_equally(total, carts)
    if share is None:
        errors.append(f"{total} gems do not share into {carts} equal carts")
    elif problem["answer"] != share:
        errors.append(f"{total} shared into {carts} carts gives {share} each, not {problem['answer']}")
    if not params["divisor_min"] <= carts <= min(params["divisor_max"], MAX_SIDE):
        errors.append(f"{carts} carts is outside {params['divisor_min']}..{params['divisor_max']}")
    if not params["quotient_min"] <= problem["answer"] <= min(params["quotient_max"], MAX_SIDE):
        errors.append(f"{problem['answer']} each is outside {params['quotient_min']}..{params['quotient_max']}")

    representation = problem["representation"]
    in_words = params["mode"] == "share" or representation == "concrete"
    wanted_line = PROMPT_SHARE if in_words else PROMPT_FACT
    if problem["prompt_line_id"] != wanted_line:
        errors.append(f"a {representation} {params['mode']} problem should use {wanted_line}")
    expected_picture = {"concrete": gems(total), "pictorial": number_line(0, total, carts, [total]), "abstract": {}}[representation]
    if problem["visual"] != expected_picture:
        errors.append(f"the {representation} picture should be {expected_picture!r}, got {problem['visual']!r}")

    errors += _check_distractors(problem, total, carts, problem["answer"])

    if problem["hint_steps"][1]["visual"] != {"type": "groups", "groups": carts, "size": problem["answer"]}:
        errors.append(f"the rung 2 model should be {carts} carts of {problem['answer']} gems")
    example = problem["hint_steps"][2]["example"]
    e_total, e_carts = example["prompt_params"]["n"], example["prompt_params"]["b"]
    if share_equally(e_total, e_carts) != example["answer"] or example["answer_line_id"] != EXAMPLE_LINE \
            or example["answer_params"] != {"n": e_total, "b": e_carts, "q": example["answer"]}:
        errors.append("the worked example does not state its own quotient")
    return errors


def _check_distractors(problem: dict, total: int, carts: int, quotient: int) -> list[str]:
    errors: list[str] = []
    wrong = distractors_by_name(problem)
    for name in wrong:
        if name not in ("multiplied_instead", "off_by_one"):
            errors.append(f"unexpected misconception {name}")
    bigger = product(total, carts)
    for value in wrong.get("multiplied_instead", []):
        if value != bigger or value > MAX_WRONG:
            errors.append(f"multiplied_instead {value} is not {total} x {carts} (at most {MAX_WRONG})")
    if bigger <= MAX_WRONG and wrong.get("multiplied_instead") != [bigger]:
        errors.append(f"multiplied_instead should offer {total} x {carts} = {bigger}")
    near = wrong.get("off_by_one", [])
    if sorted(near) != [quotient - 1, quotient + 1]:
        errors.append(f"off_by_one should offer {quotient - 1} and {quotient + 1}, got {near}")
    return errors
