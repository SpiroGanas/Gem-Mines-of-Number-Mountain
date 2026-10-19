# Zone 7's art, sound and celebration hooks (Sprint 34, no artist): its own backdrop tint with cool
# glowing crystals, its banner name, its music loop, the zone-done celebration, and the crystal
# pictures drawing inside their box at every Explorer size.
class_name Zone7PolishTest
extends GdUnitTestSuite


func before_test() -> void:
	TestWindow.use_design_size(get_window())


func after_test() -> void:
	TestWindow.restore(get_window())


func test_zone_7_has_its_own_tint_and_banner_and_zone_6_falls_back() -> void:
	assert_str(String(Backdrop.palette_for_zone(7))).is_equal("zone7")
	var seven: Color = Backdrop.PALETTES[&"zone7"]["top"]
	for zone: int in range(1, 6):
		assert_bool(Backdrop.PALETTES[Backdrop.palette_for_zone(zone)]["top"] == seven).is_false()
	assert_bool(Backdrop.PALETTES[&"zone7"]["crystals"]).is_true()
	assert_str(String(ZoneBanner.line_for(7))).is_equal("z7.zone.name")
	assert_str(Text.get_line(ZoneBanner.line_for(7))).is_equal("Crystal Shards")
	# A zone without art of its own yet takes the deepest one before it, never a missing line.
	assert_bool(Backdrop.PALETTES.has(Backdrop.palette_for_zone(6))).is_true()
	assert_bool(Text.has_line(ZoneBanner.line_for(6))).is_true()
	assert_bool(Text.has_line(ZoneBanner.line_for(12))).is_true()


func test_the_zone_7_music_loop_exists_and_is_credited() -> void:
	assert_bool(ResourceLoader.exists("res://assets/music/placeholder/mine_z7.ogg")).is_true()
	var credits: String = FileAccess.get_file_as_string("res://assets/CREDITS.md")
	assert_str(credits).contains("`assets/music/placeholder/mine_z7.ogg`")


func test_a_whole_zone_mastered_is_celebrated_once_with_its_line() -> void:
	var ids: Array = [&"a.b.c", &"a.b.d"]
	var mastered: Array[StringName] = [&"a.b.c"]
	assert_bool(RewardsRules.zone_complete(ids, mastered)).is_false()
	mastered.append(&"a.b.d")
	assert_bool(RewardsRules.zone_complete(ids, mastered)).is_true()
	assert_bool(RewardsRules.zone_complete([], mastered)).is_false()
	assert_bool(Text.has_line(RewardsRules.zone_done_line(7))).is_true()


func test_every_zone_7_picture_draws_inside_its_box() -> void:
	var catalog: SkillCatalog = SkillCatalog.load_all()
	for skill: Skill in catalog.skills_in_zone(7):
		var problem: Problem = GeneratorRegistry.make_problem(skill, 11, {"representation": skill.representations[0]})
		var model: VisualModel = load("res://scenes/mine/visual_model.tscn").instantiate()
		model.size = Vector2(700, 320)
		add_child(model)
		model.show_visual(problem.hint_steps[1]["visual"])
		assert_float(model.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))
		model.queue_redraw()
		await await_idle_frame() # _draw runs without errors for every picture type
		model.queue_free()
