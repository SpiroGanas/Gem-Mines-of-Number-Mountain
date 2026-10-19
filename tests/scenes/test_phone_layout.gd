# The phone layout pass (Phase 3; "Phones are supported", docs/decisions.md): every child screen, the
# mine with every answer input, the pause menu and the parent area open on a landscape phone (20:9 at
# 420 dpi, about 411 dp tall, and a small 1600x720 phone at 320 dpi, 360 dp tall) as well as at the
# tablet and Chromebook shapes (16:9, 16:10, 3:2, 4:3). On each, every visible tappable control lies
# fully on screen, is at least UI.min_target_px() on both sides and overlaps no other (LayoutAudit).
class_name PhoneLayoutTest
extends GdUnitTestSuite

const SHELL_SCENE: String = "res://scenes/shell/shell.tscn"
const MINE_SCENE: String = "res://scenes/mine/mine.tscn"

## Window size -> dpi for each screen shape checked (0: the design density of the headless runner).
const PHONES: Array[Array] = [[TestWindow.PHONE, TestWindow.PHONE_DPI], [TestWindow.SMALL_PHONE, TestWindow.SMALL_PHONE_DPI]]

## Child and parent screens opened on their own (screen id -> setup args).
const SCREENS: Dictionary = {
	&"title": {}, &"hub": {}, &"first_run": {}, &"settings": {}, &"museum": {}, &"garage": {},
	&"crafting": {}, &"build_site": {}, &"build": {"build_id": "cart_track"}, &"badges": {}, &"glossary": {},
	&"challenge_door": {"skill_id": "add.to_10.sums"},
	&"parent_gate": {}, &"dashboard": {}, &"family_rewards": {}, &"profiles": {}, &"onboarding": {},
	&"how_it_teaches": {}, &"poems": {},
}

var _dir: String
var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("phone_layout_" + str(Time.get_ticks_usec()))
	DeviceSettings.use_shared(DeviceSettings.new(_dir.path_join("device_settings.cfg")))
	SaveSystem.use_directory(_dir)
	SaveSystem.data()["child"]["nickname"] = "Charlie"
	SaveSystem.data()["placement"]["done"] = true
	SaveSystem.save_now()
	ParentGateScreen.forget_lock()


func after_test() -> void:
	DigitInk.reset()
	ParentGateScreen.forget_lock()
	DeviceSettings.use_shared(null)
	ScholarMode.reset_overrides()
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())
	get_tree().paused = false


## Every shape: the two phones, then the four tablet shapes at the design density.
func _shapes() -> Array[Array]:
	var shapes: Array[Array] = PHONES.duplicate()
	for size: Vector2i in TestWindow.TABLET_SIZES:
		shapes.append([size, 0])
	return shapes


func _use(shape: Array) -> void:
	if int(shape[1]) > 0:
		TestWindow.use_phone(get_window(), shape[0], int(shape[1]))
	else:
		TestWindow.use_tablet(get_window(), shape[0])


func _where(label: String, shape: Array) -> String:
	return "%s at %dx%d@%d" % [label, shape[0].x, shape[0].y, int(shape[1])]


func _settle() -> void:
	for frame: int in 3:
		await get_tree().process_frame


func _screen(screen_id: StringName, args: Dictionary) -> ShellScreen:
	var screen: ShellScreen = load(Shell.SCREEN_PATHS[screen_id]).instantiate()
	screen.setup(args)
	add_child(screen)
	return screen


func _check(root: Node, label: String, shape: Array, issues: PackedStringArray) -> void:
	if LayoutAudit.tappables(root).is_empty():
		issues.append("%s: nothing tappable found (is it on screen?)" % _where(label, shape))
	issues.append_array(LayoutAudit.problems(root, _where(label, shape)))


func _report(issues: PackedStringArray) -> void:
	assert_array(Array(issues)).override_failure_message("\n".join(issues)).is_empty()


# --- Screens -----------------------------------------------------------------------------------------


func test_every_screen_fits_phones_and_tablets() -> void:
	var issues: PackedStringArray = PackedStringArray()
	for shape: Array in _shapes():
		_use(shape)
		for screen_id: StringName in SCREENS:
			var screen: ShellScreen = _screen(screen_id, SCREENS[screen_id])
			await _settle()
			_check(screen, String(screen_id), shape, issues)
			screen.free()
	_report(issues)


func test_the_title_fits_with_one_and_four_children() -> void:
	var issues: PackedStringArray = PackedStringArray()
	for shape: Array in _shapes():
		_use(shape)
		var title: ShellScreen = _screen(&"title", {})
		await _settle()
		_check(title, "title (1 child)", shape, issues)
		title.free()
	for name: String in ["Ada", "Ben", "Cleo"]:
		Profiles.create(name, Profile.AVATARS[Profiles.count()], 1)
	for shape: Array in _shapes():
		_use(shape)
		var title: ShellScreen = _screen(&"title", {})
		await _settle()
		_check(title, "title (4 children)", shape, issues)
		title.free()
	_report(issues)


func test_the_parent_gate_and_its_pages_fit() -> void:
	var issues: PackedStringArray = PackedStringArray()
	for shape: Array in _shapes():
		_use(shape)
		var gate: ParentGateScreen = _screen(&"parent_gate", {})
		await _settle()
		_check(gate, "parent_gate", shape, issues)
		gate.free()
	_report(issues)


func test_the_pause_menu_fits() -> void:
	var issues: PackedStringArray = PackedStringArray()
	for shape: Array in _shapes():
		_use(shape)
		var shell: Shell = load(SHELL_SCENE).instantiate()
		shell.fade_seconds = 0.0
		add_child(shell)
		shell.change_screen(&"hub")
		var frames: int = 0
		while shell.current_screen_id() != &"hub" and frames < 100:
			await get_tree().process_frame
			frames += 1
		shell.pause()
		await _settle()
		_check(shell.find_child("PauseMenu", true, false), "pause", shape, issues)
		shell.resume()
		shell.free()
	_report(issues)


# --- The mine, with every answer input ----------------------------------------------------------------


## A skill (and whether the slate is on) whose problems get `kind`, found by generating problems.
## KEYBOARD (Scholar mode's keyboard entry, Zone 8) is asked for with keyboard entry allowed.
func _skill_for(kind: AnswerPanel.InputKind) -> Array:
	var keyboard: bool = kind == AnswerPanel.InputKind.KEYBOARD
	for id: StringName in _catalog.ids():
		var skill: Skill = _catalog.skill(id)
		if not GeneratorRegistry.callable_for(skill).is_valid():
			continue
		for seed_value: int in 4:
			var problem: Problem = GeneratorRegistry.make_problem(skill, 100 + seed_value)
			for slate: bool in [false, true]:
				if AnswerPanel.choose_input(problem, slate, keyboard) == kind:
					return [id, slate]
	return []


## Opens rocks until one gets `kind` (the mine draws the skill's problems itself). Null if none did.
func _mine_with(kind: AnswerPanel.InputKind) -> MineScreen:
	var found: Array = _skill_for(kind)
	if found.is_empty():
		return null
	DigitInk.availability_override = found[1]
	DigitInk.recognizer_override = FakeRecognizer.new()
	# Keyboard entry needs Scholar mode and a key pressed this session; every other input runs without.
	ScholarMode.forced_setting = "scholar" if kind == AnswerPanel.InputKind.KEYBOARD else "explorer"
	ScholarMode.forced_keyboard = kind == AnswerPanel.InputKind.KEYBOARD
	for seed_value: int in [11, 12, 13, 14]:
		var mine: MineScreen = load(MINE_SCENE).instantiate()
		mine.animation_speed = 25.0
		mine.seed_value = seed_value
		mine.skill_ids = [found[0]]
		add_child(mine)
		for index: int in mine.wall().rock_count():
			if mine.flow.state != DigFlow.State.PICK_ROCK:
				break
			mine.wall().rock(index).pressed.emit()
			var frames: int = 0
			while mine.flow.state != DigFlow.State.AWAIT_ANSWER and frames < 300:
				await get_tree().process_frame
				frames += 1
			if mine.answer_panel() != null and mine.answer_panel().input_kind == kind:
				return mine
			break
		mine.free()
	return null


func test_the_mine_fits_with_every_answer_input() -> void:
	var issues: PackedStringArray = PackedStringArray()
	var missing: PackedStringArray = PackedStringArray()
	for shape: Array in _shapes():
		_use(shape)
		for kind: int in AnswerPanel.InputKind.values():
			if kind == AnswerPanel.InputKind.NONE:
				continue
			var mine: MineScreen = await _mine_with(kind)
			var label: String = "mine/" + AnswerPanel.InputKind.keys()[kind]
			if mine == null:
				missing.append(label)
				continue
			await _settle()
			_check(mine, label, shape, issues)
			mine.free()
	assert_array(Array(missing)).override_failure_message("no rock got: " + ", ".join(missing)).is_empty()
	_report(issues)


## The help a not-quite answer brings (the picture model, then a solved example above the input)
## still fits, with Bolt's two feedback lines under the problem.
func test_the_mine_fits_with_hints_up() -> void:
	var issues: PackedStringArray = PackedStringArray()
	for shape: Array in _shapes():
		_use(shape)
		for kind: int in AnswerPanel.InputKind.values():
			if kind == AnswerPanel.InputKind.NONE:
				continue
			var mine: MineScreen = await _mine_with(kind)
			if mine == null:
				continue
			mine._show_hint(HintLadder.Rung.VISUAL_MODEL)
			await _settle()
			_check(mine, "mine model/" + AnswerPanel.InputKind.keys()[kind], shape, issues)
			mine._show_hint(HintLadder.Rung.WORKED_EXAMPLE)
			await _settle()
			_check(mine, "mine example/" + AnswerPanel.InputKind.keys()[kind], shape, issues)
			mine.free()
	_report(issues)


## The cards over the mine: a celebration, the wind-down, a Word Gem, and the wall-clear buttons.
func test_the_mine_overlays_fit() -> void:
	var issues: PackedStringArray = PackedStringArray()
	for shape: Array in _shapes():
		_use(shape)
		var mine: MineScreen = await _mine_with(AnswerPanel.InputKind.NUMBER_PAD)
		mine.celebration().celebrate([{"line_id": &"bolt.celebrate.mastery", "gem": RewardsRules.MASTERY_GEM}, {"line_id": &"bolt.celebrate.lantern", "lantern": true}])
		await _settle()
		_check(mine.celebration(), "celebration", shape, issues)
		mine.celebration().close()
		mine.word_gem_card().show_term(mine.bolt().terms()[0])
		await _settle()
		_check(mine.word_gem_card(), "word gem card", shape, issues)
		mine.word_gem_card().close()
		mine.wind_down().show_recap(Rewards.session_summary(), 3, true)
		await _settle()
		_check(mine.wind_down(), "wind-down", shape, issues)
		mine.wind_down().visible = false
		mine._on_state_changed(DigFlow.State.WALL_CLEAR, DigFlow.State.GEM_DROP)
		mine.door_button().visible = true
		await _settle()
		_check(mine, "wall clear", shape, issues)
		mine.free()
	_report(issues)


func test_the_onboarding_steps_fit() -> void:
	var issues: PackedStringArray = PackedStringArray()
	for shape: Array in _shapes():
		_use(shape)
		var screen: OnboardingScreen = _screen(&"onboarding", {})
		for step: OnboardingScreen.Step in [OnboardingScreen.Step.GATE, OnboardingScreen.Step.PROFILE, OnboardingScreen.Step.SESSION]:
			screen.show_step(step)
			await _settle()
			_check(screen, "onboarding/" + OnboardingScreen.Step.keys()[step], shape, issues)
		screen.free()
	_report(issues)
