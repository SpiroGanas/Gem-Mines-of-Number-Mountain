"""Checks every exported problem must pass whatever the skill (structure, distractors, hints,
visuals). Independent of the GDScript generators; see checkers/__init__.py."""
from __future__ import annotations

from fractions import Fraction

REQUIRED_KEYS = (
    "skill_id", "seed", "representation", "prompt_line_id", "prompt_params", "answer",
    "answer_modes", "distractors", "visual", "hint_steps", "params", "meta",
)
HINT_KINDS = ("repeat_highlight", "visual_model", "worked_example", "easier_problem")
VISUAL_TYPES = ("gem_piles", "ten_frame", "number_line", "balance", "array", "groups", "pairs", "digits",
                "lists", "gears",
                "crystals", "fraction_line", "crystal_grid", "depth_gauge", "ore_mix",
                "pattern", "figurate", "pairing", "fib_squares", "proof", "poem_shape")
# Zone 9 picture limits (Problem in scripts/core/problem.gd draws within these).
MAX_PATTERN_TERMS = 6
MAX_FIGURATE_N = 20
PAIRING_RANGE = (2, 100)
MAX_FIB_SQUARES = 8
FIGURATE_KINDS = ("triangle", "square", "two_triangles")
WALL_TILES = (2, 6)
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
    elif kind in ("pattern", "figurate", "pairing", "fib_squares", "proof", "poem_shape"):
        errors += _check_zone9_visual(visual, where)
    else:
        errors += _check_zone7_visual(visual, where)
    return errors


def _check_zone9_visual(visual: dict, where: str) -> list[str]:
    """The Zone 9 pictures can be drawn: tile rows that fit, known figures, Fibonacci squares in order."""
    errors: list[str] = []
    kind = visual["type"]
    if kind == "pattern":
        terms = visual.get("terms", [])
        if not isinstance(terms, list) or not 1 <= len(terms) <= MAX_PATTERN_TERMS or not all(is_int(t) and t >= 0 for t in terms):
            return [f"{where}: a pattern row has 1 to {MAX_PATTERN_TERMS} whole numbers"]
        if any(not is_int(b) or not 0 <= b < len(terms) for b in visual.get("blanks", [])):
            errors.append(f"{where}: a blank is off the row")
        if visual.get("style") not in ("crystals", "numbers"):
            errors.append(f"{where}: unknown pattern style {visual.get('style')!r}")
        if "steps" in visual and (len(visual["steps"]) != len(terms) - 1 or visual.get("step_op") not in ("plus", "times")):
            errors.append(f"{where}: steps go between the tiles, plus or times")
        if "figure" in visual and (visual["figure"] not in ("triangle", "square") or visual.get("first_index", 0) < 1):
            errors.append(f"{where}: a figure row is triangles or squares from index 1")
    elif kind == "figurate":
        if visual.get("kind") not in FIGURATE_KINDS or not is_int(visual.get("n")) or not 1 <= visual["n"] <= MAX_FIGURATE_N:
            errors.append(f"{where}: figurate {visual} is not a known kind of size 1 to {MAX_FIGURATE_N}")
    elif kind == "pairing":
        if not is_int(visual.get("n")) or not PAIRING_RANGE[0] <= visual["n"] <= PAIRING_RANGE[1]:
            errors.append(f"{where}: pairing n must be {PAIRING_RANGE[0]} to {PAIRING_RANGE[1]}")
    elif kind == "fib_squares":
        terms = visual.get("terms", [])
        if not 2 <= len(terms) <= MAX_FIB_SQUARES or any(terms[i] != terms[i - 1] + terms[i - 2] for i in range(2, len(terms))):
            errors.append(f"{where}: {terms} are not 2 to {MAX_FIB_SQUARES} Fibonacci numbers in order")
    elif kind == "proof":
        if not isinstance(visual.get("diagram"), str) or not is_int(visual.get("n")) or visual["n"] < 1 or not isinstance(visual.get("fitted"), bool):
            errors.append(f"{where}: proof picture {visual} is malformed")
    elif kind == "poem_shape":
        lines = visual.get("lines", [])
        if not lines or not is_int(visual.get("highlight")) or not 0 <= visual["highlight"] < len(lines):
            errors.append(f"{where}: the poem shape's lit line is off the poem")
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
    wall = meta.get("pattern_wall")
    if wall is not None:
        terms, tiles = wall.get("terms", []), wall.get("tiles", [])
        if terms.count(None) != 1 or len(terms) > MAX_PATTERN_TERMS:
            errors.append(f"pattern wall: exactly one gap in at most {MAX_PATTERN_TERMS} tiles")
        if not WALL_TILES[0] <= len(tiles) <= WALL_TILES[1] or tiles != sorted(tiles) or len(set(tiles)) != len(tiles):
            errors.append("pattern wall: 2 to 6 different tiles, smallest first")
        for value in values:
            if not is_int(value) or value not in tiles:
                errors.append(f"pattern wall: {value!r} is not a tile")
    board = meta.get("proof_board")
    if board is not None:
        if board.get("choices") != sorted(values) or board.get("diagram") != problem["answer"]:
            errors.append("proof board: the choices are the answer and every wrong answer, sorted, around the answer's diagram")
        if "label_lines" not in meta:
            errors.append("proof board: the choices need label lines")
    label_line = meta.get("label_line")
    if label_line is not None and not (isinstance(label_line, str) and label_line.count(".") >= 2):
        errors.append(f"label_line {label_line!r} is not a line id")
    labels = meta.get("label_lines")
    if labels is not None:
        for value in values:
            if label_key(value) not in labels:
                errors.append(f"no label line for answer {label_key(value)!r}")
    return errors
