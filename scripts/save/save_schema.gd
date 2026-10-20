## The shape of the save file (schema version 4) and its defaults.
##
## Version 2 (Phase 2, docs/decisions.md "Save schema v2") adds, in one step:
##   device_id    the random id of the device that last wrote this save (DeviceSettings.device_id();
##                never a hardware id). With updated_at it tells cross-device imports apart.
##   workshop     crafted recipes and build-project progress (Sprint 16)
##   motivation   badges, collected Word Gems, the weekly Deep Dig and the Challenge Door (Sprint 19)
##   family       family reward points and the parent's goals (Sprint 19)
## Everything about the child is in this one document, so Phase 3 profiles can keep one per child.
##
## Version 3 (Phase 3, Sprint 23, docs/decisions.md "Save schema v3: profiles") adds:
##   profile      {id, avatar_id, created_at, last_played_at, welcomed}: which profile this document
##                is (the folder user://save/profiles/<id>/ holds it), the code-drawn avatar on the
##                title screen, the last day played and whether Bolt has said hello (FirstRunScreen).
##                The nickname stays in child.nickname and the per-child settings stay in settings
##                (Profile.from_save reads them all). The profile index lives in its own file
##                (ProfileIndex); this document is still the one source of truth about the child.
##
## Version 4 (Phase 4, Sprint 40, docs/decisions.md "Save schema v4: saved Fib poems"; Spiro approved the
## additive change) adds:
##   poems        {saved: [{made_at, lines: [[word id, ...] x 6]}]}: the Fib poems the child built in the
##                poem maker, newest last, at most FibPoem.MAX_SAVED. Only word ids from the poem word
##                bank (curriculum/poem_words.json) are stored, never free text and never strokes; the
##                words are read from the text table when a poem is shown. A parent's progress export
##                carries them like every other part of the save.
##
## CLAUDE.md: every save carries schema_version, and any change to this structure
## needs Spiro's sign-off, a migration in scripts/save/migrations/ and a fixture in
## tests/save/fixtures/. Never break an existing save.
class_name SaveSchema
extends RefCounted

const CURRENT_VERSION: int = 4


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
		"device_id": "",
		"workshop": {"crafted": [], "builds": {}},
		"motivation": {
			"badges": [],
			"word_gems": [],
			"deep_dig": {"last_week": "", "completed": 0},
			"challenge": {"closed_until": {}, "passed": []},
		},
		"family": {"points": 0, "awarded": [], "goals": []},
		"profile": {"id": "", "avatar_id": "bolt", "created_at": now_iso, "last_played_at": "", "welcomed": true},
		"poems": {"saved": []},
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
	if int(data.get("schema_version", 0)) >= 2:
		expected_types.merge({"workshop": TYPE_DICTIONARY, "motivation": TYPE_DICTIONARY, "family": TYPE_DICTIONARY})
	if int(data.get("schema_version", 0)) >= 3:
		expected_types["profile"] = TYPE_DICTIONARY
	if int(data.get("schema_version", 0)) >= 4:
		expected_types["poems"] = TYPE_DICTIONARY
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
