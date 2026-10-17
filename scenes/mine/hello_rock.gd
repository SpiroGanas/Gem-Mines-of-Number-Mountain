## Sprint 1 "hello rock" device test (Phase 1 plan, P1-S01-04).
## One big tappable rock that wobbles, cracks with a sound, then resets, plus a
## developer overlay that reports what the device sends (input event class,
## pressure, window size, DPI, orientation). Throwaway: deleted in Sprint 4 when
## the real mine scene lands. Contains no child-facing text (rule 4); the overlay
## is developer text.
class_name HelloRock
extends Control

signal wobbled
signal cracked
signal reset

enum RockState { IDLE, WOBBLING, CRACKED }

const WOBBLE_SECONDS: float = 0.3
const RESET_SECONDS: float = 1.2
## The rock is a big target: several times the 64 dp minimum, never below 240 px.
const ROCK_TARGET_MULTIPLE: int = 4
const ROCK_MIN_PX: int = 240

@export var rock_idle: Texture2D
@export var rock_cracked: Texture2D

var state: RockState = RockState.IDLE
var taps: int = 0

var _last_event: String = "(none yet)"
var _tween: Tween

@onready var _rock: TextureButton = %Rock
@onready var _crack_sound: AudioStreamPlayer = %CrackSound
@onready var _sparkle: CPUParticles2D = %Sparkle
@onready var _overlay: Label = %DebugOverlay


func _ready() -> void:
	var side: int = maxi(UI.min_target_px() * ROCK_TARGET_MULTIPLE, ROCK_MIN_PX)
	_rock.custom_minimum_size = Vector2(side, side)
	_rock.texture_normal = rock_idle
	_rock.pressed.connect(_on_rock_pressed)
	_rock.resized.connect(_on_rock_resized)
	get_window().size_changed.connect(_refresh_overlay)
	_on_rock_resized()
	_refresh_overlay()


func _input(event: InputEvent) -> void:
	_last_event = _describe_event(event)
	_refresh_overlay()


## Entry point for taps and for tests. Ignored while the rock is busy.
func tap() -> void:
	if state != RockState.IDLE:
		return
	taps += 1
	state = RockState.WOBBLING
	_refresh_overlay()
	_wobble()


func _on_rock_pressed() -> void:
	tap()


func _on_rock_resized() -> void:
	_rock.pivot_offset = _rock.size / 2.0
	_sparkle.position = _rock.size / 2.0


func _wobble() -> void:
	_kill_tween()
	_tween = create_tween()
	var step: float = WOBBLE_SECONDS / 4.0
	_tween.tween_property(_rock, "rotation", 0.12, step)
	_tween.tween_property(_rock, "rotation", -0.12, step)
	_tween.tween_property(_rock, "rotation", 0.07, step)
	_tween.tween_property(_rock, "rotation", 0.0, step)
	_tween.tween_callback(_crack)
	wobbled.emit()


func _crack() -> void:
	state = RockState.CRACKED
	_rock.texture_normal = rock_cracked
	_crack_sound.play()
	_sparkle.restart()
	_sparkle.emitting = true
	cracked.emit()
	_refresh_overlay()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_rock, "scale", Vector2(1.08, 0.94), 0.08)
	_tween.tween_property(_rock, "scale", Vector2.ONE, 0.16)
	_tween.tween_interval(RESET_SECONDS)
	_tween.tween_callback(_reset)


func _reset() -> void:
	state = RockState.IDLE
	_rock.texture_normal = rock_idle
	_rock.rotation = 0.0
	_rock.scale = Vector2.ONE
	reset.emit()
	_refresh_overlay()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _describe_event(event: InputEvent) -> String:
	var text: String = event.get_class()
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		text += " idx=%d pressed=%s pos=%s" % [touch.index, touch.pressed, touch.position.round()]
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		text += " idx=%d pressure=%.2f tilt=%s pos=%s" % [drag.index, drag.pressure, drag.tilt, drag.position.round()]
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


func _refresh_overlay() -> void:
	if _overlay == null:
		return
	var window: Window = get_window()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("hello rock | Sprint 1 device test")
	lines.append("os=%s touchscreen=%s" % [OS.get_name(), DisplayServer.is_touchscreen_available()])
	lines.append("window=%s content=%s scale=%.2f" % [window.size, window.content_scale_size, UI.scale_factor()])
	lines.append("dpi=%d orientation=%d min_target_px=%d" % [DisplayServer.screen_get_dpi(), DisplayServer.screen_get_orientation(), UI.min_target_px()])
	lines.append("rock=%s px state=%s taps=%d" % [_rock.custom_minimum_size, RockState.keys()[state], taps])
	lines.append("last input: %s" % _last_event)
	_overlay.text = "\n".join(lines)
