## The profile index and the on-disk layout of up to four child profiles (Phase 3, Sprint 23;
## docs/decisions.md "Save schema v3: profiles"). Pure file logic like SaveStore: no autoload and no
## scene, so tests point it at a temp folder.
##
## Layout under the save root (user://save, or a test folder):
##   profiles/index.json            {schema_version, active_profile_id, onboarded, profiles: [...]}
##                                  (+ .tmp/.bak: written atomically by SaveStore)
##   profiles/<id>/profile.json     one child's save document (SaveSchema), + .tmp/.bak
##   profiles/<id>/attempts.jsonl   that child's attempt log
##   profiles/<id>/backups/         copies made before an import replaced that child's save
##   sync_log.json                  the device's import/export log (all children)
##   trash/<id>-<stamp>/            a deleted profile, kept TRASH_DAYS days, then removed at a launch
##   save.v<N>.bak                  the single Version 1.0 save, kept after it became profile 1
##
## The index is a cache for the title screen (every tile without loading every save): each entry is
## Profile.to_dict() of that child's document. When every copy of the index is unreadable it is
## rebuilt from the profile folders, so losing it never loses a child.
class_name ProfileIndex
extends RefCounted

const MAX_PROFILES: int = 4
const PROFILES_DIR: String = "profiles"
const INDEX_FILE: String = "index.json"
## Written while the single Version 1.0 save is being moved, removed once the index is written: after a
## crash in between, the next start moves the save again into the same folder (never a second one).
const MIGRATING_FILE: String = "migrating.json"
const ATTEMPTS_FILE: String = "attempts.jsonl"
const BACKUP_DIR: String = "backups"
const TRASH_DIR: String = "trash"
const TRASH_DAYS: int = 30
const ERR_NEWER_VERSION: String = "newer_version"
const ERR_CORRUPT: String = "corrupt"
const ERR_FULL: String = "full"

## How load() found the index.
const SOURCE_INDEX: StringName = &"index"
const SOURCE_REBUILT: StringName = &"rebuilt"
const SOURCE_LEGACY: StringName = &"legacy"
const SOURCE_NEW: StringName = &"new"

var root: String
## {schema_version, active_profile_id, onboarded, profiles: Array[Dictionary]}.
var data: Dictionary = {}
## True once the index has been written (a brand-new device keeps it in memory until the first save).
var on_disk: bool = false
## True when the index came from a newer build of the game: it must not be overwritten.
var read_only: bool = false

var _store: SaveStore


func _init(root_dir: String) -> void:
	root = root_dir
	_store = SaveStore.new(root.path_join(PROFILES_DIR), INDEX_FILE)
	data = _empty()


## Finds the profiles. Returns {ok, source, error, recovered, legacy_version, legacy_recovered}:
##   - the index file (or its .tmp/.bak): source "index"
##   - no readable index but profile folders: rebuilt from them, source "rebuilt"
##   - the single Version 1.0 save at the root: moved into profile 1, source "legacy"
##     (legacy_version is its schema version)
##   - nothing at all: one new profile in memory, source "new"
## A legacy save that cannot be read (error "corrupt") or comes from a newer build is left where it
## is, untouched, and a new profile starts.
func load_or_migrate(now_iso: String) -> Dictionary:
	var report: Dictionary = {"ok": true, "source": SOURCE_NEW, "error": "", "recovered": false, "legacy_version": 0, "legacy_recovered": false}
	read_only = false
	var read: Dictionary = _store.read_profile()
	if read["ok"] and not _cleaned(read["data"])["profiles"].is_empty():
		data = _cleaned(read["data"])
		on_disk = true
		report["source"] = SOURCE_INDEX
		report["recovered"] = read["recovered"]
		read_only = int(read["data"].get("schema_version", 0)) > SaveSchema.CURRENT_VERSION
		if read_only:
			report["error"] = ERR_NEWER_VERSION
		return report
	# A move of the single save that never finished leaves its marker: its folder is not a real profile
	# yet, so the single save is moved again rather than the half-made folder being trusted.
	var unfinished_move: bool = FileAccess.file_exists(_migrating_path())
	if not unfinished_move and rebuild_from_folders():
		report["source"] = SOURCE_REBUILT
		report["recovered"] = true
		save()
		return report
	if has_legacy():
		var moved: Dictionary = migrate_layout(now_iso)
		if moved["ok"]:
			report["source"] = SOURCE_LEGACY
			report["legacy_version"] = moved["from_version"]
			report["legacy_recovered"] = moved["recovered"]
			return report
		report["error"] = moved["error"]
	elif unfinished_move and rebuild_from_folders():
		report["source"] = SOURCE_REBUILT
		report["recovered"] = true
		save()
		DirAccess.remove_absolute(_migrating_path())
		return report
	data = _empty()
	add_entry(_fresh_entry(new_unique_id(), now_iso))
	data["active_profile_id"] = entries()[0]["id"]
	on_disk = false
	return report


## Writes the index atomically (unless it came from a newer build).
func save() -> Error:
	if read_only:
		return ERR_UNAVAILABLE
	data["schema_version"] = SaveSchema.CURRENT_VERSION
	var error: Error = _store.write_profile(data)
	if error == OK:
		on_disk = true
	return error


func entries() -> Array:
	return data["profiles"]


func ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries():
		result.append(str(entry.get("id", "")))
	return result


func has(id: String) -> bool:
	return ids().has(id)


func entry(id: String) -> Dictionary:
	for candidate: Dictionary in entries():
		if candidate.get("id") == id:
			return candidate
	return {}


func is_full() -> bool:
	return entries().size() >= MAX_PROFILES


## Adds a profile's entry, or replaces the entry with the same id (keeping its place in the list).
func add_entry(new_entry: Dictionary) -> void:
	var list: Array = entries()
	for index: int in list.size():
		if list[index].get("id") == new_entry.get("id"):
			list[index] = new_entry.duplicate(true)
			return
	list.append(new_entry.duplicate(true))


func remove_entry(id: String) -> void:
	var list: Array = entries()
	for index: int in range(list.size() - 1, -1, -1):
		if list[index].get("id") == id:
			list.remove_at(index)


func active_id() -> String:
	return str(data.get("active_profile_id", ""))


func set_active(id: String) -> void:
	data["active_profile_id"] = id


## True once a parent finished onboarding on this device (or the device already had Charlie's save).
func onboarded() -> bool:
	return bool(data.get("onboarded", false))


func set_onboarded(value: bool) -> void:
	data["onboarded"] = value


func profile_dir(id: String) -> String:
	return root.path_join(PROFILES_DIR).path_join(id)


## A new id not used by any profile here.
func new_unique_id() -> String:
	var id: String = Profile.new_id()
	while has(id) or DirAccess.dir_exists_absolute(profile_dir(id)):
		id = Profile.new_id()
	return id


# --- The single Version 1.0 save (legacy layout) -------------------------------------------------


## True when the root still holds a single-profile save (profile.json, or its .tmp or .bak).
func has_legacy() -> bool:
	for file_name: String in [SaveStore.PROFILE_FILE, SaveStore.TMP_FILE, SaveStore.BAK_FILE]:
		if FileAccess.file_exists(root.path_join(file_name)):
			return true
	return false


## Moves the single Version 1.0 save into profile 1 (plan section 3.5). The document is migrated to
## the current schema (every skill record, reward and workshop entry kept as it was) and written to
## profiles/<id>/profile.json, the attempt log is copied beside it, and only then is the index written:
## the index is the commit point. After it: the old profile.json becomes save.v<N>.bak, its .bak
## becomes the new profile's .bak, the import backups move into the profile, and the old log and
## .tmp are removed. A crash before the index is written leaves the old save where it was, so the next
## launch simply moves it again, into the same folder (MIGRATING_FILE remembers which).
## Returns {ok, id, from_version, recovered, error}.
func migrate_layout(now_iso: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "id": "", "from_version": 0, "recovered": false, "error": ""}
	var legacy: SaveStore = SaveStore.new(root)
	var read: Dictionary = legacy.read_profile()
	if not read["ok"]:
		result["error"] = read["error"] if read["error"] != "none" else ERR_CORRUPT
		return result
	var migration: Dictionary = SaveMigrator.migrate(read["data"])
	result["from_version"] = migration["from_version"]
	if not migration["ok"]:
		result["error"] = migration["error"]
		return result
	var id: String = _unfinished_move_id()
	if id == "":
		id = new_unique_id()
		DirAccess.make_dir_recursive_absolute(root.path_join(PROFILES_DIR))
		var marker: FileAccess = FileAccess.open(_migrating_path(), FileAccess.WRITE)
		if marker != null:
			marker.store_string(JSON.stringify({"id": id}))
			marker.close()
	var document: Dictionary = SaveSchema.with_defaults(migration["data"])
	document["profile"]["id"] = id
	if str(document["profile"].get("created_at", "")) == "":
		document["profile"]["created_at"] = str(document.get("created_at", now_iso))
	var folder: String = profile_dir(id)
	var store: SaveStore = SaveStore.new(folder)
	var write_error: Error = store.write_profile(document)
	if write_error != OK:
		result["error"] = error_string(write_error)
		return result
	var old_log: String = root.path_join(ATTEMPTS_FILE)
	if FileAccess.file_exists(old_log):
		var copy_error: Error = DirAccess.copy_absolute(old_log, folder.path_join(ATTEMPTS_FILE))
		if copy_error != OK:
			result["error"] = error_string(copy_error)
			return result
	elif FileAccess.file_exists(folder.path_join(ATTEMPTS_FILE)):
		DirAccess.remove_absolute(folder.path_join(ATTEMPTS_FILE)) # left by an unfinished move
	data = _empty()
	add_entry(Profile.from_save(document).to_dict())
	set_active(id)
	set_onboarded(true) # this family set the game up before profiles existed
	data["migrated_from"] = migration["from_version"]
	var index_error: Error = save()
	if index_error != OK:
		result["error"] = error_string(index_error)
		return result
	DirAccess.remove_absolute(_migrating_path())
	_tidy_legacy(migration["from_version"], folder, read)
	result["ok"] = true
	result["id"] = id
	result["recovered"] = read["recovered"]
	return result


func _migrating_path() -> String:
	return root.path_join(PROFILES_DIR).path_join(MIGRATING_FILE)


## The folder id of a move that did not finish (MIGRATING_FILE), or "".
func _unfinished_move_id() -> String:
	if not FileAccess.file_exists(_migrating_path()):
		return ""
	var marker: Variant = JsonUtil.parse_file(_migrating_path())
	var id: String = str(marker.get("id", "")) if marker is Dictionary else ""
	return id if Profile.is_valid_id(id) else ""


func _tidy_legacy(from_version: int, folder: String, read: Dictionary) -> void:
	var kept: String = root.path_join("save.v%d.bak" % from_version)
	var old_profile: String = root.path_join(SaveStore.PROFILE_FILE)
	if FileAccess.file_exists(kept):
		DirAccess.remove_absolute(kept)
	if FileAccess.file_exists(old_profile) and not read["recovered"]:
		DirAccess.rename_absolute(old_profile, kept)
	else:
		# The save was recovered from .tmp or .bak: keep the copy that was actually used.
		var file: FileAccess = FileAccess.open(kept, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(read["data"], "\t"))
			file.close()
		if FileAccess.file_exists(old_profile):
			DirAccess.remove_absolute(old_profile)
	var old_bak: String = root.path_join(SaveStore.BAK_FILE)
	if FileAccess.file_exists(old_bak):
		DirAccess.rename_absolute(old_bak, folder.path_join(SaveStore.BAK_FILE))
	for leftover: String in [SaveStore.TMP_FILE, ATTEMPTS_FILE]:
		if FileAccess.file_exists(root.path_join(leftover)):
			DirAccess.remove_absolute(root.path_join(leftover))
	var old_backups: String = root.path_join(BACKUP_DIR)
	if DirAccess.dir_exists_absolute(old_backups):
		DirAccess.rename_absolute(old_backups, folder.path_join(BACKUP_DIR))


## Rebuilds the index from the profile folders (every copy of index.json was unreadable). False when
## there is no readable profile folder.
func rebuild_from_folders() -> bool:
	var base: String = root.path_join(PROFILES_DIR)
	if not DirAccess.dir_exists_absolute(base):
		return false
	var found: Array[Dictionary] = []
	var names: Array = Array(DirAccess.get_directories_at(base))
	names.sort()
	for name: String in names:
		if not Profile.is_valid_id(name) or found.size() >= MAX_PROFILES:
			continue
		var read: Dictionary = SaveStore.new(base.path_join(name)).read_profile()
		if not read["ok"]:
			continue
		var profile: Profile = Profile.from_save(read["data"])
		profile.id = name
		found.append(profile.to_dict())
	if found.is_empty():
		return false
	data = _empty()
	for entry_found: Dictionary in found:
		add_entry(entry_found)
	set_active(found[0]["id"])
	set_onboarded(true)
	return true


# --- Deleting a profile (the trash) --------------------------------------------------------------


## Moves a profile's folder to trash/<id>-<stamp>/ and drops it from the index (the caller saves the
## index). The files stay TRASH_DAYS days in case a parent deleted the wrong child.
func trash(id: String, now_iso: String) -> Error:
	if not has(id):
		return ERR_DOES_NOT_EXIST
	var trash_root: String = root.path_join(TRASH_DIR)
	DirAccess.make_dir_recursive_absolute(trash_root)
	var target: String = trash_root.path_join("%s-%s" % [id, _stamp(now_iso)])
	var folder: String = profile_dir(id)
	if DirAccess.dir_exists_absolute(folder):
		var error: Error = DirAccess.rename_absolute(folder, target)
		if error != OK:
			return error
	remove_entry(id)
	return OK


## Deleted profiles still in the trash: [{folder, id, deleted_at}] (deleted_at as yyyymmddThhmmss).
func trashed() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var trash_root: String = root.path_join(TRASH_DIR)
	if not DirAccess.dir_exists_absolute(trash_root):
		return result
	for name: String in DirAccess.get_directories_at(trash_root):
		var parts: PackedStringArray = name.split("-", false, 1)
		if parts.size() == 2 and Profile.is_valid_id(parts[0]):
			result.append({"folder": trash_root.path_join(name), "id": parts[0], "deleted_at": parts[1]})
	return result


## Puts a trashed profile back (if there is room and its id is free). Returns the id or "".
func restore(trash_folder: String) -> String:
	var name: String = trash_folder.get_file()
	var id: String = name.split("-", false, 1)[0]
	if is_full() or has(id) or not DirAccess.dir_exists_absolute(trash_folder):
		return ""
	DirAccess.make_dir_recursive_absolute(root.path_join(PROFILES_DIR))
	if DirAccess.rename_absolute(trash_folder, profile_dir(id)) != OK:
		return ""
	var read: Dictionary = SaveStore.new(profile_dir(id)).read_profile()
	var profile: Profile = Profile.from_save(read["data"]) if read["ok"] else Profile.new()
	profile.id = id
	add_entry(profile.to_dict())
	return id


## Removes trashed profiles older than TRASH_DAYS days. Returns how many went.
func purge_trash(now_unix: int) -> int:
	var removed: int = 0
	for item: Dictionary in trashed():
		var stamp: String = str(item["deleted_at"])
		if stamp.length() < 15:
			continue
		var iso: String = "%s-%s-%sT%s:%s:%s" % [stamp.substr(0, 4), stamp.substr(4, 2), stamp.substr(6, 2), stamp.substr(9, 2), stamp.substr(11, 2), stamp.substr(13, 2)]
		var deleted_unix: int = Time.get_unix_time_from_datetime_string(iso)
		if now_unix - deleted_unix >= TRASH_DAYS * 86400:
			remove_tree(item["folder"])
			removed += 1
	return removed


## Deletes a folder and everything in it.
static func remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	for name: String in DirAccess.get_directories_at(path):
		remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)


func _empty() -> Dictionary:
	return {"schema_version": SaveSchema.CURRENT_VERSION, "active_profile_id": "", "onboarded": false, "profiles": []}


## The index entry of a brand-new device's first (still empty) profile.
func _fresh_entry(id: String, now_iso: String) -> Dictionary:
	var profile: Profile = Profile.new()
	profile.id = id
	profile.created_at = now_iso
	return profile.to_dict()


## A read index with its parts checked: entries with a bad id are dropped, at most MAX_PROFILES kept,
## and the active id is one of them.
func _cleaned(read: Dictionary) -> Dictionary:
	var result: Dictionary = read.duplicate(true)
	var kept: Array = []
	if read.get("profiles") is Array:
		for item: Variant in read["profiles"]:
			if item is Dictionary and Profile.is_valid_id(str(item.get("id", ""))) and kept.size() < MAX_PROFILES:
				kept.append(item)
	result["profiles"] = kept
	var ids_kept: Array = kept.map(func(item: Dictionary) -> String: return str(item["id"]))
	if not ids_kept.has(str(read.get("active_profile_id", ""))):
		result["active_profile_id"] = ids_kept[0] if not ids_kept.is_empty() else ""
	if not read.get("onboarded") is bool:
		result["onboarded"] = not kept.is_empty()
	return result


static func _stamp(now_iso: String) -> String:
	return now_iso.replace("-", "").replace(":", "").trim_suffix("Z")
