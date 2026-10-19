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


## A value the widget can give that is certainly wrong for `problem`.
static func wrong_value(problem: Problem) -> Variant:
	if not problem.distractors.is_empty():
		return problem.distractors[0]["value"]
	if problem.answer is int:
		return problem.answer + 1
	return problem.answer
