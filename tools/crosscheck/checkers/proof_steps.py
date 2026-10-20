"""Independent re-derivation of the Zone 12 starter proofs (ProofStepsGenerator, ProofBuilderGenerator).

The mini proofs are read from curriculum/mini_proofs.json and the guided proofs from curriculum/proofs/*.json; the
answers are recomputed from the cards an exported problem shows. The guided proofs are also walked here: the listed order
must satisfy every dependency, and a topological-order search finds every valid order of a partial-order proof.
Nothing here is ported from scripts/generators/proof_steps.gd."""
from __future__ import annotations

import itertools
import json
from pathlib import Path

from .common import distractor_pairs, filtered

ROOT = Path(__file__).resolve().parents[3]
MINI = json.loads((ROOT / "curriculum" / "mini_proofs.json").read_text(encoding="utf-8"))
REASONS = ["assume", "meaning", "arithmetic", "previous"]


def _proof_files() -> dict[str, dict]:
    proofs = {}
    for path in sorted((ROOT / "curriculum" / "proofs").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        proofs[data["id"]] = data
    return proofs


PROOFS = _proof_files()


def valid_orders(proof: dict) -> list[list[str]]:
    """Every order of the proof's steps that puts each step after the steps it depends on (strict proofs: the listed one)."""
    ids = [s["id"] for s in proof["steps"]]
    deps = {s["id"]: s["depends_on"] for s in proof["steps"]}
    if proof["orderings"] == "strict":
        return [ids]
    found = []
    for order in itertools.permutations(ids):
        position = {step: index for index, step in enumerate(order)}
        if all(position[d] < position[step] for step in ids for d in deps[step]):
            found.append(list(order))
    return found


def check_proof_file(proof: dict) -> list[str]:
    errors: list[str] = []
    ids = [s["id"] for s in proof["steps"]]
    if len(set(ids)) != len(ids):
        errors.append("repeated step ids")
    seen: list[str] = []
    for step in proof["steps"]:
        if step["justification"] not in proof["justifications"]:
            errors.append(f"{step['id']}: reason not in the list")
        for dep in step["depends_on"]:
            if dep not in seen:
                errors.append(f"{step['id']} depends on {dep}, which does not come before it")
        seen.append(step["id"])
    if not valid_orders(proof):
        errors.append("no valid order")
    return errors


def _cards(visual: dict) -> list[tuple[int, str]]:
    return [(card["n"], card["line_id"]) for card in visual["cards"]]


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    errors: list[str] = []
    visual = problem["visual"]
    if visual.get("type") != "statements":
        return ["a proof question shows its cards"]
    cards = _cards(visual)
    by_number = dict(cards)
    if mode in ("parts", "order", "justify"):
        chain = next((c for c in MINI["chains"] if c["id"] == problem["meta"]["chain"]), None)
        if chain is None:
            return ["unknown chain"]
        lines = [s["line_id"] for s in chain["steps"]]
        if sorted(by_number.values()) != sorted(lines):
            errors.append("the cards are not the chain's statements")
        position = {line: index for index, line in enumerate(lines)}  # place in the proof
    else:
        found = next((c for c in MINI["clashes"] if c["id"] == problem["meta"]["set"]), None)
        if found is None:
            return ["unknown clash set"]
        lines = found["steps"]
        if [by_number[n] for n in sorted(by_number)] != lines:
            errors.append("a clash set shows its steps in order")
    answer = problem["answer"]
    if mode == "parts":
        starts = problem["meta"]["starts"]
        want_line = lines[0] if starts else lines[-1]
        want = next(n for n, line in cards if line == want_line)
        if problem["prompt_line_id"] != ("z12.proof.prompt_assumption" if starts else "z12.proof.prompt_conclusion") or answer != want:
            errors.append(f"the card for the {'first' if starts else 'last'} step is {want}, not {answer!r}")
        other = next(n for n, line in cards if line == (lines[-1] if starts else lines[0]))
        wanted = [("picked_conclusion_as_assumption" if starts else "picked_assumption_as_conclusion", other)]
        wanted += [("picked_middle_step", n) for n, line in cards if line not in (lines[0], lines[-1])]
        if distractor_pairs(problem) != filtered(answer, wanted):
            errors.append(f"the wrong answers should be {filtered(answer, wanted)}")
        if list(sorted(by_number)) != list(range(1, len(cards) + 1)) or len(cards) not in (3, 4):
            errors.append("3 or 4 numbered cards")
        if starts == (cards[0][1] == lines[0] and cards[-1][1] == lines[-1] and [c[1] for c in cards] == lines):
            pass
        if [c[1] for c in cards] == lines:
            errors.append("the cards must be shuffled")
    elif mode == "order":
        want = [next(n for n, line in cards if line == step) for step in lines]
        if answer != want or problem["prompt_line_id"] != "z12.proof.prompt_order":
            errors.append(f"the cards in proof order are {want}, not {answer!r}")
        if [c[1] for c in cards] == lines:
            errors.append("the cards must be shuffled")
        wanted = [("reversed_chain", list(reversed(want)))]
        wanted += [("swapped_two_steps", want[:i] + [want[i + 1], want[i]] + want[i + 2:]) for i in range(len(want) - 1)]
        if distractor_pairs(problem) != filtered(answer, wanted):
            errors.append(f"the wrong answers should be {filtered(answer, wanted)}")
        board = problem["meta"]["tile_board"]
        if board != {"tiles": list(range(1, len(cards) + 1)), "slots": len(cards), "ordered": True}:
            errors.append("the tile board holds the card numbers")
    elif mode == "justify":
        k = problem["prompt_params"]["k"]
        reason = next(s["reason"] for s in chain["steps"] if s["line_id"] == by_number[k])
        if [c[1] for c in cards] != lines:
            errors.append("the cards are in proof order")
        if answer != reason or problem["prompt_line_id"] != "z12.proof.prompt_justify" or set(problem["prompt_params"]) != {"k"}:
            errors.append(f"step {k} is true because of {reason!r}, not {answer!r}")
        if visual.get("lit") != k:
            errors.append("the asked step is lit")
        wanted = []
        for other in REASONS:
            circular = {other, reason} == {"previous", "assume"}
            wanted.append(("circular_reasoning" if circular else "mixed_up_reason", other))
        if distractor_pairs(problem) != filtered(answer, wanted):
            errors.append(f"the wrong answers should be {filtered(answer, wanted)}")
        if problem["meta"]["label_lines"] != {r: f"z12.why.{r}" for r in REASONS}:
            errors.append("the reason buttons read z12.why.*")
    else:
        clash = found["clash"]
        if answer != clash or problem["prompt_line_id"] != "z12.proof.prompt_contradiction":
            errors.append(f"step {clash} clashes with step 1, not {answer!r}")
        if distractor_pairs(problem) != filtered(answer, [("missed_contradiction", n) for n in range(2, len(cards) + 1)]):
            errors.append("the wrong answers are the other steps after step 1")
    if problem["representation"] not in ("pictorial", "abstract"):
        errors.append("a question about cards is pictorial or abstract")
    model = problem["hint_steps"][1]["visual"]
    if model.get("type") != "statements" or [c["line_id"] for c in model["cards"]] != lines or [c["n"] for c in model["cards"]] != list(range(1, len(lines) + 1)):
        errors.append("the rung 2 model shows the cards in proof order")
    return errors


def check_builder(problem: dict) -> list[str]:
    proof = PROOFS.get(problem["answer"])
    errors: list[str] = []
    if proof is None:
        return [f"no proof {problem['answer']!r}"]
    errors += check_proof_file(proof)
    if problem["params"]["proof_id"] != problem["answer"] or problem["meta"] != {"proof_builder": {"proof_id": proof["id"]}}:
        errors.append("the problem is about the skill's proof")
    if problem["distractors"]:
        errors.append("a drag problem has no wrong answers")
    if problem["prompt_line_id"] != "z12.proof.prompt_build" or problem["prompt_params"]:
        errors.append("the prompt asks to build the proof")
    model = problem["hint_steps"][1]["visual"]
    if [c["line_id"] for c in model["cards"]] != [s["line_id"] for s in proof["steps"]] or not model.get("arrows"):
        errors.append("the rung 2 model shows the proof's steps in order with arrows")
    example = problem["hint_steps"][2]["example"]
    practice = PROOFS["proof.practice.even_plus_even"]
    if example["answer"] != practice["id"] or example["prompt_line_id"] != practice["intro_line_id"]:
        errors.append("the worked example is the practice proof")
    return errors
