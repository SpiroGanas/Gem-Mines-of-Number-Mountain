"""Independent re-derivation of the SkipCountGenerator problems (skills skip.*).

A strip is five numbers counting by `step`; two numbers in the middle are blank and the answer is
those two, left to right. Every wrong answer is rebuilt here by writing out the strip the way a child
with that misconception would, then reading off the blanks."""
from __future__ import annotations

from .common import distractors_by_name, is_int

PROMPTS = {10: "z3.skip.prompt_by_10", 5: "z3.skip.prompt_by_5", 2: "z3.skip.prompt_by_2"}
EXTRA_MISTAKE = {10: "decade_skip", 2: "off_by_one"}
PICTURE_PAIRS = "pairs_up_to_last"
STRIP_LENGTH = 5


def child_counting_by_ones(strip: list[int], blank_positions: list[int]) -> list[int]:
    """The blanks as a child counting by ones fills them: each one more than whatever is written just
    before it, including the child's own number when two blanks are side by side."""
    written: list[int] = []
    for position, number in enumerate(strip):
        written.append(written[-1] + 1 if position in blank_positions and written else number)
    return [written[position] for position in blank_positions]


def check(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    step, top = params["step"], params["max"]
    if step not in PROMPTS:
        return [f"no skip-counting prompt for step {step!r}"]
    if problem["prompt_line_id"] != PROMPTS[step] or problem["prompt_params"] != {}:
        errors.append(f"counting by {step} should use {PROMPTS[step]} with no parameters")

    strip = problem["meta"].get("strip")
    if not isinstance(strip, list) or len(strip) != STRIP_LENGTH or not all(is_int(n) for n in strip):
        return errors + [f"meta.strip should be {STRIP_LENGTH} whole numbers, got {strip!r}"]
    expected_strip = list(range(strip[0], strip[0] + STRIP_LENGTH * step, step))
    if strip != expected_strip:
        errors.append(f"the strip {strip} does not count by {step}")
    if strip[0] < step or strip[0] % step:
        errors.append(f"the strip should start on a multiple of {step} (at least {step}), not {strip[0]}")
    if strip[-1] > top:
        errors.append(f"the strip runs past {top}")

    answer = problem["answer"]
    if not isinstance(answer, list) or len(answer) != 2 or any(value not in strip for value in answer):
        return errors + [f"the answer {answer!r} should be two numbers from the strip"]
    positions = [strip.index(value) for value in answer]
    if positions != sorted(set(positions)):
        errors.append(f"the answer {answer} should list the blanks in strip order")
    if any(position in (0, STRIP_LENGTH - 1) for position in positions):
        errors.append(f"a blank is the first or last number of the strip {strip}")

    errors += _check_picture(problem, strip, step)
    errors += _check_distractors(problem, strip, positions, step)
    errors += _check_tiles(problem)
    errors += _check_hints(problem, strip, step)
    return errors


def _check_picture(problem: dict, strip: list[int], step: int) -> list[str]:
    visual = problem["visual"]
    if problem["representation"] == "concrete":
        errors = []
        if step != 2:
            errors.append("only counting by twos has a concrete (pairs) picture")
        if visual != {"type": "pairs", "count": strip[-1], "show_pairs": True}:
            errors.append(f"the concrete picture should be {strip[-1]} gems in pairs, got {visual!r}")
        if problem["meta"].get("picture") != PICTURE_PAIRS:
            errors.append(f"meta.picture should say {PICTURE_PAIRS!r}")
        return errors
    expected = {"type": "number_line", "min": strip[0], "max": strip[-1], "labeled_every": step,
                "markers": [], "blanks": problem["answer"]}
    if visual != expected:
        return [f"the pictorial strip should be the number line {expected}, got {visual!r}"]
    return []


def _check_distractors(problem: dict, strip: list[int], positions: list[int], step: int) -> list[str]:
    errors: list[str] = []
    answer = problem["answer"]
    wrong = distractors_by_name(problem)
    expected_names = {"wrong_step"} | ({EXTRA_MISTAKE[step]} if step in EXTRA_MISTAKE else set())
    if set(wrong) != expected_names:
        errors.append(f"counting by {step} should have exactly the mistakes {sorted(expected_names)}, got {sorted(wrong)}")
    by_ones = child_counting_by_ones(strip, positions)
    if wrong.get("wrong_step", [by_ones]) != [by_ones]:
        errors.append(f"wrong_step should be {by_ones} (counting by ones), got {wrong['wrong_step']}")
    for value in wrong.get("decade_skip", []):
        moved = [abs(a - b) for a, b in zip(value, answer)]
        if sorted(moved) != [0, 10]:
            errors.append(f"decade_skip {value} should move exactly one blank of {answer} by ten")
    for value in wrong.get("off_by_one", []):
        if value != [n + 1 for n in answer]:
            errors.append(f"off_by_one should be {[n + 1 for n in answer]}, got {value}")
    for entry in problem["distractors"]:
        value = entry["value"]
        if not isinstance(value, list) or len(value) != 2 or value[0] == value[1] or min(value) < 1:
            errors.append(f"{entry['misconception']} {value!r} should be two different positive numbers")
    return errors


def _check_tiles(problem: dict) -> list[str]:
    board = problem["meta"].get("tile_board")
    if not isinstance(board, dict):
        return ["a skip-counting strip needs a tile board"]
    errors: list[str] = []
    if board.get("slots") != 2 or board.get("ordered") is not True:
        errors.append("the tile board should have two ordered slots")
    needed = set(problem["answer"])
    for entry in problem["distractors"]:
        needed |= set(entry["value"])
    tiles = board.get("tiles", [])
    if sorted(tiles) != sorted(needed):
        errors.append(f"the tiles {sorted(tiles)} should be the answer and wrong numbers {sorted(needed)}, each once")
    return errors


def _check_hints(problem: dict, strip: list[int], step: int) -> list[str]:
    errors: list[str] = []
    model = problem["hint_steps"][1]["visual"]
    hops = [{"from": a, "to": b} for a, b in zip(strip, strip[1:])]
    expected = {"type": "number_line", "min": strip[0], "max": strip[-1], "labeled_every": step,
                "markers": [], "blanks": problem["answer"][1:], "jumps": hops}
    if model != expected:
        errors.append(f"the rung 2 model should be the strip with the first blank filled in, got {model!r}")
    example = problem["hint_steps"][2]["example"]
    if example["prompt_line_id"] != PROMPTS[step]:
        errors.append("the worked example should count by the same step")
    shown = example["answer"]
    if example["answer_line_id"] != "z3.hint.example_blanks" or example["answer_params"] != {"a": shown[0], "b": shown[1]}:
        errors.append("the worked example should state its two missing numbers")
    example_picture = problem["hint_steps"][2]["visual"]
    if example_picture.get("type") == "number_line" and example_picture.get("blanks") != shown:
        errors.append("the worked example's blanks do not match its answer")
    return errors
