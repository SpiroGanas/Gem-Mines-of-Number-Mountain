# Mirrors scenes/workshop/: the Gem Museum and Bolt's Garage (P1-S08-02, P1-S08-03).
class_name WorkshopTest
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("workshop_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)


func after_test() -> void:
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _screen(path: String) -> ShellScreen:
	var screen: ShellScreen = load(path).instantiate()
	add_child(screen)
	auto_free(screen)
	return screen


func test_every_museum_case_opens_from_save_data() -> void:
	var rewards: Dictionary = SaveSystem.data()["rewards"]
	for mineral: StringName in GemArt.ALL_TYPES:
		RewardsRules.add_gem(rewards, mineral, 2)
	var museum: MuseumScreen = _screen("res://scenes/workshop/museum.tscn")
	for mineral: StringName in GemArt.ALL_TYPES:
		assert_bool(museum.is_open(mineral)).is_true()
		museum.case_button(mineral).pressed.emit()
		assert_str(museum.detail_name()).is_equal(Text.get_line(StringName("hub.museum.%s_name" % mineral)))
		assert_str(museum.detail_text()).contains(Text.get_line(StringName("hub.museum.%s_fact" % mineral)))
		assert_str(museum.detail_text()).contains(Text.get_line(&"hub.museum.you_have", {"n": 2}))


func test_a_closed_case_says_how_to_find_its_mineral() -> void:
	var museum: MuseumScreen = _screen("res://scenes/workshop/museum.tscn")
	museum.case_button(&"topaz").pressed.emit()
	assert_str(museum.detail_name()).is_equal(Text.get_line(&"hub.museum.not_found"))
	assert_str(museum.detail_text()).is_equal(Text.get_line(&"hub.museum.how_learn_n", {"n": 15}))
	museum.case_button(&"garnet").pressed.emit()
	assert_str(museum.detail_text()).is_equal(Text.get_line(&"hub.museum.garnet_how"))
	for mineral: StringName in GemArt.ALL_TYPES:
		museum.case_button(mineral).pressed.emit()
		assert_bool(museum.detail_text().begins_with("[")).override_failure_message(mineral).is_false()


func test_the_garage_sells_with_coins_and_puts_the_new_lamp_on() -> void:
	SaveSystem.data()["rewards"]["coins"] = 25
	var garage: GarageScreen = _screen("res://scenes/workshop/garage.tscn")
	assert_str(garage.item_button(&"headlamp_blue").text).is_equal(Text.get_line(&"ui.garage.in_use"))
	assert_bool(garage.item_button(&"headlamp_gold").disabled).is_true() # 40 coins
	assert_str(garage.item_button(&"headlamp_gold").text).is_equal(Text.get_line(&"ui.garage.need", {"n": 15}))
	garage.item_button(&"headlamp_green").pressed.emit()
	assert_int(Rewards.coins()).is_equal(5)
	assert_str(Rewards.headlamp()).is_equal("green")
	assert_str(garage.item_button(&"headlamp_green").text).is_equal(Text.get_line(&"ui.garage.in_use"))
	assert_str(garage.item_button(&"headlamp_blue").text).is_equal(Text.get_line(&"ui.garage.use"))
	garage.item_button(&"headlamp_blue").pressed.emit()
	assert_str(Rewards.headlamp()).is_equal("blue")
	assert_int(Rewards.coins()).is_equal(5) # putting an owned lamp back on is free


func test_the_big_pickaxe_is_bought_once() -> void:
	SaveSystem.data()["rewards"]["coins"] = 120
	var garage: GarageScreen = _screen("res://scenes/workshop/garage.tscn")
	garage.item_button(&"pickaxe_t2").pressed.emit()
	assert_int(Rewards.coins()).is_equal(70)
	assert_str(Rewards.pickaxe()).is_equal("pickaxe_t2")
	assert_bool(garage.item_button(&"pickaxe_t2").disabled).is_true()
	assert_str(garage.item_button(&"pickaxe_t2").text).is_equal(Text.get_line(&"ui.garage.owned"))


func test_workshop_screens_use_full_size_targets_and_only_table_text() -> void:
	for path: String in ["res://scenes/workshop/museum.tscn", "res://scenes/workshop/garage.tscn"]:
		var screen: ShellScreen = _screen(path)
		await get_tree().process_frame
		for node: Node in screen.find_children("*", "Button", true, false):
			var button: Button = node
			assert_float(button.custom_minimum_size.y).override_failure_message("%s %s" % [path, button.name]).is_greater_equal(float(UI.min_target_px()))
		for node: Node in screen.find_children("*", "Label", true, false):
			assert_bool((node as Label).text.begins_with("[")).override_failure_message((node as Label).text).is_false()
		for forbidden: String in ["LineEdit", "TextEdit"]:
			assert_array(screen.find_children("*", forbidden, true, false)).is_empty()
