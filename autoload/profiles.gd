## Profiles autoload: up to four child profiles on one device (Phase 3, plan section 3.5).
##
## Every per-child autoload (Adaptive, Rewards, the session timer, the lantern streak) reads and
## writes through SaveSystem.data(), which is always the active child's save. This autoload creates,
## selects, renames and deletes profiles as Profile objects and announces the changes; SaveSystem does
## the file work (profile folders, the index, the trash) so a standalone one covers it in tests.
##
## Switching: select() saves the current child, loads the other one and SaveSystem emits
## profile_loaded (Adaptive and Rewards drop their in-memory session state on it); this autoload then
## emits active_profile_changed. Deleting is for the parent area only, behind two confirmations
## (ProfilesScreen); the files go to the trash for 30 days.
##
## Godot note: an *autoload* is a node Godot creates at start-up and keeps for the whole run, reachable
## by its name from any script (here `Profiles`). It is registered after SaveSystem in project.godot so
## the save is loaded before this reads it.
extends Node

## The active child changed (a switch, a deletion of the active child, an import or a test's
## use_directory()). Fired after the new child's save is loaded.
signal active_profile_changed(profile: Profile)
## A profile was added, removed, renamed or given another avatar.
signal profiles_changed()

const MAX_PROFILES: int = ProfileIndex.MAX_PROFILES

## The active child's profile (read from their save).
var active: Profile

var _save: Node


func _ready() -> void:
	use_save_system(SaveSystem)


## Points this at a SaveSystem (the autoload, or a standalone one in a test).
func use_save_system(system: Node) -> void:
	if _save != null:
		if _save.profile_loaded.is_connected(_on_profile_loaded):
			_save.profile_loaded.disconnect(_on_profile_loaded)
		if _save.profiles_changed.is_connected(_on_profiles_changed):
			_save.profiles_changed.disconnect(_on_profiles_changed)
	_save = system
	_save.profile_loaded.connect(_on_profile_loaded)
	_save.profiles_changed.connect(_on_profiles_changed)
	_refresh_active()


## Every profile on this device, in the order they were made (never empty). The active child's is
## read from their live save, so a change not yet saved already shows.
func list() -> Array[Profile]:
	var result: Array[Profile] = []
	for entry: Dictionary in _save.profile_entries():
		if entry.get("id") == _save.profile_id():
			var live: Profile = Profile.from_save(_save.data())
			live.id = _save.profile_id()
			result.append(live)
		else:
			result.append(Profile.from_dict(entry))
	return result


func count() -> int:
	return _save.profile_entries().size()


func can_add() -> bool:
	return not _save.profiles_full()


## The profile with this id, or null.
func get_profile(id: String) -> Profile:
	for profile: Profile in list():
		if profile.id == id:
			return profile
	return null


## Makes a new child profile (it does not switch to it). The new child's skills start from the
## generic placement priors of `starting_grade` (Placement.seed_from_grade) and their placement quest
## starts from that grade's probes. Returns null with four profiles already or a blank nickname.
func create(nickname: String, avatar_id: StringName, starting_grade: int, session_minutes: int = Profile.DEFAULT_SESSION_MINUTES) -> Profile:
	var cleaned: String = Profile.clean_nickname(nickname)
	if cleaned == "" or not can_add():
		return null
	var id: String = _save.create_profile(new_document(cleaned, avatar_id, starting_grade, session_minutes, _now_iso()))
	return get_profile(id) if id != "" else null


## A new child's save document: the schema defaults, this profile's fields, the grade's placement seed
## and the grade's BKT priors. Bolt has not said hello yet (profile.welcomed = false).
static func new_document(nickname: String, avatar_id: StringName, starting_grade: int, session_minutes: int, now_iso: String) -> Dictionary:
	var document: Dictionary = SaveSchema.new_profile(now_iso)
	var profile: Profile = Profile.new()
	profile.nickname = Profile.clean_nickname(nickname)
	profile.avatar_id = avatar_id if Profile.is_valid_avatar(avatar_id) else Profile.DEFAULT_AVATAR
	profile.created_at = now_iso
	profile.starting_grade = Profile.clamp_grade(starting_grade)
	profile.session_minutes = maxi(session_minutes, 1)
	profile.apply_to_save(document)
	document["profile"]["welcomed"] = false
	document["placement"]["seed"] = Placement.grade_seed_name(profile.starting_grade)
	var priors: Dictionary = Placement.seed_from_grade(profile.starting_grade)
	for skill_id: String in priors:
		document["skills"][skill_id] = SkillRecord.fresh(priors[skill_id])
	return document


## Switches to another child: saves the current one first. False if there is no such profile.
func select(profile_id: String) -> bool:
	return _save.switch_profile(profile_id) == OK


## Parent area only, after two confirmations (ProfilesScreen). The last profile cannot be deleted.
func delete(profile_id: String) -> bool:
	return _save.delete_profile(profile_id) == OK


func rename(profile_id: String, nickname: String) -> bool:
	var profile: Profile = get_profile(profile_id)
	var cleaned: String = Profile.clean_nickname(nickname)
	if profile == null or cleaned == "":
		return false
	profile.nickname = cleaned
	return _save.update_profile(profile) == OK


func set_avatar(profile_id: String, avatar_id: StringName) -> bool:
	var profile: Profile = get_profile(profile_id)
	if profile == null or not Profile.is_valid_avatar(avatar_id):
		return false
	profile.avatar_id = avatar_id
	return _save.update_profile(profile) == OK


## Deleted profiles still in the trash (parent area: "bring back").
func trashed() -> Array[Dictionary]:
	return _save.trashed_profiles()


func restore(trash_folder: String) -> Profile:
	var id: String = _save.restore_profile(trash_folder)
	return get_profile(id) if id != "" else null


# --- Onboarding (plan section 3.7) ----------------------------------------------------------------


## True on a new install: no parent has set the game up yet and no child has a name. A device that
## had Charlie's Version 1.0 save is set up already (ProfileIndex.migrate_layout).
func needs_onboarding() -> bool:
	if _save.is_onboarded():
		return false
	for profile: Profile in list():
		if profile.nickname != "":
			return false
	return true


## Onboarding's "create the first profile": the device's first, still blank profile becomes this
## child (same id, no second folder). If the active profile is not blank (it has a name or answers),
## a new profile is made and selected instead. Returns the child's profile, or null.
func setup_first(nickname: String, avatar_id: StringName, starting_grade: int, session_minutes: int) -> Profile:
	if Profile.clean_nickname(nickname) == "":
		return null
	if not is_blank():
		var made: Profile = create(nickname, avatar_id, starting_grade, session_minutes)
		if made != null:
			select(made.id)
		return made
	var document: Dictionary = new_document(nickname, avatar_id, starting_grade, session_minutes, _now_iso())
	var current: Dictionary = _save.data()
	var keep_id: String = _save.profile_id()
	var keep_created: String = str(current.get("created_at", document["created_at"]))
	current.clear()
	current.merge(document)
	current["profile"]["id"] = keep_id
	current["created_at"] = keep_created
	current["profile"]["created_at"] = keep_created
	_save.save_now()
	_save.load_profile() # Adaptive and Rewards start this child afresh (profile_loaded)
	return active


## The parent finished onboarding: it does not show again on this device.
func finish_onboarding() -> void:
	_save.mark_onboarded()


## The active profile has no name and nothing played: what a new install starts with.
func is_blank() -> bool:
	var data: Dictionary = _save.data()
	if str(data["child"].get("nickname", "")) != "":
		return false
	for id: String in data["skills"]:
		if int(data["skills"][id].get("attempts", 0)) > 0:
			return false
	return _save.read_attempts()["entries"].is_empty()


func _refresh_active() -> void:
	active = Profile.from_save(_save.data())
	active.id = _save.profile_id()


func _on_profile_loaded() -> void:
	_refresh_active()
	active_profile_changed.emit(active)


func _on_profiles_changed() -> void:
	_refresh_active()
	profiles_changed.emit()


func _now_iso() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"
