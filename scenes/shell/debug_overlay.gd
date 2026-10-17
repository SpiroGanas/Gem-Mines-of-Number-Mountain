## Developer overlay: frame rate, window size, last input device, touch-target size.
## DEVELOPER TEXT ONLY, never shown to a child: it is hidden in release builds and listed
## in tools/ci/lint_allowlist.txt, so its literal strings are exempt from lint rule 1.
## Press F3 to hide or show it in a debug build.
class_name DebugOverlay
extends Control

const REFRESH_SECONDS: float = 0.25

var screen_name: StringName = &""

var _last_event: String = "(none yet)"

@onready var _label: Label = %InfoLabel
@onready var _timer: Timer = %RefreshTimer


func _ready() -> void:
	visible = OS.is_debug_build()
	_timer.wait_time = REFRESH_SECONDS
	_timer.timeout.connect(refresh)
	InputRouter.device_kind_changed.connect(func(_kind: InputRouter.DeviceKind) -> void: refresh())
	InputRouter.posture_changed.connect(func(_size: Vector2i) -> void: refresh())
	refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask == 0:
		return # plain hovering would drown out the interesting events
	_last_event = describe_event(event)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3 and OS.is_debug_build():
		visible = not visible


func refresh() -> void:
	_label.text = describe()


## The overlay text. Public so tests can check what a developer would read.
func describe() -> String:
	var window: Window = get_window()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("screen=%s fps=%d" % [screen_name, Engine.get_frames_per_second()])
	lines.append("window=%s content=%s scale=%.2f" % [window.size, window.content_scale_size, UI.scale_factor()])
	lines.append("device=%s touch_first=%s" % [InputRouter.DeviceKind.keys()[InputRouter.last_device_kind()], InputRouter.is_touch_first()])
	lines.append("dpi=%d min_target_px=%d orientation=%d" % [DisplayServer.screen_get_dpi(), UI.min_target_px(), DisplayServer.screen_get_orientation()])
	lines.append("last input: %s" % _last_event)
	return "\n".join(lines)


## One line describing an input event: its class, and for pointers the pressure, tilt and pen flag.
## This is how to read what a ChromeOS stylus really sends (touch or mouse, with pressure?),
## the question the Sprint 1 device test answers. Ported from the retired hello-rock scene.
func describe_event(event: InputEvent) -> String:
	var text: String = event.get_class()
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		text += " idx=%d pressed=%s pos=%s" % [touch.index, touch.pressed, touch.position.round()]
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		text += " idx=%d pressure=%.2f tilt=%s pen_inverted=%s pos=%s" % [drag.index, drag.pressure, drag.tilt, drag.pen_inverted, drag.position.round()]
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		text += " button=%d pressed=%s pos=%s" % [button.button_index, button.pressed, button.position.round()]
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		text += " pressure=%.2f tilt=%s pen_inverted=%s pos=%s" % [motion.pressure, motion.tilt, motion.pen_inverted, motion.position.round()]
	elif event is InputEventKey:
		var key: InputEventKey = event
		text += " keycode=%s pressed=%s" % [OS.get_keycode_string(key.keycode), key.pressed]
	if event.device != 0:
		text += " device=%d" % event.device
	return text
