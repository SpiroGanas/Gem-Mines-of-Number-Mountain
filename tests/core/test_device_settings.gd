# Mirrors scripts/core/device_settings.gd: volumes saved on the device and applied to the buses.
class_name DeviceSettingsTest
extends GdUnitTestSuite

var _path: String


func before_test() -> void:
	_path = create_temp_dir("device_" + str(Time.get_ticks_usec())).path_join("device_settings.cfg")


func after_test() -> void:
	DeviceSettings.new(_path).apply() # leave the buses as a fresh device would
	DeviceSettings.shared().apply()


func test_a_new_device_starts_with_the_default_levels() -> void:
	var settings: DeviceSettings = DeviceSettings.new(_path)
	assert_int(settings.level("music")).is_equal(3)
	assert_int(settings.level("sfx")).is_equal(4)


func test_levels_are_saved_and_clamped() -> void:
	var settings: DeviceSettings = DeviceSettings.new(_path)
	settings.set_level("music", 9)
	settings.set_level("sfx", -2)
	var reloaded: DeviceSettings = DeviceSettings.new(_path)
	assert_int(reloaded.level("music")).is_equal(DeviceSettings.LEVELS)
	assert_int(reloaded.level("sfx")).is_equal(0)


func test_levels_set_the_audio_buses() -> void:
	var settings: DeviceSettings = DeviceSettings.new(_path)
	settings.set_level("sfx", 0)
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	assert_bool(AudioServer.is_bus_mute(sfx)).is_true()
	settings.set_level("music", DeviceSettings.LEVELS)
	var music: int = AudioServer.get_bus_index(&"Music")
	assert_bool(AudioServer.is_bus_mute(music)).is_false()
	assert_float(AudioServer.get_bus_volume_db(music)).is_equal_approx(0.0, 0.001)


func test_quieter_levels_are_fewer_decibels() -> void:
	assert_float(DeviceSettings.volume_db(1)).is_less(DeviceSettings.volume_db(4))
	assert_float(DeviceSettings.volume_db(0)).is_equal(-80.0)
