## The circular track (Zone 10, Clockwork Depths; meta.circular_track = {n, start, steps, direction}): a loop of n
## stations with Bolt's cart waiting on one of them. The child taps the station where the cart stops after riding
## `steps` stops forward (direction 1) or back (-1); a tap hands the station in. The Ride button lets the cart ride the
## loop stop by stop so the child can watch it (the concrete way to find a remainder).
##
## The loop is a picture (ClockArt) and the stations are a row of Buttons under it, one touch target each, that wrap
## onto more rows when the screen is narrow, so a loop of 12 fits a phone as well as a tablet: ring-shaped buttons
## cannot (their square corners would touch). Tapping works with finger, stylus and mouse; the number keys 0 to 9 pick
## a station on a keyboard. The cart glides with a tween. The widget never says whether the tap is right; the host
## decides. The rules (which station the ride ends on) live in ModularGenerator.
class_name CircularTrack
extends VBoxContainer

## A station was tapped.
signal submitted(station: int)

const RIDE_SECONDS_PER_STOP: float = 0.07
const MAX_RIDE_SECONDS: float = 2.4
const PICTURE_WIDTH_MULTIPLE: float = 3.2
const PICTURE_HEIGHT_MULTIPLE: float = 3.0
const COMPACT_PICTURE_HEIGHT_MULTIPLE: float = 2.3
const STATION_WIDTH_MULTIPLE: float = 1.0
const STATION_FONT: int = 28

## Tests set 0 to skip the glide.
var speed_scale: float = 1.0
var n: int = 2
var start: int = 0
var steps: int = 0
var direction: int = 1
## The cart's place on the loop in stops from station 0, fractional while it glides (it may pass n).
var cart: float = 0.0:
	set(value):
		cart = value
		if _picture != null:
			_picture.queue_redraw()

var _picture: _LoopPicture
var _stations: HFlowContainer
var _buttons: Array[Button] = []
var _ride: Button
var _how: Label
var _tween: Tween
var _enabled: bool = true


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 6)


## Builds the loop for a ride; `spec` is meta.circular_track.
func setup(spec: Dictionary) -> void:
	n = int(spec["n"])
	start = int(spec["start"])
	steps = int(spec["steps"])
	direction = int(spec["direction"])
	cart = float(start)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	if not UI.is_compact(): # a phone has no room for the line of help
		_how = Label.new()
		_how.name = "How"
		_how.text = Text.get_line(&"z10.track.how")
		_how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(_how)
	_picture = _LoopPicture.new()
	_picture.name = "Loop"
	_picture.track = self
	_picture.picture = ModularGenerator.clock_track(n, start, steps, direction, false)
	UI.make_touch_target(_picture, PICTURE_WIDTH_MULTIPLE, COMPACT_PICTURE_HEIGHT_MULTIPLE if UI.is_compact() else PICTURE_HEIGHT_MULTIPLE)
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_picture)
	_stations = HFlowContainer.new()
	_stations.name = "Stations"
	_stations.alignment = FlowContainer.ALIGNMENT_CENTER
	_stations.add_theme_constant_override(&"h_separation", 8)
	_stations.add_theme_constant_override(&"v_separation", 8)
	add_child(_stations)
	for index: int in n:
		var button: Button = Button.new()
		button.name = "Station%d" % index
		button.text = Text.display_value(index)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override(&"font_size", STATION_FONT)
		UI.make_touch_target(button, STATION_WIDTH_MULTIPLE, 1.0)
		button.pressed.connect(choose.bind(index))
		_stations.add_child(button)
		_buttons.append(button)
	_ride = Button.new()
	_ride.name = "RideButton"
	_ride.text = Text.get_line(&"z10.track.ride")
	_ride.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(_ride, 1.6, 1.0)
	_ride.pressed.connect(ride)
	_stations.add_child(_ride)
	set_enabled(_enabled)


## Taps a station: hands it in.
func choose(station: int) -> void:
	if _enabled:
		submitted.emit(station)


## Lets the cart ride its stops, one at a time.
func ride() -> void:
	if not _enabled:
		return
	if _tween != null:
		_tween.kill()
	cart = float(start)
	var target: float = float(start + direction * steps)
	if speed_scale <= 0.0 or not is_inside_tree():
		cart = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "cart", target, minf(float(steps) * RIDE_SECONDS_PER_STOP, MAX_RIDE_SECONDS) * speed_scale)


## The station the cart is on now (the whole stop it last reached).
func cart_station() -> int:
	return posmod(floori(cart + 0.5), n)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	for button: Button in _buttons:
		button.disabled = not enabled
	if _ride != null:
		_ride.disabled = not enabled


func station_button(index: int) -> Button:
	return _buttons[index]


func ride_button() -> Button:
	return _ride


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not is_visible_in_tree() or not _enabled:
		return
	var digit: int = event.unicode - KEY_0
	if event.unicode >= KEY_0 and event.unicode <= KEY_9 and digit < n:
		choose(digit)
		get_viewport().set_input_as_handled()


## The loop, the number of stops to ride and the cart.
class _LoopPicture:
	extends Control

	var track: CircularTrack
	## The loop's picture, built once in setup: the ride tweens `cart` and redraws every frame (no allocation here).
	var picture: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if track == null or track.n < 2 or picture.is_empty():
			return
		picture["cart"] = track.cart
		ClockArt.draw_track(self, Rect2(Vector2(4, 4), size - Vector2(8, 8)), picture, get_theme_default_font())
