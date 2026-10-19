## Save schema 2 -> 3 (Phase 3, Sprint 23): profiles. Adds the `profile` block (SaveSchema) and
## changes nothing else: every skill record, the rewards, the workshop, the motivation records and the
## family points are kept exactly as they were.
##
##   id              "" here; SaveSystem gives the document its profile id when it moves the single
##                   Version 1.0 save into user://save/profiles/<id>/ (ProfileIndex.migrate_layout)
##   avatar_id       "bolt", the first code-drawn avatar (a parent can change it in the parent area)
##   created_at      the save's own created_at
##   last_played_at  the newest lit lantern day, the last day the child cracked a rock (or "")
##   welcomed        true: a Version 1.0 child has met Bolt already (or will, on a blank nickname)
class_name SaveMigrationV2ToV3
extends RefCounted


static func apply(data: Dictionary) -> Dictionary:
	var block: Dictionary = data.get("profile", {}) if data.get("profile") is Dictionary else {}
	if not block.get("id") is String:
		block["id"] = ""
	if not block.get("avatar_id") is String or not Profile.is_valid_avatar(StringName(block["avatar_id"])):
		block["avatar_id"] = String(Profile.DEFAULT_AVATAR)
	if not block.get("created_at") is String:
		block["created_at"] = str(data.get("created_at", ""))
	if not block.get("last_played_at") is String:
		block["last_played_at"] = _last_lit_day(data)
	if not block.get("welcomed") is bool:
		block["welcomed"] = true
	data["profile"] = block
	return data


static func _last_lit_day(data: Dictionary) -> String:
	var rewards: Variant = data.get("rewards")
	if not rewards is Dictionary or not rewards.get("lantern") is Dictionary:
		return ""
	var days: Variant = rewards["lantern"].get("lit_days")
	var newest: String = ""
	if days is Array:
		for day: Variant in days:
			if day is String and day > newest:
				newest = day
	return newest
