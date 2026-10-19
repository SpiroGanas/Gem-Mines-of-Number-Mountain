# Mirrors scripts/save/migrations/v2_to_v3.gd and the file-layout half of schema v3
# (scripts/save/profile_index.gd): the single Version 1.0 save in user://save/ becomes profile 1 in
# user://save/profiles/<id>/ with identical skill state, rewards, workshop, motivation and family
# records, and the old file is kept as save.v2.bak. A save from every released version still loads,
# through the whole SaveSystem.
class_name MigrationsTest
extends GdUnitTestSuite

const SYSTEM_SCRIPT: String = "res://autoload/save_system.gd"
const FIXTURE_DIR: String = "res://tests/save/fixtures"
## The parts of a save the child earned; the migration must not change any of them.
const KEPT_PARTS: Array[String] = ["skills", "rewards", "placement", "workshop", "motivation", "family", "settings", "child", "created_at", "updated_at", "session"]

var _dir: String


func before_test() -> void:
	_dir = create_temp_dir("migrations_" + str(Time.get_ticks_usec()))
	DeviceSettings.use_shared(DeviceSettings.new(_dir.path_join("device_settings.cfg")))


func after_test() -> void:
	DeviceSettings.use_shared(null)


func _system() -> Node:
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.use_directory(_dir)
	return system


func _copy(from: String, to: String) -> void:
	var file: FileAccess = FileAccess.open(to, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(from))
	file.close()


## A Version 1.0 device: the single save and its attempt log at the save root.
func _legacy_device(fixture: String) -> void:
	_copy(FIXTURE_DIR.path_join(fixture), _dir.path_join("profile.json"))
	_copy(FIXTURE_DIR.path_join("attempts_sample.jsonl"), _dir.path_join("attempts.jsonl"))


# --- The document step (v2 -> v3) ---------------------------------------------------------------


func test_v2_to_v3_adds_the_profile_block_and_keeps_everything_else() -> void:
	var v2: Dictionary = JsonUtil.parse_file(FIXTURE_DIR.path_join("v2.json"))
	var result: Dictionary = SaveMigrator.migrate(v2)
	assert_bool(result["ok"]).is_true()
	assert_int(result["from_version"]).is_equal(2)
	var v3: Dictionary = result["data"]
	assert_int(v3["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION) # migrate() goes on to v4 (poems); v3 -> v4 is in test_save_v4.gd
	assert_str(v3["profile"]["id"]).is_equal("")
	assert_str(v3["profile"]["avatar_id"]).is_equal("bolt")
	assert_str(v3["profile"]["created_at"]).is_equal(v2["created_at"])
	assert_str(v3["profile"]["last_played_at"]).is_equal("2026-12-02") # the newest lit lantern day
	assert_bool(v3["profile"]["welcomed"]).is_true()
	for key: String in v2:
		if key != "schema_version":
			assert_that(v3[key]).override_failure_message("v2 key changed: " + key).is_equal(v2[key])
	assert_array(SaveSchema.validate(v3)).is_empty()


func test_v2_to_v3_keeps_a_profile_block_a_save_already_has() -> void:
	var data: Dictionary = SaveMigrationV2ToV3.apply({"profile": {"id": "p_0123abcd", "avatar_id": "gem"}, "created_at": "c"})
	assert_str(data["profile"]["id"]).is_equal("p_0123abcd")
	assert_str(data["profile"]["avatar_id"]).is_equal("gem")
	assert_str(data["profile"]["created_at"]).is_equal("c")
	assert_str(SaveMigrationV2ToV3.apply({"profile": {"avatar_id": "photo"}})["profile"]["avatar_id"]).is_equal("bolt")


func test_a_v3_save_without_its_profile_block_is_invalid() -> void:
	var data: Dictionary = SaveSchema.new_profile("t")
	data.erase("profile")
	assert_array(SaveSchema.validate(data)).contains(["'profile' is missing or has the wrong type"])


# --- The layout step: the single save becomes profile 1 ---------------------------------------------


func test_a_version_1_0_save_becomes_profile_1_with_identical_progress() -> void:
	_legacy_device("v2.json")
	var before: Dictionary = JsonUtil.parse_file(_dir.path_join("profile.json"))
	var system: Node = _system()
	var id: String = system.profile_id()
	assert_bool(Profile.is_valid_id(id)).is_true()
	assert_str(system.last_load_report["layout"]).is_equal(ProfileIndex.SOURCE_LEGACY)
	assert_int(system.last_load_report["from_version"]).is_equal(2)
	assert_bool(system.last_load_report["migrated"]).is_true()
	assert_bool(system.last_load_report["recovered"]).is_false()
	for part: String in KEPT_PARTS:
		assert_that(system.data()[part]).override_failure_message("changed: " + part).is_equal(before[part])
	assert_str(system.data()["profile"]["id"]).is_equal(id)
	# The files: profile 1's folder, the index, the old save kept as save.v2.bak, nothing left behind.
	var folder: String = _dir.path_join("profiles").path_join(id)
	assert_bool(FileAccess.file_exists(folder.path_join("profile.json"))).is_true()
	assert_int(SaveStore.new(folder).read_attempts()["entries"].size()).is_equal(10)
	assert_bool(FileAccess.file_exists(_dir.path_join("profiles/index.json"))).is_true()
	assert_bool(FileAccess.file_exists(_dir.path_join("save.v2.bak"))).is_true()
	assert_dict(JsonUtil.parse_file(_dir.path_join("save.v2.bak"))).is_equal(before)
	for gone: String in ["profile.json", "profile.json.tmp", "attempts.jsonl"]:
		assert_bool(FileAccess.file_exists(_dir.path_join(gone))).override_failure_message(gone).is_false()
	# The index: one child, Charlie, active, the device counts as set up (no parent onboarding).
	var entries: Array = system.profile_entries()
	assert_int(entries.size()).is_equal(1)
	assert_str(entries[0]["nickname"]).is_equal("Charlie")
	assert_int(entries[0]["starting_grade"]).is_equal(1)
	assert_bool(system.is_onboarded()).is_true()
	# The attempts read through the system, and the next start finds the same child.
	assert_int(system.read_attempts()["entries"].size()).is_equal(10)
	var again: Node = _system()
	assert_str(again.profile_id()).is_equal(id)
	assert_str(again.last_load_report["layout"]).is_equal(ProfileIndex.SOURCE_INDEX)
	assert_that(again.data()["skills"]).is_equal(before["skills"])


func test_a_sprint_3_save_upgrades_all_the_way_to_profile_1() -> void:
	_legacy_device("v1.json")
	var before: Dictionary = JsonUtil.parse_file(_dir.path_join("profile.json"))
	var system: Node = _system()
	assert_int(system.last_load_report["from_version"]).is_equal(1)
	assert_int(system.data()["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION)
	for part: String in ["skills", "rewards", "placement", "settings", "child"]:
		assert_that(system.data()[part]).override_failure_message("changed: " + part).is_equal(before[part])
	assert_bool(FileAccess.file_exists(_dir.path_join("save.v1.bak"))).is_true()
	assert_array(SaveSchema.validate(system.data())).is_empty()


func test_the_old_backup_and_import_backups_move_into_profile_1() -> void:
	_legacy_device("v2.json")
	_copy(FIXTURE_DIR.path_join("v2.json"), _dir.path_join("profile.json.bak"))
	DirAccess.make_dir_recursive_absolute(_dir.path_join("backups"))
	_copy(FIXTURE_DIR.path_join("v1.json"), _dir.path_join("backups/20270301T100000Z.json"))
	var system: Node = _system()
	assert_bool(FileAccess.file_exists(system.profile_dir().path_join("profile.json.bak"))).is_true()
	assert_int(system.backups().size()).is_equal(1)
	assert_bool(FileAccess.file_exists(_dir.path_join("profile.json.bak"))).is_false()


func test_a_save_recovered_from_its_backup_still_moves_and_is_reported() -> void:
	_copy(FIXTURE_DIR.path_join("v2.json"), _dir.path_join("profile.json.bak"))
	var file: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	file.store_string("{\"schema_version\": 2, \"cut") # a crash mid-write
	file.close()
	var system: Node = _system()
	assert_bool(system.last_load_report["recovered"]).is_true()
	assert_str(system.data()["child"]["nickname"]).is_equal("Charlie")
	assert_int(system.data()["rewards"]["coins"]).is_equal(120)
	assert_str(JsonUtil.parse_file(_dir.path_join("save.v2.bak"))["child"]["nickname"]).is_equal("Charlie")


func test_a_crash_before_the_index_is_written_loses_nothing() -> void:
	_legacy_device("v2.json")
	# Simulate the crash: the move had begun (its marker names profile 1's folder) and left half a log
	# there, but the index (the commit point) was never written.
	var index: ProfileIndex = ProfileIndex.new(_dir)
	var id: String = index.new_unique_id()
	DirAccess.make_dir_recursive_absolute(index.profile_dir(id))
	var marker: FileAccess = FileAccess.open(_dir.path_join("profiles").path_join(ProfileIndex.MIGRATING_FILE), FileAccess.WRITE)
	marker.store_string(JSON.stringify({"id": id}))
	marker.close()
	var half: FileAccess = FileAccess.open(index.profile_dir(id).path_join("attempts.jsonl"), FileAccess.WRITE)
	half.store_string("{\"ts\": \"2026-12-0")
	half.close()
	var system: Node = _system()
	assert_str(system.profile_id()).is_equal(id) # the same folder, not a second one
	assert_int(DirAccess.get_directories_at(_dir.path_join("profiles")).size()).is_equal(1)
	assert_str(system.data()["child"]["nickname"]).is_equal("Charlie")
	assert_int(system.data()["rewards"]["coins"]).is_equal(120)
	assert_int(system.read_attempts()["entries"].size()).is_equal(10)
	assert_int(system.read_attempts()["skipped"]).is_equal(0)
	assert_bool(FileAccess.file_exists(_dir.path_join("profiles").path_join(ProfileIndex.MIGRATING_FILE))).is_false()


func test_an_unreadable_index_is_rebuilt_from_the_profile_folders() -> void:
	_legacy_device("v2.json")
	var system: Node = _system()
	var id: String = system.profile_id()
	for name: String in ["index.json", "index.json.bak", "index.json.tmp"]:
		var file: FileAccess = FileAccess.open(_dir.path_join("profiles").path_join(name), FileAccess.WRITE)
		file.store_string("not json")
		file.close()
	var again: Node = _system()
	assert_str(again.last_load_report["layout"]).is_equal(ProfileIndex.SOURCE_REBUILT)
	assert_bool(again.last_load_report["recovered"]).is_true()
	assert_str(again.profile_id()).is_equal(id)
	assert_str(again.data()["child"]["nickname"]).is_equal("Charlie")


func test_an_unreadable_single_save_is_left_alone_and_a_new_profile_starts() -> void:
	var file: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	file.store_string("corrupted!")
	file.close()
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.save_dir = _dir
	monitor_signals(system)
	system.load_profile()
	await assert_signal(system).is_emitted("load_failed", ["corrupt"])
	system.save_now()
	assert_str(FileAccess.get_file_as_string(_dir.path_join("profile.json"))).is_equal("corrupted!") # never destroyed


func test_a_single_save_from_a_newer_build_is_never_moved_or_overwritten() -> void:
	var newer: Dictionary = SaveSchema.new_profile("t")
	newer["schema_version"] = SaveSchema.CURRENT_VERSION + 1
	SaveStore.new(_dir).write_profile(newer)
	var system: Node = _system()
	assert_str(system.last_load_report["error"]).is_equal(SaveMigrator.ERR_NEWER_VERSION)
	system.save_now()
	assert_bool(DirAccess.dir_exists_absolute(_dir.path_join("profiles"))).is_false()
	assert_int(int(SaveStore.new(_dir).read_profile()["data"]["schema_version"])).is_equal(SaveSchema.CURRENT_VERSION + 1)


func test_an_index_from_a_newer_build_is_never_overwritten() -> void:
	var system: Node = _system()
	system.save_now()
	var path: String = _dir.path_join("profiles/index.json")
	var index: Dictionary = JsonUtil.parse_file(path)
	index["schema_version"] = SaveSchema.CURRENT_VERSION + 1
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(index))
	file.close()
	var again: Node = _system()
	assert_str(again.last_load_report["error"]).is_equal(SaveMigrator.ERR_NEWER_VERSION)
	again.data()["rewards"]["coins"] = 5
	again.save_now()
	assert_int(int(JsonUtil.parse_file(path)["schema_version"])).is_equal(SaveSchema.CURRENT_VERSION + 1)


# --- Every fixture through the whole system -------------------------------------------------------


func test_every_fixture_loads_as_a_version_1_0_save_through_the_whole_system() -> void:
	var found: int = 0
	for file_name: String in DirAccess.get_files_at(FIXTURE_DIR):
		if not file_name.ends_with(".json"):
			continue
		found += 1
		var dir: String = create_temp_dir("fixture_%s_%d" % [file_name.get_basename(), Time.get_ticks_usec()])
		_copy(FIXTURE_DIR.path_join(file_name), dir.path_join("profile.json"))
		var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
		system.use_directory(dir)
		assert_str(system.last_load_report["error"]).override_failure_message(file_name).is_equal("")
		assert_int(system.data()["schema_version"]).override_failure_message(file_name).is_equal(SaveSchema.CURRENT_VERSION)
		assert_array(SaveSchema.validate(system.data())).override_failure_message(file_name).is_empty()
		assert_str(system.data()["child"]["nickname"]).override_failure_message(file_name).is_equal("Charlie")
		assert_int(system.data()["rewards"]["coins"]).override_failure_message(file_name).is_equal(120)
		assert_str(system.data()["profile"]["id"]).is_equal(system.profile_id())
	assert_int(found).is_greater_equal(SaveSchema.CURRENT_VERSION)
