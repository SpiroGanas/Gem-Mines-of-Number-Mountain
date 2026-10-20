## The coin puzzle (Zone 11, Cipher Vault; meta.coin_puzzle = {a, b, c, max}): pay exactly c with a-coins and
## b-coins. Each kind of coin has a pile with More and Less buttons and a count; the running total shows under them and
## Done hands in the two counts as [a-coins, b-coins]. Counts stay from 0 to max; nothing here ever asks for a
## negative coin (Explorer mode).
##
## Buttons work the same with finger, stylus and mouse; Up and Down on a keyboard change the first pile, Enter presses
## Done. The widget never says whether the total is right; the host decides. The rule (a·x + b·y) lives in
## DiophantineGenerator; this scene only adds it up.
class_name CoinPuzzle
extends VBoxContainer

## Done was pressed: [a-coins, b-coins].
signal submitted(counts: Array)
## A count changed (for a click).
signal changed(counts: Array)

const BUTTON_WIDTH_MULTIPLE: float = 1.8
const BUTTON_HEIGHT_MULTIPLE: float = 1.2
const COIN_SIZE_MULTIPLE: float = 1.2

var a: int = 2
var b: int = 3
var c: int = 5
var max_coins: int = 12
var counts: Array[int] = [0, 0]

var _count_labels: Array[Label] = []
var _more: Array[Button] = []
var _less: Array[Button] = []
var _total: Label
var _done: Button
var _enabled: bool = true


func _init() -> void:
	add_theme_constant_override(&"separation", 12)
	alignment = BoxContainer.ALIGNMENT_CENTER


## Builds the puzzle; `spec` is meta.coin_puzzle.
func setup(spec: Dictionary) -> void:
	a = int(spec["a"])
	b = int(spec["b"])
	c = int(spec["c"])
	max_coins = int(spec.get("max", 12))
	counts = [0, 0]
	_count_labels.clear()
	_more.clear()
	_less.clear()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if not UI.is_compact(): # a phone has no room for the line of help
		var how: Label = Label.new()
		how.name = "How"
		how.text = Text.get_line(&"z11.coins.how")
		how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(how)
	var piles: HBoxContainer = HBoxContainer.new()
	piles.name = "Piles"
	piles.alignment = BoxContainer.ALIGNMENT_CENTER
	piles.add_theme_constant_override(&"separation", 40)
	add_child(piles)
	for kind: int in 2:
		piles.add_child(_make_pile(kind))
	var summary: HBoxContainer = HBoxContainer.new()
	summary.name = "Summary"
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override(&"separation", 24)
	add_child(summary)
	_total = Label.new()
	_total.name = "Total"
	_total.theme_type_variation = &"NumberLabel"
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_child(_total)
	_done = Button.new()
	_done.name = "DoneButton"
	_done.text = Text.get_line(&"z11.coins.done")
	_done.theme_type_variation = &"GoButton"
	_done.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(_done, 2.0, BUTTON_HEIGHT_MULTIPLE)
	_done.pressed.connect(submit)
	summary.add_child(_done)
	_refresh()


func _make_pile(kind: int) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Pile%d" % kind
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 6)
	var coin: _CoinFace = _CoinFace.new()
	coin.name = "Coin"
	coin.value = a if kind == 0 else b
	coin.tint = VaultArt.COIN_A if kind == 0 else VaultArt.COIN_B
	UI.make_touch_target(coin, COIN_SIZE_MULTIPLE, COIN_SIZE_MULTIPLE)
	coin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(coin)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	column.add_child(row)
	var less: Button = _button(&"z11.coins.less", "LessButton%d" % kind)
	less.pressed.connect(change.bind(kind, -1))
	row.add_child(less)
	var count: Label = Label.new()
	count.name = "Count%d" % kind
	count.theme_type_variation = &"NumberLabel"
	count.custom_minimum_size.x = UI.target_size(1.0, 1.0).x
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(count)
	var more: Button = _button(&"z11.coins.more", "MoreButton%d" % kind)
	more.pressed.connect(change.bind(kind, 1))
	row.add_child(more)
	_less.append(less)
	_more.append(more)
	_count_labels.append(count)
	return column


## Adds (or takes away) coins of one kind: kind 0 is the a-coin, kind 1 the b-coin.
func change(kind: int, delta: int) -> void:
	if not _enabled:
		return
	var before: int = counts[kind]
	counts[kind] = clampi(before + delta, 0, max_coins)
	if counts[kind] != before:
		changed.emit(counts.duplicate())
	_refresh()


## Sets both counts straight (tests).
func set_counts(x: int, y: int) -> void:
	counts = [clampi(x, 0, max_coins), clampi(y, 0, max_coins)]
	_refresh()


func total() -> int:
	return a * counts[0] + b * counts[1]


func submit() -> void:
	if _enabled:
		submitted.emit(counts.duplicate())


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_refresh()


func more_button(kind: int) -> Button:
	return _more[kind]


func less_button(kind: int) -> Button:
	return _less[kind]


func done_button() -> Button:
	return _done


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not is_visible_in_tree():
		return
	match event.keycode:
		KEY_UP:
			change(0, 1)
		KEY_DOWN:
			change(0, -1)
		KEY_RIGHT:
			change(1, 1)
		KEY_LEFT:
			change(1, -1)
		KEY_ENTER, KEY_KP_ENTER:
			submit()
		_:
			return
	get_viewport().set_input_as_handled()


func _button(line_id: StringName, node_name: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = Text.get_line(line_id)
	button.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	return button


func _refresh() -> void:
	if _total == null:
		return
	for kind: int in 2:
		_count_labels[kind].text = Text.display_value(counts[kind])
		_less[kind].disabled = not _enabled or counts[kind] <= 0
		_more[kind].disabled = not _enabled or counts[kind] >= max_coins
	_total.text = Text.get_line(&"z11.coins.total", {"t": total()})
	_done.disabled = not _enabled


## A round coin with its value on it.
class _CoinFace:
	extends Control

	var value: int = 2
	var tint: Color = VaultArt.COIN_A

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var radius: float = minf(size.x, size.y) / 2.0 - 2.0
		draw_circle(size / 2.0, radius, tint)
		draw_arc(size / 2.0, radius, 0.0, TAU, 32, VaultArt.OUTLINE, 3.0)
		var font: Font = get_theme_default_font()
		var font_size: int = maxi(roundi(radius * 0.9), 12)
		var text: String = str(value)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, size / 2.0 + Vector2(-text_size.x / 2.0, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VaultArt.OUTLINE)
