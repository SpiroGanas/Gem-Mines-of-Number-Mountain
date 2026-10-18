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
## Imports keep copies of the save they replace here, the newest BACKUPS_KEPT (Sprint 17).
const BACKUP_DIR: String = "backups"
const BACKUPS_KEPT: int = 5
## The import/export log (per device, apart from the child's save).
const SYNC_LOG_FILE: String = "sync_log.json"
const SYNC_LOG_KEPT: int = 30
## An imported save without a usable updated_at (SaveMerge refuses it).
const ERR_NO_SAVED_TIME: String = "no_saved_time"

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
	_data["device_id"] = DeviceSettings.shared().device_id() # which device wrote this save last
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
## only the parent area calls this, and it is the only way progress leaves the device. The export is
## written to the import/export log.
func export_bundle(path: String) -> Error:
	save_now()
	var bundle: Dictionary = ProgressBundle.make(_data, read_attempts()["entries"], _now_iso(), DeviceSettings.shared().device_id())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var error: Error = FileAccess.get_open_error()
		_log_sync("export", path, "failed")
		return error
	file.store_string(JSON.stringify(bundle, "\t", false, true)) # full precision: the checksum must survive the trip
	file.close()
	_log_sync("export", path, "ok")
	return OK


## The file name an export suggests: this device and the time (ProgressBundle.file_name).
func export_file_name() -> String:
	return ProgressBundle.file_name(DeviceSettings.shared().device_id(), _now_iso())


## Reads a bundle from `path` (Sprint 17, "newest wins plus backup"; the rule is SaveMerge.choose):
##   newer than this device's save      -> it replaces the save; the old save goes to backups/ first
##   older                              -> nothing is replaced unless `use_older` (the parent chose
##                                         "Use the file anyway"); last_import_report.older says so
##   same moment                        -> this device's save is kept
## The attempt logs are merged in every accepted case. A bundle from a newer game version, a file that
## is not a bundle, a changed file (checksum) or a save with no saved time changes nothing. Every
## import is written to the import/export log. Details in last_import_report.
func import_bundle(path: String, use_older: bool = false) -> Error:
	last_import_report = {"ok": false, "error": "", "replaced": false, "attempts": 0, "older": false, "from_device": ""}
	if _read_only:
		# The save on disk came from a newer build. Importing would write an older profile over it
		# (and the next save would then bury the newer one), so the import is refused like any save.
		last_import_report["error"] = SaveMigrator.ERR_NEWER_VERSION
		_log_sync("import", path, "refused")
		return ERR_UNAVAILABLE
	var bundle: Variant = JsonUtil.parse_file(path)
	var problem: String = ProgressBundle.problem_with(bundle)
	if problem != "":
		last_import_report["error"] = problem
		_log_sync("import", path, "refused")
		return ERR_INVALID_DATA
	var migration: Dictionary = SaveMigrator.migrate(bundle["profile"])
	if not migration["ok"]:
		last_import_report["error"] = migration["error"]
		_log_sync("import", path, "refused")
		return ERR_INVALID_DATA
	var decision: Dictionary = SaveMerge.choose(_data, migration["data"])
	if decision["action"] == SaveMerge.REFUSE:
		last_import_report["error"] = ERR_NO_SAVED_TIME
		_log_sync("import", path, "refused")
		return ERR_INVALID_DATA
	last_import_report["from_device"] = str(bundle.get("device_id", migration["data"].get("device_id", "")))
	if _store == null:
		_store = SaveStore.new(save_dir)
	var merged: Array = ProgressBundle.merge_attempts(read_attempts()["entries"], bundle["attempts"])
	var log_error: Error = _store.write_attempts(merged)
	if log_error != OK:
		last_import_report["error"] = error_string(log_error)
		_log_sync("import", path, "failed")
		return log_error
	last_import_report["attempts"] = merged.size()
	last_import_report["older"] = decision["action"] == SaveMerge.ASK
	var replace: bool = decision["action"] == SaveMerge.REPLACE or (decision["action"] == SaveMerge.ASK and use_older)
	if replace:
		_write_backup()
		var write_error: Error = _store.write_profile(SaveSchema.with_defaults(migration["data"])) # also keeps ours as .bak
		if write_error != OK:
			last_import_report["error"] = error_string(write_error)
			_log_sync("import", path, "failed")
			return write_error
		last_import_report["replaced"] = true
		load_profile()
	last_import_report["ok"] = true
	_log_sync("import", path, "replaced" if replace else ("older_kept" if last_import_report["older"] else "kept"), last_import_report["from_device"])
	return OK


## Copies of the save made before an import replaced it, newest first (file paths).
func backups() -> PackedStringArray:
	var dir: String = save_dir.path_join(BACKUP_DIR)
	var names: Array = Array(DirAccess.get_files_at(dir)) if DirAccess.dir_exists_absolute(dir) else []
	names.sort()
	names.reverse()
	var paths: PackedStringArray = PackedStringArray()
	for name: String in names:
		if name.ends_with(".json"):
			paths.append(dir.path_join(name))
	return paths


## The import/export log, newest first: [{at, action, file, result, device}] (SYNC_LOG_KEPT at most).
## It belongs to this device (it is not part of the child's save, so an import never replaces it).
func sync_log() -> Array:
	var data: Variant = JsonUtil.parse_file(save_dir.path_join(SYNC_LOG_FILE)) if FileAccess.file_exists(save_dir.path_join(SYNC_LOG_FILE)) else null
	return data.get("entries", []) if data is Dictionary and data.get("entries") is Array else []


## Writes the current save to backups/<time>.json and keeps the newest BACKUPS_KEPT.
func _write_backup() -> void:
	var dir: String = save_dir.path_join(BACKUP_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp: String = _now_iso().replace(":", "").replace("-", "")
	var path: String = dir.path_join("%s.json" % stamp)
	var suffix: int = 1
	while FileAccess.file_exists(path):
		path = dir.path_join("%s-%d.json" % [stamp, suffix])
		suffix += 1
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: could not write a backup before the import")
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
	var all: PackedStringArray = backups()
	for index: int in range(BACKUPS_KEPT, all.size()):
		DirAccess.remove_absolute(all[index])


func _log_sync(action: String, path: String, result: String, device: String = "") -> void:
	var entries: Array = sync_log()
	entries.push_front({"at": _now_iso(), "action": action, "file": path.get_file(), "result": result, "device": device.substr(0, 8)})
	while entries.size() > SYNC_LOG_KEPT:
		entries.pop_back()
	DirAccess.make_dir_recursive_absolute(save_dir)
	var file: FileAccess = FileAccess.open(save_dir.path_join(SYNC_LOG_FILE), FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: could not write the import/export log")
		return
	file.store_string(JSON.stringify({"entries": entries}, "\t"))
	file.close()


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
