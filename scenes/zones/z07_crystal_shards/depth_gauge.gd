## The depth gauge (Zone 7, Sprint 33; meta.depth_gauge = {min, max, start}): a vertical number line
## with 0 at the mountain's base, Bolt's elevator cab on it, and Up, Down and Stop here buttons. The
## child rides the cab one meter at a time and presses Stop here; that hands in the cab's level (an
## int, often below zero). The cab glides to each level with a tween. Labels every 5 meters, the base
## line in green with its own label, and the cab's level read out beside the buttons.
##
## Buttons work the same with finger, stylus and mouse; the Up and Down arrow keys and Enter work too.
## The ride's rules (never past either end) live in DepthRide; this scene only draws them.
class_name DepthGauge
extends HBoxContainer

## Stop here was pressed: the cab's level.
signal submitted(level: int)
## The cab moved (for a sound).
signal moved(level: int)

const BUTTON_WIDTH_MULTIPLE: float = 2.6
const BUTTON_HEIGHT_MULTIPLE: float = 1.3
const GAUGE_WIDTH_MULTIPLE: float = 4.0
const GAUGE_HEIGHT_MULTIPLE: float = 6.5
## Seconds the cab takes to glide one meter (scaled by `speed_scale`).
const GLIDE_SECONDS: float = 0.15

## Tests set 0 to skip the glide.
var speed_scale: float = 1.0
var ride: DepthRide = DepthRide.make(-30, 30, 0)
var _picture: _GaugePicture
var _up: Button
var _down: Button
var _stop: Button
var _level_label: Label
var _glide: Tween
var _enabled: bool = true


func _ready() -> void:
	add_theme_constant_override(&"separation", 24)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_picture = _GaugePicture.new()
	_picture.name = "Gauge"
	UI.make_touch_target(_picture, GAUGE_WIDTH_MULTIPLE, GAUGE_HEIGHT_MULTIPLE)
	add_child(_picture)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Controls"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 16)
	add_child(column)
	var how: Label = Label.new()
	how.text = Text.get_line(&"z7.gauge.how")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # as wide as the buttons under it
	column.add_child(how)
	# Up, the level and Down stacked like the shaft, with Stop here beside them: four stacked buttons
	# did not fit under Bolt at 16:9 or on a phone.
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override(&"separation", 16)
	column.add_child(buttons)
	var ride_column: VBoxContainer = VBoxContainer.new()
	ride_column.add_theme_constant_override(&"separation", 8)
	buttons.add_child(ride_column)
	_up = _button(&"z7.gauge.up", "UpButton")
	_up.pressed.connect(move.bind(1))
	ride_column.add_child(_up)
	_level_label = Label.new()
	_level_label.name = "Level"
	_level_label.theme_type_variation = &"NumberLabel"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ride_column.add_child(_level_label)
	_down = _button(&"z7.gauge.down", "DownButton")
	_down.pressed.connect(move.bind(-1))
	ride_column.add_child(_down)
	_stop = _button(&"z7.gauge.stop", "StopButton")
	_stop.theme_type_variation = &"GoButton"
	_stop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stop.pressed.connect(submit)
	buttons.add_child(_stop)
	_refresh()


## A gauge from `low` to `high` with the cab at `start`.
func setup(low: int, high: int, start: int) -> void:
	ride = DepthRide.make(low, high, start)
	_picture.low = floori(ride.low / 10.0) * 10
	_picture.high = ceili(ride.high / 10.0) * 10
	_picture.cab = float(ride.level)
	_picture.start = ride.level
	_refresh()


## Rides the cab `meters` up (positive) or down (negative), stopping at the ends.
func move(meters: int) -> void:
	if not _enabled:
		return
	var before: int = ride.level
	ride.move(meters)
	if ride.level == before:
		return
	if _glide != null:
		_glide.kill()
	if speed_scale <= 0.0 or not is_inside_tree():
		_picture.cab = float(ride.level)
	else:
		_glide = create_tween()
		_glide.tween_property(_picture, "cab", float(ride.level), GLIDE_SECONDS * speed_scale)
	_refresh()
	moved.emit(ride.level)


func level() -> int:
	return ride.level


func submit() -> void:
	if _enabled:
		submitted.emit(ride.level)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_refresh()


func up_button() -> Button:
	return _up


func down_button() -> Button:
	return _down


func stop_button() -> Button:
	return _stop


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not is_visible_in_tree():
		return
	match event.keycode:
		KEY_UP:
			move(1)
		KEY_DOWN:
			move(-1)
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
	if _up == null:
		return
	_up.disabled = not _enabled or not ride.can_go_up()
	_down.disabled = not _enabled or not ride.can_go_down()
	_stop.disabled = not _enabled
	_level_label.text = Text.display_value(ride.level)
	_picture.queue_redraw()


## The gauge itself, drawn by CrystalArt, with the cab at a (tweened) fractional level.
class _GaugePicture:
	extends Control

	var low: int = -30
	var high: int = 30
	var start: int = 0
	var cab: float = 0.0:
		set(value):
			cab = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var area: Rect2 = Rect2(Vector2.ZERO, size)
		var picture: Dictionary = {"type": "depth_gauge", "min": low, "max": high, "labeled_every": 5, "markers": [start]}
		CrystalArt.draw_gauge(self, area, picture, get_theme_default_font())
		var x: float = area.position.x + area.size.x * 0.45
		var top: float = area.position.y + 16.0
		var bottom: float = area.end.y - 16.0
		var share: float = clampf((float(high) - cab) / float(maxi(high - low, 1)), 0.0, 1.0)
		CrystalArt.draw_cab(self, Vector2(x, lerpf(top, bottom, share)))
