## File-level save storage: atomic profile writes, backup recovery and the attempt log.
##
## Pure file logic, no autoload and no scene, so tests can point it at a temp folder and
## even "kill the app" at each step of a write (see `crash_after`).
##
## Files in the save folder:
##   profile.json       the save
##   profile.json.bak   the previous good save
##   profile.json.tmp   exists only during a write (or after a crash during one)
##   attempts.jsonl     append-only attempt log, one JSON object per line
##
## Write order: serialize -> write .tmp -> copy the current good profile to .bak -> rename
## .tmp over profile.json. At every instant at least one complete, valid copy exists, and
## read_profile() finds it: profile.json first, then .tmp, then .bak.
class_name SaveStore
extends RefCounted

const PROFILE_FILE: String = "profile.json"
const TMP_FILE: String = "profile.json.tmp"
const BAK_FILE: String = "profile.json.bak"
const ATTEMPTS_FILE: String = "attempts.jsonl"

## Where read_profile() found the data.
const SOURCE_PROFILE: StringName = &"profile"
const SOURCE_TMP: StringName = &"tmp"
const SOURCE_BACKUP: StringName = &"backup"

## Test seam: set to one of these to stop write_profile() as if the app were killed at
## that moment. Production code never sets it.
const CRASH_TMP_PARTIAL: StringName = &"tmp_partial"  # half the JSON is in .tmp
const CRASH_AFTER_TMP: StringName = &"after_tmp"      # .tmp complete, nothing else done
const CRASH_AFTER_BAK: StringName = &"after_bak"      # .bak copied, not yet renamed
const CRASH_MID_RENAME: StringName = &"mid_rename"    # profile.json removed, .tmp not yet renamed

var dir: String
var crash_after: StringName = &""


func _init(save_dir: String) -> void:
	dir = save_dir


## Atomically replaces profile.json with `data`. Returns OK or an error code.
func write_profile(data: Dictionary) -> Error:
	var make_error: Error = DirAccess.make_dir_recursive_absolute(dir)
	if make_error != OK:
		return make_error
	var text: String = JSON.stringify(data, "\t")
	var tmp_path: String = _path(TMP_FILE)
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	if crash_after == CRASH_TMP_PARTIAL:
		file.store_string(text.substr(0, int(text.length() * 0.5)))
		file.close()
		return ERR_FILE_CANT_WRITE
	file.store_string(text)
	file.flush()
	file.close()
	if crash_after == CRASH_AFTER_TMP:
		return ERR_FILE_CANT_WRITE

	# Keep the previous save as .bak, but only if it is itself valid. Copying a corrupt
	# profile.json over a good .bak would destroy the only good copy.
	var profile_path: String = _path(PROFILE_FILE)
	if _read_valid(profile_path) != null:
		var copy_error: Error = DirAccess.copy_absolute(profile_path, _path(BAK_FILE))
		if copy_error != OK:
			return copy_error
	if crash_after == CRASH_AFTER_BAK:
		return ERR_FILE_CANT_WRITE

	if crash_after == CRASH_MID_RENAME:
		DirAccess.remove_absolute(profile_path)
		return ERR_FILE_CANT_WRITE
	var rename_error: Error = DirAccess.rename_absolute(tmp_path, profile_path)
	if rename_error != OK:
		# Some platforms refuse to rename over an existing file: remove it, then rename.
		# read_profile() still finds the complete .tmp if we die between the two calls.
		DirAccess.remove_absolute(profile_path)
		rename_error = DirAccess.rename_absolute(tmp_path, profile_path)
	return rename_error


## Finds the newest valid save. Returns
## {ok: bool, data: Dictionary, source: StringName, recovered: bool, error: String}.
## - no files at all: ok = false, error = "none" (a fresh start, not a problem)
## - files exist but none is valid: ok = false, error = "corrupt"
## - `recovered` is true when the data came from .tmp or .bak instead of profile.json, so
##   the parent dashboard can mention it.
func read_profile() -> Dictionary:
	var any_file: bool = false
	for candidate: Array in [[PROFILE_FILE, SOURCE_PROFILE], [TMP_FILE, SOURCE_TMP], [BAK_FILE, SOURCE_BACKUP]]:
		var path: String = _path(candidate[0])
		if not FileAccess.file_exists(path):
			continue
		any_file = true
		var data: Variant = _read_valid(path)
		if data != null:
			return {
				"ok": true, "data": data, "source": candidate[1],
				"recovered": candidate[1] != SOURCE_PROFILE, "error": "",
			}
	return {
		"ok": false, "data": {}, "source": &"", "recovered": false,
		"error": "corrupt" if any_file else "none",
	}


## Appends one JSON object as a line of attempts.jsonl.
func append_attempt(entry: Dictionary) -> Error:
	var make_error: Error = DirAccess.make_dir_recursive_absolute(dir)
	if make_error != OK:
		return make_error
	var path: String = _path(ATTEMPTS_FILE)
	var file: FileAccess
	var needs_newline: bool = false
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		if file == null:
			return FileAccess.get_open_error()
		var length: int = file.get_length()
		if length > 0:
			# A crash may have left a half-written last line; start a fresh line so the
			# new entry is not glued onto it.
			file.seek(length - 1)
			needs_newline = file.get_8() != 10
		file.seek_end()
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
	if needs_newline:
		file.store_string("\n")
	file.store_string(JSON.stringify(entry) + "\n")
	file.flush()
	file.close()
	return OK


## Reads the attempt log. Returns {entries: Array[Dictionary], skipped: int}; lines that
## are not valid JSON objects (for example a line cut off by a crash) are counted, not fatal.
func read_attempts() -> Dictionary:
	var entries: Array[Dictionary] = []
	var skipped: int = 0
	var path: String = _path(ATTEMPTS_FILE)
	if FileAccess.file_exists(path):
		for line: String in FileAccess.get_file_as_string(path).split("\n", false):
			var parsed: Variant = JsonUtil.parse_text(line)
			if parsed is Dictionary:
				entries.append(parsed)
			else:
				skipped += 1
	return {"entries": entries, "skipped": skipped}


## Replaces attempts.jsonl with `entries` (an import merges two logs). Written to a .tmp first and
## renamed, so a crash leaves the old log or the new one, never half of one.
func write_attempts(entries: Array) -> Error:
	var make_error: Error = DirAccess.make_dir_recursive_absolute(dir)
	if make_error != OK:
		return make_error
	var tmp_path: String = _path(ATTEMPTS_FILE + ".tmp")
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	for entry: Variant in entries:
		file.store_string(JSON.stringify(entry) + "\n")
	file.flush()
	file.close()
	var path: String = _path(ATTEMPTS_FILE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp_path, path)


## The entries of any attempt log file (a fixture, a log from a bundle), skipping broken lines.
func read_attempts_file(path: String) -> Array:
	var entries: Array = []
	if FileAccess.file_exists(path):
		for line: String in FileAccess.get_file_as_string(path).split("\n", false):
			var parsed: Variant = JsonUtil.parse_text(line)
			if parsed is Dictionary:
				entries.append(parsed)
	return entries


func _path(file_name: String) -> String:
	return dir.path_join(file_name)


## The parsed Dictionary if the file holds a complete JSON object with a schema_version,
## otherwise null.
func _read_valid(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JsonUtil.parse_text(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.has("schema_version"):
		return parsed
	return null
