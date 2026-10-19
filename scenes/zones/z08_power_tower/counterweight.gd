## The counterweight lever (Zone 8, Sprint 36; meta.lever = {left_w, left_d, right_d, max}): the elevator's
## counterweight beam on its pivot, a weight hanging on the left, and an empty hook on the right that the
## child loads with More and Less. The beam leans toward the heavier side as the weight changes (weight
## × distance on each side; a tween eases it over) and sits level when the moments match. Balance hands in
## the right weight. The beam never says whether that is right; the host decides.
##
## Used for lever.counterweight.balance rocks in the mine and for every step of the Counterweight
## Elevator build. Buttons work the same with finger, stylus and mouse; Plus, Minus and Enter work on a
## keyboard. The rules (moments, the tilt) live in Lever; this scene only draws them.
class_name CounterweightLever
extends VBoxContainer

## Balance was pressed: the weight on the right hook.
signal submitted(weight: int)
## The weight changed (for a sound).
signal weight_changed(weight: int)

const BUTTON_WIDTH_MULTIPLE: float = 2.0
const BUTTON_HEIGHT_MULTIPLE: float = 1.2
const PICTURE_WIDTH_MULTIPLE: float = 6.0
const PICTURE_HEIGHT_MULTIPLE: float = 2.2
const TILT_SECONDS: float = 0.25

var lever: Lever = Lever.make(8, 2, 4, 32)
## Tests set 0 to skip the beam's tween.
var speed_scale: float = 1.0

var _picture: _LeverPicture
var _less: Button
var _more: Button
var _balance: Button
var _weight: Label
var _tilt: Tween
var _enabled: bool = true


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var how: Label = Label.new()
	how.name = "How"
	how.text = Text.get_line(&"z8.lever.how")
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(how)
	_picture = _LeverPicture.new()
	_picture.name = "Lever"
	UI.make_touch_target(_picture, PICTURE_WIDTH_MULTIPLE, PICTURE_HEIGHT_MULTIPLE)
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_picture)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Controls"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)
	_less = _button(&"z8.lever.less", "LessButton")
	_less.pressed.connect(change_weight.bind(-1))
	row.add_child(_less)
	_weight = Label.new()
	_weight.name = "Weight"
	_weight.theme_type_variation = &"NumberLabel"
	_weight.custom_minimum_size.x = UI.target_size(1.2, 1.0).x
	_weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_weight)
	_more = _button(&"z8.lever.more", "MoreButton")
	_more.pressed.connect(change_weight.bind(1))
	row.add_child(_more)
	_balance = _button(&"z8.lever.balance", "BalanceButton")
	_balance.theme_type_variation = &"GoButton"
	_balance.pressed.connect(submit)
	row.add_child(_balance)
	_refresh(false)


## A left weight `left_w` at `left_d` steps, the right hook at `right_d`, room for `most` weight.
func setup(left_w: int, left_d: int, right_d: int, most: int) -> void:
	lever = Lever.make(left_w, left_d, right_d, most)
	_refresh(false)


## Adds (positive) or takes off (negative) weight, between 0 and the most the hook takes.
func change_weight(amount: int) -> void:
	if not _enabled:
		return
	var before: int = lever.right_weight
	lever.add_weight(amount)
	if lever.right_weight != before:
		_refresh(true)
		weight_changed.emit(lever.right_weight)


## Sets the right weight directly (tests and the keyboard).
func set_weight(weight: int) -> void:
	change_weight(weight - lever.right_weight)


func weight() -> int:
	return lever.right_weight


func submit() -> void:
	if _enabled:
		submitted.emit(lever.right_weight)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_refresh(false)


func more_button() -> Button:
	return _more


func less_button() -> Button:
	return _less


func balance_button() -> Button:
	return _balance


## The beam's lean now (after any tween): negative when the left side is down.
func beam_angle() -> float:
	return PowerArt.tilt_angle(lever.tilt())


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not is_visible_in_tree():
		return
	match event.keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_UP:
			change_weight(1)
		KEY_MINUS, KEY_KP_SUBTRACT, KEY_DOWN:
			change_weight(-1)
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


func _refresh(animate: bool) -> void:
	if _balance == null:
		return
	_less.disabled = not _enabled or lever.right_weight <= 0
	_more.disabled = not _enabled or lever.right_weight >= lever.max_weight
	_balance.disabled = not _enabled
	_weight.text = Text.display_value(lever.right_weight)
	_picture.set_weights(lever.left_weight, lever.left_distance, lever.right_weight, lever.right_distance)
	var target: float = beam_angle()
	if _tilt != null:
		_tilt.kill()
	if animate and speed_scale > 0.0 and is_inside_tree():
		_tilt = create_tween()
		_tilt.tween_property(_picture, "angle", target, TILT_SECONDS * speed_scale)
	else:
		_picture.angle = target


## The beam, drawn by PowerArt at a (tweened) angle. The weights' numbers are set in set_weights(), so
## the frames of a tilt draw without making strings.
class _LeverPicture:
	extends Control

	var angle: float = 0.0:
		set(value):
			angle = value
			queue_redraw()
	var _left_w: int = 0
	var _left_d: int = 1
	var _right_w: int = 0
	var _right_d: int = 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_weights(left_w: int, left_d: int, right_w: int, right_d: int) -> void:
		_left_w = left_w
		_left_d = left_d
		_right_w = right_w
		_right_d = right_d
		queue_redraw()

	func _draw() -> void:
		PowerArt.draw_lever(self, Rect2(Vector2(8, 8), size - Vector2(16, 16)), _left_w, _left_d, _right_w, _right_d, angle, false, get_theme_default_font())
