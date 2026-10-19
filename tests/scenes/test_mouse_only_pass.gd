# The mouse-only pass (Phase 3, Sprint 25; docs/phases/phase-3-public-release-readiness.md 3.8):
# on a device with no touch screen (DeviceCaps.touch_override = false, as on a mouse-only
# Chromebook or an editor run with --no-touch) the ChalkSlate never appears, every skill's answer
# widget can be answered, the drag widgets take a mouse drag that lands a little outside the
# target, and the number pad takes real mouse clicks and the keyboard.
# The manual half of the pass (every screen, on the emulator) is in docs/release-checklist.md.
class_name MouseOnlyPassTest
extends GdUnitTestSuite

const ROUTER_SCRIPT: String = "res://autoload/input_router.gd"

var _catalog: SkillCatalog
var _router: Node
var _settings_dir: String


func before() -> void:
	_catalog = SkillCatalog.load_all()


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	DeviceCaps.touch_override = false
	_settings_dir = create_temp_dir("mouse_only_" + str(Time.get_ticks_usec()))
	DeviceSettings.use_shared(DeviceSettings.new(_settings_dir + "/device_settings.cfg")) # handwriting left on
	_router = auto_free(load(ROUTER_SCRIPT).new())
	add_child(_router)


func after_test() -> void:
	DeviceCaps.reset()
	DigitInk.reset()
	DeviceSettings.use_shared(null)
	get_tree().paused = false
	TestWindow.restore(get_window())


func _panel() -> AnswerPanel:
	var panel: AnswerPanel = load("res://scenes/mine/answer_panel.tscn").instantiate()
	panel.size = Vector2(1100, 800)
	add_child(panel)
	auto_free(panel)
	return panel


func _mouse_drag(from: Vector2, to: Vector2) -> void:
	InputSim.mouse_button(_router, from, true)
	for step: int in range(1, 6):
		InputSim.mouse_move(_router, from.lerp(to, float(step) / 5.0))
	InputSim.mouse_button(_router, to, false)


## A real left click at `pos`, delivered through the viewport like the engine delivers one.
func _click(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pos
		event.global_position = pos
		event.pressed = pressed
		get_viewport().push_input(event)


# --- The answer panel ------------------------------------------------------------------------


func test_no_skill_offers_the_chalk_slate_and_every_one_can_be_answered() -> void:
	var panel: AnswerPanel = _panel()
	assert_bool(panel.slate_wanted()).is_false() # handwriting is on, but there is no touch screen
	for id: StringName in _catalog.ids():
		var problem: Problem = GeneratorRegistry.make_problem(_catalog.skill(id), 3)
		var heard: Array = []
		panel.setup(problem, RandomNumberGenerator.new())
		panel.set_enabled(true)
		assert_int(panel.input_kind).override_failure_message("%s got the slate" % id).is_not_equal(AnswerPanel.InputKind.SLATE)
		panel.answered.connect(func(given: Variant) -> void: heard.append(given), CONNECT_ONE_SHOT)
		assert_bool(PanelDriver.give(panel, problem.answer)).override_failure_message("%s: no way to answer" % id).is_true()
		assert_int(heard.size()).override_failure_message("%s: nothing answered" % id).is_equal(1)
		assert_bool(problem.is_correct(heard[0])).override_failure_message("%s judged wrong" % id).is_true()


func test_a_handwriting_skill_gets_the_number_pad_and_takes_mouse_clicks() -> void:
	var panel: AnswerPanel = _panel()
	var problem: Problem = GeneratorRegistry.make_problem(_catalog.skill(&"count.write.numeral"), 4)
	panel.setup(problem, RandomNumberGenerator.new())
	panel.set_enabled(true)
	await await_idle_frame()
	assert_int(panel.input_kind).is_equal(AnswerPanel.InputKind.NUMBER_PAD)
	var heard: Array = []
	panel.answered.connect(func(given: Variant) -> void: heard.append(given))
	var pad: NumberPad = panel.number_pad()
	for digit: String in str(int(problem.answer)):
		_click(pad.digit_button(int(digit)).get_global_rect().get_center())
	assert_str(pad.entry()).is_equal(str(int(problem.answer)))
	_click(pad.go_button().get_global_rect().get_center())
	assert_array(heard).is_equal([problem.answer])


func test_the_number_pad_takes_the_keyboard_digits_backspace_and_enter() -> void:
	var panel: AnswerPanel = _panel()
	panel.setup(GeneratorRegistry.make_problem(_catalog.skill(&"count.write.numeral"), 4), RandomNumberGenerator.new())
	panel.set_enabled(true)
	var heard: Array = []
	panel.answered.connect(func(given: Variant) -> void: heard.append(given))
	var pad: NumberPad = panel.number_pad()
	for key: Key in [KEY_4, KEY_9, KEY_BACKSPACE, KEY_KP_7]:
		InputSim.key(pad, key)
	assert_str(pad.entry()).is_equal("47")
	InputSim.key(pad, KEY_ENTER)
	assert_array(heard).is_equal([47])


# --- Drops land on a target that counts as 25% bigger ----------------------------------------


func test_a_mouse_drop_just_outside_the_tray_still_adds_the_piece() -> void:
	var board: BuildBoard = load("res://scenes/input/build_board.tscn").instantiate()
	board.router = _router
	var host: Control = auto_free(Control.new())
	host.size = Vector2(1400, 1000)
	add_child(host)
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(board)
	await await_idle_frame()
	await await_idle_frame()
	var tray: Rect2 = board.tray().get_global_rect()
	var just_outside: Vector2 = Vector2(tray.get_center().x, tray.end.y + tray.size.y * 0.08)
	assert_bool(tray.has_point(just_outside)).is_false()
	_mouse_drag(board.source(DragItem.TEN).get_global_rect().get_center(), just_outside)
	assert_dict(board.answer()).is_equal({"tens": 1, "ones": 0})
	DeviceCaps.touch_override = true # with a touch screen the same drop misses
	_mouse_drag(board.source(DragItem.ONE).get_global_rect().get_center(), just_outside)
	assert_dict(board.answer()).is_equal({"tens": 1, "ones": 0})


func test_a_mouse_drop_just_outside_a_slot_still_places_the_tile() -> void:
	var board: TileBoard = load("res://scenes/input/tile_board.tscn").instantiate()
	board.router = _router
	board.tiles = [61, 62, 63, 64]
	board.slot_count = 2
	board.size = Vector2(1000, 600)
	add_child(board)
	auto_free(board)
	await await_idle_frame()
	await await_idle_frame()
	var slot: Rect2 = board.slot_face(0).get_global_rect()
	var just_outside: Vector2 = Vector2(slot.get_center().x, slot.position.y - slot.size.y * 0.08)
	assert_bool(slot.has_point(just_outside)).is_false()
	_mouse_drag(board.tile_face(61).get_global_rect().get_center(), just_outside)
	assert_array(board.placed()).contains_exactly([61, null])


func test_the_pickaxe_snaps_from_a_little_further_away() -> void:
	var split: BoulderSplit = load("res://scenes/mine/boulder_split/boulder_split.tscn").instantiate()
	split.router = _router
	split.speed_scale = 30.0
	split.size = Vector2(1200, 800)
	add_child(split)
	auto_free(split)
	var splits: Array[Vector2i] = []
	split.split_chosen.connect(func(_v: int, a: int, b: int) -> void: splits.append(Vector2i(a, b)))
	split.setup(12, [2, 3, 4, 6])
	await await_idle_frame()
	await await_idle_frame()
	var notch: Rect2 = split.notches()[0].get_global_rect()
	# Past the touch snap radius (1.2 targets beyond the half-width) but inside the mouse-only one (1.5).
	var reach: float = notch.size.x / 2.0 + float(UI.min_target_px()) * BoulderSplit.SNAP_RADIUS_MULTIPLE * 1.12
	var away: Vector2 = notch.get_center() + Vector2(0.0, -reach)
	DeviceCaps.touch_override = true
	_mouse_drag(split.pickaxe().get_global_rect().get_center(), away)
	assert_array(splits).is_empty()
	DeviceCaps.touch_override = false
	_mouse_drag(split.pickaxe().get_global_rect().get_center(), away)
	assert_array(splits).is_equal([Vector2i(2, 6)])
