## SaveSystem autoload: the children's saved progress, on this device only.
##
## Owns the live save Dictionary of the active profile. Other autoloads (Rewards, Adaptive) read and
## change it through their own methods, then ask for a save; scenes never edit it directly.
## File handling lives in scripts/save/save_store.gd (atomic write, .bak recovery) and
## scripts/save/profile_index.gd (the profile folders and their index, schema v3).
##
## Profiles (Phase 3, Sprint 23): the save root holds up to four children, each in profiles/<id>/
## with their own profile.json and attempts.jsonl. data() is always the active child's document;
## switch_profile() saves it, loads another and emits profile_loaded, on which Adaptive and Rewards
## drop whatever they kept in memory about the previous child. The Profiles autoload is the friendly
## face of this (Profile objects, the four-profile limit); the file work is all here, so a standalone
## SaveSystem in a test folder covers it.
##
## Save points (CLAUDE.md): after every rock, when leaving any screen (Shell), on a posture change
## (Shell), on a profile switch, and here on NOTIFICATION_APPLICATION_PAUSED and
## NOTIFICATION_WM_CLOSE_REQUEST. Closing the app at any moment loses nothing.
extends Node

## A save was written.
signal saved
## Loading found a save it could not use. reason is "corrupt" or "newer_version".
## "none" (no save yet) is a normal first start and does not emit this.
signal load_failed(reason: String)
## A profile was (re)loaded: at start, after use_directory(), after an import and after a profile
## switch. Autoloads that keep in-memory state about the child (Adaptive's placement quest and
## session, Rewards' session tally) reset on this.
signal profile_loaded
## A profile was added, removed, renamed or given another avatar (the title screen's tiles change).
signal profiles_changed

const DEFAULT_DIR: String = "user://save"
## Imports keep copies of the save they replace here (inside the child's folder), the newest
## BACKUPS_KEPT (Sprint 17).
const BACKUP_DIR: String = ProfileIndex.BACKUP_DIR
const BACKUPS_KEPT: int = 5
## The import/export log (per device, apart from the children's saves).
const SYNC_LOG_FILE: String = "sync_log.json"
const SYNC_LOG_KEPT: int = 30
## An imported save without a usable updated_at (SaveMerge refuses it).
const ERR_NO_SAVED_TIME: String = "no_saved_time"
## "Add as a new child" with four profiles already.
const ERR_FULL: String = ProfileIndex.ERR_FULL

## The save root (the profile folders and their index live under it). Tests point this at a temp
## folder with use_directory().
var save_dir: String = DEFAULT_DIR
## What the last load_profile() found: {source, recovered, error, from_version, migrated, profile_id,
## layout}. `layout` is how the profiles were found (ProfileIndex: index, rebuilt, legacy or new).
## The parent dashboard shows a note when `recovered` is true.
var last_load_report: Dictionary = {}
## What the last import_bundle() did: {ok, error, replaced, attempts, older, from_device, added}.
## `added` is the new profile's id after "add as a new child", else "".
var last_import_report: Dictionary = {}

var _index: ProfileIndex
var _profile_id: String = ""
var _store: SaveStore
var _data: Dictionary = {}
## True when the save on disk came from a newer build; we must not overwrite it.
var _read_only: bool = false


func _ready() -> void:
	load_profile()


## Finds the profiles (moving a Version 1.0 single save into profile 1 the first time), then reads
## the active child's save, recovering from .tmp/.bak if needed, migrates it to the current schema and
## fills in any missing keys. With nothing on disk, starts one new profile (written at the first save).
## Named load_profile (not load) because `load` would shadow GDScript's global load().
func load_profile() -> void:
	_index = ProfileIndex.new(save_dir)
	var found: Dictionary = _index.load_or_migrate(_now_iso())
	if _index.on_disk:
		_index.purge_trash(int(Time.get_unix_time_from_system()))
	_load_active(found)


func _load_active(found: Dictionary) -> void:
	_read_only = _index.read_only
	_profile_id = _index.active_id()
	_store = SaveStore.new(_index.profile_dir(_profile_id))
	var read: Dictionary = _store.read_profile()
	var layout_error: String = str(found.get("error", ""))
	last_load_report = {
		"source": read["source"],
		"recovered": read["recovered"] or bool(found.get("recovered", false)) or bool(found.get("legacy_recovered", false)),
		"error": read["error"], "from_version": 0, "migrated": false, "profile_id": _profile_id,
		"layout": found.get("source", &""),
	}
	if layout_error == ProfileIndex.ERR_NEWER_VERSION:
		# The index, or the single save waiting to be moved into profile 1, came from a newer build:
		# nothing is written, so that build finds everything as it left it.
		_read_only = true
		last_load_report["error"] = layout_error
		_data = _new_document()
		load_failed.emit(layout_error)
		profile_loaded.emit()
		return
	if not read["ok"]:
		_data = _new_document()
		if layout_error != "":
			last_load_report["error"] = layout_error
			load_failed.emit(layout_error)
		elif read["error"] != "none":
			load_failed.emit(read["error"])
		profile_loaded.emit()
		return
	var migration: Dictionary = SaveMigrator.migrate(read["data"])
	last_load_report["from_version"] = migration["from_version"]
	if not migration["ok"]:
		last_load_report["error"] = migration["error"]
		_data = _new_document()
		_read_only = migration["error"] == SaveMigrator.ERR_NEWER_VERSION
		load_failed.emit(migration["error"])
		profile_loaded.emit()
		return
	if found.get("source") == ProfileIndex.SOURCE_LEGACY:
		last_load_report["from_version"] = found["legacy_version"] # the Version 1.0 save it came from
	last_load_report["migrated"] = last_load_report["from_version"] != SaveSchema.CURRENT_VERSION
	_data = SaveSchema.with_defaults(migration["data"])
	_data["profile"]["id"] = _profile_id
	profile_loaded.emit()


## A new save document for the active profile, carrying what the index knows about it.
func _new_document() -> Dictionary:
	var document: Dictionary = SaveSchema.new_profile(_now_iso())
	var entry: Dictionary = _index.entry(_profile_id)
	if not entry.is_empty():
		var profile: Profile = Profile.from_dict(entry)
		if profile.created_at == "":
			profile.created_at = document["created_at"]
		profile.apply_to_save(document)
	document["profile"]["id"] = _profile_id
	return document


## The live save dictionary. Mutate it only through the owning autoload.
func data() -> Dictionary:
	return _data


## Writes the save now (atomic). Safe to call often; it is a few kilobytes. The profile index is
## written too when this child's entry changed (nickname, avatar, last day played...) or it was never
## written.
func save_now() -> void:
	_ensure_loaded()
	if _read_only:
		push_warning("SaveSystem: not saving over a save from a newer version of the game")
		return
	_data["updated_at"] = _now_iso()
	_data["device_id"] = DeviceSettings.shared().device_id() # which device wrote this save last
	var error: Error = _store.write_profile(_data)
	if error != OK:
		push_error("SaveSystem: save failed (%s)" % error_string(error))
		return
	_sync_index_entry()
	saved.emit()


func _sync_index_entry() -> void:
	var entry: Dictionary = Profile.from_save(_data).to_dict()
	entry["id"] = _profile_id
	var before: Dictionary = _index.entry(_profile_id)
	if before == entry and _index.on_disk:
		return
	_index.add_entry(entry)
	if _index.save() != OK:
		push_warning("SaveSystem: could not write the profile index")
	if before.get("nickname") != entry["nickname"] or before.get("avatar_id") != entry["avatar_id"]:
		profiles_changed.emit()


## Appends one answer attempt to the active child's attempts.jsonl.
func append_attempt(attempt: Attempt) -> void:
	_ensure_loaded()
	var error: Error = _store.append_attempt(attempt.to_json())
	if error != OK:
		push_error("SaveSystem: could not log attempt (%s)" % error_string(error))


## The active child's logged attempts, oldest first: {entries: Array[Dictionary], skipped: int}.
func read_attempts() -> Dictionary:
	_ensure_loaded()
	return _store.read_attempts()


## A SaveSystem made with new() (a test) and used before load_profile() loads first.
func _ensure_loaded() -> void:
	if _index == null:
		load_profile()


# --- Profiles (Phase 3, Sprint 23) ----------------------------------------------------------------


## The active child's folder (profile.json, attempts.jsonl, backups/).
func profile_dir() -> String:
	return _index.profile_dir(_profile_id)


func profile_id() -> String:
	return _profile_id


## Every profile's index entry (Profile.to_dict()), in the order they were made. Never empty: a new
## device has its first (still blank) profile here before anything is written.
func profile_entries() -> Array:
	return _index.entries().duplicate(true)


func has_profile(id: String) -> bool:
	return _index.has(id)


func profiles_full() -> bool:
	return _index.is_full()


## True once a parent finished onboarding here, or the device already had a Version 1.0 save.
func is_onboarded() -> bool:
	return _index.onboarded()


func mark_onboarded() -> void:
	_index.set_onboarded(true)
	if not _read_only:
		save_now()
		_index.save()


## Saves the active child, then makes `id` the active one and loads it (profile_loaded). A save point.
func switch_profile(id: String) -> Error:
	if not _index.has(id):
		return ERR_DOES_NOT_EXIST
	if id == _profile_id:
		return OK
	if _index.read_only:
		return ERR_UNAVAILABLE
	save_now()
	_index.set_active(id)
	var error: Error = _index.save()
	if error != OK:
		return error
	_load_active({})
	return OK


## Writes a new child's save document into a new profile folder and adds it to the index. Returns the
## new profile's id, or "" with four profiles already (or a read-only index). It does not switch to it.
func create_profile(document: Dictionary) -> String:
	if _index.read_only or _index.is_full():
		return ""
	if not _index.on_disk:
		save_now() # the device's first profile is written before a second one joins it
	var id: String = _index.new_unique_id()
	var new_document: Dictionary = SaveSchema.with_defaults(document)
	new_document["profile"]["id"] = id
	new_document["updated_at"] = _now_iso()
	var error: Error = SaveStore.new(_index.profile_dir(id)).write_profile(new_document)
	if error != OK:
		push_error("SaveSystem: could not create a profile (%s)" % error_string(error))
		return ""
	_index.add_entry(Profile.from_save(new_document).to_dict())
	_index.save()
	profiles_changed.emit()
	return id


## Writes a profile's fields (nickname, avatar, grade, session length, coaching) into that child's
## save, whether or not it is the active one.
func update_profile(profile: Profile) -> Error:
	if not _index.has(profile.id):
		return ERR_DOES_NOT_EXIST
	if profile.id == _profile_id:
		profile.apply_to_save(_data)
		save_now()
		profiles_changed.emit()
		return OK
	if _index.read_only:
		return ERR_UNAVAILABLE
	var store: SaveStore = SaveStore.new(_index.profile_dir(profile.id))
	var read: Dictionary = store.read_profile()
	var document: Dictionary
	if read["ok"]:
		var migration: Dictionary = SaveMigrator.migrate(read["data"])
		if not migration["ok"]:
			return ERR_INVALID_DATA
		document = SaveSchema.with_defaults(migration["data"])
	else:
		document = SaveSchema.new_profile(_now_iso())
	profile.apply_to_save(document)
	var error: Error = store.write_profile(document)
	if error != OK:
		return error
	_index.add_entry(Profile.from_save(document).to_dict())
	_index.save()
	profiles_changed.emit()
	return OK


## Moves a profile to the trash (ProfileIndex.trash; kept 30 days). The last profile cannot be
## deleted. Deleting the active child switches to another one first.
func delete_profile(id: String) -> Error:
	if not _index.has(id):
		return ERR_DOES_NOT_EXIST
	if _index.entries().size() <= 1 or _index.read_only:
		return ERR_UNAVAILABLE
	if id == _profile_id:
		for other: String in _index.ids():
			if other != id:
				var switch_error: Error = switch_profile(other)
				if switch_error != OK:
					return switch_error
				break
	var error: Error = _index.trash(id, _now_iso())
	if error != OK:
		return error
	_index.save()
	profiles_changed.emit()
	return OK


## Deleted profiles still in the trash: [{folder, id, deleted_at}].
func trashed_profiles() -> Array[Dictionary]:
	return _index.trashed()


## Puts a deleted profile back from the trash. Returns its id, or "" (four profiles, or not found).
func restore_profile(trash_folder: String) -> String:
	if _index.read_only:
		return ""
	var id: String = _index.restore(trash_folder)
	if id != "":
		_index.save()
		profiles_changed.emit()
	return id


# --- Progress files (Sprint 17; per profile since Sprint 23) -------------------------------------


## Writes the active child's progress bundle (the save and the whole attempt log) to `path`.
## Parent-gated: only the parent area calls this, and it is the only way progress leaves the device.
## The bundle names the profile (profile_id, nickname). The export is written to the import/export log.
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


## Reads a bundle from `path`. Two choices for the parent (plan section 3.5):
##
## "Replace this profile" (as_new = false; Sprint 17, "newest wins plus backup", the rule is
## SaveMerge.choose), into the active child:
##   newer than this child's save       -> it replaces the save; the old save goes to backups/ first
##   older                              -> nothing is replaced unless `use_older` (the parent chose
##                                         "Use the file anyway"); last_import_report.older says so
##   same moment                        -> this child's save is kept
## The attempt logs are merged in every accepted case. The replaced save keeps this profile's id.
##
## "Add as a new child" (as_new = true): the bundle becomes a new profile (its own id if that is free
## here), with its attempt log; refused with four profiles already (error "full").
##
## A bundle from a newer game version, a file that is not a bundle, a changed file (checksum) or a save
## with no saved time changes nothing. Every import is written to the import/export log. Details in
## last_import_report.
func import_bundle(path: String, use_older: bool = false, as_new: bool = false) -> Error:
	last_import_report = {"ok": false, "error": "", "replaced": false, "attempts": 0, "older": false, "from_device": "", "added": ""}
	if _read_only or _index.read_only:
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
	last_import_report["from_device"] = str(bundle.get("device_id", migration["data"].get("device_id", "")))
	if as_new:
		return _import_as_new(path, bundle, SaveSchema.with_defaults(migration["data"]))
	var decision: Dictionary = SaveMerge.choose(_data, migration["data"])
	if decision["action"] == SaveMerge.REFUSE:
		last_import_report["error"] = ERR_NO_SAVED_TIME
		_log_sync("import", path, "refused")
		return ERR_INVALID_DATA
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
		var incoming: Dictionary = SaveSchema.with_defaults(migration["data"])
		incoming["profile"]["id"] = _profile_id # the file now lives in this child's folder
		var write_error: Error = _store.write_profile(incoming) # also keeps ours as .bak
		if write_error != OK:
			last_import_report["error"] = error_string(write_error)
			_log_sync("import", path, "failed")
			return write_error
		last_import_report["replaced"] = true
		_index.add_entry(Profile.from_save(incoming).to_dict())
		_index.save()
		_load_active({})
		profiles_changed.emit()
	last_import_report["ok"] = true
	_log_sync("import", path, "replaced" if replace else ("older_kept" if last_import_report["older"] else "kept"), last_import_report["from_device"])
	return OK


func _import_as_new(path: String, bundle: Dictionary, document: Dictionary) -> Error:
	if _index.is_full():
		last_import_report["error"] = ERR_FULL
		_log_sync("import", path, "refused")
		return ERR_UNAVAILABLE
	if not _index.on_disk:
		save_now()
	var wanted: String = str(document["profile"].get("id", ""))
	var id: String = wanted if Profile.is_valid_id(wanted) and not _index.has(wanted) and not DirAccess.dir_exists_absolute(_index.profile_dir(wanted)) else _index.new_unique_id()
	document["profile"]["id"] = id
	var store: SaveStore = SaveStore.new(_index.profile_dir(id))
	var error: Error = store.write_profile(document)
	if error == OK:
		var attempts: Array = ProgressBundle.merge_attempts([], bundle["attempts"])
		error = store.write_attempts(attempts)
		last_import_report["attempts"] = attempts.size()
	if error != OK:
		last_import_report["error"] = error_string(error)
		_log_sync("import", path, "failed")
		return error
	_index.add_entry(Profile.from_save(document).to_dict())
	_index.save()
	last_import_report["ok"] = true
	last_import_report["added"] = id
	_log_sync("import", path, "added", last_import_report["from_device"], str(document["child"].get("nickname", "")))
	profiles_changed.emit()
	return OK


## Copies of the active child's save made before an import replaced it, newest first (file paths).
func backups() -> PackedStringArray:
	var dir: String = profile_dir().path_join(BACKUP_DIR)
	var names: Array = Array(DirAccess.get_files_at(dir)) if DirAccess.dir_exists_absolute(dir) else []
	names.sort()
	names.reverse()
	var paths: PackedStringArray = PackedStringArray()
	for name: String in names:
		if name.ends_with(".json"):
			paths.append(dir.path_join(name))
	return paths


## The import/export log, newest first: [{at, action, file, result, device, profile}] (SYNC_LOG_KEPT
## at most). It belongs to this device (it is not part of any child's save, so an import never
## replaces it); `profile` is the nickname of the child it was about.
func sync_log() -> Array:
	var data: Variant = JsonUtil.parse_file(save_dir.path_join(SYNC_LOG_FILE)) if FileAccess.file_exists(save_dir.path_join(SYNC_LOG_FILE)) else null
	return data.get("entries", []) if data is Dictionary and data.get("entries") is Array else []


## Writes the active child's save to backups/<time>.json and keeps the newest BACKUPS_KEPT.
func _write_backup() -> void:
	var dir: String = profile_dir().path_join(BACKUP_DIR)
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


func _log_sync(action: String, path: String, result: String, device: String = "", nickname: String = "") -> void:
	var entries: Array = sync_log()
	var who: String = nickname
	if who == "" and _data.get("child") is Dictionary:
		who = str(_data["child"].get("nickname", ""))
	entries.push_front({"at": _now_iso(), "action": action, "file": path.get_file(), "result": result, "device": device.substr(0, 8), "profile": who})
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
