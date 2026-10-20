# The pattern wall of Zone 9 (Sprint 40, P4-S40-01): the drag-tile framework with one gap set into the
# row. A tile dragged (finger or mouse) or tapped into the gap and Done hand in its number; the wall
# never judges. Problems of the sequence, Fibonacci and figurate skills route to it.
class_name PatternWallTest
extends GdUnitTestSuite

const ROUTER_SCRIPT: String = "res://autoload/input_router.gd"

var _router: Node


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_router = auto_free(load(ROUTER_SCRIPT).new())
	add_child(_router)


func after_test() -> void:
	DeviceCaps.reset()
	TestWindow.restore(get_window())


func _wall(terms: Array, tiles: Array) -> PatternWall:
	var wall: PatternWall = load("res://scenes/zones/z09_pattern_grotto/pattern_wall.tscn").instantiate()
	wall.router = _router
	wall.setup(terms, tiles)
	wall.size = Vector2(1000, 600)
	add_child(wall)
	auto_free(wall)
	await get_tree().process_frame
	await get_tree().process_frame
	return wall


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func test_dragging_a_crystal_into_the_gap_and_done_hands_in_its_number() -> void:
	var wall: PatternWall = await _wall([3, 7, 11, 15, null], [15, 19, 20])
	var got: Array[int] = []
	wall.number_chosen.connect(func(value: int) -> void: got.append(value))
	assert_bool(wall.done_button().disabled).is_true() # nothing in the gap yet
	InputSim.drag_path(_router, _center(wall.tile_face(19)), _center(wall.slot_face(0)))
	assert_array(wall.placed()).contains_exactly([19])
	wall.done_button().pressed.emit()
	assert_array(got).contains_exactly([19])


func test_a_tap_drops_a_tile_in_and_a_wrong_one_can_be_swapped() -> void:
	var wall: PatternWall = await _wall([1, 3, 6, 10, null], [10, 15, 16, 25])
	InputSim.tap(_router, _center(wall.tile_face(16)))
	assert_array(wall.placed()).contains_exactly([16])
	InputSim.tap(_router, _center(wall.tile_face(15))) # the gap is full: a new tile takes its place
	InputSim.drag_path(_router, _center(wall.tile_face(15)), _center(wall.slot_face(0)))
	assert_array(wall.placed()).contains_exactly([15])


func test_a_mouse_drag_works_like_a_finger() -> void:
	DeviceCaps.touch_override = false
	var wall: PatternWall = await _wall([2, 4, 6, 8, null], [8, 10, 11])
	var from: Vector2 = _center(wall.tile_face(10))
	var to: Vector2 = _center(wall.slot_face(0))
	InputSim.mouse_button(_router, from, true)
	for step: int in range(1, 6):
		InputSim.mouse_move(_router, from.lerp(to, step / 5.0))
	InputSim.mouse_button(_router, to, false)
	assert_array(wall.placed()).contains_exactly([10])


func test_every_tile_and_the_gap_are_touch_targets_and_the_how_line_comes_from_the_table() -> void:
	var wall: PatternWall = await _wall([5, 8, null, 14, 17], [11, 12, 22])
	for value: int in [11, 12, 22]:
		assert_float(wall.tile_face(value).size.y).is_greater_equal(float(UI.min_target_px()))
	assert_float(wall.slot_face(0).size.x).is_greater_equal(float(UI.min_target_px()))
	assert_str((wall.find_child("How", true, false) as Label).text).is_equal(Text.get_line(&"z9.wall.how"))
	# Compact enough for a landscape phone (about 5.6 touch targets tall in all).
	assert_float(wall.get_combined_minimum_size().y).is_less(5.6 * UI.min_target_px())


func test_zone_9_wall_problems_route_to_the_wall_and_others_to_the_pad() -> void:
	var catalog: SkillCatalog = SkillCatalog.load_all()
	for skill_id: StringName in [&"seq.arith.next_term", &"seq.geom.next_term", &"fib.sequence.next_term", &"fig.triangular.build", &"fig.square.build"]:
		var skill: Skill = catalog.skill(skill_id)
		var concrete: Problem = GeneratorRegistry.make_problem(skill, 5, {"representation": &"concrete"})
		assert_int(AnswerPanel.choose_input(concrete)).override_failure_message(str(skill_id)).is_equal(AnswerPanel.InputKind.PATTERN)
		assert_float(AnswerPanel.chance_for(concrete)).is_equal(1.0 / float(concrete.meta["pattern_wall"]["tiles"].size()))
	var missing: Problem = GeneratorRegistry.make_problem(catalog.skill(&"seq.arith.missing_term"), 5, {"representation": &"pictorial"})
	assert_int(AnswerPanel.choose_input(missing)).is_equal(AnswerPanel.InputKind.PATTERN)
	var abstract: Problem = GeneratorRegistry.make_problem(catalog.skill(&"seq.arith.next_term"), 5, {"representation": &"abstract"})
	assert_int(AnswerPanel.choose_input(abstract)).is_equal(AnswerPanel.InputKind.NUMBER_PAD)
	assert_str(String(AnswerPanel.answer_mode_for(abstract))).is_equal("number_pad")
