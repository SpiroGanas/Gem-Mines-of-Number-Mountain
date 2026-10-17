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
	assert_int(seen.size()).is_equal(4)


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


func test_the_museum_minerals_for_the_mvp_zones_match_the_rewards_plan() -> void:
	# Rewards v1: quartz, garnet, pyrite, plus amethyst for mastery.
	assert_array(GemArt.ALL_TYPES).contains_exactly([&"quartz", &"garnet", &"pyrite", &"amethyst"])
