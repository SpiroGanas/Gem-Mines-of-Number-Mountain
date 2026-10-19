"""Checks every exported problem must pass whatever the skill (structure, distractors, hints,
visuals). Independent of the GDScript generators; see checkers/__init__.py."""
from __future__ import annotations

import math
from fractions import Fraction

REQUIRED_KEYS = (
    "skill_id", "seed", "representation", "prompt_line_id", "prompt_params", "answer",
    "answer_modes", "distractors", "visual", "hint_steps", "params", "meta",
)
HINT_KINDS = ("repeat_highlight", "visual_model", "worked_example", "easier_problem")
VISUAL_TYPES = ("gem_piles", "ten_frame", "number_line", "balance", "array", "groups", "pairs", "digits",
                "lists", "gears",
                "crystals", "fraction_line", "crystal_grid", "depth_gauge", "ore_mix",
                "power_tower", "notation", "cube_blocks", "lamps", "lever")
ZONE8_VISUALS = ("power_tower", "notation", "cube_blocks", "lamps", "lever")
MAX_PLACES = 8  # the most lamps or dials a vault lock (or a lamps picture) has (Zone 8)
LIST_KINDS = ("factors", "multiples", "recipe")
MAX_LIST_ITEMS = 16
MAX_LIST_ROWS = 2
MAX_GEARS = 3
GEAR_TEETH = (2, 200)
TAP_SHARDS = 12  # the most shards a crystal the child taps may have (Zone 7)
DIGIT_FOCUS = ("last", "last_two", "sum", "sum_and_last", "recipe")
TILTS = ("unknown", "level", "left", "right")


def is_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def exact_value(value: object) -> Fraction | None:
    """The exact value of a Zone 7 answer shape (fraction, mixed number, decimal), else None. Built with
    fractions.Fraction from the integers, never through a float."""
    if not isinstance(value, dict):
        return None
    keys = set(value)
    if keys == {"num", "den"} and is_int(value["num"]) and is_int(value["den"]) and value["den"] != 0:
        return Fraction(value["num"], value["den"])
    if keys == {"whole", "num", "den"} and value["den"] != 0:
        return value["whole"] + Fraction(value["num"], value["den"])
    if keys == {"mantissa", "scale"} and is_int(value["scale"]) and value["scale"] >= 0:
        return Fraction(value["mantissa"], 10 ** value["scale"])
    return None


def same_answer(x: object, y: object, simplest_form: bool = False) -> bool:
    """Two answers are the same: fractions, mixed numbers and decimals by value (2/4 is 1/2, 0.50 is 0.5)
    and ratios by cross-multiplying (4 : 6 is 2 : 3), unless the problem asks for simplest form
    (meta.simplest_form, Zone 6's simplify skills): then by exact form, so 6/9 is not 2/3. Anything
    else exactly."""
    if not simplest_form:
        ex, ey = exact_value(x), exact_value(y)
        if ex is not None and ey is not None:
            return ex == ey
        if isinstance(x, dict) and isinstance(y, dict) and set(x) == set(y) == {"a", "b"}:
            return x["a"] * y["b"] == y["a"] * x["b"]
    return x == y


def pile_total(pile: dict) -> int:
    """Value of one gem pile: hundreds, tens and ones."""
    return pile["hundreds"] * 100 + pile["tens"] * 10 + pile["ones"]


def distractors_by_name(problem: dict) -> dict[str, list]:
    """{misconception name: [values]} in the order given."""
    result: dict[str, list] = {}
    for entry in problem["distractors"]:
        result.setdefault(entry["misconception"], []).append(entry["value"])
    return result


def check_structure(problem: dict, skill: dict, allowed_names: set[str]) -> list[str]:
    errors: list[str] = []
    missing = [key for key in REQUIRED_KEYS if key not in problem]
    if missing:
        return [f"missing keys {missing}"]
    if problem["skill_id"] != skill["id"]:
        errors.append(f"skill_id {problem['skill_id']!r} is not {skill['id']!r}")
    if not is_int(problem["seed"]):
        errors.append("seed is not an integer")
    if problem["representation"] not in skill["representations"]:
        errors.append(f"representation {problem['representation']!r} is not allowed for the skill")
    if problem["answer_modes"] != skill["answer_modes"]:
        errors.append("answer_modes differ from the skill's")
    if not isinstance(problem["prompt_line_id"], str) or not problem["prompt_line_id"]:
        errors.append("prompt_line_id is empty")
    for key, value in problem["prompt_params"].items():
        # Whole numbers, or (Zone 7) an exact decimal {mantissa, scale} or fraction {num, den}.
        if not is_int(value) and not (isinstance(value, dict) and set(value) in ({"mantissa", "scale"}, {"num", "den"}) and exact_value(value) is not None):
            errors.append(f"prompt param {key!r} is not a whole number or an exact decimal: {value!r}")
    errors += _check_distractors(problem, skill, allowed_names)
    errors += _check_hints(problem)
    errors += check_visual(problem["visual"], "visual")
    errors += check_input_meta(problem)
    return errors


def _check_distractors(problem: dict, skill: dict, allowed_names: set[str]) -> list[str]:
    errors: list[str] = []
    seen: list = []
    simplest = bool(problem["meta"].get("simplest_form", False))
    for entry in problem["distractors"]:
        if set(entry) != {"value", "misconception"}:
            errors.append(f"malformed distractor {entry!r}")
            continue
        name = entry["misconception"]
        if name not in allowed_names:
            errors.append(f"unknown misconception {name!r}")
        if name not in skill["misconceptions"]:
            errors.append(f"misconception {name!r} is not listed for the skill")
        if same_answer(entry["value"], problem["answer"], simplest):
            errors.append(f"distractor equals the answer: {entry['value']!r}")
        if any(same_answer(entry["value"], earlier, simplest) for earlier in seen):
            errors.append(f"duplicate distractor value {entry['value']!r}")
        seen.append(entry["value"])
    if "tap" in problem["answer_modes"] and not problem["distractors"]:
        errors.append("a tap problem needs at least one distractor")
    return errors


def _check_hints(problem: dict) -> list[str]:
    errors: list[str] = []
    steps = problem["hint_steps"]
    if [step.get("kind") for step in steps] != list(HINT_KINDS):
        return [f"hint rungs must be {list(HINT_KINDS)}, got {[step.get('kind') for step in steps]}"]
    for number, step in enumerate(steps, start=1):
        if not isinstance(step.get("line_id"), str) or not step["line_id"]:
            errors.append(f"rung {number} has no line_id")
    if not steps[1]["visual"]:
        errors.append("rung 2 has no visual model")
    errors += check_visual(steps[1]["visual"], "rung 2 visual")
    example = steps[2].get("example")
    if not isinstance(example, dict) or not {"prompt_line_id", "prompt_params", "answer", "answer_line_id", "answer_params"} <= set(example):
        errors.append("rung 3 has no complete worked example")
    elif example["prompt_params"] == problem["prompt_params"] and example["prompt_line_id"] == problem["prompt_line_id"] and steps[2]["visual"] == problem["visual"]:
        errors.append("the worked example is the same problem")
    wanted = problem["params"].get("difficulty", 0) - 1
    if steps[3].get("easier_params", {}).get("difficulty") != wanted:
        errors.append(f"rung 4 must set difficulty to {wanted}")
    if steps[0].get("line_id") != problem["prompt_line_id"] or steps[0].get("params") != problem["prompt_params"]:
        errors.append("rung 1 must repeat the prompt with its parameters")
    return errors


def check_visual(visual: dict, where: str) -> list[str]:
    errors: list[str] = []
    if not visual:
        return errors
    kind = visual.get("type")
    if kind not in VISUAL_TYPES:
        return [f"{where}: unknown visual type {kind!r}"]
    if kind == "gem_piles":
        if not visual["piles"]:
            errors.append(f"{where}: no piles")
        for pile in visual["piles"]:
            for key in ("hundreds", "tens", "ones"):
                if not is_int(pile.get(key)) or pile[key] < 0:
                    errors.append(f"{where}: pile {key} must be a whole number of at least 0")
    elif kind == "ten_frame":
        second = visual.get("second", 0)
        if visual["count"] < 0 or second < 0 or visual["count"] + second > 10 * visual["frames"]:
            errors.append(f"{where}: count {visual['count']} + {second} does not fit {visual['frames']} frame(s)")
    elif kind == "number_line":
        low, high = visual["min"], visual["max"]
        if low >= high:
            errors.append(f"{where}: min must be below max")
        for value in visual["markers"] + visual["blanks"]:
            if not low <= value <= high:
                errors.append(f"{where}: value {value} is off the line {low}..{high}")
        if visual["labeled_every"] < 1:
            errors.append(f"{where}: labeled_every must be at least 1")
        for jump in visual.get("jumps", []):
            for end in ("from", "to"):
                if not is_int(jump.get(end)) or not low <= jump[end] <= high:
                    errors.append(f"{where}: jump {end} {jump.get(end)!r} is off the line {low}..{high}")
    elif kind == "balance":
        totals = []
        for side in ("left", "right"):
            terms = visual.get(side)
            if not isinstance(terms, list) or not 1 <= len(terms) <= 3 or not all(is_int(t) and t >= 0 for t in terms):
                return errors + [f"{where}: the {side} pan needs 1 to 3 whole numbers, got {terms!r}"]
            totals.append(sum(terms))
        tilt = visual.get("tilt")
        if tilt not in TILTS:
            errors.append(f"{where}: unknown tilt {tilt!r}")
        elif tilt != "unknown":
            expected = "level" if totals[0] == totals[1] else ("left" if totals[0] > totals[1] else "right")
            if tilt != expected:
                errors.append(f"{where}: pans of {totals[0]} and {totals[1]} should tilt {expected}, not {tilt}")
    elif kind == "array":
        for key in ("rows", "cols"):
            if not is_int(visual.get(key)) or not 1 <= visual[key] <= 10:
                errors.append(f"{where}: array {key} must be 1 to 10")
    elif kind == "groups":
        for key in ("groups", "size"):
            if not is_int(visual.get(key)) or not 1 <= visual[key] <= 10:
                errors.append(f"{where}: {key} must be 1 to 10")
    elif kind == "pairs":
        if not is_int(visual.get("count")) or not 0 <= visual["count"] <= 40:
            errors.append(f"{where}: pairs count must be 0 to 40")
    elif kind == "digits":
        digits = visual.get("digits")
        if not isinstance(digits, list) or not 1 <= len(digits) <= 4 or not all(is_int(d) and 0 <= d <= 9 for d in digits):
            errors.append(f"{where}: digits must be 1 to 4 digits from 0 to 9")
        if visual.get("focus") not in DIGIT_FOCUS:
            errors.append(f"{where}: unknown digits focus {visual.get('focus')!r}")
    elif kind == "lists":
        errors += _check_lists(visual, where)
    elif kind == "gears":
        teeth = visual.get("teeth")
        if not isinstance(teeth, list) or not 1 <= len(teeth) <= MAX_GEARS:
            return errors + [f"{where}: gears needs 1 to {MAX_GEARS} gears"]
        for count in teeth:
            if not is_int(count) or not GEAR_TEETH[0] <= count <= GEAR_TEETH[1]:
                errors.append(f"{where}: a gear has {count!r} teeth, not {GEAR_TEETH[0]} to {GEAR_TEETH[1]}")
        if "shaded" in visual and (not is_int(visual["shaded"]) or not 0 <= visual["shaded"] <= teeth[0]):
            errors.append(f"{where}: shaded must be 0 to the first gear's teeth")
    elif kind in ZONE8_VISUALS:
        errors += _check_zone8_visual(visual, where)
    else:
        errors += _check_zone7_visual(visual, where)
    return errors


def _check_lists(visual: dict, where: str) -> list[str]:
    """A `lists` picture (Zone 6): a known kind, one or two rows, marks and lit positions that exist."""
    errors: list[str] = []
    if visual.get("kind") not in LIST_KINDS:
        errors.append(f"{where}: unknown lists kind {visual.get('kind')!r}")
    rows = visual.get("rows")
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_LIST_ROWS:
        return errors + [f"{where}: lists needs 1 to {MAX_LIST_ROWS} rows"]
    shown: list = []
    for row in rows:
        items = row.get("items") if isinstance(row, dict) else None
        if not isinstance(row, dict) or not is_int(row.get("n")) or not isinstance(items, list) or not 1 <= len(items) <= MAX_LIST_ITEMS:
            errors.append(f"{where}: each row needs n and 1 to {MAX_LIST_ITEMS} items")
            continue
        if not all(is_int(item) and item >= 1 for item in items):
            errors.append(f"{where}: list items must be whole numbers above 0")
        for index in row.get("lit", []):
            if not is_int(index) or not 0 <= index < len(items):
                errors.append(f"{where}: lit position {index!r} is off the row")
        shown += items
    for value in visual.get("marked", []):
        if value not in shown:
            errors.append(f"{where}: marked {value!r} is in no row")
    return errors


def _check_zone8_meta(problem: dict) -> list[str]:
    """Zone 8 inputs can give the answer: lock and pad places, the cab's floors, the lever's range."""
    errors: list[str] = []
    meta, answer = problem["meta"], problem["answer"]
    for key in ("vault_lock", "base_pad"):
        spec = meta.get(key)
        if spec is not None and not (is_base_number(answer) and spec.get("base") == answer["base"]
                                     and len(answer["digits"]) <= spec.get("places", 0) <= MAX_PLACES):
            errors.append(f"{key}: cannot show the answer {answer!r}")
    tower = meta.get("tower")
    if tower is not None and not (is_int(answer) and 0 <= answer <= tower.get("floors", -1) <= 10):
        errors.append("tower: the cab cannot stop on the answer's floor")
    lever = meta.get("lever")
    if lever is not None and not (is_int(answer) and 0 <= answer <= lever.get("max", -1)):
        errors.append("lever: the weight range cannot hold the answer")
    digits = meta.get("pad_digits")
    if digits is not None and is_int(answer) and len(str(answer)) > digits:
        errors.append("pad_digits: the pad is too short for the answer")
    sci_pad = meta.get("sci_pad")
    if sci_pad is not None and not (is_normalized_sci(answer) and answer["exp"] <= sci_pad.get("max_exp", -1)):
        errors.append("sci_pad: the pad cannot give the answer")
    return errors


def _check_zone7_visual(visual: dict, where: str) -> list[str]:
    """The Zone 7 pictures can be drawn: shard counts, lit counts, grids, the gauge and the ore mix."""
    errors: list[str] = []
    kind = visual["type"]
    if kind == "crystals":
        crystals = visual.get("crystals")
        if not isinstance(crystals, list) or not 1 <= len(crystals) <= 2:
            return [f"{where}: crystals needs 1 or 2 crystals"]
        if visual.get("shape") not in ("crystal", "bar"):
            errors.append(f"{where}: unknown crystal shape {visual.get('shape')!r}")
        if not 0 <= visual.get("wholes", 0) <= 9:
            errors.append(f"{where}: 0 to 9 whole crystals")
        for crystal in crystals:
            den, lit, second = crystal.get("den", 0), crystal.get("lit", -1), crystal.get("second", 0)
            if not (1 <= den <= 24 and lit >= 0 and second >= 0 and lit + second <= den):
                errors.append(f"{where}: crystal {crystal} does not fit")
    elif kind == "fraction_line":
        den, wholes = visual.get("den", 0), visual.get("wholes", 0)
        marker = visual.get("marker", {})
        if den < 2 or wholes < 1 or visual.get("ticks") != den * wholes + 1:
            errors.append(f"{where}: a fraction line needs ticks = den * wholes + 1")
        elif marker.get("den") != den or not 0 <= marker.get("num", -1) <= den * wholes:
            errors.append(f"{where}: the marker {marker} is not on a tick")
    elif kind == "crystal_grid":
        cells = visual.get("cells")
        grids = visual.get("grids", [])
        if cells not in (10, 100) or not 1 <= len(grids) <= 2:
            errors.append(f"{where}: a crystal grid has 10 or 100 cells and 1 or 2 numbers")
        for grid in grids:
            if not (0 <= grid.get("lit", -1) <= (cells or 0) and 0 <= grid.get("wholes", -1) <= 9):
                errors.append(f"{where}: grid {grid} does not fit")
    elif kind == "depth_gauge":
        low, high = visual.get("min", 0), visual.get("max", 0)
        if not low < 0 < high or visual.get("labeled_every", 0) < 1:
            errors.append(f"{where}: a depth gauge runs from below 0 to above 0")
        for value in visual.get("markers", []) + [end for jump in visual.get("jumps", []) for end in (jump.get("from"), jump.get("to"))]:
            if not is_int(value) or not low <= value <= high:
                errors.append(f"{where}: {value!r} is off the gauge {low}..{high}")
    elif kind == "ore_mix":
        a, b, groups = visual.get("a", -1), visual.get("b", -1), visual.get("groups", 1)
        if a < 0 or b < 0 or not 1 <= a + b <= 72 or groups < 1 or a % groups or b % groups:
            errors.append(f"{where}: ore mix {visual} does not split into its groups")
    return errors


def _check_zone8_visual(visual: dict, where: str) -> list[str]:
    """The Zone 8 pictures can be drawn: tower floors, notation forms, cubes, lamp rows and levers."""
    errors: list[str] = []
    kind = visual["type"]
    if kind == "power_tower":
        if not (is_int(visual.get("base")) and 2 <= visual["base"] <= 12 and is_int(visual.get("exp"))
                and 0 <= visual["exp"] <= 10 and isinstance(visual.get("values"), bool)):
            errors.append(f"{where}: a power tower needs base 2..12, 0..10 floors and values true/false")
    elif kind == "notation":
        form = visual.get("form")
        if form == "power":
            if not (is_int(visual.get("base")) and is_int(visual.get("exp")) and visual["base"] >= 0 and visual["exp"] >= 0):
                errors.append(f"{where}: a power needs a base and an exponent")
        elif form == "root":
            n = visual.get("n")
            if not is_int(n) or n < 1 or math.isqrt(n) ** 2 != n:
                errors.append(f"{where}: a root card shows only perfect squares, got {n!r}")
        elif form == "sci":
            if not is_normalized_sci({k: visual.get(k) for k in ("mantissa", "scale", "exp")}):
                errors.append(f"{where}: a scientific-notation card must be normalized")
        else:
            errors.append(f"{where}: unknown notation form {form!r}")
    elif kind == "cube_blocks":
        if not is_int(visual.get("n")) or not 1 <= visual["n"] <= 8:
            errors.append(f"{where}: a cube of blocks is 1 to 8 a side")
    elif kind == "lamps":
        base, places, rows = visual.get("base"), visual.get("places"), visual.get("rows")
        if not (is_int(base) and 2 <= base <= 10 and is_int(places) and 1 <= places <= MAX_PLACES
                and visual.get("style") in ("lamps", "dials", "digits")):
            return [f"{where}: lamps need base 2..10, 1..{MAX_PLACES} places and a known style"]
        if not isinstance(rows, list) or not 1 <= len(rows) <= 3:
            return [f"{where}: lamps show 1 to 3 rows"]
        for row in rows:
            if not isinstance(row, list) or len(row) > places or not all(is_int(d) and 0 <= d < base for d in row):
                errors.append(f"{where}: the row {row!r} does not fit {places} base-{base} places")
    elif kind == "lever":
        moments = []
        for side in ("left", "right"):
            hook = visual.get(side)
            if not isinstance(hook, dict) or not (is_int(hook.get("w")) and 0 <= hook["w"] <= 64 and is_int(hook.get("d")) and 1 <= hook["d"] <= 8):
                return [f"{where}: the {side} weight must hang 1..8 steps out and weigh 0..64"]
            moments.append(hook["w"] * hook["d"])
        tilt = visual.get("tilt")
        if tilt not in TILTS:
            errors.append(f"{where}: unknown tilt {tilt!r}")
        elif tilt != "unknown":
            expected = "level" if moments[0] == moments[1] else ("left" if moments[0] > moments[1] else "right")
            if tilt != expected:
                errors.append(f"{where}: moments {moments} should tilt {expected}, not {tilt}")
    return errors


def is_normalized_sci(value: object) -> bool:
    """{mantissa, scale, exp} with 1 <= mantissa / 10^scale < 10 and no trailing zero after the point."""
    if not isinstance(value, dict) or set(value) != {"mantissa", "scale", "exp"}:
        return False
    mantissa, scale, exp = value["mantissa"], value["scale"], value["exp"]
    if not (is_int(mantissa) and is_int(scale) and is_int(exp)) or scale < 0 or mantissa <= 0:
        return False
    if scale > 0 and mantissa % 10 == 0:
        return False
    return 1 <= Fraction(mantissa, 10 ** scale) < 10


def is_base_number(value: object, canonical: bool = True) -> bool:
    """{base, digits}: base 2..10, digits below the base, and (canonical) no leading zero."""
    if not isinstance(value, dict) or set(value) != {"base", "digits"}:
        return False
    base, digits = value["base"], value["digits"]
    if not is_int(base) or not 2 <= base <= 10 or not isinstance(digits, list) or not digits:
        return False
    if not all(is_int(d) and 0 <= d < base for d in digits):
        return False
    return not canonical or len(digits) == 1 or digits[0] != 0


def filtered(answer: object, candidates: list[tuple[str, object]], allowed: set[str] | None = None,
             allow_negative: bool = False) -> list[tuple[str, object]]:
    """The wrong answers a generator keeps from `candidates` (name, value) in order: none equal to the
    answer or to an earlier one, no negative whole number, and (with `allowed`) only listed names."""
    kept: list[tuple[str, object]] = []
    for name, value in candidates:
        if allowed is not None and name not in allowed:
            continue
        if is_int(value) and value < 0 and not allow_negative:
            continue
        if same_answer(value, answer) or any(same_answer(value, earlier) for _, earlier in kept):
            continue
        kept.append((name, value))
    return kept


def distractor_pairs(problem: dict) -> list[tuple[str, object]]:
    """The problem's (misconception, value) pairs in order."""
    return [(entry["misconception"], entry["value"]) for entry in problem["distractors"]]


def label_key(value: object) -> str:
    """The key an answer value has in meta.label_lines (see Problem.label_key in GDScript)."""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def sort_key(value: object) -> tuple:
    """Numbers before text, each in natural order: the order of an unordered tile answer."""
    return (0, value, "") if is_int(value) else (1, 0, str(value))


def check_input_meta(problem: dict) -> list[str]:
    """The meta keys that pick the answer input must agree with the answer and distractors."""
    errors: list[str] = []
    meta = problem["meta"]
    values = [problem["answer"]] + [entry["value"] for entry in problem["distractors"]]
    board = meta.get("tile_board")
    if board is not None:
        tiles, slots = board.get("tiles", []), board.get("slots")
        if not is_int(slots) or not slots <= len(tiles) <= 8:
            errors.append(f"tile board: {len(tiles)} tiles for {slots} slots (needs slots..8)")
        if len(tiles) != len({repr(t) for t in tiles}):
            errors.append("tile board: a tile is listed twice")
        for value in values:
            if not isinstance(value, list) or len(value) != slots:
                errors.append(f"tile board: {value!r} must fill exactly {slots} slots")
                continue
            spare = list(tiles)
            for item in value:
                if item in spare:
                    spare.remove(item)
                else:
                    errors.append(f"tile board: {value!r} needs a tile {item!r} that is not on the board")
            if not board.get("ordered", True) and value != sorted(value, key=sort_key):
                errors.append(f"tile board: unordered answer {value!r} is not sorted")
    builder = meta.get("array_builder")
    if builder is not None:
        for value in values:
            if not isinstance(value, dict) or set(value) != {"rows", "cols"}:
                errors.append(f"array builder: {value!r} must be {{rows, cols}}")
            elif not (1 <= value["rows"] <= builder["max_rows"] and 1 <= value["cols"] <= builder["max_cols"]):
                errors.append(f"array builder: {value!r} does not fit {builder['max_rows']}x{builder['max_cols']}")
    grid = meta.get("sieve_grid")
    if grid is not None:
        for value in values:
            if not isinstance(value, list) or not all(is_int(v) and 1 <= v <= grid.get("size", 0) for v in value):
                errors.append(f"sieve grid: {value!r} must be rocks of the {grid.get('size')}-rock grid")
    tree = meta.get("factor_tree")
    if tree is not None:
        for value in values:
            if not isinstance(value, list) or not value or not all(is_int(v) and v >= 1 for v in value):
                errors.append(f"factor tree: {value!r} must be a list of pieces")
    bench = meta.get("gear_bench")
    if bench is not None:
        tray = bench.get("tray", [])
        if not isinstance(tray, list) or tray != sorted(tray) or len(tray) != len(values):
            errors.append("gear bench: the tray must hold the answer and every wrong gear, smallest first")
        for value in values:
            if value not in tray:
                errors.append(f"gear bench: gear {value!r} is not in the tray")
    crystal = meta.get("crystal")
    if crystal is not None:
        den = crystal.get("den", 0)
        if not 2 <= den <= TAP_SHARDS:
            errors.append(f"crystal: a crystal to tap has 2 to {TAP_SHARDS} shards, got {den}")
        elif not any(same_answer({"num": lit, "den": den}, problem["answer"]) for lit in range(den + 1)):
            errors.append("crystal: no way of lighting the shards gives the answer")
    mixer = meta.get("alloy")
    if mixer is not None and not (is_int(problem["answer"]) and 0 <= problem["answer"] <= mixer.get("max", -1)):
        errors.append("alloy: the tin hopper cannot hold the answer")
    ride = meta.get("depth_gauge")
    if ride is not None and not (is_int(problem["answer"]) and ride["min"] <= problem["answer"] <= ride["max"] and ride["min"] <= ride["start"] <= ride["max"]):
        errors.append("depth gauge: the cab cannot ride to the answer")
    errors += _check_zone8_meta(problem)
    labels = meta.get("label_lines")
    if labels is not None:
        for value in values:
            if label_key(value) not in labels:
                errors.append(f"no label line for answer {label_key(value)!r}")
    return errors
