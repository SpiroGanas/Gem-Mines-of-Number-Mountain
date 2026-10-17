## Plays the short sound effects on the SFX bus (project-made placeholder sounds, see
## tools/sfx/generate_placeholder_sfx.py).
##
## Every action in the game has a sound (GDD section 8). A small pool of players lets
## sounds overlap (a crack and a gem pop at nearly the same moment). `played` fires for every
## request, even in a muted or headless run, so tests can check that an action asked for its
## sound.
##
## Godot note: an AudioStreamPlayer plays one stream at a time; `bus` says which mixer channel
## it feeds (default_bus_layout.tres has Music, SFX and Voice) so volume can be set per kind.
class_name SfxBank
extends Node

## A sound was requested (whether or not audio hardware exists).
signal played(sfx_id: StringName)

const SOUND_DIR: String = "res://assets/sfx/placeholder"
const BUS: StringName = &"SFX"
const VOICES: int = 4
const SOUND_IDS: Array[StringName] = [&"tap", &"select", &"place", &"wobble", &"crack", &"gem", &"coin", &"soft_miss", &"fanfare", &"sparkle", &"lantern", &"buy"]

var _streams: Dictionary[StringName, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0


func _ready() -> void:
	for id: StringName in SOUND_IDS:
		var path: String = "%s/%s.ogg" % [SOUND_DIR, id]
		var stream: AudioStream = load(path)
		if stream == null:
			push_error("SfxBank: missing sound %s" % path)
			continue
		_streams[id] = stream
	for i: int in VOICES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = BUS
		add_child(player)
		_players.append(player)


func has_sound(id: StringName) -> bool:
	return _streams.has(id)


func play(id: StringName) -> void:
	played.emit(id)
	if not _streams.has(id) or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[id]
	player.play()
