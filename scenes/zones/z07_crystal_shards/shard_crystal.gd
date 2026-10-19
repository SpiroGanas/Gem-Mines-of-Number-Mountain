## One round crystal the child lights shard by shard (Zone 7). A tap on a shard lights it; a second tap
## turns it off. The shards are wedges, so the tap is placed by its angle (CrystalShards.shard_at), not
## by a rectangle. A shard counts as tapped on release inside the same shard it was pressed on, and a
## press InputRouter cancels (a palm the pen took over) does nothing. Works the same with a finger, a
## stylus (both reach the GUI as mouse buttons) and a mouse; with a keyboard, Left and Right pick a
## shard and Space or Enter lights it.
##
## The radius is chosen so every shard's outer edge is at least the 64 dp touch minimum
## (CrystalShards.radius_for_targets). Presentation only: the lit state lives in a CrystalShards.
class_name ShardCrystal
extends Control

## A shard was lit (true) or turned off (false).
signal shard_toggled(index: int, lit: bool)

## The smallest radius, in touch targets, even for a crystal of two shards.
const MIN_RADIUS_TARGETS: float = 1.6
const FOCUS_COLOR: Color = Color("#FFD166")

var crystal: CrystalShards = CrystalShards.make(1)
var _pressed_shard: int = -1
var _focus_shard: int = 0
var _enabled: bool = true


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	if InputRouter.has_signal(&"pointer_cancelled"):
		InputRouter.pointer_cancelled.connect(_on_pointer_cancelled)
	_resize()
	UI.metrics_changed.connect(_resize)


func _exit_tree() -> void:
	if InputRouter.pointer_cancelled.is_connected(_on_pointer_cancelled):
		InputRouter.pointer_cancelled.disconnect(_on_pointer_cancelled)
	if UI.metrics_changed.is_connected(_resize):
		UI.metrics_changed.disconnect(_resize)


## Shows a crystal of `shards` shards, none lit.
func setup(shards: int) -> void:
	crystal = CrystalShards.make(shards)
	_focus_shard = 0
	_resize()
	queue_redraw()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_pressed_shard = -1
	modulate = Color(1, 1, 1, 1.0 if enabled else 0.7)


## The radius every shard needs to be a touch target.
func radius() -> float:
	var target: float = float(UI.min_target_px())
	return maxf(CrystalShards.radius_for_targets(target, crystal.den), target * MIN_RADIUS_TARGETS)


## Where the centre of shard `index` is, in this control's coordinates (tests tap there).
func shard_center(index: int) -> Vector2:
	var angle: float = CrystalShards.start_angle(index, crystal.den) + PI / float(crystal.den)
	return size * 0.5 + Vector2.from_angle(angle) * radius() * 0.62


## Lights or turns off shard `index` (a tap, a key, or a test).
func toggle(index: int) -> void:
	if not _enabled or index < 0 or index >= crystal.den:
		return
	var lit: bool = crystal.toggle(index)
	queue_redraw()
	shard_toggled.emit(index, lit)


func _gui_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var shard: int = CrystalShards.shard_at(event.position - size * 0.5, radius(), crystal.den)
		if event.pressed:
			_pressed_shard = shard
		else:
			if shard >= 0 and shard == _pressed_shard:
				toggle(shard)
			_pressed_shard = -1
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				_focus_shard = posmod(_focus_shard - 1, crystal.den)
			KEY_RIGHT:
				_focus_shard = posmod(_focus_shard + 1, crystal.den)
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				toggle(_focus_shard)
			_:
				return
		queue_redraw()
		accept_event()


func _on_pointer_cancelled(_index: int) -> void:
	_pressed_shard = -1


func _resize() -> void:
	var side: float = radius() * 2.0 + 24.0
	custom_minimum_size = Vector2(side, side)


func _draw() -> void:
	var lit: Array[bool] = crystal.lit_flags()
	CrystalArt.draw_crystal(self, size * 0.5, radius(), crystal.den, lit)
	if has_focus():
		var at: Vector2 = shard_center(_focus_shard)
		draw_arc(at, float(UI.min_target_px()) * 0.35, 0.0, TAU, 24, FOCUS_COLOR, 4.0)
