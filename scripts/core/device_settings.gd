## Settings that belong to the device, not to the child: the music and sound volumes.
## Kept in user://device_settings.cfg (a Godot ConfigFile), apart from the child's save, so the save
## schema does not change and a second child on the same tablet (Phase 3 profiles) shares them.
## Levels run 0 (off) to LEVELS; apply() sets the Music and SFX audio buses.
##
## Godot note: an audio bus is a mixer channel (default_bus_layout.tres); AudioServer sets a bus's
## volume in decibels, and linear_to_db() turns a 0..1 loudness into decibels.
class_name DeviceSettings
extends RefCounted

const DEFAULT_PATH: String = "user://device_settings.cfg"
const LEVELS: int = 5
const DEFAULT_LEVELS: Dictionary = {"music": 3, "sfx": 4}
const BUSES: Dictionary = {"music": &"Music", "sfx": &"SFX"}

static var _shared: DeviceSettings

var path: String
var _config: ConfigFile = ConfigFile.new()


## The settings every screen shares (loaded once).
static func shared() -> DeviceSettings:
	if _shared == null:
		_shared = DeviceSettings.new()
	return _shared


## Swaps the shared settings (tests point them at a temp file; null goes back to the real one).
static func use_shared(settings: DeviceSettings) -> void:
	_shared = settings


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path
	_config.load(path) # a missing file just means the defaults


func level(channel: String) -> int:
	return clampi(int(_config.get_value("audio", channel, DEFAULT_LEVELS.get(channel, LEVELS))), 0, LEVELS)


func set_level(channel: String, value: int) -> void:
	_config.set_value("audio", channel, clampi(value, 0, LEVELS))
	_config.save(path)
	apply()


## Sets the audio buses to the saved levels.
func apply() -> void:
	for channel: String in BUSES:
		var bus: int = AudioServer.get_bus_index(BUSES[channel])
		if bus < 0:
			continue
		AudioServer.set_bus_mute(bus, level(channel) == 0)
		AudioServer.set_bus_volume_db(bus, volume_db(level(channel)))


## Decibels for a level: full at LEVELS, quieter below, silent (muted) at 0.
static func volume_db(for_level: int) -> float:
	if for_level <= 0:
		return -80.0
	return linear_to_db(float(for_level) / float(LEVELS))
