## The shape of the save file (schema version 1) and its defaults.
##
## CLAUDE.md: every save carries schema_version, and any change to this structure
## needs Spiro's sign-off, a migration in scripts/save/migrations/ and a fixture in
## tests/save/fixtures/. Never break an existing save.
class_name SaveSchema
extends RefCounted

const CURRENT_VERSION: int = 1


## A brand-new profile. now_iso is an ISO 8601 UTC timestamp supplied by the caller
## (keeps this class pure and testable).
static func new_profile(now_iso: String) -> Dictionary:
	return {
		"schema_version": CURRENT_VERSION,
		"created_at": now_iso,
		"updated_at": now_iso,
		"child": {"nickname": ""},
		"settings": {
			"session_minutes": 20,
			"interface_mode": "explorer",
			"read_aloud": false,
			"handwriting_coaching": false,
			"starting_grade": 1,
		},
		"placement": {"done": false, "seed": "star_2026_09"},
		"skills": {},
		"rewards": {
			"coins": 0,
			"gems": {},
			"inventory": ["pickaxe_t1"],
			"bolt": {"headlamp": "blue", "paint": "default", "sticker": "none"},
			"lantern": {"lit_days": [], "streak": 0},
		},
		"session": {"resume": null},
	}


## Fills any key missing from data with its default, recursively, and never touches a
## value that is present. Lets a save written by an older build load after a build adds
## an optional key that needs no migration.
static func with_defaults(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	_merge_missing(result, new_profile(str(data.get("created_at", ""))))
	return result


## Problems found in a save, as readable strings. Empty means the structure is sound.
static func validate(data: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if not data.get("schema_version") is int and not data.get("schema_version") is float:
		problems.append("schema_version is missing or not a number")
	var expected_types: Dictionary = {
		"child": TYPE_DICTIONARY,
		"settings": TYPE_DICTIONARY,
		"placement": TYPE_DICTIONARY,
		"skills": TYPE_DICTIONARY,
		"rewards": TYPE_DICTIONARY,
		"session": TYPE_DICTIONARY,
	}
	for key: String in expected_types:
		if typeof(data.get(key)) != expected_types[key]:
			problems.append("'%s' is missing or has the wrong type" % key)
	var settings: Variant = data.get("settings")
	if settings is Dictionary:
		var minutes: Variant = settings.get("session_minutes")
		if not (minutes is int or minutes is float) or minutes < 1:
			problems.append("settings.session_minutes must be a positive number")
	return problems


static func _merge_missing(target: Dictionary, defaults: Dictionary) -> void:
	for key: Variant in defaults:
		if not target.has(key):
			var value: Variant = defaults[key]
			target[key] = value.duplicate(true) if value is Dictionary or value is Array else value
		elif target[key] is Dictionary and defaults[key] is Dictionary:
			_merge_missing(target[key], defaults[key])
