# Mirrors the cross-device half of autoload/save_system.gd and scripts/save/progress_bundle.gd
# (Sprint 17): the device id, the export file name, the checksum, the backups before an import, the
# parent's "use the older file anyway" choice and the import/export log. A two-device round trip runs
# 2-in-1 -> tablet -> 2-in-1 with the backups checked.
class_name CrossDeviceTest
extends GdUnitTestSuite

const SYSTEM_SCRIPT: String = "res://autoload/save_system.gd"

var _dir: String


func before_test() -> void:
	_dir = create_temp_dir("cross_device_" + str(Time.get_ticks_usec()))
	DeviceSettings.use_shared(DeviceSettings.new(_dir.path_join("device_settings.cfg")))


func after_test() -> void:
	DeviceSettings.use_shared(null)


## A device: its own save folder and its own device settings (so its own id).
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


func test_the_device_id_is_a_random_uuid_that_stays() -> void:
	var settings: DeviceSettings = DeviceSettings.new(_dir.path_join("a.cfg"))
	var id: String = settings.device_id()
	assert_int(id.length()).is_equal(36)
	assert_str(id.substr(14, 1)).is_equal("4") # version 4
	assert_str(settings.device_id()).is_equal(id)
	assert_str(DeviceSettings.new(_dir.path_join("a.cfg")).device_id()).is_equal(id) # kept on disk
	assert_str(DeviceSettings.new(_dir.path_join("b.cfg")).device_id()).is_not_equal(id)


func test_every_save_records_the_device_that_wrote_it() -> void:
	var device: Node = _device("tablet")
	device.save_now()
	assert_str(device.data()["device_id"]).is_equal(DeviceSettings.shared().device_id())


func test_the_export_name_carries_the_device_and_the_time() -> void:
	var name: String = ProgressBundle.file_name("5f0c2a8e-7b1d-4c3e-9a6f-2d8e4b1c7a90", "2027-03-08T10:04:05Z")
	assert_str(name).is_equal("gem-mines-progress-5f0c2a8e-20270308-100405.json")


func test_a_changed_file_is_refused_with_no_state_change() -> void:
	var source: Node = _device("source")
	source.data()["rewards"]["coins"] = 10
	var path: String = _dir.path_join("bundle.json")
	assert_int(source.export_bundle(path)).is_equal(OK)
	var bundle: Dictionary = JsonUtil.parse_file(path)
	bundle["profile"]["rewards"]["coins"] = 9999 # edited by hand after export
	_write(path, JSON.stringify(bundle))
	var target: Node = _device("target")
	target.data()["rewards"]["coins"] = 3
	target.data()["updated_at"] = "2000-01-01T00:00:00Z"
	assert_int(target.import_bundle(path)).is_equal(ERR_INVALID_DATA)
	assert_str(target.last_import_report["error"]).is_equal(ProgressBundle.ERR_CHECKSUM)
	assert_int(target.data()["rewards"]["coins"]).is_equal(3)
	assert_array(target.read_attempts()["entries"]).is_empty()
	assert_array(target.backups()).is_empty()


func test_a_file_cut_short_is_refused() -> void:
	var source: Node = _device("source")
	var path: String = _dir.path_join("cut.json")
	source.export_bundle(path)
	var text: String = FileAccess.get_file_as_string(path)
	_write(path, text.substr(0, text.length() / 2))
	var target: Node = _device("target")
	assert_int(target.import_bundle(path)).is_equal(ERR_INVALID_DATA)
	assert_str(target.last_import_report["error"]).is_equal(ProgressBundle.ERR_NOT_A_BUNDLE)


func test_a_checksum_survives_a_real_round_trip() -> void:
	var source: Node = _device("source")
	source.data()["skills"]["count.to_20.objects"] = SkillRecord.fresh(0.42)
	var path: String = _dir.path_join("ok.json")
	source.export_bundle(path)
	assert_str(ProgressBundle.problem_with(JsonUtil.parse_file(path))).is_equal("")


func test_an_older_file_asks_and_the_parent_can_use_it_anyway() -> void:
	var old_device: Node = _device("old")
	old_device.data()["rewards"]["coins"] = 5
	var path: String = _dir.path_join("old.json")
	old_device.export_bundle(path)
	var other: Node = _device("other")
	other.data()["rewards"]["coins"] = 99
	other.data()["updated_at"] = "2099-01-01T00:00:00Z"
	assert_int(other.import_bundle(path)).is_equal(OK)
	assert_bool(other.last_import_report["older"]).is_true()
	assert_bool(other.last_import_report["replaced"]).is_false()
	assert_int(other.data()["rewards"]["coins"]).is_equal(99) # "keep this device's progress" is the default
	assert_int(other.import_bundle(path, true)).is_equal(OK) # "use the imported file anyway"
	assert_bool(other.last_import_report["replaced"]).is_true()
	assert_int(other.data()["rewards"]["coins"]).is_equal(5)
	var backups: PackedStringArray = other.backups()
	assert_int(backups.size()).is_equal(1)
	assert_int(int(JsonUtil.parse_file(backups[0])["rewards"]["coins"])).is_equal(99)


func test_only_the_newest_five_backups_are_kept() -> void:
	var target: Node = _device("target")
	for round: int in 7:
		var source: Node = _device("source_%d" % round)
		source.data()["rewards"]["coins"] = round
		var path: String = _dir.path_join("b%d.json" % round)
		source.export_bundle(path)
		target.data()["updated_at"] = "2000-01-01T00:00:00Z" # always older, so each import replaces
		assert_int(target.import_bundle(path)).is_equal(OK)
		assert_bool(target.last_import_report["replaced"]).is_true()
	assert_int(target.backups().size()).is_equal(SaveSystem.BACKUPS_KEPT)


func test_the_log_records_every_export_and_import() -> void:
	var tablet: Node = _device("tablet")
	var tablet_id: String = DeviceSettings.shared().device_id()
	var path: String = _dir.path_join(ProgressBundle.file_name(tablet_id, "2027-03-08T10:00:00Z"))
	tablet.export_bundle(path)
	var chromebook: Node = _device("chromebook")
	chromebook.data()["updated_at"] = "2000-01-01T00:00:00Z"
	chromebook.import_bundle(path)
	var log: Array = chromebook.sync_log()
	assert_int(log.size()).is_equal(1)
	assert_str(log[0]["action"]).is_equal("import")
	assert_str(log[0]["result"]).is_equal("replaced")
	assert_str(log[0]["device"]).is_equal(tablet_id.substr(0, 8))
	assert_str(log[0]["file"]).is_equal(path.get_file())
	assert_str(tablet.sync_log()[0]["action"]).is_equal("export")


func test_a_round_trip_two_in_one_to_tablet_and_back_keeps_everything() -> void:
	var two_in_one: Node = _device("two_in_one")
	two_in_one.data()["rewards"]["coins"] = 40
	two_in_one.data()["workshop"]["builds"]["cart_track"] = {"step": 3, "done": true}
	var first: String = _dir.path_join("first.json")
	two_in_one.export_bundle(first)
	var tablet: Node = _device("tablet")
	tablet.data()["updated_at"] = "2000-01-01T00:00:00Z"
	assert_int(tablet.import_bundle(first)).is_equal(OK)
	assert_bool(tablet.data()["workshop"]["builds"]["cart_track"]["done"]).is_true()
	tablet.data()["rewards"]["coins"] = 55 # Charlie plays on the tablet
	var second: String = _dir.path_join("second.json")
	tablet.export_bundle(second)
	# The 2-in-1 last saved before the tablet's play (saves are stamped to the second, and this test
	# runs within one, so the 2-in-1's stamp is set back rather than waiting on the wall clock).
	two_in_one.data()["updated_at"] = "2000-01-01T00:00:00Z"
	assert_int(two_in_one.import_bundle(second)).is_equal(OK)
	assert_bool(two_in_one.last_import_report["replaced"]).is_true()
	assert_int(two_in_one.data()["rewards"]["coins"]).is_equal(55)
	assert_int(int(JsonUtil.parse_file(two_in_one.backups()[0])["rewards"]["coins"])).is_equal(40)
