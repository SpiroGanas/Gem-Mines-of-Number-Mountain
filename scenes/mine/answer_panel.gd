## The answer side of the problem panel: the problem's picture plus the right way to answer it.
##
## The input is the first of the skill's answer modes (in the order the skill lists them, GDD
## section 4) that the problem can be answered with (choose_input is pure and tested):
##   TAP_PILE    tap one of the piles in the picture (which pile has more)
##   BOARD       build with ten-bars and one-gems on the BuildBoard (build, regroup)
##   CHOICES     big answer buttons: the answer plus named wrong answers, shuffled
##   NUMBER_PAD  the on-screen number pad (write the numeral, sums and differences)
##   TILES       drag tiles into slots on the TileBoard (number strips, ordering, fact families)
##   ARRAY       drag or tap out rows and columns on the ArrayBuilder (build an array)
##   SPLIT       drag the pickaxe to a split point on the BoulderSplit rail (Zone 4, meta.boulder_split)
##   SIEVE       tap rocks on the Sieve of Eratosthenes grid to cross them out, then Done (Zone 5,
##               meta.sieve_grid)
##   TREE        build a factor tree by splitting pieces with the pickaxe, then Done (Zone 5,
##               meta.factor_tree)
##   GEAR        drag a gear from the tray onto the empty axle of the gear bench, watch it turn, then
##               Go (Zone 6, meta.gear_bench)
##   SLATE       write the number with a finger or stylus on the ChalkSlate (Phase 2), one digit per
##               box. Takes the number pad's place when the skill lists the `handwriting` mode, the
##               device can read handwriting (DigitInk.is_available), a grown-up has not turned it off
##               and the answer is a whole number of one to three digits. Otherwise the number pad.
## Zone 7 (Phase 4, Sprint 32-33) adds:
##   FRACTION_PAD   the fraction pad (top over bottom) for a fraction answer, the slate's fallback
##   DECIMAL_PAD    the same pad with a fixed point for a decimal answer (meta.decimal_places)
##   FRACTION_SLATE the two-row slate (skill mode `handwriting_fraction`), numerator over denominator
##   DECIMAL_SLATE  the slate with a fixed point (skill mode `handwriting`)
##   CRYSTAL        tap shards of a crystal to light them, then Done (meta.crystal)
##   ALLOY          the alloy mixer: set the tin scoops, then Mix (meta.alloy)
##   GAUGE          ride the elevator cab up and down the depth gauge, then Stop here (meta.depth_gauge)
## A problem that carries a zone mechanic (crystal, alloy, depth_gauge) and lists `tap` is answered on
## the mechanic. The number pad gets a minus key when meta.signed is set (depths below zero).
## Zone 8 (Phase 4, Sprints 35-37) adds:
##   VAULT      the vault lock: tap lamps or turn dials, then Open (meta.vault_lock)
##   TOWER      the tower elevator: ride to a floor, then Stop here (meta.tower)
##   LEVER      the counterweight lever: set the weight with More and Less, then Balance (meta.lever)
##   SCI_PAD    the scientific-notation pad for a {mantissa, scale, exp} answer
##   BASE_PAD   the base pad (keys 0 to base - 1) for a {base, digits} answer
##   KEYBOARD   Scholar mode's keyboard entry: replaces a pad (or the slate) when ModeGate's
##              KEYBOARD_ENTRY is on for the child and the skill lists `keyboard`; "Use the pad" brings
##              the pad back. The number pad takes meta.pad_digits digits (powers of 10 need 7).
## Zone 9 (Phase 4, Sprint 40) adds, under the `drag` mode:
##   PATTERN     the pattern wall: drag a crystal tile into the gap of the row, then Done (meta.pattern_wall)
##   PROOF       the proof board: fit the loose piece into place, then tap the fact it shows (meta.proof_board)
## and answer buttons that read a line with the number (meta.label_line, "Add 4") or a Fib poem line's
## words (meta.array_label "words"). meta.pad_digits widens the number pad (Gauss's sums up to 5050).
## Zone 10 (Phase 5) adds, under the `drag` mode:
##   TRACK       the circular track: tap the station where the cart stops (meta.circular_track)
##   DIAL        the clock lock: point the dial at the mark the turns end on, then Set (meta.clock_lock)
##   TABLE       the mixing table: tap the number that does nothing, then Done (meta.mixing_table)
## Zone 11 (Phase 5) adds, under the `drag` mode:
##   WHEEL       the cipher wheel: turn it until the code spells a word, then Set (meta.cipher_wheel)
##   COINS       the coin puzzle: More and Less on each pile, then Done (meta.coin_puzzle)
## Whatever the child gives comes out of `answered`; the panel never decides if it is right.
## From hint rung 2 the panel also shows the problem's picture model, and from rung 3 a solved
## "friend" of the problem (show_hint).
class_name AnswerPanel
extends VBoxContainer

## The child gave an answer. `given` is in the problem's canonical answer shape.
signal answered(given: Variant)
## The child said "Try again" to the slate's "Did you write 47?". Not a wrong answer: the mine logs it
## apart and the dig goes on.
signal rejected
## A digit written on the slate was accepted; `mirrored` when it was written backwards.
signal digit_written(digit: int, mirrored: bool)

enum InputKind { NONE, TAP_PILE, BOARD, CHOICES, NUMBER_PAD, TILES, ARRAY, SLATE, SPLIT, SIEVE, TREE, GEAR, FRACTION_PAD, DECIMAL_PAD, FRACTION_SLATE, DECIMAL_SLATE, CRYSTAL, ALLOY, GAUGE, VAULT, TOWER, LEVER, SCI_PAD, BASE_PAD, KEYBOARD, PATTERN, PROOF, TRACK, DIAL, TABLE, WHEEL, COINS }

## The inputs a typed answer can take, which keyboard entry replaces in Scholar mode.
const TYPED_KINDS: Array[InputKind] = [InputKind.NUMBER_PAD, InputKind.SLATE, InputKind.FRACTION_PAD, InputKind.DECIMAL_PAD, InputKind.FRACTION_SLATE, InputKind.DECIMAL_SLATE, InputKind.SCI_PAD, InputKind.BASE_PAD]

const BOARD_SCENE: PackedScene = preload("res://scenes/input/build_board.tscn")
const CHOICES_SCENE: PackedScene = preload("res://scenes/input/choice_buttons.tscn")
const PAD_SCENE: PackedScene = preload("res://scenes/input/number_pad.tscn")
const TILES_SCENE: PackedScene = preload("res://scenes/input/tile_board.tscn")
const ARRAY_SCENE: PackedScene = preload("res://scenes/input/array_builder.tscn")
const SPLIT_SCENE: PackedScene = preload("res://scenes/mine/boulder_split/boulder_split.tscn")
const SIEVE_SCENE: PackedScene = preload("res://scenes/zones/z05_prime_caverns/sieve_grid.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/zones/z05_prime_caverns/factor_tree.tscn")
const GEAR_SCENE: PackedScene = preload("res://scenes/zones/z06_gear_works/gear_bench.tscn")
const SLATE_SCENE: PackedScene = preload("res://scenes/input/chalk_slate/chalk_slate.tscn")
const VISUAL_SCENE: PackedScene = preload("res://scenes/mine/visual_model.tscn")
const FRACTION_PAD_SCENE: PackedScene = preload("res://scenes/input/fraction_pad.tscn")
const CRYSTAL_SCENE: PackedScene = preload("res://scenes/zones/z07_crystal_shards/crystal.tscn")
const ALLOY_SCENE: PackedScene = preload("res://scenes/zones/z07_crystal_shards/alloy_mixer.tscn")
const GAUGE_SCENE: PackedScene = preload("res://scenes/zones/z07_crystal_shards/depth_gauge.tscn")
const VAULT_SCENE: PackedScene = preload("res://scenes/zones/z08_power_tower/vault_lock.tscn")
const TOWER_SCENE: PackedScene = preload("res://scenes/zones/z08_power_tower/tower_elevator.tscn")
const LEVER_SCENE: PackedScene = preload("res://scenes/zones/z08_power_tower/counterweight.tscn")
const POWER_PAD_SCENE: PackedScene = preload("res://scenes/input/power_pad.tscn")
const KEYBOARD_SCENE: PackedScene = preload("res://scenes/input/keyboard_entry.tscn")
const PATTERN_SCENE: PackedScene = preload("res://scenes/zones/z09_pattern_grotto/pattern_wall.tscn")
const PROOF_SCENE: PackedScene = preload("res://scenes/zones/z09_pattern_grotto/proof_board.tscn")
const TRACK_SCENE: PackedScene = preload("res://scenes/zones/z10_clockwork_depths/circular_track.tscn")
const DIAL_SCENE: PackedScene = preload("res://scenes/zones/z10_clockwork_depths/clock_lock.tscn")
const TABLE_SCENE: PackedScene = preload("res://scenes/zones/z10_clockwork_depths/mixing_table.tscn")
const WHEEL_SCENE: PackedScene = preload("res://scenes/zones/z11_cipher_vault/cipher_wheel.tscn")
const COINS_SCENE: PackedScene = preload("res://scenes/zones/z11_cipher_vault/coin_puzzle.tscn")
## The number pad's digits unless meta.pad_digits asks for more (Zones 8 and 9).
const PAD_DIGITS: int = 3
## The slate and the pad take fractions with up to this many digits in the top and in the bottom.
const FRACTION_BOXES: int = 2
## The picture beside the fraction and decimal pads and slates is narrower than beside the number pad
## (in touch targets), so picture, boxes and keys fit beside Bolt at 16:9.
const FRACTION_VISUAL_WIDTH: float = 4.0
## Inputs whose worked-example card (hint rung 3) also draws the friend problem's picture: the card
## stands where the problem's picture was. The others (tappable piles, which are the picture, and the
## tall zone mechanics) get the card's two lines of text only, so the input stays on the screen.
const EXAMPLE_PICTURE_KINDS: Array[InputKind] = [InputKind.CHOICES, InputKind.NUMBER_PAD, InputKind.SLATE, InputKind.TILES]
## How often a blind guess is right when the answer is typed or built rather than picked from a
## few options (a random number on the pad, a random pile on the board). Used by the adaptive
## engine's guessing guard; deliberately generous.
const FREE_RESPONSE_CHANCE: float = 0.05
## The answer buttons show the answer and at most this many distractors.
const MAX_CHOICE_DISTRACTORS: int = 3

var problem: Problem
var input_kind: InputKind = InputKind.NONE
## Tests set this to true or false to decide the slate without asking the device; null asks
## DigitInk.is_available() and the device setting.
var slate_override: Variant = null
## The reader for the slate; null uses DigitInk.make_recognizer(). Tests inject a FakeRecognizer.
var recognizer: Recognizer
## Tests set this to true or false to decide keyboard entry without the profile and the device; null
## asks ScholarMode (Scholar mode on and a key pressed this session).
var keyboard_override: Variant = null
## The number pad's wide layout (three rows of keys, NumberPad.wide) even on a tablet: hosts with less
## height than the mine (the workshop's problem card) set it. Phones always get it.
var wide_pad: bool = false

var _visual: VisualModel
var _hint_visual: VisualModel
var _board: BuildBoard
var _choices: ChoiceButtons
var _pad: NumberPad
var _pad_row: HBoxContainer
var _tiles: TileBoard
var _array: ArrayBuilder
var _slate: ChalkSlate
var _split: BoulderSplit
var _sieve: SieveGrid
var _tree: FactorTree
var _gear_bench: GearBench
var _fraction_pad: FractionPad
var _crystal: CrystalPicker
var _alloy: AlloyMixer
var _gauge: DepthGauge
var _vault: VaultLockPicker
var _tower: TowerElevator
var _lever: CounterweightLever
var _power_pad: PowerPad
var _keyboard: KeyboardEntry
var _pattern_wall: PatternWall
var _proof_board: ProofBoard
var _track: CircularTrack
var _dial: ClockLock
var _table: MixingTable
var _wheel: CipherWheel
var _coins: CoinPuzzle
var _example: PanelContainer
var _enabled: bool = false


## Which input fits a problem: the first listed answer mode this panel can serve. Pure.
static func choose_input(for_problem: Problem, slate_allowed: bool = false, keyboard_allowed: bool = false) -> InputKind:
	var kind: InputKind = _first_input(for_problem, slate_allowed)
	if keyboard_allowed and TYPED_KINDS.has(kind) and for_problem.answer_modes.has(&"keyboard"):
		return InputKind.KEYBOARD # Scholar mode: type it on the keyboard (the pad is one tap away)
	return kind


static func _first_input(for_problem: Problem, slate_allowed: bool) -> InputKind:
	if for_problem.answer_modes.has(&"tap"):
		var mechanic: InputKind = _mechanic_for(for_problem)
		if mechanic != InputKind.NONE:
			return mechanic
	for mode: StringName in for_problem.answer_modes:
		var kind: InputKind = _input_for_mode(mode, for_problem, slate_allowed)
		if kind != InputKind.NONE:
			return kind
	return InputKind.CHOICES if not for_problem.distractors.is_empty() else InputKind.NUMBER_PAD


## True when the slate could take this problem's answer: the skill lists `handwriting` and the answer
## is a whole number of one to three digits (or, Zone 7, a decimal; a fraction needs
## `handwriting_fraction` and fits in FRACTION_BOXES digits top and bottom).
static func slate_fits(for_problem: Problem) -> bool:
	if Rational.is_fraction(for_problem.answer):
		var digits: Dictionary = for_problem.fraction_digits()
		return for_problem.answer_modes.has(&"handwriting_fraction") and not digits.is_empty() and int(digits["num"]) <= FRACTION_BOXES and int(digits["den"]) <= FRACTION_BOXES
	if Rational.is_decimal(for_problem.answer):
		return for_problem.answer_modes.has(&"handwriting") and int(for_problem.answer["mantissa"]) >= 0
	return for_problem.answer_modes.has(&"handwriting") and for_problem.answer is int and for_problem.answer_digits() >= 1 and for_problem.answer_digits() <= 3


## The zone mechanic a problem's meta asks for (Zone 7), or NONE.
static func _mechanic_for(for_problem: Problem) -> InputKind:
	if for_problem.meta.has("crystal"):
		return InputKind.CRYSTAL
	if for_problem.meta.has("alloy"):
		return InputKind.ALLOY
	if for_problem.meta.has("depth_gauge"):
		return InputKind.GAUGE
	if for_problem.meta.has("vault_lock"):
		return InputKind.VAULT
	if for_problem.meta.has("tower"):
		return InputKind.TOWER
	if for_problem.meta.has("lever"):
		return InputKind.LEVER
	return InputKind.NONE


## Whether this device offers the slate now: it can read handwriting and a grown-up has not turned it off.
func slate_wanted() -> bool:
	if slate_override != null:
		return bool(slate_override)
	return DigitInk.is_available() and DeviceSettings.shared().handwriting_enabled()


## Whether keyboard entry takes the pad's place now (Scholar mode, Sprint 37): ModeGate's KEYBOARD_ENTRY
## for the child playing, which needs a real key press this session.
func keyboard_wanted() -> bool:
	if keyboard_override != null:
		return bool(keyboard_override)
	return ScholarMode.is_on(ModeGate.Feature.KEYBOARD_ENTRY)


static func _input_for_mode(mode: StringName, for_problem: Problem, slate_allowed: bool) -> InputKind:
	match mode:
		&"tap":
			if for_problem.meta.get("tap_target") == "pile":
				return InputKind.TAP_PILE
			if for_problem.meta.has("sieve_grid"):
				return InputKind.SIEVE
			if not for_problem.distractors.is_empty():
				return InputKind.CHOICES
		&"drag":
			if for_problem.meta.has("tools"):
				return InputKind.BOARD
			if for_problem.meta.has("tile_board"):
				return InputKind.TILES
			if for_problem.meta.has("array_builder"):
				return InputKind.ARRAY
			if for_problem.meta.has("boulder_split"):
				return InputKind.SPLIT
			if for_problem.meta.has("factor_tree"):
				return InputKind.TREE
			if for_problem.meta.has("gear_bench"):
				return InputKind.GEAR
			if for_problem.meta.has("pattern_wall"):
				return InputKind.PATTERN
			if for_problem.meta.has("proof_board"):
				return InputKind.PROOF
			if for_problem.meta.has("circular_track"):
				return InputKind.TRACK
			if for_problem.meta.has("clock_lock"):
				return InputKind.DIAL
			if for_problem.meta.has("mixing_table"):
				return InputKind.TABLE
			if for_problem.meta.has("cipher_wheel"):
				return InputKind.WHEEL
			if for_problem.meta.has("coin_puzzle"):
				return InputKind.COINS
		&"number_pad", &"keyboard":
			if for_problem.answer is int:
				# writing the number replaces typing it where the skill allows `handwriting`
				return InputKind.SLATE if slate_allowed and slate_fits(for_problem) else InputKind.NUMBER_PAD
			if Rational.is_fraction(for_problem.answer):
				return InputKind.FRACTION_SLATE if slate_allowed and slate_fits(for_problem) else InputKind.FRACTION_PAD
			if Rational.is_decimal(for_problem.answer):
				return InputKind.DECIMAL_SLATE if slate_allowed and slate_fits(for_problem) else InputKind.DECIMAL_PAD
			if Notation.is_sci(for_problem.answer):
				return InputKind.SCI_PAD
			if Notation.is_base_number(for_problem.answer):
				return InputKind.BASE_PAD
	return InputKind.NONE


## How likely a blind guess is to be right with the input this problem gets, after `eliminated`
## options were already tried and missed on this rock. Pure; the adaptive engine weighs evidence
## by it, so tapping one of two piles counts for less than typing a number.
static func chance_for(for_problem: Problem, eliminated: int = 0) -> float:
	var options: int = 0
	match choose_input(for_problem):
		InputKind.TAP_PILE:
			options = for_problem.visual.get("piles", []).size()
		InputKind.CHOICES:
			options = mini(for_problem.distractors.size(), MAX_CHOICE_DISTRACTORS) + 1
		InputKind.TILES:
			return tile_chance(for_problem.meta["tile_board"])
		InputKind.ARRAY:
			var limits: Dictionary = for_problem.meta["array_builder"]
			return 1.0 / float(maxi(int(limits["max_rows"]) * int(limits["max_cols"]), 1))
		InputKind.SPLIT:
			var spec: Dictionary = for_problem.meta["boulder_split"]
			var factors: Array[int] = []
			for factor: Variant in spec.get("factors", []):
				factors.append(int(factor))
			return 1.0 / float(maxi(BoulderSplit.pairs_for(int(spec["value"]), factors).size(), 1))
		InputKind.GEAR:
			return 1.0 / float(maxi(for_problem.meta["gear_bench"].get("tray", []).size() - eliminated, 1))
		InputKind.PATTERN:
			options = for_problem.meta["pattern_wall"].get("tiles", []).size()
		InputKind.PROOF:
			options = for_problem.meta["proof_board"].get("choices", []).size()
		InputKind.TRACK:
			options = int(for_problem.meta["circular_track"]["n"]) # one tap on any of the stations
		InputKind.DIAL:
			options = int(for_problem.meta["clock_lock"]["n"])
		InputKind.TABLE:
			options = int(for_problem.meta["mixing_table"]["n"])
		InputKind.WHEEL:
			options = int(for_problem.meta["cipher_wheel"]["max"]) # a shift of 1 to max
		InputKind.COINS:
			options = (int(for_problem.meta["coin_puzzle"]["max"]) + 1) * (int(for_problem.meta["coin_puzzle"]["max"]) + 1)
		InputKind.CRYSTAL:
			options = int(for_problem.meta["crystal"]["den"]) + 1 # light 0 to den shards
		InputKind.ALLOY:
			options = int(for_problem.meta["alloy"]["max"]) + 1
		InputKind.GAUGE:
			var ride: Dictionary = for_problem.meta["depth_gauge"]
			options = int(ride["max"]) - int(ride["min"]) + 1
		InputKind.VAULT:
			var lock: Dictionary = for_problem.meta["vault_lock"]
			options = Notation.power(int(lock["base"]), int(lock["places"])) # every setting of the places
		InputKind.TOWER:
			options = int(for_problem.meta["tower"]["floors"]) + 1
		InputKind.LEVER:
			options = int(for_problem.meta["lever"]["max"]) + 1
		_:
			return FREE_RESPONSE_CHANCE
	return 1.0 / float(maxi(options - eliminated, 1))


## The chance that tiles dropped into the slots at random are right: one arrangement out of all the
## ordered (or, when order does not matter, unordered) ways to fill the slots from the pool.
static func tile_chance(board: Dictionary) -> float:
	var pool: int = board.get("tiles", []).size()
	var slots: int = int(board.get("slots", 1))
	var ways: float = 1.0
	for index: int in slots:
		ways *= float(pool - index)
	if not board.get("ordered", true):
		for index: int in range(2, slots + 1):
			ways /= float(index)
	return 1.0 / maxf(ways, 1.0)


## The attempt log's answer_mode for the input a problem gets without the slate: tap, drag or number_pad.
static func answer_mode_for(for_problem: Problem) -> StringName:
	return answer_mode_for_kind(choose_input(for_problem))


## The attempt log's answer_mode for an input: tap, drag, number_pad or handwriting.
static func answer_mode_for_kind(kind: InputKind) -> StringName:
	match kind:
		InputKind.TAP_PILE, InputKind.CHOICES, InputKind.SIEVE, InputKind.CRYSTAL, InputKind.ALLOY, InputKind.GAUGE, InputKind.VAULT, InputKind.TOWER, InputKind.LEVER:
			return &"tap"
		InputKind.NUMBER_PAD, InputKind.FRACTION_PAD, InputKind.DECIMAL_PAD, InputKind.SCI_PAD, InputKind.BASE_PAD:
			return &"number_pad"
		InputKind.KEYBOARD:
			return &"keyboard"
		InputKind.SLATE, InputKind.DECIMAL_SLATE:
			return &"handwriting"
		InputKind.FRACTION_SLATE:
			return &"handwriting_fraction"
	return &"drag"


## The text on an answer button: numerals, symbols, "30 + 4" for expanded form and "62, 64" for lists.
static func label_for(value: Variant, for_problem: Problem) -> String:
	var words: Dictionary = for_problem.meta.get("label_lines", {})
	if words.has(Problem.label_key(value)):
		return Text.get_line(StringName(words[Problem.label_key(value)])) # "True", "Even"...
	if value is Array:
		if for_problem.meta.get("array_label") == "words":
			return poem_line_text(value) # a Fib poem line (Zone 9)
		if for_problem.meta.get("array_label") == "coins" and value.size() == 2:
			return Text.get_line(&"z11.coins.pair", {"x": int(value[0]), "y": int(value[1])}) # "2 and 1" (Zone 11)
		var parts: PackedStringArray = PackedStringArray()
		for item: Variant in value:
			parts.append(str(item))
		var joiner: String = ", "
		match for_problem.meta.get("array_label"):
			"sum":
				joiner = " + "
			"product":
				joiner = " × "

		return joiner.join(parts)
	if for_problem.meta.has("label_line") and value is int:
		return Text.get_line(StringName(str(for_problem.meta["label_line"])), {"n": value}) # "Add 4" (Zone 9)
	if for_problem.meta.get("percent", false) and value is int:
		return Text.display_value(value) + "%"
	if Notation.is_notation(value):
		return Notation.text(value) # "3 × 3 × 3 × 3", binary "1101" (Zone 8)
	return Text.display_value(value) # numerals, "3/4" and "2 : 3" (Zone 6 on), "2 1/3", "0.25", "−15" (Zone 7)


## The words of a Fib poem line as the child reads them, from the text table: "glowing crystal".
static func poem_line_text(words: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for word: Variant in words:
		parts.append(Text.get_line(PoemWords.line_id(str(word))))
	return " ".join(parts)


## Builds the picture and the input for a problem. `rng` shuffles the answer buttons.
func setup(new_problem: Problem, rng: RandomNumberGenerator) -> void:
	_clear()
	problem = new_problem
	input_kind = choose_input(problem, slate_wanted(), keyboard_wanted())
	add_theme_constant_override(&"separation", UI.spacing(32)) # half the gaps on a phone
	alignment = BoxContainer.ALIGNMENT_CENTER # the content sits in the middle of the free space
	match input_kind:
		InputKind.TAP_PILE:
			_add_visual(true)
		InputKind.BOARD:
			_add_board()
		InputKind.CHOICES:
			_add_visual(false)
			_add_choices(rng)
		InputKind.NUMBER_PAD:
			_add_pad_with_visual()
		InputKind.TILES:
			_add_visual(false)
			_add_tiles()
		InputKind.ARRAY:
			_add_visual(false)
			_add_array_builder()
		InputKind.SPLIT:
			_add_split()
		InputKind.SLATE:
			_add_slate()
		InputKind.SIEVE:
			_add_sieve()
		InputKind.TREE:
			_add_tree()
		InputKind.GEAR:
			_add_gear_bench()
		InputKind.FRACTION_PAD, InputKind.DECIMAL_PAD:
			_add_fraction_pad()
		InputKind.FRACTION_SLATE, InputKind.DECIMAL_SLATE:
			_add_slate()
		InputKind.CRYSTAL:
			_add_crystal()
		InputKind.ALLOY:
			_add_alloy()
		InputKind.GAUGE:
			_add_gauge()
		InputKind.VAULT:
			_add_vault()
		InputKind.TOWER:
			_add_tower()
		InputKind.LEVER:
			_add_lever()
		InputKind.SCI_PAD, InputKind.BASE_PAD:
			_add_power_pad()
		InputKind.KEYBOARD:
			_add_keyboard()
		InputKind.PATTERN:
			if problem.visual.has("figure"):
				_add_visual(false) # the triangles or squares above the numbers (figurate walls)
			_add_pattern_wall()
		InputKind.PROOF:
			_add_proof_board(rng)
		InputKind.TRACK:
			_add_track()
		InputKind.DIAL:
			_add_dial()
		InputKind.TABLE:
			_add_table()
		InputKind.WHEEL:
			_add_wheel()
		InputKind.COINS:
			_add_coins()
	set_enabled(_enabled)


## True when the input needs the screen's whole height on a phone (five rows of array cells, each a
## 64 dp target, take nearly all of a 360 dp phone): the mine then moves Bolt beside the panel.
func wants_height() -> bool:
	return input_kind == InputKind.ARRAY


## True while the panel takes answers (false under the Word Gem card, the stroke demo or an animation).
func is_enabled() -> bool:
	return _enabled


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _board != null:
		_board.set_enabled(enabled)
	if _choices != null:
		_choices.set_enabled(enabled)
	if _pad != null:
		_pad.set_enabled(enabled)
	if _tiles != null:
		_tiles.set_enabled(enabled)
	if _array != null:
		_array.set_enabled(enabled)
	if _slate != null:
		_slate.set_enabled(enabled)
	if _split != null:
		_split.set_enabled(enabled)
	if _sieve != null:
		_sieve.set_enabled(enabled)
	if _tree != null:
		_tree.set_enabled(enabled)
	if _gear_bench != null:
		_gear_bench.set_enabled(enabled)
	for widget: Control in [_fraction_pad, _crystal, _alloy, _gauge, _vault, _tower, _lever, _power_pad, _keyboard, _pattern_wall, _proof_board, _track, _dial, _table, _wheel, _coins]:
		if widget != null:
			widget.call(&"set_enabled", enabled)
	if _visual != null and input_kind == InputKind.TAP_PILE:
		for button: Button in _visual.pile_buttons():
			button.disabled = not enabled


func visual_model() -> VisualModel:
	return _visual


## The hint picture added by show_hint(), or null (it may also be shown in the problem's own
## picture slot; see show_hint).
func hint_visual() -> VisualModel:
	return _hint_visual


## Shows the help a hint rung puts in the answer area and returns the picture model it shows (or
## null). From rung 2 (VISUAL_MODEL) that is the problem's picture model (hint_steps[1].visual): it
## takes the place of the problem's own picture when that picture is only to look at, and is added
## above the input otherwise (tappable piles, the build board, a problem with no picture). From
## rung 3 (WORKED_EXAMPLE) a card shows a solved problem of the same skill with other numbers. It
## takes the picture's place (beside the pad or the slate, or above the input) and the picture and
## any added model box step aside, so the input always stays on the screen (16:9 and phones alike;
## Bolt still reads the problem). Where the picture is the input (tappable piles) or the input is a
## tall zone mechanic, the card keeps to its two lines of text (EXAMPLE_PICTURE_KINDS).
func show_hint(rung: HintLadder.Rung) -> VisualModel:
	if not HintLadder.shows_model(rung) or problem.hint_steps.size() < 2:
		return null
	var shown: VisualModel = _show_model()
	if HintLadder.shows_example(rung) and problem.hint_steps.size() >= 3:
		_show_example()
		if _example != null:
			if _hint_visual != null and _hint_visual != _visual:
				_hint_visual.visible = false
			if _visual != null and input_kind != InputKind.TAP_PILE:
				_visual.visible = false # the problem is still Bolt's line; the card needs the room
	return shown


## The worked-example card from rung 3, or null.
func example_card() -> PanelContainer:
	return _example


func _show_model() -> VisualModel:
	var model: Dictionary = problem.hint_steps[1].get("visual", {})
	if model.is_empty():
		return null
	if _visual != null and input_kind != InputKind.TAP_PILE:
		_visual.show_visual(model, false)
		_hint_visual = _visual
		return _hint_visual
	if _hint_visual == null:
		_hint_visual = VISUAL_SCENE.instantiate()
		_hint_visual.compact = true
		_hint_visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hint_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _pad_row != null:
			_hint_visual.width_multiple = FRACTION_VISUAL_WIDTH # beside an input it is the narrow picture
			_pad_row.add_child(_hint_visual)
			_pad_row.move_child(_hint_visual, 0)
		else:
			add_child(_hint_visual)
			move_child(_hint_visual, 0)
	_hint_visual.show_visual(model, false)
	return _hint_visual


func _show_example() -> void:
	if _example != null:
		return
	var step: Dictionary = problem.hint_steps[2]
	var example: Dictionary = step.get("example", {})
	if example.is_empty():
		return
	_example = PanelContainer.new()
	_example.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	_example.add_child(column)
	var asked: Label = Label.new()
	asked.text = Text.get_line(StringName(example["prompt_line_id"]), example["prompt_params"])
	asked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(asked)
	var picture: Dictionary = step.get("visual", {}) if EXAMPLE_PICTURE_KINDS.has(input_kind) else {}
	if not picture.is_empty():
		var visual: VisualModel = VISUAL_SCENE.instantiate()
		visual.compact = true
		visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(visual)
		visual.show_visual(picture, false)
	var solved: Label = Label.new()
	solved.text = Text.get_line(StringName(example["answer_line_id"]), example["answer_params"])
	solved.add_theme_color_override(&"font_color", Color(Text.HIGHLIGHT_COLOR))
	solved.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(solved)
	if _pad_row != null:
		# Beside the pad or the slate, where the problem's picture was.
		_example.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_pad_row.add_child(_example)
		_pad_row.move_child(_example, 0)
	else:
		add_child(_example)
		move_child(_example, 0)


func board() -> BuildBoard:
	return _board


func choices() -> ChoiceButtons:
	return _choices


func number_pad() -> NumberPad:
	return _pad


func tile_board() -> TileBoard:
	return _tiles


func array_builder() -> ArrayBuilder:
	return _array


func chalk_slate() -> ChalkSlate:
	return _slate


func boulder_split() -> BoulderSplit:
	return _split


## True when the last answer came from the slate after the child confirmed an unsure reading.
func slate_confirmed() -> bool:
	return _slate != null and _slate.last_answer_confirmed()


func sieve_grid() -> SieveGrid:
	return _sieve


func factor_tree() -> FactorTree:
	return _tree


func gear_bench() -> GearBench:
	return _gear_bench
func fraction_pad() -> FractionPad:
	return _fraction_pad


func crystal_picker() -> CrystalPicker:
	return _crystal


func alloy_mixer() -> AlloyMixer:
	return _alloy


func depth_gauge() -> DepthGauge:
	return _gauge


func vault_lock() -> VaultLockPicker:
	return _vault


func tower_elevator() -> TowerElevator:
	return _tower


func counterweight() -> CounterweightLever:
	return _lever


func power_pad() -> PowerPad:
	return _power_pad


func keyboard_entry() -> KeyboardEntry:
	return _keyboard
func pattern_wall() -> PatternWall:
	return _pattern_wall


func proof_board() -> ProofBoard:
	return _proof_board


func circular_track() -> CircularTrack:
	return _track


func clock_lock() -> ClockLock:
	return _dial


func mixing_table() -> MixingTable:
	return _table


func cipher_wheel() -> CipherWheel:
	return _wheel


func coin_puzzle() -> CoinPuzzle:
	return _coins


func _clear() -> void:
	for child: Node in get_children():
		child.queue_free()
		remove_child(child)
	_visual = null
	_hint_visual = null
	_board = null
	_choices = null
	_pad = null
	_pad_row = null
	_tiles = null
	_array = null
	_slate = null
	_split = null
	_sieve = null
	_tree = null
	_gear_bench = null
	_fraction_pad = null
	_crystal = null
	_alloy = null
	_gauge = null
	_vault = null
	_tower = null
	_lever = null
	_power_pad = null
	_keyboard = null
	_pattern_wall = null
	_proof_board = null
	_track = null
	_dial = null
	_table = null
	_wheel = null
	_coins = null
	_example = null


func _add_visual(tappable: bool) -> void:
	if problem.visual.is_empty():
		return
	_visual = VISUAL_SCENE.instantiate()
	_visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER # sized to its content, not the whole panel
	_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_visual)
	_visual.show_visual(problem.visual, tappable)
	if tappable:
		_visual.pile_tapped.connect(_on_value_given)


func _add_choices(rng: RandomNumberGenerator) -> void:
	_choices = CHOICES_SCENE.instantiate()
	add_child(_choices)
	var label_for_value: Callable = func(value: Variant) -> String: return label_for(value, problem)
	_choices.setup(problem.choice_options(label_for_value, MAX_CHOICE_DISTRACTORS), rng)
	_choices.chosen.connect(_on_value_given)


func _add_board() -> void:
	_board = BOARD_SCENE.instantiate()
	var tools: Array[StringName] = []
	for tool: Variant in problem.meta["tools"]:
		tools.append(StringName(str(tool)))
	_board.tools = tools
	var start: Dictionary = problem.meta.get("start", {})
	_board.initial = {"hundreds": start.get("hundreds", 0), "tens": start.get("tens", 0), "ones": start.get("ones", 0)}
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_board)
	_board.submitted.connect(_on_value_given)


## The picture and an input side by side, so both fit on a 16:9 screen: the picture takes the free
## width on the left. Returns the row (the input is added by the caller).
func _add_row_with_visual(visual_width: float = 6.0) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	_pad_row = row
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", UI.spacing(32))
	add_child(row)
	if not problem.visual.is_empty():
		_visual = VISUAL_SCENE.instantiate()
		_visual.width_multiple = visual_width
		_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_visual)
		_visual.show_visual(problem.visual, false)
	return row


## The number pad sits beside the picture.
func _add_pad_with_visual() -> void:
	var row: HBoxContainer = _add_row_with_visual()
	_pad = PAD_SCENE.instantiate()
	# Powers of 10 and scientific notation (Zone 8) and Gauss's sums (Zone 9) need more digits.
	_pad.max_digits = maxi(int(problem.meta.get("pad_digits", PAD_DIGITS)), PAD_DIGITS)
	_pad.wide = wide_pad
	_pad.allow_negative = bool(problem.meta.get("signed", false)) # depths below zero (Zone 7)
	_pad.size_flags_horizontal = Control.SIZE_SHRINK_END
	_pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_pad)
	_pad.submitted.connect(_on_value_given)


func _add_tiles() -> void:
	var spec: Dictionary = problem.meta["tile_board"]
	_tiles = TILES_SCENE.instantiate()
	_tiles.tiles = spec["tiles"].duplicate()
	_tiles.slot_count = int(spec["slots"])
	_tiles.ordered = bool(spec.get("ordered", true))
	_tiles.sequence = strip_sequence(problem)
	_tiles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tiles)
	_tiles.submitted.connect(_on_value_given)


func _add_array_builder() -> void:
	var limits: Dictionary = problem.meta["array_builder"]
	_array = ARRAY_SCENE.instantiate()
	_array.max_rows = int(limits["max_rows"])
	_array.max_cols = int(limits["max_cols"])
	_array.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if UI.is_compact():
		# On a phone the grid takes the whole height: the hint picture and the worked example go
		# beside it (show_hint adds them to the row, as beside the number pad).
		_pad_row = HBoxContainer.new()
		_pad_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_pad_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_pad_row.add_theme_constant_override(&"separation", UI.spacing(32))
		add_child(_pad_row)
		_array.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pad_row.add_child(_array)
	else:
		add_child(_array)
	_array.submitted.connect(_on_value_given)


## The boulder and its factor rail (meta.boulder_split = {value, factors}). A split gives [a, b] with
## a <= b; the pickaxe bouncing off a prime gives [value].
func _add_split() -> void:
	var spec: Dictionary = problem.meta["boulder_split"]
	var factors: Array[int] = []
	for factor: Variant in spec.get("factors", []):
		factors.append(int(factor))
	_split = SPLIT_SCENE.instantiate()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_split)
	_split.setup(int(spec["value"]), factors)
	_split.split_chosen.connect(func(_value: int, factor_a: int, factor_b: int) -> void: _on_value_given([factor_a, factor_b]))
	_split.prime_declared.connect(func(prime: int) -> void: _on_value_given([prime]))


## The sieve grid (meta.sieve_grid = {size, cols, precrossed}); Done gives every crossed rock.
func _add_sieve() -> void:
	var spec: Dictionary = problem.meta["sieve_grid"]
	_sieve = SIEVE_SCENE.instantiate()
	_sieve.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_sieve)
	_sieve.setup(int(spec["size"]), int(spec.get("cols", 10)), spec.get("precrossed", []))
	_sieve.submitted.connect(_on_value_given)


## The factor tree (meta.factor_tree = {value}); Done, or a finished tree, gives the leaves.
func _add_tree() -> void:
	_tree = TREE_SCENE.instantiate()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tree)
	_tree.setup(int(problem.meta["factor_tree"]["value"]))
	_tree.submitted.connect(_on_value_given)


## The gear bench (meta.gear_bench = {driver, turns, tray}); Go gives the teeth of the gear on the axle.
func _add_gear_bench() -> void:
	var spec: Dictionary = problem.meta["gear_bench"]
	_gear_bench = GEAR_SCENE.instantiate()
	_gear_bench.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_gear_bench)
	var tray: Array[int] = []
	for teeth: Variant in spec.get("tray", []):
		tray.append(int(teeth))
	_gear_bench.setup(int(spec["driver"]), tray, int(spec.get("turns", 1)))
	_gear_bench.gear_chosen.connect(_on_value_given)


## The slate sits beside the picture, where the number pad would. If it cannot read (no
## recognizer), the number pad replaces it.
func _add_slate() -> void:
	var row: HBoxContainer = _add_row_with_visual(6.0 if input_kind == InputKind.SLATE else FRACTION_VISUAL_WIDTH)
	_slate = SLATE_SCENE.instantiate()
	_slate.size_flags_horizontal = Control.SIZE_SHRINK_END
	_slate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_slate)
	var reader: Recognizer = recognizer if recognizer != null else DigitInk.make_recognizer()
	match input_kind:
		InputKind.FRACTION_SLATE:
			_slate.setup_fraction(FRACTION_BOXES, FRACTION_BOXES, reader)
		InputKind.DECIMAL_SLATE:
			_slate.setup_decimal(_whole_digits(), _decimal_places(), reader)
		_:
			_slate.setup(problem.answer_digits(), reader)
	_slate.answer_written.connect(_on_value_given)
	_slate.answer_rejected.connect(func() -> void: rejected.emit())
	_slate.digit_read.connect(func(digit: int, mirrored: bool) -> void: digit_written.emit(digit, mirrored))
	_slate.fell_back_to_number_pad.connect(_on_slate_fell_back, CONNECT_ONE_SHOT)


func _on_slate_fell_back() -> void:
	if _slate == null:
		return
	var row: Node = _slate.get_parent()
	row.queue_free()
	remove_child(row)
	_slate = null
	_visual = null
	_pad_row = null
	match input_kind:
		InputKind.FRACTION_SLATE:
			input_kind = InputKind.FRACTION_PAD
			_add_fraction_pad()
		InputKind.DECIMAL_SLATE:
			input_kind = InputKind.DECIMAL_PAD
			_add_fraction_pad()
		_:
			input_kind = InputKind.NUMBER_PAD
			_add_pad_with_visual()
	set_enabled(_enabled)


## The fraction or decimal pad beside the picture (the slate's fallback, and mouse-only devices).
func _add_fraction_pad() -> void:
	var row: HBoxContainer = _add_row_with_visual(FRACTION_VISUAL_WIDTH)
	_fraction_pad = FRACTION_PAD_SCENE.instantiate()
	if input_kind == InputKind.DECIMAL_PAD:
		_fraction_pad.layout = FractionPad.Layout.DECIMAL
		_fraction_pad.box_digits = _whole_digits()
		_fraction_pad.decimal_places = _decimal_places()
	else:
		_fraction_pad.layout = FractionPad.Layout.FRACTION
		_fraction_pad.box_digits = FRACTION_BOXES
	_fraction_pad.size_flags_horizontal = Control.SIZE_SHRINK_END
	_fraction_pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_fraction_pad)
	_fraction_pad.submitted.connect(_on_value_given)


## How many digits the ones of a decimal answer take (at least 1, at most 2).
func _whole_digits() -> int:
	var places: int = int(problem.answer["scale"])
	var whole: int = floori(int(problem.answer["mantissa"]) / float(Rational.pow10(places)))
	return clampi(str(whole).length(), 1, 2)


## The places after the point for a decimal answer: meta.decimal_places, else the answer's own.
func _decimal_places() -> int:
	return maxi(int(problem.meta.get("decimal_places", int(problem.answer["scale"]))), 1)


## The crystal to light (meta.crystal = {den, match?}) beside the picture; Done gives the lit fraction.
func _add_crystal() -> void:
	var spec: Dictionary = problem.meta["crystal"]
	var row: HBoxContainer = _add_row_with_visual()
	_crystal = CRYSTAL_SCENE.instantiate()
	_crystal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_crystal)
	_crystal.setup(int(spec["den"]), spec.get("match", {}))
	_crystal.submitted.connect(_on_value_given)


## The alloy mixer (meta.alloy = {a, b, given, max}); Mix gives the tin count.
func _add_alloy() -> void:
	var spec: Dictionary = problem.meta["alloy"]
	_alloy = ALLOY_SCENE.instantiate()
	_alloy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_alloy)
	_alloy.setup(int(spec["a"]), int(spec["b"]), int(spec["given"]), int(spec["max"]))
	_alloy.submitted.connect(_on_value_given)


## The depth gauge (meta.depth_gauge = {min, max, start}); Stop here gives the cab's level.
func _add_gauge() -> void:
	var spec: Dictionary = problem.meta["depth_gauge"]
	_gauge = GAUGE_SCENE.instantiate()
	_gauge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_gauge)
	_gauge.setup(int(spec["min"]), int(spec["max"]), int(spec["start"]))
	_gauge.submitted.connect(_on_value_given)


## The vault lock (meta.vault_lock = {base, places}); Open gives the {base, digits} it shows.
func _add_vault() -> void:
	var spec: Dictionary = problem.meta["vault_lock"]
	_vault = VAULT_SCENE.instantiate()
	_vault.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_vault)
	_vault.setup(int(spec["base"]), int(spec["places"]))
	_vault.submitted.connect(_on_value_given)


## The tower elevator (meta.tower = {base, floors, start}); Stop here gives the cab's floor.
func _add_tower() -> void:
	var spec: Dictionary = problem.meta["tower"]
	_tower = TOWER_SCENE.instantiate()
	_tower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tower)
	_tower.setup(int(spec["base"]), int(spec["floors"]), int(spec.get("start", 0)))
	_tower.submitted.connect(_on_value_given)


## The counterweight lever (meta.lever = {left_w, left_d, right_d, max}); Balance gives the right weight.
func _add_lever() -> void:
	var spec: Dictionary = problem.meta["lever"]
	_lever = LEVER_SCENE.instantiate()
	_lever.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_lever)
	_lever.setup(int(spec["left_w"]), int(spec["left_d"]), int(spec["right_d"]), int(spec["max"]))
	_lever.submitted.connect(_on_value_given)


## The scientific-notation or base pad beside the picture.
func _add_power_pad() -> void:
	var row: HBoxContainer = _add_row_with_visual()
	_power_pad = POWER_PAD_SCENE.instantiate()
	if input_kind == InputKind.BASE_PAD:
		var spec: Dictionary = problem.meta.get("base_pad", {"base": int(problem.answer["base"]), "places": BaseGenerator.MAX_PLACES})
		_power_pad.layout = PowerPad.Layout.BASE
		_power_pad.base = int(spec["base"])
		_power_pad.places = int(spec["places"])
	else:
		_power_pad.layout = PowerPad.Layout.SCI
	_power_pad.size_flags_horizontal = Control.SIZE_SHRINK_END
	_power_pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_power_pad)
	_power_pad.submitted.connect(_on_value_given)


## Keyboard entry beside the picture (Scholar mode), set up for the answer's shape.
func _add_keyboard() -> void:
	var row: HBoxContainer = _add_row_with_visual()
	_keyboard = KEYBOARD_SCENE.instantiate()
	var answer: Variant = problem.answer
	if Rational.is_fraction(answer):
		_keyboard.kind = KeyboardEntry.Kind.FRACTION
		_keyboard.max_digits = FRACTION_BOXES
	elif Rational.is_decimal(answer):
		_keyboard.kind = KeyboardEntry.Kind.DECIMAL
		_keyboard.max_digits = 4
	elif Notation.is_sci(answer):
		_keyboard.kind = KeyboardEntry.Kind.SCI
	elif Notation.is_base_number(answer):
		_keyboard.kind = KeyboardEntry.Kind.BASE
		_keyboard.base = int(answer["base"])
		_keyboard.max_digits = int(problem.meta.get("base_pad", {}).get("places", BaseGenerator.MAX_PLACES))
	else:
		_keyboard.kind = KeyboardEntry.Kind.INTEGER
		_keyboard.allow_negative = bool(problem.meta.get("signed", false))
		_keyboard.max_digits = maxi(int(problem.meta.get("pad_digits", PAD_DIGITS)), PAD_DIGITS)
	_keyboard.size_flags_horizontal = Control.SIZE_SHRINK_END
	_keyboard.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_keyboard)
	_keyboard.submitted.connect(_on_value_given)
	_keyboard.pad_requested.connect(use_pad, CONNECT_ONE_SHOT)


## "Use the pad" on keyboard entry: the on-screen pad (never the slate) takes its place for this problem.
func use_pad() -> void:
	if _keyboard == null:
		return
	var row: Node = _keyboard.get_parent()
	row.queue_free()
	remove_child(row)
	_keyboard = null
	_visual = null
	_pad_row = null
	input_kind = choose_input(problem, false, false)
	match input_kind:
		InputKind.FRACTION_PAD, InputKind.DECIMAL_PAD:
			_add_fraction_pad()
		InputKind.SCI_PAD, InputKind.BASE_PAD:
			_add_power_pad()
		_:
			input_kind = InputKind.NUMBER_PAD
			_add_pad_with_visual()
	set_enabled(_enabled)
## The pattern wall (meta.pattern_wall = {terms, tiles}); Done gives the number in the gap.
func _add_pattern_wall() -> void:
	var spec: Dictionary = problem.meta["pattern_wall"]
	_pattern_wall = PATTERN_SCENE.instantiate()
	_pattern_wall.setup(spec["terms"], spec["tiles"])
	_pattern_wall.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_pattern_wall)
	_pattern_wall.number_chosen.connect(_on_value_given)


## The proof board (meta.proof_board = {diagram, n, choices}); a fact button gives its diagram id.
func _add_proof_board(rng: RandomNumberGenerator) -> void:
	var spec: Dictionary = problem.meta["proof_board"]
	var options: Array[Dictionary] = []
	for id: Variant in spec.get("choices", []):
		options.append({"value": str(id), "label": label_for(str(id), problem)})
	_proof_board = PROOF_SCENE.instantiate()
	_proof_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_proof_board)
	_proof_board.setup(str(spec["diagram"]), int(spec["n"]), options, rng)
	_proof_board.chosen.connect(_on_value_given)


## For a number strip (a number line whose blanks are the answer, or meta.strip), the strip in
## reading order with null where each blank goes, so the slots sit between the numbers around
## them. Otherwise empty.
static func strip_sequence(for_problem: Problem) -> Array:
	var line: Dictionary = for_problem.visual
	var slots: int = int(for_problem.meta.get("tile_board", {}).get("slots", 0))
	var sequence: Array = []
	var strip: Array = for_problem.meta.get("strip", [])
	if not strip.is_empty() and for_problem.answer is Array:
		for value: Variant in strip:
			sequence.append(null if for_problem.answer.has(value) else value)
	elif line.get("type") == "number_line" and line.get("blanks", []).size() == slots:
		var step: int = maxi(int(line["labeled_every"]), 1)
		for value: int in range(int(line["min"]), int(line["max"]) + 1, step):
			sequence.append(null if line["blanks"].has(value) else value)
	return sequence if sequence.count(null) == slots and sequence.size() <= 8 else []


func _on_value_given(given: Variant) -> void:
	if _enabled:
		answered.emit(given)


## The circular track (meta.circular_track = {n, start, steps, direction}); a tap on a station gives the station.
func _add_track() -> void:
	_track = TRACK_SCENE.instantiate()
	_track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_track)
	_track.setup(problem.meta["circular_track"])
	_track.submitted.connect(_on_value_given)


## The clock lock (meta.clock_lock = {n, turns}); Set gives the mark the pointer is on.
func _add_dial() -> void:
	_dial = DIAL_SCENE.instantiate()
	_dial.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_dial)
	_dial.setup(problem.meta["clock_lock"])
	_dial.submitted.connect(_on_value_given)


## The mixing table (meta.mixing_table = {n, op}); Done gives the number chosen.
func _add_table() -> void:
	_table = TABLE_SCENE.instantiate()
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_table)
	_table.setup(problem.meta["mixing_table"])
	_table.submitted.connect(_on_value_given)


## The cipher wheel (meta.cipher_wheel = {text, max}); Set gives the shift the wheel is on.
func _add_wheel() -> void:
	_wheel = WHEEL_SCENE.instantiate()
	_wheel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_wheel)
	_wheel.setup(problem.meta["cipher_wheel"])
	_wheel.submitted.connect(_on_value_given)


## The coin puzzle (meta.coin_puzzle = {a, b, c, max}); Done gives [a-coins, b-coins].
func _add_coins() -> void:
	_coins = COINS_SCENE.instantiate()
	_coins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_coins)
	_coins.setup(problem.meta["coin_puzzle"])
	_coins.submitted.connect(_on_value_given)
