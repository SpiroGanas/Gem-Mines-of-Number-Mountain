# Mirrors autoload/save_system.gd. Uses a fresh SaveSystem instance on a temp folder,
# never the global autoload, so the real save is untouched.
class_name SaveSystemTest
extends GdUnitTestSuite

const SYSTEM_SCRIPT: String = "res://autoload/save_system.gd"

var _dir: String


func before_test() -> void:
	_dir = create_temp_dir("save_system_" + str(Time.get_ticks_usec()))


func _system() -> Node:
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.use_directory(_dir)
	return system


func test_a_first_start_makes_a_new_profile_without_complaint() -> void:
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.save_dir = _dir
	monitor_signals(system)
	system.load_profile()
	await assert_signal(system).is_not_emitted("load_failed")
	assert_int(system.data()["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION)
	assert_str(system.last_load_report["error"]).is_equal("none")


func test_save_now_writes_the_file_and_announces_it() -> void:
	var system: Node = _system()
	monitor_signals(system)
	system.data()["rewards"]["coins"] = 55
	system.save_now()
	await assert_signal(system).is_emitted("saved")
	assert_bool(FileAccess.file_exists(_dir.path_join("profile.json"))).is_true()
	var reloaded: Node = _system()
	assert_int(reloaded.data()["rewards"]["coins"]).is_equal(55)


func test_saving_updates_the_updated_at_stamp() -> void:
	var system: Node = _system()
	system.data()["updated_at"] = "2000-01-01T00:00:00Z"
	system.save_now()
	assert_str(system.data()["updated_at"]).is_not_equal("2000-01-01T00:00:00Z")
	assert_str(system.data()["updated_at"]).ends_with("Z")


func test_loading_a_recovered_save_is_reported_for_the_parent_dashboard() -> void:
	var system: Node = _system()
	system.data()["rewards"]["coins"] = 1
	system.save_now()
	system.data()["rewards"]["coins"] = 2
	system.save_now()
	var file: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	file.store_string("corrupted!")
	file.close()
	var recovered: Node = _system()
	assert_bool(recovered.last_load_report["recovered"]).is_true()
	assert_str(recovered.last_load_report["source"]).is_equal("backup")
	assert_int(recovered.data()["rewards"]["coins"]).is_equal(1)


func test_when_nothing_is_readable_it_starts_fresh_and_says_why() -> void:
	var file: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	file.store_string("corrupted!")
	file.close()
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.save_dir = _dir
	monitor_signals(system)
	system.load_profile()
	await assert_signal(system).is_emitted("load_failed", ["corrupt"])
	assert_int(system.data()["rewards"]["coins"]).is_equal(0)


func test_a_save_from_a_newer_build_is_kept_and_never_overwritten() -> void:
	var newer: Dictionary = SaveSchema.new_profile("t")
	newer["schema_version"] = SaveSchema.CURRENT_VERSION + 1
	newer["rewards"]["coins"] = 999
	assert_int(SaveStore.new(_dir).write_profile(newer)).is_equal(OK)
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.save_dir = _dir
	monitor_signals(system)
	system.load_profile()
	await assert_signal(system).is_emitted("load_failed", ["newer_version"])
	system.save_now() # must be refused
	var on_disk: Dictionary = SaveStore.new(_dir).read_profile()["data"]
	assert_int(on_disk["rewards"]["coins"]).is_equal(999)
	assert_int(on_disk["schema_version"]).is_equal(SaveSchema.CURRENT_VERSION + 1)


func test_the_v1_fixture_loads_through_the_whole_system() -> void:
	var fixture: String = FileAccess.get_file_as_string("res://tests/save/fixtures/v1.json")
	var file: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	file.store_string(fixture)
	file.close()
	var system: Node = _system()
	assert_str(system.data()["child"]["nickname"]).is_equal("Charlie")
	assert_int(system.data()["rewards"]["coins"]).is_equal(120)
	assert_bool(system.last_load_report["recovered"]).is_false()
	assert_bool(system.last_load_report["migrated"]).is_false()


func test_missing_keys_in_an_old_save_are_filled_with_defaults() -> void:
	var sparse: Dictionary = {"schema_version": 1, "settings": {"session_minutes": 30}}
	SaveStore.new(_dir).write_profile(sparse)
	var system: Node = _system()
	assert_int(system.data()["settings"]["session_minutes"]).is_equal(30)
	assert_array(SaveSchema.validate(system.data())).is_empty()


func test_attempts_are_logged_through_the_system() -> void:
	var system: Node = _system()
	var attempt: Attempt = Attempt.new()
	attempt.skill_id = &"count.to_20.objects"
	attempt.correct = true
	system.append_attempt(attempt)
	system.append_attempt(attempt)
	assert_array(system.read_attempts()["entries"]).has_size(2)
	assert_str(system.read_attempts()["entries"][0]["skill_id"]).is_equal("count.to_20.objects")


func test_the_app_pausing_or_closing_saves() -> void:
	for notification: int in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_WM_CLOSE_REQUEST]:
		var dir: String = create_temp_dir("notify_" + str(notification))
		var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
		system.use_directory(dir)
		system.data()["rewards"]["coins"] = notification
		system._notification(notification)
		var on_disk: Dictionary = SaveStore.new(dir).read_profile()["data"]
		assert_int(on_disk["rewards"]["coins"]).override_failure_message("notification %d did not save" % notification).is_equal(notification)


func test_other_notifications_do_not_save() -> void:
	var system: Node = _system()
	system._notification(Node.NOTIFICATION_READY)
	assert_bool(FileAccess.file_exists(_dir.path_join("profile.json"))).is_false()
