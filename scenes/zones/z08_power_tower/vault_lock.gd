## The vault lock (Zone 8, Sprint 36; meta.vault_lock = {base, places}): a row of lamps for binary, or of
## dials for another base, each with its place's worth under it (32, 16, 8, 4, 2, 1 or 25, 5, 1). A tap on
## a lamp toggles it; a tap on a dial turns it to its next digit (0 to base - 1, then round to 0). The
## number the lock shows is read out underneath, and Open hands in the lock's {base, digits} with a
## crystal glow (no flame). The lock never says whether it is right; the host decides.
##
## The rules (sum of digit × base^place) live in VaultLock; this scene only draws them. Every place is a
## Button of at least one touch target, so finger, stylus and mouse work the same; on a keyboard, Left
## and Right pick a place, Space taps it and Enter opens.
class_name VaultLockPicker
extends VBoxContainer

## Open was pressed: the {base, digits} the lock shows (no leading zeros).
signal submitted(value: Dictionary)
## A place changed (for a sound).
signal changed(value: int)

const PLACE_MULTIPLE: float = 1.25
const OPEN_WIDTH_MULTIPLE: float = 2.6
const OPEN_HEIGHT_MULTIPLE: float = 1.0

var lock: VaultLock = VaultLock.make(2, 6)
## Tests set 0 to skip the glow.
var speed_scale: float = 1.0

var _how: Label
var _row: HBoxContainer
var _places: Array[Button] = []
var _faces: Array[_PlaceFace] = []
var _worths: Array[Label] = []
var _total: Label
var _open: Button
var _selected: int = -1
var _enabled: bool = true


func _ready() -> void:
	add_theme_constant_override(&"separation", 4)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_how = Label.new()
	_how.name = "How"
	_how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_how)
	_row = HBoxContainer.new()
	_row.name = "Places"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override(&"separation", 10)
	add_child(_row)
	_total = Label.new()
	_total.name = "Total"
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_total)
	_open = Button.new()
	_open.name = "OpenButton"
	_open.text = Text.get_line(&"z8.vault.open")
	_open.theme_type_variation = &"GoButton"
	_open.focus_mode = Control.FOCUS_NONE
	_open.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_open, OPEN_WIDTH_MULTIPLE, OPEN_HEIGHT_MULTIPLE)
	_open.pressed.connect(submit)
	add_child(_open)
	setup(lock.base, lock.places())


## A lock of `places` places in `base` (lamps for 2, dials otherwise), every place at 0.
func setup(base: int, places: int) -> void:
	lock = VaultLock.make(base, places)
	_selected = -1
	if _row == null:
		return
	for column: Node in _row.get_children():
		_row.remove_child(column)
		column.queue_free()
	_places.clear()
	_faces.clear()
	_worths.clear()
	# Many places share the row's width (a phone is narrow), but never below one touch target.
	var side: float = PLACE_MULTIPLE if places <= 6 else 1.0
	for index: int in lock.places():
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override(&"separation", 2)
		var button: Button = Button.new()
		button.name = "Place%d" % index
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(button, side, side)
		button.pressed.connect(tap.bind(index))
		var face: _PlaceFace = _PlaceFace.new()
		face.style = "lamps" if lock.is_lamp_row() else "dials"
		button.add_child(face)
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.add_child(button)
		var worth: Label = Label.new()
		worth.text = Text.display_value(lock.place_value(index))
		worth.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		worth.add_theme_color_override(&"font_color", PowerArt.MARK)
		worth.add_theme_font_size_override(&"font_size", 26)
		column.add_child(worth)
		_row.add_child(column)
		_places.append(button)
		_faces.append(face)
		_worths.append(worth)
	_how.text = Text.get_line(&"z8.vault.how" if lock.is_lamp_row() else &"z8.vault.how_dials")
	_refresh()


## A tap on place `index`: a lamp toggles, a dial turns.
func tap(index: int) -> void:
	if not _enabled:
		return
	lock.tap(index)
	_refresh()
	changed.emit(lock.value())


## Sets the places from digits (most significant first, right-aligned): tests and a resumed rock.
func set_digits(digits: Array) -> void:
	lock.set_digits(digits)
	_refresh()


func value() -> int:
	return lock.value()


func submit() -> void:
	if not _enabled:
		return
	submitted.emit(lock.answer())
	if speed_scale > 0.0 and is_inside_tree():
		var glow: Tween = create_tween()
		for face: _PlaceFace in _faces:
			glow.parallel().tween_property(face, "glow", 0.0, 0.6 * speed_scale).from(1.0)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_refresh()


func place_button(index: int) -> Button:
	return _places[index]


func open_button() -> Button:
	return _open


func place_count() -> int:
	return _places.size()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not is_visible_in_tree() or _places.is_empty():
		return
	match event.keycode:
		KEY_LEFT:
			_selected = maxi(_selected - 1, 0) if _selected >= 0 else _places.size() - 1
		KEY_RIGHT:
			_selected = mini(_selected + 1, _places.size() - 1)
		KEY_SPACE:
			if _selected >= 0:
				tap(_selected)
		KEY_ENTER, KEY_KP_ENTER:
			submit()
		_:
			return
	_refresh()
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _open == null:
		return
	for index: int in _places.size():
		_places[index].disabled = not _enabled
		_faces[index].digit = lock.digits[index]
		_faces[index].selected = index == _selected
	_total.text = Text.get_line(&"z8.vault.total", {"n": lock.value()})
	_open.disabled = not _enabled


## One lamp or dial, drawn by PowerArt (and a crystal glow after Open).
class _PlaceFace:
	extends Control

	var style: String = "lamps"
	var digit: int = 0:
		set(value):
			digit = value
			_digit_text = Text.display_value(value)
			queue_redraw()
	var selected: bool = false:
		set(value):
			selected = value
			queue_redraw()
	var glow: float = 0.0:
		set(value):
			glow = value
			queue_redraw()
	## Built when the digit changes, so the glow's frames draw without making strings.
	var _digit_text: String = "0"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cell: Rect2 = Rect2(Vector2.ZERO, size)
		if glow > 0.0:
			draw_circle(cell.get_center(), minf(size.x, size.y) * 0.5, Color(PowerArt.CRYSTAL, 0.4 * glow))
		PowerArt.draw_place(self, cell, style, digit, get_theme_default_font(), _digit_text)
		if selected:
			draw_rect(cell.grow(-2.0), PowerArt.MARK, false, 4.0)
