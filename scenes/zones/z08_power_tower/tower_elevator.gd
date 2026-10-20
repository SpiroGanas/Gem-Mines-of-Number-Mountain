## The tower elevator (Zone 8, Sprint 36; meta.tower = {base, floors, start}): the Power Tower with its
## floors stacked up, Bolt's cab, and Up, Down and Stop here buttons. Floor k is base^k meters up (the
## doubling tower: 1, 2, 4, 8 ... meters), and every floor the cab has visited shows its height, so the
## child watches the height double as the cab climbs. Stop here hands in the floor (an int: the
## exponent). The cab glides with a tween; the elevator hums only through the shared sound bank.
##
## Buttons work the same with finger, stylus and mouse; Up, Down and Enter work on a keyboard. The
## ride's rules live in TowerRide; this scene only draws them. Compact enough for a landscape phone:
## the buttons sit two to a row beside the tower.
class_name TowerElevator
extends HBoxContainer

## Stop here was pressed: the cab's floor.
signal submitted(floor_number: int)
## The cab moved (for a sound).
signal moved(floor_number: int)

const BUTTON_WIDTH_MULTIPLE: float = 1.8
const BUTTON_HEIGHT_MULTIPLE: float = 1.2
const TOWER_WIDTH_MULTIPLE: float = 3.0
const TOWER_HEIGHT_MULTIPLE: float = 3.6
## Seconds the cab takes to glide one floor (scaled by `speed_scale`).
const GLIDE_SECONDS: float = 0.2

## Tests set 0 to skip the glide.
var speed_scale: float = 1.0
var ride: TowerRide = TowerRide.make(2, 10, 0)

var _picture: _TowerPicture
var _up: Button
var _down: Button
var _stop: Button
var _floor_label: Label
var _height_label: Label
var _glide: Tween
var _enabled: bool = true


func _ready() -> void:
	add_theme_constant_override(&"separation", 24)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_picture = _TowerPicture.new()
	_picture.name = "Tower"
	UI.make_touch_target(_picture, TOWER_WIDTH_MULTIPLE, TOWER_HEIGHT_MULTIPLE)
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_picture)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Controls"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 8)
	add_child(column)
	var how: Label = Label.new()
	how.text = Text.get_line(&"z8.tower.how")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = UI.target_size(BUTTON_WIDTH_MULTIPLE * 2.0, 1.0).x
	column.add_child(how)
	var arrows: HBoxContainer = HBoxContainer.new()
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	arrows.add_theme_constant_override(&"separation", 12)
	column.add_child(arrows)
	_up = _button(&"z8.tower.up", "UpButton")
	_up.pressed.connect(move.bind(1))
	arrows.add_child(_up)
	_down = _button(&"z8.tower.down", "DownButton")
	_down.pressed.connect(move.bind(-1))
	arrows.add_child(_down)
	var info: HBoxContainer = HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override(&"separation", 16)
	column.add_child(info)
	_floor_label = Label.new()
	_floor_label.name = "Floor"
	info.add_child(_floor_label)
	_height_label = Label.new()
	_height_label.name = "Height"
	_height_label.add_theme_color_override(&"font_color", PowerArt.MARK)
	info.add_child(_height_label)
	_stop = _button(&"z8.tower.stop", "StopButton")
	_stop.theme_type_variation = &"GoButton"
	_stop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stop.pressed.connect(submit)
	column.add_child(_stop)
	_refresh()


## A tower in `base` with floors 0 to `floors`, the cab on `start`.
func setup(base: int, floors: int, start: int = 0) -> void:
	ride = TowerRide.make(base, floors, start)
	_picture.cab = float(ride.floor_now)
	_refresh()


## Rides the cab `steps` floors up (positive) or down (negative), stopping at the ends.
func move(steps: int) -> void:
	if not _enabled:
		return
	var before: int = ride.floor_now
	ride.move(steps)
	if ride.floor_now == before:
		return
	if _glide != null:
		_glide.kill()
	if speed_scale <= 0.0 or not is_inside_tree():
		_picture.cab = float(ride.floor_now)
	else:
		_glide = create_tween()
		_glide.tween_property(_picture, "cab", float(ride.floor_now), GLIDE_SECONDS * speed_scale)
	_refresh()
	moved.emit(ride.floor_now)


func floor_now() -> int:
	return ride.floor_now


func submit() -> void:
	if _enabled:
		submitted.emit(ride.floor_now)


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
	_floor_label.text = Text.get_line(&"z8.tower.floor", {"k": ride.floor_now})
	_height_label.text = Text.get_line(&"z8.tower.height", {"n": ride.height_of(ride.floor_now)})
	var shown: PackedStringArray = PackedStringArray()
	for floor_number: int in ride.floors + 1:
		shown.append(Text.display_value(ride.height_of(floor_number)) if ride.was_visited(floor_number) else "")
	_picture.set_floors(shown)


## The tower and the cab at a (tweened) fractional floor. Heights are text built in set_floors(), so
## the frames of a glide draw without making strings.
class _TowerPicture:
	extends Control

	var cab: float = 0.0:
		set(value):
			cab = value
			queue_redraw()
	var _heights: PackedStringArray = PackedStringArray()
	var _boxes: Array[Rect2] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(_layout)

	## One text per floor: its height when visited, else "".
	func set_floors(heights: PackedStringArray) -> void:
		_heights = heights
		_layout()

	func _layout() -> void:
		var area: Rect2 = Rect2(Vector2(size.x * 0.32, 4.0), Vector2(size.x * 0.66, size.y - 8.0))
		_boxes = PowerArt.tower_floors(area, maxi(_heights.size() - 1, 0))
		queue_redraw()

	func _draw() -> void:
		if _boxes.is_empty():
			return
		var font: Font = get_theme_default_font()
		var size_now: int = clampi(roundi(_boxes[0].size.y * 0.6), 12, PowerArt.LABEL_SIZE)
		for index: int in _boxes.size():
			var box: Rect2 = _boxes[index]
			draw_rect(box, PowerArt.GROUND.darkened(0.35) if index == 0 else PowerArt.FLOOR)
			draw_rect(box, PowerArt.INK, false, 2.0)
			if index < _heights.size() and not _heights[index].is_empty():
				draw_string(font, Vector2(0.0, box.get_center().y + size_now * 0.35), _heights[index], HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.3, size_now, PowerArt.MARK)
		var low: Rect2 = _boxes[0]
		var high: Rect2 = _boxes[_boxes.size() - 1]
		var share: float = clampf(cab / float(maxi(_boxes.size() - 1, 1)), 0.0, 1.0)
		var y: float = lerpf(low.get_center().y, high.get_center().y, share)
		PowerArt.draw_cab(self, Vector2(low.get_center().x, y), minf(low.size.y * 0.9, 56.0))
