## One child profile on this device (Phase 3, plan section 3.5): who is playing, which picture marks
## their tile on the title screen, and the settings a parent chose for them. Up to four per device
## (Profiles.MAX_PROFILES).
##
## The child's save document stays the one source of truth (SaveSchema, schema v3): this object is
## read from it (from_save) and written back to it (apply_to_save). The profile index
## (user://save/profiles/index.json) keeps a copy of to_dict() for each profile so the title screen can
## show every tile without loading every save.
##
## The nickname is the only personal data the game stores: a first name or a nickname, typed by a
## parent in the parent area. Avatars are code-drawn pictures (AvatarArt), never photos.
##
## Godot note: a *Resource* is Godot's data object (it can be saved, duplicated and passed around
## by reference). This one holds no node references, so tests build it on its own.
class_name Profile
extends Resource

## The code-drawn avatars (AvatarArt draws each one). Bolt-themed mining pictures; no animals.
const AVATARS: Array[StringName] = [&"bolt", &"lamp", &"gem", &"pickaxe", &"cart", &"crystal", &"rocket", &"gear"]
const DEFAULT_AVATAR: StringName = &"bolt"
## Grades a parent can pick: 0 is kindergarten, then grades 1 to 6.
const MIN_GRADE: int = 0
const MAX_GRADE: int = 6
const DEFAULT_GRADE: int = 1
const DEFAULT_SESSION_MINUTES: int = 20
const NICKNAME_MAX_LENGTH: int = 20
## "p_" plus 8 hex characters.
const ID_PREFIX: String = "p_"
const ID_HEX_LENGTH: int = 8

var id: String = ""
var nickname: String = ""
var avatar_id: StringName = DEFAULT_AVATAR
## ISO 8601 UTC timestamp the profile was made.
var created_at: String = ""
## The last day (yyyy-mm-dd) this child played, or "" before the first rock.
var last_played_at: String = ""
var starting_grade: int = DEFAULT_GRADE
## "explorer" for every Phase 3 profile (Scholar mode arrives in Phase 4).
var interface_mode: String = "explorer"
## The parent's soft session limit.
var session_minutes: int = DEFAULT_SESSION_MINUTES
var handwriting_coaching: bool = false


## A new random id: "p_" and 8 hex characters from the system's secure random (Crypto). Not derived
## from anything about the child or the device.
static func new_id() -> String:
	return ID_PREFIX + Crypto.new().generate_random_bytes(ID_HEX_LENGTH / 2).hex_encode()


## True for an id new_id() could have made (the profile folder is named after it, so nothing else is
## ever used as a path).
static func is_valid_id(value: String) -> bool:
	if value.length() != ID_PREFIX.length() + ID_HEX_LENGTH or not value.begins_with(ID_PREFIX):
		return false
	for character: String in value.substr(ID_PREFIX.length()):
		if not "0123456789abcdef".contains(character):
			return false
	return true


## The nickname as stored: trimmed and at most NICKNAME_MAX_LENGTH characters.
static func clean_nickname(value: String) -> String:
	return value.strip_edges().left(NICKNAME_MAX_LENGTH)


static func is_valid_avatar(value: StringName) -> bool:
	return AVATARS.has(value)


static func clamp_grade(value: int) -> int:
	return clampi(value, MIN_GRADE, MAX_GRADE)


func to_dict() -> Dictionary:
	return {
		"id": id, "nickname": nickname, "avatar_id": String(avatar_id),
		"created_at": created_at, "last_played_at": last_played_at,
		"starting_grade": starting_grade, "interface_mode": interface_mode,
		"session_minutes": session_minutes, "handwriting_coaching": handwriting_coaching,
	}


## A profile from an index entry. Missing or mistyped fields get their defaults.
static func from_dict(data: Dictionary) -> Profile:
	var profile: Profile = Profile.new()
	profile.id = str(data.get("id", ""))
	profile.nickname = clean_nickname(str(data.get("nickname", "")))
	var avatar: StringName = StringName(str(data.get("avatar_id", DEFAULT_AVATAR)))
	profile.avatar_id = avatar if is_valid_avatar(avatar) else DEFAULT_AVATAR
	profile.created_at = str(data.get("created_at", ""))
	profile.last_played_at = str(data.get("last_played_at", ""))
	profile.starting_grade = clamp_grade(_int(data.get("starting_grade"), DEFAULT_GRADE))
	profile.interface_mode = str(data.get("interface_mode", "explorer"))
	profile.session_minutes = maxi(_int(data.get("session_minutes"), DEFAULT_SESSION_MINUTES), 1)
	profile.handwriting_coaching = bool(data.get("handwriting_coaching", false))
	return profile


## The profile a save document describes (schema v3: the `profile` block, child.nickname and the
## settings).
static func from_save(save: Dictionary) -> Profile:
	var block: Dictionary = save.get("profile", {}) if save.get("profile") is Dictionary else {}
	var settings: Dictionary = save.get("settings", {}) if save.get("settings") is Dictionary else {}
	var child: Dictionary = save.get("child", {}) if save.get("child") is Dictionary else {}
	return from_dict({
		"id": block.get("id", ""), "nickname": child.get("nickname", ""),
		"avatar_id": block.get("avatar_id", DEFAULT_AVATAR),
		"created_at": block.get("created_at", save.get("created_at", "")),
		"last_played_at": block.get("last_played_at", ""),
		"starting_grade": settings.get("starting_grade", DEFAULT_GRADE),
		"interface_mode": settings.get("interface_mode", "explorer"),
		"session_minutes": settings.get("session_minutes", DEFAULT_SESSION_MINUTES),
		"handwriting_coaching": settings.get("handwriting_coaching", false),
	})


## Writes this profile's fields into a save document (the inverse of from_save). Keys the profile does
## not own (read_aloud, the skills, the rewards...) are left alone.
func apply_to_save(save: Dictionary) -> void:
	if not save.get("profile") is Dictionary:
		save["profile"] = {}
	if not save.get("settings") is Dictionary:
		save["settings"] = {}
	if not save.get("child") is Dictionary:
		save["child"] = {}
	save["profile"]["id"] = id
	save["profile"]["avatar_id"] = String(avatar_id)
	save["profile"]["created_at"] = created_at
	save["profile"]["last_played_at"] = last_played_at
	save["child"]["nickname"] = nickname
	save["settings"]["starting_grade"] = starting_grade
	save["settings"]["interface_mode"] = interface_mode
	save["settings"]["session_minutes"] = session_minutes
	save["settings"]["handwriting_coaching"] = handwriting_coaching


static func _int(value: Variant, fallback: int) -> int:
	return int(value) if value is int or value is float else fallback
