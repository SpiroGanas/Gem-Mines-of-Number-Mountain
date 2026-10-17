## Developer overlay: frame rate, window size, last input device, touch-target size.
## DEVELOPER TEXT ONLY, never shown to a child: it is hidden in release builds and listed
## in tools/ci/lint_allowlist.txt, so its literal strings are exempt from lint rule 1.
## Press F3 to hide or show it in a debug build.
class_name DebugOverlay
extends Control

const REFRESH_SECONDS: float = 0.25

var screen_name: StringName = &""

@onready var _label: Label = %InfoLabel
@onready var _timer: Timer = %RefreshTimer


func _ready() -> void:
	visible = OS.is_debug_build()
	_timer.wait_time = REFRESH_SECONDS
	_timer.timeout.connect(refresh)
	InputRouter.device_kind_changed.connect(func(_kind: InputRouter.DeviceKind) -> void: refresh())
	InputRouter.posture_changed.connect(func(_size: Vector2i) -> void: refresh())
	refresh()


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
	lines.append("dpi=%d min_target_px=%d" % [DisplayServer.screen_get_dpi(), UI.min_target_px()])
	return "\n".join(lines)
