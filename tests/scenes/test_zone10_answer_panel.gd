# Zone 10 (Clockwork Depths) through the answer panel (P5-S42): every skill gets the widget the plan describes
# (the circular track, the clock lock, the mixing table, answer buttons, the number pad), can be answered right
# and wrong through it with a mouse alone, and its pictures draw. The widgets themselves are covered below.
class_name Zone10AnswerPanelTest
extends GdUnitTestSuite

const I := AnswerPanel.InputKind
## The inputs each skill uses without handwriting and without a keyboard, by representation.
const EXPECTED: Dictionary = {
	&"mod.remainder.find": {"concrete": I.TRACK, "pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"mod.track.stop": {"concrete": I.TRACK, "pictorial": I.NUMBER_PAD},
	&"mod.track.backward": {"concrete": I.TRACK, "pictorial": I.NUMBER_PAD},
	&"mod.congruence.check": {"pictorial": I.CHOICES, "abstract": I.CHOICES},
	&"mod.congruence.notation": {"abstract": I.CHOICES},
	&"mod.add.wrap": {"concrete": I.DIAL, "abstract": I.NUMBER_PAD},
	&"mod.mul.wrap": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"group.identity.find": {"pictorial": I.TABLE},
	&"group.inverse.find": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"group.closure.verify": {"pictorial": I.CHOICES},
	&"group.table.complete": {"pictorial": I.CHOICES},
	&"group.cyclic.generate": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"div.rule.explain_3_9": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"div.rule.explain_2_5_10": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"div.rule.explain_4_8": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
}

var _catalog: SkillCatalog
var _panel: AnswerPanel
var _given: Array = []


func before() -> void:
	_catalog = SkillCatalog.load_all()


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_given.clear()
	_panel = load("res://scenes/mine/answer_panel.tscn").instantiate()
	_panel.size = Vector2(1000, 760)
	_panel.slate_override = false # a mouse-only device: no handwriting
	_panel.keyboard_override = false
	add_child(_panel)
	auto_free(_panel)
	_panel.answered.connect(func(value: Variant) -> void: _given.append(value))


func after_test() -> void:
	TestWindow.restore(get_window())


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _problem(skill_id: StringName, seed_value: int, representation: StringName) -> Problem:
	return GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed_value, {"representation": representation})


func test_each_zone_10_skill_gets_the_input_the_plan_describes() -> void:
	assert_int(EXPECTED.size()).is_equal(_catalog.skills_in_zone(10).size())
	for skill_id: StringName in EXPECTED:
		for representation: String in EXPECTED[skill_id]:
			for seed_value: int in [3, 17]:
				var problem: Problem = _problem(skill_id, seed_value, StringName(representation))
				_panel.setup(problem, _rng(seed_value))
				assert_int(_panel.input_kind).override_failure_message("%s %s" % [skill_id, representation]).is_equal(EXPECTED[skill_id][representation])


func test_every_zone_10_problem_can_be_answered_right_and_wrong() -> void:
	for skill_id: StringName in EXPECTED:
		for representation: String in EXPECTED[skill_id]:
			for seed_value: int in [5, 29, 61]:
				var problem: Problem = _problem(skill_id, seed_value, StringName(representation))
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_given.clear()
				var where: String = "%s %s seed %d" % [skill_id, representation, seed_value]
				assert_bool(PanelDriver.give(_panel, problem.answer)).override_failure_message(where).is_true()
				assert_int(_given.size()).override_failure_message(where).is_equal(1)
				assert_bool(problem.is_correct(_given[0])).override_failure_message("%s gave %s" % [where, _given[0]]).is_true()
				_panel.setup(problem, _rng(seed_value))
				_panel.set_enabled(true)
				_given.clear()
				var wrong: Variant = PanelDriver.wrong_value(problem)
				if PanelDriver.give(_panel, wrong) and not _given.is_empty() and Problem.same(_given[0], wrong):
					assert_bool(problem.is_correct(_given[0])).override_failure_message(where + " wrong").is_false()


func test_the_circular_track_lays_a_target_on_every_station_and_the_cart_rides() -> void:
	var problem: Problem = _problem(&"mod.track.stop", 4, &"concrete")
	_panel.setup(problem, _rng())
	_panel.set_enabled(true)
	var track: CircularTrack = _panel.circular_track()
	assert_int(track.n).is_equal(problem.meta["circular_track"]["n"])
	for index: int in track.n:
		var button: Button = track.station_button(index)
		assert_bool(button.size.x >= 28.0 and button.size.y >= 28.0).is_true()
		assert_str(button.text).is_equal(str(index))
	track.speed_scale = 0.0
	track.ride_button().pressed.emit()
	assert_int(track.cart_station()).is_equal(problem.answer) # the ride ends where the problem says


func test_the_track_has_a_touch_target_for_every_station_and_a_ride_button() -> void:
	for stations: int in range(2, 13):
		var track: CircularTrack = load("res://scenes/zones/z10_clockwork_depths/circular_track.tscn").instantiate()
		add_child(track)
		auto_free(track)
		track.setup({"n": stations, "start": 0, "steps": 5, "direction": 1})
		for index: int in stations:
			var rect: Vector2 = track.station_button(index).custom_minimum_size
			assert_float(rect.x).is_greater_equal(float(UI.min_target_px()) - 0.5)
			assert_float(rect.y).is_greater_equal(float(UI.min_target_px()) - 0.5)
		assert_float(track.ride_button().custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()) - 0.5)


func test_the_clock_lock_points_the_dial_and_sets_it() -> void:
	var problem: Problem = _problem(&"mod.add.wrap", 6, &"concrete")
	_panel.setup(problem, _rng())
	_panel.set_enabled(true)
	var dial: ClockLock = _panel.clock_lock()
	dial.speed_scale = 0.0
	dial.mark_button(1).pressed.emit()
	assert_float(dial.pointer).is_equal(1.0)
	dial.set_button().pressed.emit()
	assert_int(_given[0]).is_equal(1)
	# The pointer takes the shorter way round: from 1 to the last mark is one step back.
	dial.point_at(dial.n - 1)
	assert_float(dial.pointer).is_equal(float(dial.n - 1))


func test_the_mixing_table_lights_the_chosen_row_and_done_needs_a_choice() -> void:
	var problem: Problem = _problem(&"group.identity.find", 2, &"pictorial")
	_panel.setup(problem, _rng())
	_panel.set_enabled(true)
	var table: MixingTable = _panel.mixing_table()
	assert_bool(table.done_button().disabled).is_true()
	table.number_button(2).pressed.emit()
	assert_int(table.chosen).is_equal(2)
	assert_bool(table.done_button().disabled).is_false()
	assert_bool(table.number_button(2).button_pressed).is_true()
	table.done_button().pressed.emit()
	assert_int(_given[0]).is_equal(2)


func test_the_loop_and_table_pictures_draw_in_the_visual_model() -> void:
	for visual: Dictionary in [
			ModularGenerator.clock_track(7, 3, 20, 1, true),
			ModularGenerator.clock_track(12, 5, 33, -1, false),
			ModularGenerator.clock_track(6, 0, 2, 1, true, -1, true),
			ModularGenerator.clock_track(5, 0, 13, 1, true, 8),
			GroupGenerator.cayley_picture(12, &"mul", true, [3, 4], [3, 4]),
			GroupGenerator.cayley_picture(9, &"add", false),
			GroupGenerator.cayley_picture(5, &"add", true, [], [], "identity", 2),
			ModularGenerator.congruence_card(17, 5, 12),
			DivisibilityWhyGenerator.digits_model(1234, "last_digits", 8)]:
		var model: VisualModel = load("res://scenes/mine/visual_model.tscn").instantiate()
		model.size = Vector2(500, 300)
		add_child(model)
		auto_free(model)
		model.show_visual(visual)
		await get_tree().process_frame
		assert_str(String(model.visual_type())).is_equal(String(visual["type"]))


func test_the_geometry_helpers() -> void:
	assert_array(ClockArt.orbit_stations(6, 2)).contains_exactly([0, 2, 4, 0])
	assert_array(ClockArt.orbit_stations(5, 2)).contains_exactly([0, 2, 4, 1, 3, 0])
	assert_array(ClockArt.orbit_stations(6, 3)).contains_exactly([0, 3, 0])
	var top: Vector2 = ClockArt.station_point(Vector2.ZERO, 10.0, 4, 0)
	assert_float(top.y).is_equal_approx(-10.0, 0.001)
	var rect: Rect2 = Rect2(0, 0, 130, 130)
	assert_bool(rect.encloses(ClockArt.cell_rect(rect, 12, 11, 11))).is_true()
	assert_bool(rect.encloses(ClockArt.cell_rect(rect, 12, -1, -1))).is_true()
