# Zone 6's art, sound and celebration hooks (P4-S31-03): its own backdrop tint with wall gears, its
# banner name, its music loop, the lists and gears pictures fitting their boxes, and the zone-finished
# celebration firing only when every Zone 6 skill is mastered.
class_name Zone6PolishTest
extends GdUnitTestSuite


func test_zone_6_has_its_own_tint_with_gears_and_a_banner_name() -> void:
	var palette: StringName = Backdrop.palette_for_zone(6)
	assert_str(String(palette)).is_equal("zone6")
	assert_bool(Backdrop.PALETTES[palette].get("gears", false)).is_true()
	for zone: int in range(1, 6):
		assert_bool(Backdrop.PALETTES[Backdrop.palette_for_zone(zone)]["top"] == Backdrop.PALETTES[palette]["top"]).is_false()
	assert_str(String(ZoneBanner.line_for(6))).is_equal("z6.zone.name")
	assert_str(Text.get_line(ZoneBanner.line_for(6))).is_equal("Gear Works")


func test_the_backdrop_draws_zone_6() -> void:
	var backdrop: Backdrop = Backdrop.new()
	backdrop.palette = Backdrop.palette_for_zone(6)
	backdrop.size = Vector2(1920, 1080)
	add_child(backdrop)
	auto_free(backdrop)
	await await_idle_frame()
	assert_str(String(backdrop.palette)).is_equal("zone6")


func test_zone_6_has_a_music_loop() -> void:
	assert_bool(ResourceLoader.exists("res://assets/music/placeholder/mine_z6.ogg")).is_true()


func test_a_zone_is_finished_only_when_every_skill_is_mastered() -> void:
	var ids: Array = [&"gcf.list.common_factors", &"gcf.find.by_listing"]
	assert_bool(RewardsRules.zone_finished(6, ids, [&"gcf.list.common_factors"])).is_false()
	assert_bool(RewardsRules.zone_finished(6, ids, [&"gcf.list.common_factors", &"gcf.find.by_listing"])).is_true()
	assert_bool(RewardsRules.zone_finished(6, [], [])).is_false()
	assert_bool(RewardsRules.zone_finished(5, ids, [&"gcf.list.common_factors", &"gcf.find.by_listing"])).is_false() # before Zone 6: unchanged


func test_list_cells_fit_their_box() -> void:
	var box: Rect2 = Rect2(10, 10, 600, 200)
	var rows: Array = [{"n": 48, "items": [1, 2, 3, 4, 6, 8, 12, 16, 24, 48]}, {"n": 36, "items": [1, 2, 3, 4, 6, 9, 12, 18, 36]}]
	var cells: Array[Dictionary] = VisualModel.list_cells(rows, box)
	assert_int(cells.size()).is_equal(2 + 10 + 9)
	for cell: Dictionary in cells:
		assert_bool(box.grow(0.5).encloses(cell["rect"])).override_failure_message(str(cell)).is_true()


func test_gear_layout_meshes_the_gears_inside_their_box() -> void:
	var box: Rect2 = Rect2(0, 0, 500, 240)
	for teeth: Array in [[24, 8], [8, 12, 16], [48], [192, 6]]:
		var layout: Array[Dictionary] = VisualModel.gear_layout(teeth, box)
		assert_int(layout.size()).is_equal(teeth.size())
		for index: int in layout.size():
			var reach: Rect2 = Rect2(layout[index]["center"] - Vector2.ONE * layout[index]["radius"], Vector2.ONE * layout[index]["radius"] * 2.0)
			assert_bool(box.grow(1.0).encloses(reach)).override_failure_message("%s gear %d" % [teeth, index]).is_true()
			if index > 0:
				var gap: float = layout[index]["center"].x - layout[index - 1]["center"].x
				assert_float(gap).is_less(layout[index]["radius"] + layout[index - 1]["radius"]) # the teeth overlap: they mesh


func test_the_lists_and_gears_pictures_draw() -> void:
	for picture: Dictionary in [
		{"type": "lists", "kind": "factors", "rows": [{"n": 8, "items": [1, 2, 4, 8]}, {"n": 12, "items": [1, 2, 3, 4, 6, 12]}], "marked": [1, 2, 4]},
		{"type": "lists", "kind": "recipe", "rows": [{"n": 12, "items": [2, 2, 3], "lit": [0, 2]}], "marked": []},
		{"type": "gears", "teeth": [18], "shaded": 12},
		{"type": "gears", "teeth": [8, 12], "marks": true},
	]:
		var model: VisualModel = load("res://scenes/mine/visual_model.tscn").instantiate()
		model.size = Vector2(800, 300)
		add_child(model)
		auto_free(model)
		model.show_visual(picture)
		await await_idle_frame()
		assert_str(String(model.visual_type())).is_equal(String(picture["type"]))
