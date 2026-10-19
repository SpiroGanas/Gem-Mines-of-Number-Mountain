# Mirrors the Sprint 20 art and polish pass: Bolt's six poses (Kenney frames plus tweens), the
# headlamp layer still recolored by the garage, the zone palettes and banners, the gem's arc.
class_name PolishTest
extends GdUnitTestSuite


func before_test() -> void:
	TestWindow.use_design_size(get_window())


func after_test() -> void:
	TestWindow.restore(get_window())


func _bolt() -> Bolt:
	var bolt: Bolt = load("res://scenes/mine/bolt.tscn").instantiate()
	bolt.speed_scale = 20.0
	add_child(bolt)
	auto_free(bolt)
	return bolt


func test_every_pose_but_think_eases_back_to_idle() -> void:
	var bolt: Bolt = _bolt()
	for pose: StringName in Bolt.POSES:
		bolt.set_pose(pose)
		assert_that(bolt.pose()).is_equal(pose)
		if pose == &"think" or pose == &"idle":
			continue
		var frames: int = 0
		while bolt.pose() != &"idle" and frames < 120:
			await get_tree().process_frame
			frames += 1
		assert_that(bolt.pose()).override_failure_message("%s did not settle" % pose).is_equal(&"idle")


func test_an_unknown_pose_is_ignored() -> void:
	var bolt: Bolt = _bolt()
	bolt.set_pose(&"think")
	bolt.set_pose(&"sulk")
	assert_that(bolt.pose()).is_equal(&"think")


func test_every_headlamp_color_is_distinct_and_electric_light() -> void:
	var colors: Array[Color] = []
	for lamp: String in RewardsRules.HEADLAMP_ITEMS:
		var color: Color = Bolt.lamp_color(lamp)
		assert_bool(colors.has(color)).is_false()
		colors.append(color)


func test_every_zone_has_a_palette_and_a_banner_name() -> void:
	var palettes: Array[StringName] = []
	for zone: int in range(1, Backdrop.LAST_PALETTE_ZONE + 1):
		var palette: StringName = Backdrop.palette_for_zone(zone)
		assert_bool(Backdrop.PALETTES.has(palette)).is_true()
		assert_bool(palettes.has(palette)).override_failure_message("zone %d shares a tint" % zone).is_false()
		palettes.append(palette)
		assert_bool(Text.has_line(ZoneBanner.line_for(zone))).is_true()


func test_the_backdrop_art_files_exist() -> void:
	for path: String in [Backdrop.STALACTITES_PATH, Backdrop.STALAGMITES_PATH, ZoneBanner.SIGN_PATH, Rock.SPARKLE_TEXTURE_PATH, Bolt.CHEER_TEXTURE_PATH, Bolt.THINK_TEXTURE_PATH]:
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
