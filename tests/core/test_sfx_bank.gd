# Mirrors scripts/core/sfx_bank.gd and the generated sounds in assets/sfx/placeholder/.
class_name SfxBankTest
extends GdUnitTestSuite

var _bank: SfxBank


func before_test() -> void:
	_bank = SfxBank.new()
	add_child(_bank)
	auto_free(_bank)


func test_every_listed_sound_loads() -> void:
	for id: StringName in SfxBank.SOUND_IDS:
		assert_bool(_bank.has_sound(id)).override_failure_message("missing sound " + id).is_true()


func test_the_sound_folder_holds_exactly_the_listed_sounds() -> void:
	var on_disk: Array[String] = []
	for file_name: String in DirAccess.get_files_at(SfxBank.SOUND_DIR):
		if file_name.ends_with(".ogg"):
			on_disk.append(file_name.get_basename())
	on_disk.sort()
	var listed: Array[String] = []
	for id: StringName in SfxBank.SOUND_IDS:
		listed.append(String(id))
	listed.sort()
	assert_array(on_disk).is_equal(listed)


func test_players_feed_the_sfx_bus_and_the_bus_exists() -> void:
	assert_int(AudioServer.get_bus_index(SfxBank.BUS)).is_not_equal(-1)
	var players: Array[Node] = _bank.find_children("*", "AudioStreamPlayer", false, false)
	assert_int(players.size()).is_equal(SfxBank.VOICES)
	for node: Node in players:
		assert_str((node as AudioStreamPlayer).bus).is_equal(String(SfxBank.BUS))


func test_play_announces_each_request() -> void:
	var heard: Array[StringName] = []
	_bank.played.connect(func(id: StringName) -> void: heard.append(id))
	_bank.play(&"crack")
	_bank.play(&"gem")
	assert_array(heard).contains_exactly([&"crack", &"gem"])


func test_an_unknown_sound_is_announced_but_does_not_crash() -> void:
	var heard: Array[StringName] = []
	_bank.played.connect(func(id: StringName) -> void: heard.append(id))
	_bank.play(&"no_such_sound")
	assert_array(heard).contains_exactly([&"no_such_sound"])
	assert_bool(_bank.has_sound(&"no_such_sound")).is_false()


func test_overlapping_sounds_use_different_players() -> void:
	_bank.play(&"crack")
	_bank.play(&"gem")
	var players: Array[Node] = _bank.find_children("*", "AudioStreamPlayer", false, false)
	var streams: Array = []
	for node: Node in players:
		var stream: AudioStream = (node as AudioStreamPlayer).stream
		if stream != null:
			streams.append(stream.resource_path.get_file())
	streams.sort()
	assert_array(streams).contains_exactly(["crack.ogg", "gem.ogg"])
