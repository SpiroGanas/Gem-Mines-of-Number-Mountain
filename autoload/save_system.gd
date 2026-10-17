## SaveSystem autoload: the child's saved progress, on this device only.
##
## Owns the live save Dictionary. Other autoloads (Rewards, Adaptive) read and change
## it through their own methods, then ask for a save; scenes never edit it directly.
## File handling lives in scripts/save/save_store.gd (atomic write, .bak recovery).
##
## Save points (CLAUDE.md): after every rock, when leaving any screen (Shell), on a
## posture change (Shell), and here on NOTIFICATION_APPLICATION_PAUSED and
## NOTIFICATION_WM_CLOSE_REQUEST. Closing the app at any moment loses nothing.
extends Node

## A save was written.
signal saved
## Loading found a save it could not use. reason is "corrupt" or "newer_version".
## "none" (no save yet) is a normal first start and does not emit this.
signal load_failed(reason: String)

const DEFAULT_DIR: String = "user://save"

## Where the save files live. Tests point this at a temp folder with use_directory().
var save_dir: String = DEFAULT_DIR
## What the last load_profile() found: {source, recovered, error, from_version, migrated}.
## The parent dashboard shows a note when `recovered` is true.
var last_load_report: Dictionary = {}

var _store: SaveStore
var _data: Dictionary = {}
## True when the save on disk came from a newer build; we must not overwrite it.
var _read_only: bool = false


func _ready() -> void:
	load_profile()


## Reads the save from disk (recovering from .tmp/.bak if needed), migrates it to the
## current schema, and fills in any missing keys. With no save on disk, starts a new profile.
## Named load_profile (not load) because `load` would shadow GDScript's global load().
func load_profile() -> void:
	_store = SaveStore.new(save_dir)
	_read_only = false
	var read: Dictionary = _store.read_profile()
	last_load_report = {"source": read["source"], "recovered": read["recovered"], "error": read["error"], "from_version": 0, "migrated": false}
	if not read["ok"]:
		_data = SaveSchema.new_profile(_now_iso())
		if read["error"] != "none":
			load_failed.emit(read["error"])
		return
	var migration: Dictionary = SaveMigrator.migrate(read["data"])
	last_load_report["from_version"] = migration["from_version"]
	if not migration["ok"]:
		last_load_report["error"] = migration["error"]
		_data = SaveSchema.new_profile(_now_iso())
		_read_only = migration["error"] == SaveMigrator.ERR_NEWER_VERSION
		load_failed.emit(migration["error"])
		return
	last_load_report["migrated"] = migration["from_version"] != SaveSchema.CURRENT_VERSION
	_data = SaveSchema.with_defaults(migration["data"])


## The live save dictionary. Mutate it only through the owning autoload.
func data() -> Dictionary:
	return _data


## Writes the save now (atomic). Safe to call often; it is a few kilobytes.
func save_now() -> void:
	if _read_only:
		push_warning("SaveSystem: not saving over a save from a newer version of the game")
		return
	if _store == null:
		_store = SaveStore.new(save_dir)
	_data["updated_at"] = _now_iso()
	var error: Error = _store.write_profile(_data)
	if error != OK:
		push_error("SaveSystem: save failed (%s)" % error_string(error))
		return
	saved.emit()


## Appends one answer attempt to attempts.jsonl.
func append_attempt(attempt: Attempt) -> void:
	if _store == null:
		_store = SaveStore.new(save_dir)
	var error: Error = _store.append_attempt(attempt.to_json())
	if error != OK:
		push_error("SaveSystem: could not log attempt (%s)" % error_string(error))


## All logged attempts, oldest first: {entries: Array[Dictionary], skipped: int}.
func read_attempts() -> Dictionary:
	if _store == null:
		_store = SaveStore.new(save_dir)
	return _store.read_attempts()


## Points the save system at another folder and reloads from it. Used by tests so they
## never touch the real save; call use_directory(DEFAULT_DIR) to switch back.
func use_directory(path: String) -> void:
	save_dir = path
	load_profile()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


func _now_iso() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"
