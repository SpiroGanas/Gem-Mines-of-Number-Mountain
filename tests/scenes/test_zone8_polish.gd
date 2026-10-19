# Zone 8's art, sound and celebration hooks (Sprint 37, no artist) and its notation (Sprint 35, P4-S35-05):
# its own backdrop tint with the tower in the rock, its banner name, its music loop, the zone-done
# celebration, every Zone 8 picture drawing inside its box, and powers, roots and scientific notation
# written as composed Labels (a smaller, raised exponent), with words underneath only in Explorer mode.
class_name Zone8PolishTest
extends GdUnitTestSuite


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	ScholarMode.reset_overrides()


func after_test() -> void:
	ScholarMode.reset_overrides()
	TestWindow.restore(get_window())


func test_zone_8_has_its_own_tint_and_banner() -> void:
	assert_int(Backdrop.LAST_PALETTE_ZONE).is_equal(8)
	assert_str(String(Backdrop.palette_for_zone(8))).is_equal("zone8")
	var eight: Color = Backdrop.PALETTES[&"zone8"]["top"]
	for zone: int in range(1, 8):
		assert_bool(Backdrop.PALETTES[Backdrop.palette_for_zone(zone)]["top"] == eight).is_false()
	assert_bool(Backdrop.PALETTES[&"zone8"]["tower"]).is_true()
	assert_str(Text.get_line(ZoneBanner.line_for(8))).is_equal("Power Tower")
	assert_str(String(Backdrop.palette_for_zone(9))).is_equal("zone8") # a zone without art takes Zone 8's


func test_the_zone_8_music_loop_exists_and_is_credited() -> void:
	assert_bool(ResourceLoader.exists("res://assets/music/placeholder/mine_z8.ogg")).is_true()
	assert_str(FileAccess.get_file_as_string("res://assets/CREDITS.md")).contains("`assets/music/placeholder/mine_z8.ogg`")


func test_the_whole_zone_is_celebrated_with_its_line() -> void:
	assert_str(String(RewardsRules.zone_done_line(8))).is_equal("z8.zone.done")
	assert_bool(Text.has_line(RewardsRules.zone_done_line(8))).is_true()
	assert_bool(RewardsRules.zone_finished(8, [&"a.b.c"], [&"a.b.c"] as Array[StringName])).is_true()


func test_every_zone_8_picture_draws_inside_its_box() -> void:
	var catalog: SkillCatalog = SkillCatalog.load_all()
	for skill: Skill in catalog.skills_in_zone(8):
		for representation: StringName in skill.representations:
			var problem: Problem = GeneratorRegistry.make_problem(skill, 11, {"representation": representation})
			for picture: Dictionary in [problem.visual, problem.hint_steps[1]["visual"]]:
				if picture.is_empty():
					continue
				var model: VisualModel = load("res://scenes/mine/visual_model.tscn").instantiate()
				model.size = Vector2(700, 320)
				add_child(model)
				model.show_visual(picture)
				assert_float(model.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))
				model.queue_redraw()
				await await_idle_frame() # _draw runs without errors for every picture type
				if str(picture["type"]) == "notation":
					assert_object(model.notation()).is_not_null()
				model.queue_free()


func test_the_tower_floors_fit_their_box() -> void:
	var box: Rect2 = Rect2(0, 0, 400, 300)
	for floors: int in range(0, 11):
		for floor_box: Rect2 in PowerArt.tower_floors(box, floors):
			assert_bool(box.encloses(floor_box)).override_failure_message("%d floors" % floors).is_true()
	assert_array(PowerArt.place_values(2, 6)).is_equal([32, 16, 8, 4, 2, 1])
	assert_array(PowerArt.place_values(5, 3)).is_equal([25, 5, 1])


func test_an_exponent_is_smaller_and_raised() -> void:
	var power: ExponentDisplay = ExponentDisplay.new()
	add_child(power)
	auto_free(power)
	power.show_power(2, 5)
	await await_idle_frame()
	assert_str(power.base_label().text).is_equal("2")
	assert_str(power.exponent_label().text).is_equal("5")
	assert_float(power.exponent_ratio()).is_less(0.7)
	assert_float(power.exponent_label().position.y).is_less_equal(power.base_label().position.y) # raised
	assert_float(power.exponent_label().get_rect().end.y).is_less(power.base_label().get_rect().end.y)
	assert_int(power.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_ten_cubed_and_scientific_notation_render() -> void:
	var ten: MathNotation = MathNotation.make({"form": "power", "base": 10, "exp": 3})
	add_child(ten)
	auto_free(ten)
	var sci: MathNotation = MathNotation.make({"form": "sci", "mantissa": 34, "scale": 1, "exp": 5})
	add_child(sci)
	auto_free(sci)
	var root: MathNotation = MathNotation.make({"form": "root", "n": 49})
	add_child(root)
	auto_free(root)
	await await_idle_frame()
	assert_str((ten.display() as ExponentDisplay).exponent_label().text).is_equal("3")
	var written: SciNotationDisplay = sci.display()
	assert_str(written.mantissa_text()).is_equal("3.4") # exact: built from integers, never a float
	assert_str(written.power().base_label().text).is_equal("10")
	assert_str(written.power().exponent_label().text).is_equal("5")
	assert_str((root.display() as RootDisplay).number_label().text).is_equal("49")


func test_explorer_shows_the_words_and_scholar_the_notation_alone() -> void:
	ScholarMode.forced_setting = "explorer"
	var explorer: MathNotation = MathNotation.make({"form": "power", "base": 2, "exp": 5})
	add_child(explorer)
	auto_free(explorer)
	assert_bool(explorer.words_label().visible).is_true()
	assert_str(explorer.words_label().text).is_equal("2 to the power 5")
	ScholarMode.forced_setting = "scholar"
	var scholar: MathNotation = MathNotation.make({"form": "power", "base": 2, "exp": 5})
	add_child(scholar)
	auto_free(scholar)
	assert_bool(scholar.words_label().visible).is_false()
	assert_str(MathNotation.words_for({"form": "sci", "mantissa": 34, "scale": 1, "exp": 5})).is_equal("3.4 times 10 to the power 5")
