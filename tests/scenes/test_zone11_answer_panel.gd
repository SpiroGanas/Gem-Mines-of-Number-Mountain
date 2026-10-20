# Zone 11 (Cipher Vault) through the answer panel (P5-S45): every skill gets the input the plan describes (answer
# buttons for words, the cipher wheel, the coin puzzle, the number pad), can be answered right and wrong through it with
# a mouse alone, and the pictures draw. The widgets themselves, the letter pad, the secret message and the lock door
# are covered below.
class_name Zone11AnswerPanelTest
extends GdUnitTestSuite

const I := AnswerPanel.InputKind
const EXPECTED: Dictionary = {
	&"cipher.caesar.encode": {"concrete": I.CHOICES, "abstract": I.CHOICES},
	&"cipher.caesar.decode": {"concrete": I.CHOICES, "abstract": I.CHOICES},
	&"cipher.caesar.crack": {"concrete": I.WHEEL, "pictorial": I.CHOICES},
	&"cipher.affine.encode": {"abstract": I.CHOICES},
	&"cipher.affine.decode": {"abstract": I.CHOICES},
	&"modinv.exists.decide": {"pictorial": I.CHOICES, "abstract": I.CHOICES},
	&"modinv.find.small": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"euclid.basic.gcd": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"euclid.steps.count": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"euclid.extended.coeffs": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"dioph.linear.solve": {"concrete": I.COINS, "abstract": I.CHOICES},
	&"dioph.linear.decide": {"pictorial": I.CHOICES, "abstract": I.CHOICES},
	&"rsa.toy.keygen": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"rsa.toy.encrypt": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
	&"rsa.toy.decrypt": {"pictorial": I.NUMBER_PAD, "abstract": I.NUMBER_PAD},
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


func test_each_zone_11_skill_gets_the_input_the_plan_describes() -> void:
	assert_int(EXPECTED.size()).is_equal(_catalog.skills_in_zone(11).size())
	for skill_id: StringName in EXPECTED:
		for representation: String in EXPECTED[skill_id]:
			for seed_value: int in [3, 17]:
				var problem: Problem = _problem(skill_id, seed_value, StringName(representation))
				_panel.setup(problem, _rng(seed_value))
				assert_int(_panel.input_kind).override_failure_message("%s %s" % [skill_id, representation]).is_equal(EXPECTED[skill_id][representation])


func test_every_zone_11_problem_can_be_answered_right_and_wrong() -> void:
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


func test_word_and_coin_answer_buttons_read_the_answer() -> void:
	var word: Problem = _problem(&"cipher.caesar.encode", 4, &"abstract")
	assert_str(AnswerPanel.label_for(word.answer, word)).is_equal(word.answer)
	var coins: Problem = _problem(&"dioph.linear.solve", 4, &"abstract")
	assert_str(AnswerPanel.label_for([2, 1], coins)).is_equal("2 and 1")


func test_the_cipher_wheel_turns_the_code_back_and_stays_in_range() -> void:
	var problem: Problem = _problem(&"cipher.caesar.crack", 6, &"concrete")
	_panel.setup(problem, _rng())
	_panel.set_enabled(true)
	var wheel: CipherWheel = _panel.cipher_wheel()
	assert_str(wheel.shown_text()).is_equal(problem.meta["coded"])
	assert_bool(wheel.back_button().disabled).is_true()
	wheel.forward_button().pressed.emit()
	assert_int(wheel.shift).is_equal(1)
	assert_str(wheel.shown_text()).is_equal(CipherGenerator.shift_text(problem.meta["coded"], -1))
	wheel.set_shift(problem.answer)
	assert_str(wheel.shown_text()).is_equal(problem.meta["word"]) # the right shift spells the word
	wheel.set_shift(99)
	assert_int(wheel.shift).is_equal(25)
	assert_bool(wheel.forward_button().disabled).is_true()
	wheel.set_shift(problem.answer)
	wheel.set_button().pressed.emit()
	assert_int(_given[0]).is_equal(problem.answer)


func test_the_coin_puzzle_adds_up_the_total_and_keeps_counts_in_range() -> void:
	var problem: Problem = _problem(&"dioph.linear.solve", 6, &"concrete")
	_panel.setup(problem, _rng())
	_panel.set_enabled(true)
	var puzzle: CoinPuzzle = _panel.coin_puzzle()
	var p: Dictionary = problem.prompt_params
	puzzle.less_button(0).pressed.emit()
	assert_int(puzzle.counts[0]).is_equal(0) # never below 0
	puzzle.more_button(0).pressed.emit()
	puzzle.more_button(1).pressed.emit()
	puzzle.more_button(1).pressed.emit()
	assert_int(puzzle.total()).is_equal(p["a"] + 2 * p["b"])
	puzzle.set_counts(99, 99)
	assert_int(puzzle.counts[0]).is_equal(12)
	assert_bool(puzzle.more_button(0).disabled).is_true()
	puzzle.set_counts(problem.answer[0], problem.answer[1])
	assert_int(puzzle.total()).is_equal(p["c"])
	puzzle.done_button().pressed.emit()
	assert_array(_given[0]).contains_exactly(problem.answer)


func test_the_euclid_machine_steps_to_the_gcf_and_starts_again() -> void:
	var machine: EuclidMachine = load("res://scenes/zones/z11_cipher_vault/euclid_machine.tscn").instantiate()
	add_child(machine)
	auto_free(machine)
	machine.setup(18, 48)
	var found: Array[int] = []
	machine.finished.connect(func(g: int) -> void: found.append(g))
	assert_int(machine.revealed).is_equal(0)
	for step: int in 3:
		machine.next_button().pressed.emit()
	assert_bool(machine.is_done()).is_true()
	assert_array(found).contains_exactly([6])
	assert_bool(machine.next_button().disabled).is_true()
	machine.again_button().pressed.emit()
	assert_int(machine.revealed).is_equal(0)
	assert_bool(machine.next_button().disabled).is_false()


func test_the_letter_pad_emits_capital_letters_and_spaces_only() -> void:
	var pad: LetterPad = load("res://scenes/input/letter_pad.tscn").instantiate()
	add_child(pad)
	auto_free(pad)
	var typed: Array[String] = []
	pad.key_pressed.connect(func(ch: String) -> void: typed.append(ch))
	pad.letter_button("H").pressed.emit()
	pad.space_button().pressed.emit()
	pad.press("a") # not a capital letter
	pad.press("7")
	pad.press("HI")
	pad.press("Z")
	assert_array(typed).contains_exactly(["H", " ", "Z"])
	pad.set_enabled(false)
	pad.press("A")
	assert_int(typed.size()).is_equal(3)
	assert_float(pad.letter_button("A").custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()) - 0.5)


func test_the_secret_message_codes_a_note_and_keeps_nothing() -> void:
	var before: String = JSON.stringify(SaveSystem.data())
	var screen: SecretMessageScreen = load("res://scenes/zones/z11_cipher_vault/secret_message.tscn").instantiate()
	add_child(screen)
	auto_free(screen)
	for letter: String in "HI MOM":
		screen.pad().press(letter)
	assert_str(screen.message).is_equal("HI MOM")
	assert_str(screen.coded()).is_equal(CipherGenerator.shift_text("HI MOM", 3))
	assert_str(screen.code_label().text).is_equal(screen.coded())
	assert_str(screen.note_label().text).is_equal("HI MOM")
	screen.change_shift(2)
	assert_str(screen.coded()).is_equal(CipherGenerator.shift_text("HI MOM", 5))
	assert_str(screen.key_label().text).is_equal(Text.get_line(&"z11.secret.key_shift", {"k": 5}))
	for index: int in 60:
		screen.type_letter("A")
	assert_int(screen.message.length()).is_equal(SecretMessageScreen.MAX_LETTERS)
	screen.pad().delete_button().pressed.emit()
	assert_int(screen.message.length()).is_equal(SecretMessageScreen.MAX_LETTERS - 1)
	screen.pad().clear_button().pressed.emit()
	assert_str(screen.message).is_equal("")
	assert_bool(screen.find_child("Kind1", true, false) == null).is_true() # no times code before it is learned
	screen.type_letter("S")
	assert_str(JSON.stringify(SaveSystem.data())).is_equal(before) # nothing was saved


func test_the_times_code_opens_with_the_affine_cipher_and_keeps_a_valid_multiplier() -> void:
	assert_bool(SecretMessageScreen.multipliers().has(13)).is_false() # 13 shares a factor with 26
	assert_bool(SecretMessageScreen.multipliers().has(15)).is_true()
	for a: int in SecretMessageScreen.multipliers():
		assert_bool(CipherGenerator.is_coprime_26(a)).is_true()


func test_the_toy_lock_door_locks_and_unlocks_the_same_number() -> void:
	var door: RsaDoorScreen = load("res://scenes/zones/z11_cipher_vault/rsa_door.tscn").instantiate()
	add_child(door)
	auto_free(door)
	for p_step: int in 4:
		for q_step: int in 4:
			door.p_index = p_step
			door.q_index = q_step
			if door.p_index == door.q_index:
				continue
			door._settle()
			assert_int(door.n()).is_equal(door.p() * door.q())
			assert_int(door.t()).is_equal((door.p() - 1) * (door.q() - 1))
			assert_int((door.e() * door.d()) % door.t()).is_equal(1)
			for number: int in range(2, door.n()):
				door.number = number
				assert_int(RsaGenerator.pow_mod(door.locked(), door.d(), door.n())).is_equal(number)
	door.p_index = 0
	door.q_index = 1
	door.e_index = 0
	door.change_p(-1)
	assert_int(door.p_index).is_equal(0)
	door.change_q(-1) # would land on p's prime: stays
	assert_int(door.q_index).is_equal(1)
	assert_str(door.result_label("n").text).contains(str(door.n()))
	assert_int(door.machine().rows.size()).is_greater(0)


func test_the_vault_pictures_draw_in_the_visual_model() -> void:
	for visual: Dictionary in [
			CipherGenerator.cipher_picture("GEM", 3), CipherGenerator.cipher_picture("GEM", -1, true), CipherGenerator.cipher_picture("ELEVATOR"),
			EuclidGenerator.euclid_picture(48, 18, 0), EuclidGenerator.euclid_picture(48, 18, -1), DiophantineGenerator.coins_picture(3, 5, 11)]:
		var model: VisualModel = load("res://scenes/mine/visual_model.tscn").instantiate()
		model.size = Vector2(500, 300)
		add_child(model)
		auto_free(model)
		model.show_visual(visual)
		await get_tree().process_frame
		assert_str(String(model.visual_type())).is_equal(String(visual["type"]))


func test_the_vault_art_geometry() -> void:
	assert_array(Array(VaultArt.ladder_lines(48, 18, -1))).contains_exactly(["48 = 2 × 18 + 12", "18 = 1 × 12 + 6", "12 = 2 × 6 + 0"])
	assert_array(Array(VaultArt.ladder_lines(48, 18, 1))).contains_exactly(["48 = 2 × 18 + 12"])
	assert_bool(VaultArt.ladder_lines(48, 18, 0).is_empty()).is_true()
	var bars: Vector2 = VaultArt.bar_lengths(48, 18, 240.0)
	assert_float(bars.x).is_equal_approx(240.0, 0.01)
	assert_float(bars.y).is_equal_approx(90.0, 0.01)
	assert_str(VaultArt.inner_letter(0, 3)).is_equal("D")
	assert_str(VaultArt.inner_letter(24, 3)).is_equal("B")
	var top: Vector2 = VaultArt.wheel_point(Vector2.ZERO, 10.0, 0)
	assert_float(top.y).is_equal_approx(-10.0, 0.001)
