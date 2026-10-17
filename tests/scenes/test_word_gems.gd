# Word Gems (P1-S07-03): every Zone 1-2 term opens a card with its picture and kid-sized
# definition, from a chip under Bolt's bubble or from the underlined word in Bolt's line.
class_name WordGemsTest
extends GdUnitTestSuite

var _bolt: Bolt
var _card: WordGemCard


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_bolt = auto_free(load("res://scenes/mine/bolt.tscn").instantiate())
	add_child(_bolt)
	_card = auto_free(WordGemCard.new())
	add_child(_card)


func after_test() -> void:
	TestWindow.restore(get_window())


func _terms_of_zones(zones: Array[int]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: Dictionary in JsonUtil.parse_file("res://curriculum/vocabulary.json")["terms"]:
		if zones.has(int(entry["zone"])):
			ids.append(StringName(entry["id"]))
	return ids


func test_every_zone_1_and_2_term_opens_a_card_with_its_word_picture_and_definition() -> void:
	var terms: Array[StringName] = _terms_of_zones([1, 2])
	assert_int(terms.size()).is_greater(10)
	for id: StringName in terms:
		var gem: Dictionary = Text.term_definition(id)
		_card.show_term(id)
		await get_tree().process_frame
		assert_bool(_card.visible).is_true()
		assert_str(_card.term_text()).is_equal(gem["term"])
		assert_str(_card.definition_text()).is_equal(gem["text"])
		assert_bool(_card.definition_text().begins_with("[")).override_failure_message(id).is_false()
		assert_str(String(_card.picture().visual_type())).override_failure_message("%s has no picture" % id).is_not_empty()
		_card.ok_button().pressed.emit()
		assert_bool(_card.visible).is_false()


func test_every_word_gem_picture_is_a_valid_visual() -> void:
	for id: StringName in Text.term_ids():
		var visual: Dictionary = Text.term_definition(id)["visual"]
		assert_dict(visual).override_failure_message("%s has no picture" % id).is_not_empty()
		var errors: Array[String] = GeneratorChecks._visual_errors(visual, String(id))
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_a_chip_appears_for_each_term_and_tapping_it_reports_the_term() -> void:
	var tapped: Array[StringName] = []
	_bolt.term_tapped.connect(func(id: StringName) -> void: tapped.append(id))
	_bolt.say(&"z1.dig.prompt_build_number", {"n": 34})
	_bolt.set_terms([&"tens", &"ones"])
	var chips: Array[Button] = _bolt.term_chips()
	assert_int(chips.size()).is_equal(2)
	assert_str(chips[0].text).is_equal(Text.get_line(&"vocab.tens.term"))
	for chip: Button in chips:
		assert_float(chip.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))
	chips[1].pressed.emit()
	assert_array(tapped).contains_exactly([&"ones"])
	_bolt.set_terms([])
	assert_array(_bolt.term_chips()).is_empty()


func test_a_term_word_in_bolts_line_becomes_a_tappable_link() -> void:
	_bolt.set_terms([&"tens", &"ones"])
	_bolt.say(&"z1.pv.prompt_read_words", {"tens": 6, "ones": 8}) # "{tens} tens and {ones} ones. What number is that?"
	var bbcode: String = _bolt.spoken_bbcode()
	assert_str(bbcode).contains("[url=tens][u]tens[/u][/url]")
	assert_str(bbcode).contains("[url=ones][u]ones[/u][/url]")
	assert_str(_bolt.spoken_text()).is_equal("6 tens and 8 ones. What number is that?") # the numbers, not the links


func test_links_never_break_placeholders_or_join_two_terms() -> void:
	var links: Dictionary = {"equal": &"equal", "equal groups": &"equal_groups", "tens": &"tens"}
	assert_str(Text._link_words("Make {tens} tens.", links)).is_equal("Make {tens} [url=tens][u]tens[/u][/url].")
	assert_str(Text._link_words("Equal groups are equal.", links)).is_equal("[url=equal_groups][u]Equal groups[/u][/url] are [url=equal][u]equal[/u][/url].")
	assert_str(Text._link_words("Attention", links)).is_equal("Attention") # whole words only


func test_tapping_outside_the_card_closes_it() -> void:
	_card.show_term(&"sum")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_card._on_dimmer_input(click)
	assert_bool(_card.visible).is_false()


func test_an_unknown_term_opens_nothing() -> void:
	_card.show_term(&"no_such_term")
	assert_bool(_card.visible).is_false()
