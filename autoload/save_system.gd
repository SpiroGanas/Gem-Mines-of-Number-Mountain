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
## A profile was (re)loaded: at start, after use_directory() and after an import. Autoloads that
## keep in-memory state about the child (Adaptive's placement quest and session) reset on this.
signal profile_loaded

const DEFAULT_DIR: String = "user://save"

## Where the save files live. Tests point this at a temp folder with use_directory().
var save_dir: String = DEFAULT_DIR
## What the last load_profile() found: {source, recovered, error, from_version, migrated}.
## The parent dashboard shows a note when `recovered` is true.
var last_load_report: Dictionary = {}
## What the last import_bundle() did: {ok, error, replaced, attempts}.
var last_import_report: Dictionary = {}

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
		profile_loaded.emit()
		return
	var migration: Dictionary = SaveMigrator.migrate(read["data"])
	last_load_report["from_version"] = migration["from_version"]
	if not migration["ok"]:
		last_load_report["error"] = migration["error"]
		_data = SaveSchema.new_profile(_now_iso())
		_read_only = migration["error"] == SaveMigrator.ERR_NEWER_VERSION
		load_failed.emit(migration["error"])
		profile_loaded.emit()
		return
	last_load_report["migrated"] = migration["from_version"] != SaveSchema.CURRENT_VERSION
	_data = SaveSchema.with_defaults(migration["data"])
	profile_loaded.emit()


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


## Writes the progress bundle (the profile and the whole attempt log) to `path`. Parent-gated:
## only the parent area calls this, and it is the only way progress leaves the device.
func export_bundle(path: String) -> Error:
	save_now()
	var bundle: Dictionary = ProgressBundle.make(_data, read_attempts()["entries"], _now_iso())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(bundle, "\t"))
	file.close()
	return OK


## Reads a bundle from `path`. The newer profile wins (the one replaced is kept as profile.json.bak)
## and the two attempt logs are merged. A bundle from a newer game version, or a file that is not a
## bundle, changes nothing. Details in last_import_report.
func import_bundle(path: String) -> Error:
	last_import_report = {"ok": false, "error": "", "replaced": false, "attempts": 0}
	if _read_only:
		# The save on disk came from a newer build. Importing would write an older profile over it
		# (and the next save would then bury the newer one), so the import is refused like any save.
		last_import_report["error"] = SaveMigrator.ERR_NEWER_VERSION
		return ERR_UNAVAILABLE
	var bundle: Variant = JsonUtil.parse_file(path)
	var problem: String = ProgressBundle.problem_with(bundle)
	if problem != "":
		last_import_report["error"] = problem
		return ERR_INVALID_DATA
	var migration: Dictionary = SaveMigrator.migrate(bundle["profile"])
	if not migration["ok"]:
		last_import_report["error"] = migration["error"]
		return ERR_INVALID_DATA
	if _store == null:
		_store = SaveStore.new(save_dir)
	var merged: Array = ProgressBundle.merge_attempts(read_attempts()["entries"], bundle["attempts"])
	var log_error: Error = _store.write_attempts(merged)
	if log_error != OK:
		last_import_report["error"] = error_string(log_error)
		return log_error
	last_import_report["attempts"] = merged.size()
	if ProgressBundle.is_newer(migration["data"], _data):
		var write_error: Error = _store.write_profile(SaveSchema.with_defaults(migration["data"])) # keeps ours as .bak
		if write_error != OK:
			last_import_report["error"] = error_string(write_error)
			return write_error
		last_import_report["replaced"] = true
		load_profile()
	last_import_report["ok"] = true
	return OK


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
