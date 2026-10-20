## Drives an AnswerPanel's widget the way a child would, so tests can answer any problem.
class_name PanelDriver
extends RefCounted


## Gives `target` through whichever widget the panel built. Returns false if it could not
## (for example a value that is not among the answer buttons).
static func give(panel: AnswerPanel, target: Variant) -> bool:
	match panel.input_kind:
		AnswerPanel.InputKind.TAP_PILE:
			panel.visual_model().pile_buttons()[int(target)].pressed.emit()
			return true
		AnswerPanel.InputKind.CHOICES:
			var values: Array = panel.choices().values_in_order()
			for index: int in values.size():
				if Problem.same(values[index], target):
					panel.choices().button(index).pressed.emit()
					return true
			return false
		AnswerPanel.InputKind.NUMBER_PAD:
			panel.number_pad().clear()
			for digit: String in str(absi(int(target))):
				panel.number_pad().press_digit(int(digit))
			if int(target) < 0:
				if panel.number_pad().minus_button() == null:
					return false # no minus key: this pad cannot give a number below zero
				panel.number_pad().toggle_sign()
			panel.number_pad().submit()
			return true
		AnswerPanel.InputKind.FRACTION_PAD, AnswerPanel.InputKind.DECIMAL_PAD:
			return give_fraction_pad(panel.fraction_pad(), target)
		AnswerPanel.InputKind.CRYSTAL:
			var picker: CrystalPicker = panel.crystal_picker()
			var den: int = picker.crystal().crystal.den
			var exact: Dictionary = Rational.value_of(target)
			if exact.is_empty() or (int(exact["num"]) * den) % int(exact["den"]) != 0:
				return false # this crystal cannot show that fraction
			var count: int = floori(int(exact["num"]) * den / float(int(exact["den"])))
			if count < 0 or count > den:
				return false
			picker.crystal().crystal.clear()
			for index: int in count:
				picker.crystal().toggle(index)
			picker.submit()
			return true
		AnswerPanel.InputKind.ALLOY:
			var mixer: AlloyMixer = panel.alloy_mixer()
			mixer.set_tin(int(target))
			if mixer.tin != int(target):
				return false
			mixer.submit()
			return true
		AnswerPanel.InputKind.GAUGE:
			var gauge: DepthGauge = panel.depth_gauge()
			gauge.speed_scale = 0.0
			gauge.move(int(target) - gauge.level())
			if gauge.level() != int(target):
				return false
			gauge.submit()
			return true
		AnswerPanel.InputKind.PATTERN:
			return target is int and panel.pattern_wall().choose(int(target))
		AnswerPanel.InputKind.PROOF:
			panel.proof_board().speed_scale = 0.0
			panel.proof_board().toggle_fit() # fit the pieces first, as a child would
			return panel.proof_board().choose(str(target))
		AnswerPanel.InputKind.VAULT:
			var lock: VaultLockPicker = panel.vault_lock()
			lock.speed_scale = 0.0
			if not Notation.is_base_number(target) or int(target["base"]) != lock.lock.base or target["digits"].size() > lock.place_count():
				return false
			lock.set_digits([])
			# Tap each place up to its digit, the way a child turns a dial.
			var offset: int = lock.place_count() - target["digits"].size()
			for index: int in target["digits"].size():
				for turn: int in int(target["digits"][index]):
					lock.place_button(index + offset).pressed.emit()
			lock.open_button().pressed.emit()
			return true
		AnswerPanel.InputKind.TOWER:
			var tower: TowerElevator = panel.tower_elevator()
			tower.speed_scale = 0.0
			tower.move(int(target) - tower.floor_now())
			if tower.floor_now() != int(target):
				return false
			tower.stop_button().pressed.emit()
			return true
		AnswerPanel.InputKind.LEVER:
			var lever: CounterweightLever = panel.counterweight()
			lever.speed_scale = 0.0
			lever.set_weight(int(target))
			if lever.weight() != int(target):
				return false
			lever.balance_button().pressed.emit()
			return true
		AnswerPanel.InputKind.TRACK:
			var track: CircularTrack = panel.circular_track()
			if int(target) < 0 or int(target) >= track.n:
				return false
			track.station_button(int(target)).pressed.emit()
			return true
		AnswerPanel.InputKind.DIAL:
			var dial: ClockLock = panel.clock_lock()
			dial.speed_scale = 0.0
			if int(target) < 0 or int(target) >= dial.n:
				return false
			dial.mark_button(int(target)).pressed.emit()
			dial.set_button().pressed.emit()
			return true
		AnswerPanel.InputKind.TABLE:
			var table: MixingTable = panel.mixing_table()
			if int(target) < 0 or int(target) >= table.n:
				return false
			table.number_button(int(target)).pressed.emit()
			table.done_button().pressed.emit()
			return true
		AnswerPanel.InputKind.WHEEL:
			var wheel: CipherWheel = panel.cipher_wheel()
			if int(target) < 0 or int(target) > wheel.max_shift:
				return false
			wheel.set_shift(int(target))
			wheel.set_button().pressed.emit()
			return true
		AnswerPanel.InputKind.COINS:
			var puzzle: CoinPuzzle = panel.coin_puzzle()
			if not target is Array or target.size() != 2 or int(target[0]) > puzzle.max_coins or int(target[1]) > puzzle.max_coins:
				return false
			puzzle.set_counts(int(target[0]), int(target[1]))
			puzzle.done_button().pressed.emit()
			return true
		AnswerPanel.InputKind.SCI_PAD, AnswerPanel.InputKind.BASE_PAD:
			return give_power_pad(panel.power_pad(), target)
		AnswerPanel.InputKind.KEYBOARD:
			return type_on_keyboard(panel.keyboard_entry(), target)
		AnswerPanel.InputKind.TILES:
			var board: TileBoard = panel.tile_board()
			board.clear()
			for index: int in target.size():
				if board.tile_face(target[index]) == null:
					return false
				board.put(target[index], index)
			board.submit()
			return true
		AnswerPanel.InputKind.SPLIT:
			return panel.boulder_split().choose_pair(int(target[0])) # a split gives [smaller, larger]
		AnswerPanel.InputKind.SIEVE:
			var grid: SieveGrid = panel.sieve_grid()
			for number: int in range(1, grid.size_limit + 1):
				if grid.is_crossed(number) != target.has(number) and not grid.toggle(number):
					return false # a rock crossed from the start cannot come back
			grid.submit()
			return true
		AnswerPanel.InputKind.TREE:
			return grow_tree(panel.factor_tree(), target)
		AnswerPanel.InputKind.GEAR:
			if not panel.gear_bench().place(int(target)):
				return false
			panel.gear_bench().submit()
			return true
		AnswerPanel.InputKind.ARRAY:
			panel.array_builder().set_array(int(target["rows"]), int(target["cols"]))
			panel.array_builder().submit()
			return true
		AnswerPanel.InputKind.BOARD:
			var tray: DragTarget = panel.board().tray()
			tray.clear()
			for kind: StringName in [DragItem.HUNDRED, DragItem.TEN, DragItem.ONE]:
				var key: String = {DragItem.HUNDRED: "hundreds", DragItem.TEN: "tens", DragItem.ONE: "ones"}[kind]
				for i: int in int(target.get(key, 0)):
					tray.add_item(DragItem.make(kind))
			panel.board().submit()
			return true
	return false


## Builds a factor tree whose leaves are `target` (sorted): splits pieces until the leaves match, taps
## each prime leaf with the pickaxe (it bounces and becomes a gem), and presses Done if a composite
## leaf is left standing. Returns false if `target` cannot be grown from the tree's number.
static func grow_tree(tree: FactorTree, target: Array) -> bool:
	tree.pause_seconds = 0.0
	var want: Array = target.duplicate()
	var kept: Array[int] = []
	for step: int in 64:
		var next: int = -1
		for index: int in tree.leaf_order():
			if not bool(tree.node(index)["gem"]) and not kept.has(index):
				next = index
				break
		if next < 0:
			break
		tree.pick(next)
		var value: int = tree.node(next)["value"]
		if want.has(value):
			want.erase(value)
			if FactorTree.proper_factors(value).is_empty():
				tree.boulder_split().choose_pair(1) # a prime: the pickaxe bounces
			else:
				kept.append(next)
			continue
		var low: int = -1
		for part: Variant in want:
			if int(part) > 1 and int(part) < value and value % int(part) == 0:
				low = mini(int(part), floori(float(value) / int(part)))
				break
		if low < 0 or not tree.boulder_split().choose_pair(low):
			return false
	if not want.is_empty():
		return false
	if not tree.is_complete():
		tree.submit()
	return true


## Types a fraction {num, den} or a decimal {mantissa, scale} into the fraction pad's boxes and presses
## Go. False when it does not fit the boxes.
static func give_fraction_pad(pad: FractionPad, target: Variant) -> bool:
	pad.clear()
	var parts: Array[String] = []
	if Rational.is_fraction(target):
		parts = [str(int(target["num"])), str(int(target["den"]))]
	elif Rational.is_decimal(target):
		var places: int = pad.decimal_places
		if int(target["scale"]) > places or int(target["mantissa"]) < 0:
			return false
		var hundredths: int = int(target["mantissa"]) * Rational.pow10(places - int(target["scale"]))
		var fraction_digits: String = str(hundredths % Rational.pow10(places))
		while fraction_digits.length() < places:
			fraction_digits = "0" + fraction_digits
		parts = [str(floori(hundredths / float(Rational.pow10(places)))), fraction_digits]
	else:
		return false
	for index: int in parts.size():
		pad.select(index)
		for digit: String in parts[index]:
			pad.press_digit(int(digit))
		if pad.texts()[index] != parts[index]:
			return false
	pad.go()
	return true


## Types {mantissa, scale: 1, exp} (SCI) or {base, digits} (BASE) on the Zone 8 pad and presses Go.
static func give_power_pad(pad: PowerPad, target: Variant) -> bool:
	pad.clear()
	if pad.layout == PowerPad.Layout.BASE:
		if not Notation.is_base_number(target):
			return false
		for digit: Variant in target["digits"]:
			pad.press_digit(int(digit))
		pad.go()
		return Notation.text(pad.value()) == Notation.text(target)
	if not Notation.is_sci(target) or int(target["scale"]) != 1 or int(target["mantissa"]) < 10 or int(target["mantissa"]) > 99 or int(target["exp"]) > 9 or int(target["exp"]) < 0:
		return false # the pad's boxes hold d.d × 10^d only
	for digit: String in str(int(target["mantissa"])) + str(int(target["exp"])):
		pad.press_digit(int(digit))
	pad.go()
	return true


## Types a value on keyboard entry with real key events (digits, "-", "/", ".", "^") and presses Enter.
static func type_on_keyboard(entry: KeyboardEntry, target: Variant) -> bool:
	entry.clear()
	var keys: String = ""
	if target is int:
		keys = str(absi(target)) + ("-" if target < 0 else "")
	elif Rational.is_fraction(target):
		keys = "%d/%d" % [int(target["num"]), int(target["den"])]
	elif Rational.is_decimal(target):
		keys = Rational.decimal_text(target)
	elif Notation.is_sci(target):
		keys = Rational.decimal_text({"mantissa": int(target["mantissa"]), "scale": int(target["scale"])}) + "^" + str(int(target["exp"]))
	elif Notation.is_base_number(target):
		keys = Notation.text(target)
	else:
		return false
	for character: String in keys:
		entry.handle_key_event(key_event(character))
	entry.handle_key_event(key_event("\n"))
	return true


## A pressed InputEventKey for one typed character ("\n" is Enter).
static func key_event(character: String) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	match character:
		"\n":
			event.keycode = KEY_ENTER
		"-":
			event.keycode = KEY_MINUS
		"/":
			event.keycode = KEY_SLASH
		".":
			event.keycode = KEY_PERIOD
		"^":
			event.keycode = KEY_ASCIICIRCUM
		_:
			event.keycode = (KEY_0 + int(character)) as Key
	return event


## A value the widget can give that is certainly wrong for `problem`.
static func wrong_value(problem: Problem) -> Variant:
	if not problem.distractors.is_empty():
		return problem.distractors[0]["value"]
	if problem.answer is int:
		return problem.answer + 1
	return problem.answer
