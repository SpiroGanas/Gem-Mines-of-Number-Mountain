## The gear bench (Zone 6 dig mechanic, P4-S30-02): an electric motor turns the driver gear on the left;
## the axle beside it is empty. The child drags a gear from the tray onto the axle (or taps a tray gear),
## the train turns once so the child can watch and count the marked tooth go round, and Go hands the
## gear in. Another gear can be swapped in any number of times before Go; trying costs nothing.
##
## Driven by InputRouter pointer signals, so finger, stylus and mouse drag the same way, and a tap works
## too (mouse-only devices). Presentation only: the turning comes from GearTrain (scripts/zones/), and
## the bench never says whether a gear is right; the AnswerPanel's host decides (meta.gear_bench).
##
## Godot note: the turn is a Tween made with create_tween(): a one-shot animation object that calls
## _show_turns() with values from 0 to 1 over SPIN_SECONDS and frees itself when it is done.
class_name GearBench
extends VBoxContainer

## Go was pressed with a gear on the axle: `teeth` is that gear's tooth count.
signal gear_chosen(teeth: int)
## A gear went onto the axle (by drag or tap).
signal gear_placed(teeth: int)

const SPIN_SECONDS: float = 1.6
const TAP_SLOP_PX: float = 14.0
## The tray holds gears drawn at least this big (touch-target multiples), whatever their teeth.
const TRAY_MULTIPLE: float = 1.5
## A 12-tooth gear's radius on the stage is at most this many touch targets.
const MAX_UNIT_MULTIPLE: float = 0.8

## The pointer source. Defaults to the InputRouter autoload; tests inject their own.
var router: Node
## 1.0 is normal speed; tests raise it so the turn finishes quickly.
var speed_scale: float = 1.0

var driver_teeth: int = 12
var turns_asked: int = 1
var tray_teeth: Array[int] = []

var _enabled: bool = true
var _placed_teeth: int = 0
var _message: Label
var _stage: Control
var _driver: Gear
var _axle: _Axle
var _placed: Gear
var _tray: HBoxContainer
var _tray_gears: Array[Gear] = []
var _go: Button
var _drag_layer: Control
var _ghost: Gear
var _dragging: bool = false
var _drag_teeth: int = 0
var _down_position: Vector2 = Vector2.ZERO
var _train: GearTrain = GearTrain.new([12, 12])
var _driver_base: float = 0.0
var _placed_base: float = 0.0
var _spin: Tween


func _ready() -> void:
	add_theme_constant_override(&"separation", 16)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_message = Label.new()
	_message.name = "Message"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.text = Text.get_line(&"z6.bench.drag_gear")
	add_child(_message)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = UI.target_size(6.0, 3.6)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_axle = _Axle.new()
	_axle.name = "Axle"
	_stage.add_child(_axle)
	_driver = _new_gear("Driver")
	_driver.marked = true
	_stage.add_child(_driver)
	_placed = _new_gear("Placed")
	_placed.marked = true
	_placed.visible = false
	_stage.add_child(_placed)
	_tray = HBoxContainer.new()
	_tray.name = "Tray"
	_tray.alignment = BoxContainer.ALIGNMENT_CENTER
	_tray.add_theme_constant_override(&"separation", 24)
	add_child(_tray)
	_go = Button.new()
	_go.name = "GoButton"
	_go.text = Text.get_line(&"z6.bench.go")
	_go.theme_type_variation = &"GoButton"
	_go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_go, 3.0, 1.4)
	_go.disabled = true
	_go.pressed.connect(submit)
	add_child(_go)
	_drag_layer = Control.new()
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_layer.top_level = true
	add_child(_drag_layer)
	if router == null:
		router = InputRouter
	router.pointer_down.connect(_on_pointer_down)
	router.pointer_move.connect(_on_pointer_move)
	router.pointer_up.connect(_on_pointer_up)
	router.pointer_cancelled.connect(_on_pointer_cancelled)
	_stage.resized.connect(_layout)


func _exit_tree() -> void:
	if router != null and router.pointer_down.is_connected(_on_pointer_down):
		router.pointer_down.disconnect(_on_pointer_down)
		router.pointer_move.disconnect(_on_pointer_move)
		router.pointer_up.disconnect(_on_pointer_up)
		router.pointer_cancelled.disconnect(_on_pointer_cancelled)


## A paused game ends a drag in progress (the pause menu is on top); see BuildBoard.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _dragging:
		_cancel_drag()


## Shows the driver gear and the tray. `turns` is how many times the wanted gear should turn.
func setup(driver: int, tray: Array[int], turns: int) -> void:
	driver_teeth = driver
	turns_asked = turns
	tray_teeth = tray.duplicate()
	_placed_teeth = 0
	_driver.teeth = driver
	_placed.visible = false
	for gear: Gear in _tray_gears:
		gear.queue_free()
		_tray.remove_child(gear)
	_tray_gears.clear()
	for count: int in tray_teeth:
		var gear: Gear = _new_gear("Tray%d" % count)
		gear.teeth = count
		gear.custom_minimum_size = UI.target_size(TRAY_MULTIPLE, TRAY_MULTIPLE)
		_tray.add_child(gear)
		_tray_gears.append(gear)
	_refresh()
	_layout.call_deferred()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled and _dragging:
		_cancel_drag()
	_refresh()


## Puts the gear with `teeth` (one of the tray's) on the axle and turns the train once. The same call
## a tap, a drop and a test make. Returns false when nothing happened.
func place(teeth: int) -> bool:
	if not _enabled or not tray_teeth.has(teeth):
		return false
	_placed_teeth = teeth
	_placed.teeth = teeth
	_placed.visible = true
	_train.set_teeth([driver_teeth, teeth])
	_layout()
	_refresh()
	gear_placed.emit(teeth)
	_turn_once()
	return true


## Hands in the gear on the axle (the Go button).
func submit() -> void:
	if not _enabled or _placed_teeth == 0:
		return
	gear_chosen.emit(_placed_teeth)


## The gear on the axle (0 when the axle is empty).
func placed_teeth() -> int:
	return _placed_teeth


func driver_gear() -> Gear:
	return _driver


func placed_gear() -> Gear:
	return _placed


func axle() -> Control:
	return _axle


func tray_gears() -> Array[Gear]:
	return _tray_gears


func tray_gear(teeth: int) -> Gear:
	for gear: Gear in _tray_gears:
		if gear.teeth == teeth:
			return gear
	return null


func go_button() -> Button:
	return _go


func message_text() -> String:
	return _message.text


func is_spinning() -> bool:
	return _spin != null and _spin.is_running()


func is_dragging() -> bool:
	return _dragging


# --- Turning -----------------------------------------------------------------------------------


func _turn_once() -> void:
	if _spin != null:
		_spin.kill()
	_message.text = Text.get_line(&"z6.bench.watch")
	_spin = create_tween()
	_spin.set_speed_scale(speed_scale)
	_spin.tween_method(_show_turns, 0.0, 1.0, SPIN_SECONDS)
	_spin.tween_callback(func() -> void: _message.text = Text.get_line(&"z6.bench.drag_gear"))


## The driver has turned `driver_turns` times (0 to 1): each gear's angle from the train. No allocation.
func _show_turns(driver_turns: float) -> void:
	_driver.angle = _driver_base + _train.angle_of(0, driver_turns)
	_placed.angle = _placed_base + _train.angle_of(1, driver_turns)


# --- Layout ------------------------------------------------------------------------------------


func _layout() -> void:
	if _stage == null or _stage.size.x < 8.0:
		return
	var biggest: int = driver_teeth
	for count: int in tray_teeth:
		biggest = maxi(biggest, count)
	var driver_scale: float = GearArt.radius_for(driver_teeth, 1.0)
	var biggest_scale: float = GearArt.radius_for(biggest, 1.0)
	# The pair spans 1.92 × (both radii) across (the teeth overlap a little where they mesh).
	var unit: float = minf(_stage.size.x * 0.94 / (1.92 * (driver_scale + biggest_scale)), _stage.size.y * 0.47 / maxf(driver_scale, biggest_scale))
	unit = minf(unit, float(UI.min_target_px()) * MAX_UNIT_MULTIPLE)
	var driver_radius: float = driver_scale * unit
	var span: float = 1.92 * (driver_scale + biggest_scale) * unit
	var driver_center: Vector2 = Vector2((_stage.size.x - span) * 0.5 + driver_radius, _stage.size.y * 0.5)
	_set_gear_rect(_driver, driver_center, driver_radius)
	var placed_radius: float = GearArt.radius_for(_placed_teeth if _placed_teeth > 0 else 12, 1.0) * unit
	var axle_center: Vector2 = driver_center + Vector2(driver_radius * 0.92 + placed_radius * 0.92, 0.0)
	_set_gear_rect(_placed, axle_center, placed_radius)
	var target_radius: float = maxf(placed_radius, float(UI.min_target_px()))
	_axle.position = axle_center - Vector2(target_radius, target_radius)
	_axle.size = Vector2(target_radius, target_radius) * 2.0
	# Marked teeth start facing each other where the gears meet.
	_driver_base = -TAU / float(GearArt.drawn_teeth(driver_teeth)) * 0.36
	_placed_base = PI - TAU / float(GearArt.drawn_teeth(maxi(_placed_teeth, 3))) * 0.36
	if not is_spinning():
		_show_turns(0.0)


func _set_gear_rect(gear: Gear, center: Vector2, radius: float) -> void:
	var side: float = radius * 2.0 / 0.9 # Gear draws at 90% of its half-size
	gear.size = Vector2(side, side)
	gear.position = center - gear.size * 0.5


func _new_gear(gear_name: String) -> Gear:
	var gear: Gear = Gear.new()
	gear.name = gear_name
	return gear


func _refresh() -> void:
	if _go == null:
		return
	_go.disabled = not _enabled or _placed_teeth == 0
	for gear: Gear in _tray_gears:
		gear.highlighted = gear.teeth == _placed_teeth
		gear.modulate.a = 1.0 if _enabled else 0.6


# --- Pointer -----------------------------------------------------------------------------------


func _accepts_pointer() -> bool:
	return _enabled and is_visible_in_tree() and can_process()


func _on_pointer_down(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if _dragging or not _accepts_pointer():
		return
	for gear: Gear in _tray_gears:
		if gear.get_global_rect().has_point(pos):
			_begin_drag(gear.teeth, pos)
			return


func _on_pointer_move(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if not _dragging or _ghost == null:
		return
	_ghost.global_position = pos - _ghost.size * 0.5
	_axle.hot = _axle.get_global_rect().has_point(pos)


func _on_pointer_up(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if not _dragging:
		return
	var teeth: int = _drag_teeth
	var is_tap: bool = pos.distance_to(_down_position) <= TAP_SLOP_PX
	var on_axle: bool = _axle.get_global_rect().has_point(pos)
	_cancel_drag()
	if not _accepts_pointer():
		return
	if is_tap or on_axle:
		place(teeth)
	# dropped anywhere else: the gear goes back to the tray, nothing is lost


## A resting palm the pen took over from was holding a gear: it goes back to the tray.
func _on_pointer_cancelled(_index: int) -> void:
	if _dragging:
		_cancel_drag()


func _begin_drag(teeth: int, pos: Vector2) -> void:
	_dragging = true
	_drag_teeth = teeth
	_down_position = pos
	_ghost = _new_gear("Ghost")
	_ghost.teeth = teeth
	_ghost.highlighted = true
	_ghost.size = UI.target_size(TRAY_MULTIPLE, TRAY_MULTIPLE)
	_drag_layer.add_child(_ghost)
	_ghost.global_position = pos - _ghost.size * 0.5


func _cancel_drag() -> void:
	_dragging = false
	_drag_teeth = 0
	_axle.hot = false
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null


## The empty axle: a pin in a dashed ring that lights up while a gear is dragged over it.
class _Axle extends Control:
	var hot: bool = false:
		set(value):
			hot = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5
		var color: Color = GearArt.MARK if hot else GearArt.BODY
		for index: int in 16:
			var from: float = TAU * float(index) / 16.0
			draw_arc(center, radius - 3.0, from, from + TAU / 32.0, 4, color, 4.0 if hot else 2.0, true)
		draw_circle(center, radius * 0.12, GearArt.HUB)
		draw_arc(center, radius * 0.12, 0.0, TAU, 16, GearArt.EDGE, 2.0, true)
