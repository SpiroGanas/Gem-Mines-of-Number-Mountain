# Mirrors scenes/mine/gem_art.gd. Gems must differ by shape, not only by color (accessibility).
class_name GemArtTest
extends GdUnitTestSuite


func test_every_gem_has_a_closed_polygon_inside_the_unit_square() -> void:
	for type: StringName in GemArt.ALL_TYPES:
		var points: PackedVector2Array = GemArt.shape_points(type)
		assert_int(points.size()).is_greater_equal(4)
		for point: Vector2 in points:
			assert_float(point.x).is_between(0.0, 1.0)
			assert_float(point.y).is_between(0.0, 1.0)


func test_gems_differ_by_shape() -> void:
	var seen: Array[PackedVector2Array] = []
	for type: StringName in GemArt.ALL_TYPES:
		var points: PackedVector2Array = GemArt.shape_points(type)
		for other: PackedVector2Array in seen:
			assert_bool(points == other).override_failure_message(type + " has the same outline as another gem").is_false()
		seen.append(points)
	assert_int(seen.size()).is_equal(10)


func test_gems_differ_by_color() -> void:
	var colors: Array[Color] = []
	for type: StringName in GemArt.ALL_TYPES:
		assert_bool(colors.has(GemArt.color_for(type))).is_false()
		colors.append(GemArt.color_for(type))


func test_each_zone_has_its_own_gem() -> void:
	assert_str(GemArt.gem_for_zone(1)).is_equal(GemArt.QUARTZ)
	assert_str(GemArt.gem_for_zone(2)).is_equal(GemArt.GARNET)
	assert_str(GemArt.gem_for_zone(3)).is_equal(GemArt.PYRITE)


func test_a_gem_never_takes_clicks() -> void:
	var gem: GemArt = auto_free(GemArt.new())
	assert_int(gem.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_the_museum_minerals_match_the_rewards_plan() -> void:
	# Rewards v1: the ten Gem Museum minerals, zone gems and the mastery gem first.
	assert_array(GemArt.ALL_TYPES).contains_exactly([&"quartz", &"garnet", &"pyrite", &"amethyst", &"malachite", &"fluorite", &"hematite", &"calcite", &"topaz", &"obsidian"])


func test_every_mineral_draws() -> void:
	for type: StringName in GemArt.ALL_TYPES:
		var gem: GemArt = auto_free(GemArt.new())
		gem.gem_type = type
		gem.size = Vector2(96, 96)
		add_child(gem)
		await get_tree().process_frame
		assert_str(gem.gem_type).is_equal(type)


func test_the_rare_gems_differ_in_shape_and_color_from_every_other_gem() -> void:
	var everything: Array[StringName] = GemArt.ALL_TYPES + GemArt.RARE_TYPES
	everything.append(GemArt.GEODE) # the Deep Dig's gem (Sprint 19)
	assert_int(GemArt.RARE_TYPES.size()).is_equal(4)
	var shapes: Array[PackedVector2Array] = []
	var colors: Array[Color] = []
	for type: StringName in everything:
		var points: PackedVector2Array = GemArt.shape_points(type)
		assert_int(points.size()).is_greater_equal(4)
		for point: Vector2 in points:
			assert_float(point.x).is_between(0.0, 1.0)
			assert_float(point.y).is_between(0.0, 1.0)
		assert_bool(shapes.has(points)).override_failure_message(type + " shares an outline").is_false()
		assert_bool(colors.has(GemArt.color_for(type))).override_failure_message(type + " shares a color").is_false()
		shapes.append(points)
		colors.append(GemArt.color_for(type))


func test_every_rare_gem_draws() -> void:
	for type: StringName in GemArt.RARE_TYPES:
		var gem: GemArt = auto_free(GemArt.new())
		gem.gem_type = type
		gem.size = Vector2(96, 96)
		add_child(gem)
		await get_tree().process_frame
		assert_str(gem.gem_type).is_equal(type)
