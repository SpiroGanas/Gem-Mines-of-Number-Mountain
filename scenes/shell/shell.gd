## The Shell: the one persistent root scene. It hosts one screen at a time, plus the
## pause overlay, a fade transition and (debug builds) the developer overlay.
##
## Screens never call get_tree().change_scene_to_file(). They emit request_screen and the
## Shell swaps them, so the pause overlay survives screen changes.
##
## Godot note: a *Tween* animates a property over time (here the fade); you create one with
## create_tween() and can `await tween.finished` to continue after it ends. `await` pauses
## this function (not the game) until a signal fires.
class_name Shell
extends Control

## A screen is now the current one (after the swap, as the fade-in starts).
signal screen_changed(screen_id: StringName)

## Screen id -> scene path.
const SCREEN_PATHS: Dictionary = {
	&"title": "res://scenes/shell/title.tscn",
	&"hub": "res://scenes/shell/hub.tscn",
	&"first_run": "res://scenes/shell/first_run.tscn",
	&"settings": "res://scenes/shell/settings.tscn",
	&"mine": "res://scenes/mine/mine.tscn",
	&"museum": "res://scenes/workshop/museum.tscn",
	&"garage": "res://scenes/workshop/garage.tscn",
	&"crafting": "res://scenes/workshop/crafting/crafting.tscn",
	&"build_site": "res://scenes/workshop/builds/build_site.tscn",
	&"build": "res://scenes/workshop/builds/build_screen.tscn",
	&"badges": "res://scenes/workshop/museum/badge_case.tscn",
	&"glossary": "res://scenes/workshop/museum/word_gems.tscn",
	&"challenge_door": "res://scenes/zones/common/challenge_door.tscn",
	&"family_rewards": "res://scenes/shell/parent_area/family_rewards.tscn",
	&"parent_gate": "res://scenes/shell/parent_area/parent_gate.tscn",
	&"dashboard": "res://scenes/shell/parent_area/dashboard.tscn",
	&"capture": "res://scenes/shell/parent_area/capture.tscn",
}
const START_SCREEN: StringName = &"title"
## Screens where Escape does nothing: nothing to pause there, and the parent area has no pause
## overlay (GDD section 3).
const NON_PAUSABLE: Array[StringName] = [&"title", &"first_run", &"parent_gate", &"dashboard", &"capture", &"family_rewards"]

@export var fade_seconds: float = 0.2

## Which music loop plays on which screen; screens not listed keep the workshop music. A screen can
## also choose its own (ShellScreen.music_id: the mine picks its zone's loop).
const MUSIC_FOR_SCREEN: Dictionary = {
	&"mine": &"mine", &"challenge_door": &"mine",
	&"crafting": &"build", &"build_site": &"build", &"build": &"build",
}
const MUSIC_DIR: String = "res://assets/music/placeholder"
const MUSIC_FADE_SECONDS: float = 0.8
## Silence for a cross-fade's quiet end (decibels).
const MUSIC_SILENT_DB: float = -40.0

var _current_id: StringName = &""
var _current: ShellScreen
var _changing: bool = false
var _queued_id: StringName = &""
var _queued_args: Dictionary = {}

@onready var _screen_host: Control = %ScreenHost
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _transition: ColorRect = %Transition
@onready var _debug_overlay: DebugOverlay = %DebugOverlay

## Two music players cross-fade (Sprint 20): the new loop rises on one while the old one falls on the
## other, so a screen change never cuts the music off.
var _music: AudioStreamPlayer
var _music_out: AudioStreamPlayer
var _music_id: StringName = &""


func _ready() -> void:
	theme = UI.theme()
	DeviceSettings.shared().apply()
	DeviceCaps.check_at_startup() # touch screen or mouse-only (Phase 3, Sprint 25); --no-touch simulates it
	_music = _make_music_player()
	_music_out = _make_music_player()
	_pause_menu.resume_requested.connect(resume)
	_pause_menu.hub_requested.connect(_on_pause_hub_requested)
	_pause_menu.settings_requested.connect(_on_pause_settings_requested)
	InputRouter.pause_requested.connect(toggle_pause)
	InputRouter.posture_changed.connect(_on_posture_changed)
	UI.metrics_changed.connect(_on_metrics_changed)
	_transition.color.a = 1.0 # start black; the first screen fades in
	change_screen(START_SCREEN)


func current_screen_id() -> StringName:
	return _current_id


func current_screen() -> ShellScreen:
	return _current


func is_paused() -> bool:
	return _pause_menu.visible


## Fades to another screen. Calls made during a fade are not lost: the latest one runs next.
func change_screen(screen_id: StringName, args: Dictionary = {}) -> void:
	if not SCREEN_PATHS.has(screen_id):
		push_warning("Shell: no screen registered for '%s'" % screen_id)
		return
	if _changing:
		_queued_id = screen_id
		_queued_args = args
		return
	_changing = true
	_close_pause()
	if _current != null:
		SaveSystem.save_now() # leaving a screen is a save point
		await _fade_to(1.0)
	_swap_screen(screen_id, args)
	await _fade_to(0.0)
	_changing = false
	if _queued_id != &"":
		var next_id: StringName = _queued_id
		var next_args: Dictionary = _queued_args
		_queued_id = &""
		_queued_args = {}
		change_screen(next_id, next_args)


## Cross-fades to a music loop (assets/music/placeholder/<id>.ogg) unless it is already playing.
func play_music(music_id: StringName) -> void:
	if music_id == _music_id:
		return
	var path: String = "%s/%s.ogg" % [MUSIC_DIR, music_id]
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_id = music_id
	var old: AudioStreamPlayer = _music
	_music = _music_out
	_music_out = old
	_music.stream = stream
	_music.volume_db = MUSIC_SILENT_DB
	_music.play()
	var fade: Tween = create_tween().set_parallel(true)
	fade.tween_property(_music, "volume_db", 0.0, MUSIC_FADE_SECONDS)
	if _music_out.playing:
		fade.tween_property(_music_out, "volume_db", MUSIC_SILENT_DB, MUSIC_FADE_SECONDS)
		fade.chain().tween_callback(_music_out.stop)


func _make_music_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = &"Music"
	player.process_mode = Node.PROCESS_MODE_ALWAYS # the music keeps playing under the pause menu
	add_child(player)
	return player


func current_music() -> StringName:
	return _music_id


func toggle_pause() -> void:
	if is_paused():
		resume()
	elif can_pause():
		pause()


func can_pause() -> bool:
	return _current_id != &"" and not NON_PAUSABLE.has(_current_id) and not _changing


func pause() -> void:
	if not can_pause() or is_paused():
		return
	get_tree().paused = true
	_pause_menu.open()


func resume() -> void:
	_close_pause()


func _notification(what: int) -> void:
	# Android's back gesture arrives as this notification; project.godot turns off the
	# default "quit on back" so it opens the pause menu instead.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle_pause()


func _swap_screen(screen_id: StringName, args: Dictionary) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	var scene: PackedScene = load(SCREEN_PATHS[screen_id])
	var screen: ShellScreen = scene.instantiate()
	screen.setup(args)
	screen.request_screen.connect(change_screen)
	screen.pause_requested.connect(pause)
	_screen_host.add_child(screen)
	_current = screen
	_current_id = screen_id
	_debug_overlay.screen_name = screen_id
	var own: StringName = screen.music_id()
	play_music(own if own != &"" else MUSIC_FOR_SCREEN.get(screen_id, &"hub"))
	screen_changed.emit(screen_id)


func _fade_to(alpha: float) -> void:
	_transition.mouse_filter = Control.MOUSE_FILTER_STOP # swallow taps during a fade
	if fade_seconds > 0.0:
		var tween: Tween = create_tween()
		tween.tween_property(_transition, "color:a", alpha, fade_seconds)
		await tween.finished
	else:
		_transition.color.a = alpha
	if alpha <= 0.0:
		_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _close_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
	_pause_menu.close()


func _on_pause_hub_requested() -> void:
	change_screen(&"hub")


func _on_pause_settings_requested() -> void:
	change_screen(&"settings", {"back_to": &"hub"})


func _on_posture_changed(_size: Vector2i) -> void:
	SaveSystem.save_now() # CLAUDE.md save point: posture change


## A posture change can change the touch-target size, and the theme's button padding derives from
## it (UI.theme() rebuilds the theme). The Shell's theme reaches every screen through the tree; the
## pause menu sits in a CanvasLayer and styles itself.
func _on_metrics_changed() -> void:
	theme = UI.theme()
	_pause_menu.theme = theme
