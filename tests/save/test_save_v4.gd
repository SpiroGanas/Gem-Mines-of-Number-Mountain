# Mirrors scripts/save/migrations/v3_to_v4.gd and the poems half of schema v4 (Phase 4, Sprint 40): a v3
# save gains an empty poems block and keeps everything else; saves from every earlier version load as v4
# through the whole SaveSystem; saved poems survive a save, a reload and a parent's export and import
# (checksum and newest-wins merge unchanged), and a v3 progress file still imports.
class_name SaveV4Test
extends GdUnitTestSuite

const SYSTEM_SCRIPT: String = "res://autoload/save_system.gd"
const FIXTURE_DIR: String = "res://tests/save/fixtures"
## A poem whose six lines fit 1, 1, 2, 3, 5, 8 (word ids from curriculum/poem_words.json).
const POEM: Array = [["sun"], ["glow"], ["crystal"], ["deep", "cave", "light"], ["shining", "silver", "star"], ["watermelon", "helicopter"]]

var _dir: String


func before_test() -> void:
	_dir = create_temp_dir("save_v4_" + str(Time.get_ticks_usec()))
	DeviceSettings.use_shared(DeviceSettings.new(_dir.path_join("device_settings.cfg")))


func after_test() -> void:
	DeviceSettings.use_shared(null)


func _device(name: String) -> Node:
	var folder: String = create_temp_dir("%s_%d" % [name, Time.get_ticks_usec()])
	DeviceSettings.use_shared(DeviceSettings.new(folder.path_join("device_settings.cfg")))
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.use_directory(folder)
	return system


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_the_schema_is_version_4_with_an_empty_poems_block() -> void:
	assert_int(SaveSchema.CURRENT_VERSION).is_equal(4)
	var fresh: Dictionary = SaveSchema.new_profile("2027-08-20T10:00:00Z")
	assert_dict(fresh["poems"]).is_equal({"saved": []})
	assert_array(SaveSchema.validate(fresh)).is_empty()
	fresh.erase("poems")
	assert_array(SaveSchema.validate(fresh)).contains(["'poems' is missing or has the wrong type"])


func test_v3_to_v4_adds_the_poems_block_and_keeps_everything_else() -> void:
	var v3: Dictionary = JsonUtil.parse_file(FIXTURE_DIR.path_join("v3.json"))
	var result: Dictionary = SaveMigrator.migrate(v3)
	assert_bool(result["ok"]).is_true()
	assert_int(result["from_version"]).is_equal(3)
	var v4: Dictionary = result["data"]
	assert_int(v4["schema_version"]).is_equal(4)
	assert_dict(v4["poems"]).is_equal({"saved": []})
	for key: String in v3:
		if key != "schema_version":
			assert_that(v4[key]).override_failure_message("v3 key changed: " + key).is_equal(v3[key])
	assert_array(SaveSchema.validate(v4)).is_empty()


func test_v3_to_v4_keeps_good_poems_a_save_already_has_and_drops_broken_ones() -> void:
	var data: Dictionary = SaveMigrationV3ToV4.apply({"poems": {"saved": [{"made_at": "t", "lines": POEM}, {"made_at": "t", "lines": [["no_such_word"]]}, "a poem as text"]}})
	assert_int(data["poems"]["saved"].size()).is_equal(1)
	assert_array(data["poems"]["saved"][0]["lines"]).is_equal(POEM)
	assert_dict(SaveMigrationV3ToV4.apply({"poems": "broken"})["poems"]).is_equal({"saved": []})


func test_every_earlier_version_upgrades_to_v4() -> void:
	for version: int in [1, 2, 3]:
		var data: Dictionary = JsonUtil.parse_file(FIXTURE_DIR.path_join("v%d.json" % version))
		var result: Dictionary = SaveMigrator.migrate(data)
		assert_bool(result["ok"]).override_failure_message("v%d" % version).is_true()
		var current: Dictionary = SaveSchema.with_defaults(result["data"])
		assert_int(current["schema_version"]).is_equal(4)
		assert_dict(current["poems"]).is_equal({"saved": []})
		assert_array(SaveSchema.validate(current)).is_empty()
		assert_int(current["rewards"]["coins"]).is_equal(120)


func test_the_v4_fixture_keeps_its_poem_through_the_whole_system() -> void:
	_write(_dir.path_join("profile.json"), FileAccess.get_file_as_string(FIXTURE_DIR.path_join("v4.json")))
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.use_directory(_dir)
	assert_str(system.last_load_report["error"]).is_equal("")
	assert_bool(system.last_load_report["migrated"]).is_false()
	var saved: Array = FibPoem.saved(system.data())
	assert_int(saved.size()).is_equal(1)
	assert_bool(FibPoem.is_saved_poem(saved[0])).is_true()
	assert_bool(FibPoem.is_complete(saved[0]["lines"])).is_true()


func test_a_saved_poem_survives_a_reload() -> void:
	var tablet: Node = _device("tablet")
	assert_bool(FibPoem.add_poem(tablet.data(), POEM, "2027-08-20T17:00:00Z")).is_true()
	tablet.save_now()
	var again: Node = auto_free(load(SYSTEM_SCRIPT).new())
	again.use_directory(tablet.save_dir)
	assert_array(FibPoem.saved(again.data())[0]["lines"]).is_equal(POEM)
	assert_str(FibPoem.saved(again.data())[0]["made_at"]).is_equal("2027-08-20T17:00:00Z")


func test_poems_travel_in_a_progress_file_and_the_checksum_holds() -> void:
	var source: Node = _device("source")
	FibPoem.add_poem(source.data(), POEM, "2027-08-20T17:00:00Z")
	source.data()["updated_at"] = "2027-08-20T17:00:01Z"
	var path: String = _dir.path_join("poems_bundle.json")
	assert_int(source.export_bundle(path)).is_equal(OK)
	assert_str(ProgressBundle.problem_with(JsonUtil.parse_file(path))).is_equal("")
	var target: Node = _device("target")
	target.data()["updated_at"] = "2000-01-01T00:00:00Z"
	assert_int(target.import_bundle(path)).is_equal(OK)
	assert_bool(target.last_import_report["replaced"]).is_true()
	assert_array(FibPoem.saved(target.data())[0]["lines"]).is_equal(POEM)
	# A poem edited by hand after export breaks the checksum like any other change.
	var bundle: Dictionary = JsonUtil.parse_file(path)
	bundle["profile"]["poems"]["saved"][0]["lines"][0] = ["moon"]
	_write(path, JSON.stringify(bundle))
	assert_int(_device("third").import_bundle(path)).is_equal(ERR_INVALID_DATA)


func test_a_progress_file_from_before_poems_still_imports() -> void:
	var bundle: Dictionary = {"format": ProgressBundle.FORMAT, "bundle_version": 1, "exported_at": "2027-05-01T10:00:00Z", "device_id": "", "profile": JsonUtil.parse_file(FIXTURE_DIR.path_join("v3.json")), "attempts": []}
	bundle["checksum"] = ProgressBundle.checksum_of(bundle)
	var path: String = _dir.path_join("v3_bundle.json")
	_write(path, JSON.stringify(bundle, "\t", false, true))
	var target: Node = _device("target")
	target.data()["updated_at"] = "2000-01-01T00:00:00Z"
	assert_int(target.import_bundle(path)).is_equal(OK)
	assert_int(target.data()["schema_version"]).is_equal(4)
	assert_dict(target.data()["poems"]).is_equal({"saved": []})
	assert_str(target.data()["child"]["nickname"]).is_equal("Charlie")


func test_the_newest_save_still_wins_with_poems_in_it() -> void:
	var ours: Dictionary = SaveSchema.new_profile("2027-08-01T00:00:00Z")
	var theirs: Dictionary = SaveSchema.new_profile("2027-08-01T00:00:00Z")
	FibPoem.add_poem(theirs, POEM, "2027-08-02T00:00:00Z")
	theirs["updated_at"] = "2027-08-02T00:00:00Z"
	assert_str(String(SaveMerge.choose(ours, theirs)["action"])).is_equal(String(SaveMerge.REPLACE))
	assert_str(String(SaveMerge.choose(theirs, ours)["action"])).is_equal(String(SaveMerge.ASK))
