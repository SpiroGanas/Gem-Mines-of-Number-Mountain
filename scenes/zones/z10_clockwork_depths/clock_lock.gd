## The clock lock (Zone 10, Clockwork Depths; meta.clock_lock = {n, turns}): a dial with n marks, 0 to n - 1, and a
## pointer that starts on 0. The child points the dial at the mark the turns end on (tap a mark; the pointer swings
## there) and presses Set, which hands the mark in. Set waits for that first tap, so the untouched 0 is never handed in. Used for mod.add.wrap rocks in the mine and for each dial of the
## Clockwork Vault build.
##
## The dial is a picture (ClockArt) and the marks are a row of Buttons under it, one touch target each, that wrap onto
## more rows when the screen is narrow, as on the circular track. Finger, stylus and mouse all tap the same way; the
## number keys 0 to 9 point the dial and Enter sets it. The widget never says whether the mark is right; the host
## decides.
class_name ClockLock
extends VBoxContainer

## Set was pressed: the mark the pointer is on.
signal submitted(mark: int)
## The pointer moved to a mark (for a click).
signal pointed(mark: int)

const SWING_SECONDS: float = 0.25
const MARK_FONT: int = 28
const PICTURE_WIDTH_MULTIPLE: float = 3.2
const PICTURE_HEIGHT_MULTIPLE: float = 3.0
const COMPACT_PICTURE_HEIGHT_MULTIPLE: float = 2.3

## Tests set 0 to skip the swing.
var speed_scale: float = 1.0
var n: int = 2
var turns: Array[int] = []
## The mark the pointer is on, fractional while it swings.
var pointer: float = 0.0:
	set(value):
		pointer = value
		if _picture != null:
			_picture.queue_redraw()
## The mark the child chose (0 until a tap).
var chosen: int = 0
## True once a mark was pointed at: Set and Enter do nothing before (peer review 05: Set used to hand in 0 untouched).
var pointed_once: bool = false

var _picture: _DialPicture
var _marks: HFlowContainer
var _buttons: Array[Button] = []
var _set: Button
var _how: Label
var _tween: Tween
var _enabled: bool = true


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 6)


## Builds the dial; `spec` is meta.clock_lock.
func setup(spec: Dictionary) -> void:
	n = int(spec["n"])
	turns = GeneratorKit.ints_of(spec.get("turns", []))
	chosen = 0
	pointed_once = false
	pointer = 0.0
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	if not UI.is_compact(): # a phone has no room for the line of help
		_how = Label.new()
		_how.name = "How"
		_how.text = Text.get_line(&"z10.lock.how")
		_how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(_how)
	_picture = _DialPicture.new()
	_picture.name = "Dial"
	_picture.lock = self
	UI.make_touch_target(_picture, PICTURE_WIDTH_MULTIPLE, COMPACT_PICTURE_HEIGHT_MULTIPLE if UI.is_compact() else PICTURE_HEIGHT_MULTIPLE)
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_picture)
	_marks = HFlowContainer.new()
	_marks.name = "Marks"
	_marks.alignment = FlowContainer.ALIGNMENT_CENTER
	_marks.add_theme_constant_override(&"h_separation", 8)
	_marks.add_theme_constant_override(&"v_separation", 8)
	add_child(_marks)
	for index: int in n:
		var button: Button = Button.new()
		button.name = "Mark%d" % index
		button.text = Text.display_value(index)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override(&"font_size", MARK_FONT)
		UI.make_touch_target(button, 1.0, 1.0)
		button.pressed.connect(point_at.bind(index))
		_marks.add_child(button)
		_buttons.append(button)
	_set = Button.new()
	_set.name = "SetButton"
	_set.text = Text.get_line(&"z10.lock.set")
	_set.theme_type_variation = &"GoButton"
	_set.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(_set, 1.6, 1.0)
	_set.pressed.connect(submit)
	_marks.add_child(_set)
	set_enabled(_enabled)


## Points the dial at a mark (the shorter way round).
func point_at(mark: int) -> void:
	if not _enabled:
		return
	chosen = mark
	pointed_once = true
	if _set != null:
		_set.disabled = false
	pointed.emit(mark)
	if _tween != null:
		_tween.kill()
	var here: float = fmod(pointer, float(n))
	var delta: float = float(mark) - here
	if delta > float(n) / 2.0:
		delta -= float(n)
	elif delta < -float(n) / 2.0:
		delta += float(n)
	if speed_scale <= 0.0 or not is_inside_tree():
		pointer = float(mark)
		return
	_tween = create_tween()
	_tween.tween_property(self, "pointer", here + delta, SWING_SECONDS * speed_scale)


func submit() -> void:
	if _enabled and pointed_once:
		submitted.emit(chosen)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	for button: Button in _buttons:
		button.disabled = not enabled
	if _set != null:
		_set.disabled = not enabled or not pointed_once


func mark_button(index: int) -> Button:
	return _buttons[index]


func set_button() -> Button:
	return _set


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not is_visible_in_tree() or not _enabled:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		submit()
	elif event.unicode >= KEY_0 and event.unicode <= KEY_9 and event.unicode - KEY_0 < n:
		point_at(event.unicode - KEY_0)
	else:
		return
	get_viewport().set_input_as_handled()


## The dial's ring, its marks and its pointer.
class _DialPicture:
	extends Control

	var lock: ClockLock

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if lock == null or lock.n < 2:
			return
		ClockArt.draw_dial(self, Rect2(Vector2(4, 4), size - Vector2(8, 8)), lock.n, lock.pointer, get_theme_default_font())
