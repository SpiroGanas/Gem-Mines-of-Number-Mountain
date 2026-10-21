# Scholar mode part 2 (Phase 5): notation levels, the drawn set symbols, formal Word Gem definitions, and the
# Master Miner rank on the hub and the parent dashboard.
class_name ScholarPart2Test
extends GdUnitTestSuite


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	ScholarMode.reset_overrides()


func after_test() -> void:
	ScholarMode.reset_overrides()
	Text.scholar_override = null
	TestWindow.restore(get_window())


func test_notation_levels_by_form() -> void:
	assert_int(NotationRules.form_level("power")).is_equal(NotationRules.TAUGHT)
	assert_int(NotationRules.form_level("congruence")).is_equal(NotationRules.TAUGHT)
	assert_int(NotationRules.form_level("set")).is_equal(NotationRules.FORMAL)
	assert_bool(NotationRules.symbols_allowed("set", false)).is_false()
	assert_bool(NotationRules.symbols_allowed("set", true)).is_true()
	assert_bool(NotationRules.symbols_allowed("power", false)).is_true()


func test_set_symbols_are_drawn_from_strokes_inside_the_box() -> void:
	for symbol: StringName in SetSymbolDisplay.SYMBOLS:
		var strokes: Array[PackedVector2Array] = SetSymbolDisplay.strokes(symbol)
		assert_int(strokes.size()).is_greater(0)
		for stroke: PackedVector2Array in strokes:
			for point: Vector2 in stroke:
				assert_bool(point.x >= 0.0 and point.x <= 1.0 and point.y >= 0.0 and point.y <= 1.0).is_true()
	assert_int(SetSymbolDisplay.strokes(&"Z").size()).is_equal(1)
	assert_int(SetSymbolDisplay.strokes(&"R").size()).is_equal(3)
	assert_int(SetSymbolDisplay.strokes(&"Q").size()).is_equal(2)


func test_set_symbols_show_in_scholar_mode_and_words_in_explorer_mode() -> void:
	ScholarMode.forced_setting = "explorer"
	var explorer: MathNotation = MathNotation.make({"form": "set", "set": "Q"})
	add_child(explorer)
	auto_free(explorer)
	assert_bool(explorer.display().visible).is_false()
	assert_bool(explorer.words_label().visible).is_true()
	assert_str(explorer.words_label().text).is_equal("the rational numbers")
	ScholarMode.forced_setting = "scholar"
	var scholar: MathNotation = MathNotation.make({"form": "set", "set": "R"})
	add_child(scholar)
	auto_free(scholar)
	assert_bool(scholar.display().visible).is_true()
	assert_bool(scholar.display() is SetSymbolDisplay).is_true()
	assert_bool(scholar.words_label().visible).is_false()


## Peer review 05: the set symbols had no producer in the game. The number rings (the sets.* pictures, the rings room,
## the hint models) now wear ℤ ℚ ℝ in Scholar mode and stay plain in Explorer mode.
func test_the_number_rings_wear_their_symbols_only_in_scholar_mode() -> void:
	ScholarMode.forced_setting = "explorer"
	assert_bool(CoreArt.set_symbols_shown()).is_false()
	ScholarMode.forced_setting = "scholar"
	assert_bool(CoreArt.set_symbols_shown()).is_true()
	var radii: Array[float] = CoreArt.ring_radii(100.0)
	var boxes: Array[Rect2] = CoreArt.ring_symbol_boxes(Vector2(200, 200), radii)
	assert_int(boxes.size()).is_equal(3)
	for index: int in boxes.size():
		var box: Rect2 = boxes[index]
		var inner: float = radii[index - 1] if index > 0 else 0.0
		for corner: Vector2 in [box.position, box.end, Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y)]:
			var distance: float = corner.distance_to(Vector2(200, 200))
			assert_bool(distance <= radii[index] + 0.5 and distance >= inner - 0.5).override_failure_message("ring %d corner %s" % [index, corner]).is_true()
		for other: int in range(index + 1, boxes.size()):
			assert_bool(box.intersects(boxes[other])).is_false()
	var picture: VisualModel = load("res://scenes/mine/visual_model.tscn").instantiate()
	add_child(picture)
	auto_free(picture)
	picture.show_visual({"type": "number_card", "form": "int", "a": -3, "rings": true, "lit": "integer"}) # draws without error in both modes
	ScholarMode.forced_setting = "explorer"
	picture.show_visual({"type": "number_card", "form": "frac", "a": 1, "b": 2, "rings": true})


func test_every_skill_has_a_notation_level_and_the_symbol_skills_are_marked() -> void:
	var catalog: SkillCatalog = SkillCatalog.load_all()
	for id: StringName in catalog.ids():
		assert_int(catalog.skill(id).notation_level).is_between(0, 2)
	assert_int(catalog.skill(&"pv.tens_ones.build").notation_level).is_equal(0)
	assert_int(catalog.skill(&"exp.square.numbers").notation_level).is_equal(1)
	# Peer review 05: the congruence sign is level 1 like NotationRules says (Explorer sees it with the words); the
	# set symbols are the only level-2 notation, and the Zone 12 ring skills carry them.
	assert_int(catalog.skill(&"mod.congruence.notation").notation_level).is_equal(1)
	for id: StringName in [&"sets.integer.classify", &"sets.rational.classify", &"sets.real.classify"]:
		assert_int(catalog.skill(id).notation_level).is_equal(NotationRules.FORMAL)
	for id: StringName in catalog.ids():
		var skill: Skill = catalog.skill(id)
		assert_bool(skill.notation_level < NotationRules.FORMAL or String(id).begins_with("sets.")).override_failure_message(String(id)).is_true()


func test_every_number_answer_skill_lists_keyboard_entry() -> void:
	var catalog: SkillCatalog = SkillCatalog.load_all()
	for id: StringName in catalog.ids():
		var skill: Skill = catalog.skill(id)
		if skill.zone > 11:
			continue # Zone 12 sets its own modes
		var typed: bool = skill.answer_modes.has(&"number_pad") or skill.answer_modes.has(&"handwriting") or skill.answer_modes.has(&"handwriting_fraction")
		if typed:
			assert_bool(skill.answer_modes.has(&"keyboard")).override_failure_message(str(id)).is_true()


func test_every_word_gem_has_a_formal_definition_shown_only_in_scholar_mode() -> void:
	for id: StringName in Text.term_ids():
		var gem: Dictionary = Text.term_definition(id)
		assert_str(gem["scholar_text"]).override_failure_message(str(id)).is_not_empty()
	var card: WordGemCard = auto_free(WordGemCard.new())
	add_child(card)
	Text.scholar_override = false
	card.show_term(&"prime")
	await get_tree().process_frame
	assert_bool(card.scholar_label().visible).is_false()
	Text.scholar_override = true
	card.show_term(&"prime")
	assert_bool(card.scholar_label().visible).is_true()
	assert_str(card.scholar_label().text).is_equal(Text.term_definition(&"prime")["scholar_text"])


func test_the_rank_shows_on_the_hub() -> void:
	var hub: HubScreen = auto_free(load("res://scenes/shell/hub.tscn").instantiate())
	add_child(hub)
	await get_tree().process_frame
	assert_str(hub.rank_label().text).is_equal(Text.get_line(&"ui.hub.rank", {"rank": Text.get_line(RankRules.name_line(Rewards.rank_for()))}))
