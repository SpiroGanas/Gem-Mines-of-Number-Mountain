# Mirrors scripts/save/save_schema.gd and save_migrator.gd.
class_name SaveSchemaTest
extends GdUnitTestSuite

const FIXTURE_DIR: String = "res://tests/save/fixtures"


func test_a_new_profile_is_current_and_valid() -> void:
	var profile: Dictionary = SaveSchema.new_profile("2026-11-20T15:04:05Z")
	assert_int(profile["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION)
	assert_array(SaveSchema.validate(profile)).is_empty()
	assert_str(profile["created_at"]).is_equal("2026-11-20T15:04:05Z")


func test_new_profile_defaults_follow_the_plan() -> void:
	var profile: Dictionary = SaveSchema.new_profile("t")
	assert_int(profile["settings"]["session_minutes"]).is_equal(20)
	assert_str(profile["settings"]["interface_mode"]).is_equal("explorer")
	assert_bool(profile["settings"]["read_aloud"]).is_false()
	assert_int(profile["rewards"]["coins"]).is_equal(0)
	assert_array(profile["rewards"]["inventory"]).contains_exactly(["pickaxe_t1"])
	assert_str(profile["rewards"]["bolt"]["headlamp"]).is_equal("blue")
	assert_int(profile["rewards"]["lantern"]["streak"]).is_equal(0)


func test_new_profile_returns_independent_copies() -> void:
	var a: Dictionary = SaveSchema.new_profile("t")
	var b: Dictionary = SaveSchema.new_profile("t")
	a["rewards"]["inventory"].append("extra")
	assert_array(b["rewards"]["inventory"]).has_size(1)


func test_validate_reports_missing_and_mistyped_parts() -> void:
	var problems: PackedStringArray = SaveSchema.validate({"schema_version": 1, "settings": "oops"})
	assert_bool(problems.size() >= 5).is_true() # child, settings, placement, skills, rewards, session
	assert_array(SaveSchema.validate({})).contains(["schema_version is missing or not a number"])
	var bad_minutes: Dictionary = SaveSchema.new_profile("t")
	bad_minutes["settings"]["session_minutes"] = 0
	assert_array(SaveSchema.validate(bad_minutes)).contains(["settings.session_minutes must be a positive number"])


func test_with_defaults_fills_missing_keys_and_keeps_existing_values() -> void:
	var partial: Dictionary = {
		"schema_version": 1,
		"settings": {"session_minutes": 35},
		"rewards": {"coins": 7},
	}
	var filled: Dictionary = SaveSchema.with_defaults(partial)
	assert_int(filled["settings"]["session_minutes"]).is_equal(35) # kept
	assert_str(filled["settings"]["interface_mode"]).is_equal("explorer") # added
	assert_int(filled["rewards"]["coins"]).is_equal(7)
	assert_str(filled["rewards"]["bolt"]["headlamp"]).is_equal("blue")
	assert_array(SaveSchema.validate(filled)).is_empty()
	assert_bool(partial["settings"].has("interface_mode")).is_false() # input untouched


# --- Migrator -------------------------------------------------------------------------


func test_a_current_version_save_passes_through_unchanged() -> void:
	var save: Dictionary = SaveSchema.new_profile("t")
	var result: Dictionary = SaveMigrator.migrate(save)
	assert_bool(result["ok"]).is_true()
	assert_int(result["from_version"]).is_equal(SaveSchema.CURRENT_VERSION)
	assert_dict(result["data"]).is_equal(save)


func test_a_save_from_a_newer_build_is_refused() -> void:
	var save: Dictionary = {"schema_version": SaveSchema.CURRENT_VERSION + 1}
	var result: Dictionary = SaveMigrator.migrate(save)
	assert_bool(result["ok"]).is_false()
	assert_str(result["error"]).is_equal(SaveMigrator.ERR_NEWER_VERSION)


func test_a_save_without_a_version_is_refused() -> void:
	var result: Dictionary = SaveMigrator.migrate({"coins": 1})
	assert_str(result["error"]).is_equal(SaveMigrator.ERR_NO_VERSION)


func test_a_float_version_from_json_is_understood() -> void:
	var result: Dictionary = SaveMigrator.migrate({"schema_version": 1.0})
	assert_bool(result["ok"]).is_true()


func test_a_registered_migration_runs_and_bumps_the_version() -> void:
	# Pretend version 0 existed: its migration renames a key. This proves the chain machinery
	# that the first real migration (v1 to v2) will rely on.
	var migrations: Dictionary = SaveMigrator.default_migrations()
	migrations[0] = func(data: Dictionary) -> Dictionary:
		data["child"] = {"nickname": data["name"]}
		data.erase("name")
		return data
	var result: Dictionary = SaveMigrator.migrate({"schema_version": 0, "name": "Charlie"}, migrations)
	assert_bool(result["ok"]).is_true()
	assert_int(result["data"]["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION)
	assert_str(result["data"]["child"]["nickname"]).is_equal("Charlie")
	assert_int(result["from_version"]).is_equal(0)


func test_a_missing_migration_step_is_an_error_not_a_guess() -> void:
	var result: Dictionary = SaveMigrator.migrate({"schema_version": 0}, {})
	assert_bool(result["ok"]).is_false()
	assert_str(result["error"]).is_equal(SaveMigrator.ERR_MISSING_MIGRATION)


func test_migrating_does_not_modify_the_input() -> void:
	var migrations: Dictionary = {0: func(data: Dictionary) -> Dictionary:
		data["touched"] = true
		return data}
	var original: Dictionary = {"schema_version": 0}
	SaveMigrator.migrate(original, migrations)
	assert_bool(original.has("touched")).is_false()


# --- Fixtures: a save from every released version must still load ---------------------


func test_every_fixture_loads_migrates_and_validates() -> void:
	var dir: DirAccess = DirAccess.open(FIXTURE_DIR)
	assert_object(dir).is_not_null()
	var found: int = 0
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		found += 1
		var data: Variant = JsonUtil.parse_file(FIXTURE_DIR.path_join(file_name))
		assert_bool(data is Dictionary).override_failure_message(file_name + " is not a JSON object").is_true()
		var result: Dictionary = SaveMigrator.migrate(data)
		assert_bool(result["ok"]).override_failure_message(file_name + " failed to migrate: " + result["error"]).is_true()
		var current: Dictionary = SaveSchema.with_defaults(result["data"])
		assert_array(SaveSchema.validate(current)).override_failure_message(file_name + " is invalid after migration").is_empty()
		assert_int(current["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION)
	assert_int(found).is_greater_equal(SaveSchema.CURRENT_VERSION)


func test_there_is_a_fixture_for_every_version_up_to_current() -> void:
	for version: int in range(1, SaveSchema.CURRENT_VERSION + 1):
		var path: String = FIXTURE_DIR.path_join("v%d.json" % version)
		assert_bool(FileAccess.file_exists(path)).override_failure_message("missing fixture " + path).is_true()
		var data: Dictionary = JsonUtil.parse_file(path)
		assert_int(data["schema_version"]).is_equal(version)


func test_the_v1_fixture_keeps_its_values_through_a_load() -> void:
	var data: Dictionary = JsonUtil.parse_file(FIXTURE_DIR.path_join("v1.json"))
	var current: Dictionary = SaveSchema.with_defaults(SaveMigrator.migrate(data)["data"])
	assert_str(current["child"]["nickname"]).is_equal("Charlie")
	assert_int(current["rewards"]["coins"]).is_equal(120)
	assert_float(current["skills"]["pv.tens_ones.build"]["p_learned"]).is_equal(0.42)
	assert_int(current["skills"]["pv.tens_ones.build"]["recent_latency_ms"][0]).is_equal(4200)


# --- Version 2 (Phase 2) ----------------------------------------------------------------


func test_v1_to_v2_adds_the_phase_2_records_and_keeps_everything_else() -> void:
	var v1: Dictionary = JsonUtil.parse_file(FIXTURE_DIR.path_join("v1.json"))
	var result: Dictionary = SaveMigrator.migrate(v1)
	assert_bool(result["ok"]).is_true()
	assert_int(result["from_version"]).is_equal(1)
	var v2: Dictionary = result["data"]
	assert_int(v2["schema_version"]).is_equal(2)
	assert_str(v2["device_id"]).is_equal("")
	assert_array(v2["workshop"]["crafted"]).is_empty()
	assert_dict(v2["workshop"]["builds"]).is_empty()
	assert_array(v2["motivation"]["badges"]).is_empty()
	assert_str(v2["motivation"]["deep_dig"]["last_week"]).is_equal("")
	assert_int(v2["family"]["points"]).is_equal(0)
	assert_array(v2["family"]["goals"]).is_empty()
	for key: String in v1:
		if key != "schema_version":
			assert_that(v2[key]).override_failure_message("v1 key changed: " + key).is_equal(v1[key])
	assert_array(SaveSchema.validate(v2)).is_empty()


func test_v1_to_v2_keeps_records_a_partial_save_already_has() -> void:
	var data: Dictionary = SaveMigrationV1ToV2.apply({"family": {"points": 12}, "workshop": "broken"})
	assert_int(data["family"]["points"]).is_equal(12)
	assert_array(data["family"]["goals"]).is_empty()
	assert_dict(data["workshop"]["builds"]).is_empty()


func test_the_v2_fixture_keeps_its_values_through_a_load() -> void:
	var data: Dictionary = JsonUtil.parse_file(FIXTURE_DIR.path_join("v2.json"))
	var current: Dictionary = SaveSchema.with_defaults(SaveMigrator.migrate(data)["data"])
	assert_bool(current["workshop"]["builds"]["cart_track"]["done"]).is_true()
	assert_int(current["workshop"]["builds"]["balance_elevator"]["step"]).is_equal(1)
	assert_array(current["motivation"]["badges"]).contains_exactly(["gauss"])
	assert_int(current["family"]["points"]).is_equal(35)
	assert_str(current["family"]["goals"][0]["text"]).is_equal("Pick the Saturday park")


func test_a_v2_save_without_its_phase_2_records_is_invalid() -> void:
	var data: Dictionary = SaveSchema.new_profile("t")
	data.erase("workshop")
	assert_array(SaveSchema.validate(data)).contains(["'workshop' is missing or has the wrong type"])
