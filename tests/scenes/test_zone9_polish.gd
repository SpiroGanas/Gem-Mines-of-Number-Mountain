# Zone 9's art, sound, badge and celebration hooks (Sprint 40, no artist): its own backdrop tint with pink
# crystal light and a golden spiral, its banner name, its music loop, the zone-done line, the Gauss
# Staircase badge earned by Gauss's sum, and every Zone 9 picture drawing inside its box.
class_name Zone9PolishTest
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("zone9_polish_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)


func after_test() -> void:
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func test_zone_9_has_its_own_tint_spiral_and_banner() -> void:
	assert_str(String(Backdrop.palette_for_zone(9))).is_equal("zone9")
	var nine: Color = Backdrop.PALETTES[&"zone9"]["top"]
	for zone: int in range(1, 8):
		assert_bool(Backdrop.PALETTES[Backdrop.palette_for_zone(zone)]["top"] == nine).override_failure_message("zone %d" % zone).is_false()
	assert_bool(Backdrop.PALETTES[&"zone9"]["spiral"]).is_true()
	assert_str(String(ZoneBanner.line_for(9))).is_equal("z9.zone.name")
	assert_str(Text.get_line(ZoneBanner.line_for(9))).is_equal("Pattern Grotto")
	var backdrop: Backdrop = Backdrop.new()
	backdrop.palette = &"zone9"
	backdrop.size = Vector2(1920, 1080)
	add_child(backdrop)
	auto_free(backdrop)
	backdrop.queue_redraw()
	await await_idle_frame() # the spiral draws without errors


func test_the_zone_9_music_loop_exists_and_is_credited() -> void:
	assert_bool(ResourceLoader.exists("res://assets/music/placeholder/mine_z9.ogg")).is_true()
	var credits: String = FileAccess.get_file_as_string("res://assets/CREDITS.md")
	assert_str(credits).contains("`assets/music/placeholder/mine_z9.ogg`")


func test_finishing_zone_9_has_its_own_line() -> void:
	assert_bool(Text.has_line(RewardsRules.zone_done_line(9))).is_true()
	assert_bool(RewardsRules.zone_finished(9, [&"a.b.c"], [&"a.b.c"])).is_true()


func test_the_gauss_staircase_badge_comes_with_gauss_s_sum() -> void:
	var badge: Dictionary = {}
	for entry: Dictionary in MotivationRules.load_badges():
		if entry["id"] == "gauss_staircase":
			badge = entry
	assert_dict(badge).is_not_empty()
	assert_array(badge["unlock"]["skills_mastered"]).contains_exactly(["gauss.sum.pairing", "gauss.sum.formula"])
	for entry: Dictionary in badge["story"]:
		var line: String = Text.get_line(StringName(str(entry["line_id"])), entry["params"])
		assert_bool(line.contains("{") or line.begins_with("[")).is_false()
	var engine: AdaptiveEngine = Adaptive.engine
	engine.master_by_challenge(&"gauss.sum.pairing")
	assert_bool(Rewards.has_badge(&"gauss_staircase")).is_false()
	engine.master_by_challenge(&"gauss.sum.formula")
	assert_bool(Rewards.has_badge(&"gauss_staircase")).is_true()
	var art: BadgeArt = BadgeArt.new()
	art.emblem = &"staircase"
	art.size = Vector2(160, 160)
	add_child(art)
	auto_free(art)
	await await_idle_frame()


func test_every_zone_9_picture_draws_inside_its_box() -> void:
	var catalog: SkillCatalog = SkillCatalog.load_all()
	for skill: Skill in catalog.skills_in_zone(9):
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
				model.queue_free()


func test_figures_pieces_and_squares_stay_inside_the_picture() -> void:
	var box: Rect2 = Rect2(0, 0, 400, 200)
	for kind: String in ["triangle", "square"]:
		var cells: Array[Dictionary] = PatternArt.figure_cells(kind, 12)
		assert_int(cells.size()).is_equal(78 if kind == "triangle" else 144)
	var columns: Array[int] = PatternArt.pairing_columns(100)
	assert_array(columns).contains_exactly([1, 2, 3, -1, 98, 99, 100])
	assert_int(PatternArt.pairing_columns(7).size()).is_equal(7)
	var rects: Array[Rect2] = PatternArt.fib_square_rects(6)
	var bounds: Rect2 = rects[0]
	for spot: Rect2 in rects:
		bounds = bounds.merge(spot)
	assert_vector(bounds.position).is_equal(Vector2.ZERO)
	assert_float(bounds.get_area()).is_equal(8.0 * 13.0)
	assert_bool(box.has_area()).is_true()
