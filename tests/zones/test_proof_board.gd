# The proof board of Zone 9 (Sprint 40, P4-S40-02) and its pure rules (ProofFit, PatternArt.proof_pieces):
# every proof picture really is the shape its fact names once fitted (no gaps, no overlaps), the loose
# piece slides in by a drag, a tap or the Fit button (finger, mouse and keyboard alike), and a fact button
# hands in its diagram id without the board judging it.
class_name ProofBoardTest
extends GdUnitTestSuite

const ROUTER_SCRIPT: String = "res://autoload/input_router.gd"

var _router: Node


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_router = auto_free(load(ROUTER_SCRIPT).new())
	add_child(_router)


func after_test() -> void:
	TestWindow.restore(get_window())


func _count(pieces: Array[Dictionary], piece: int) -> int:
	var count: int = 0
	for entry: Dictionary in pieces:
		if int(entry["piece"]) == piece:
			count += 1
	return count


func test_two_staircases_make_an_n_by_n_plus_1_rectangle() -> void:
	for n: int in range(2, 9):
		var pieces: Array[Dictionary] = PatternArt.proof_pieces("staircases", n, true)
		assert_bool(ProofFit.covers_exactly(pieces)).is_true()
		assert_vector(PatternArt.pieces_bounds(pieces).size).is_equal(Vector2(n + 1, n))
		assert_int(_count(pieces, 0)).is_equal(FigurateGenerator.triangular(n)) # 1 + 2 + ... + n
		assert_int(_count(pieces, 1)).is_equal(FigurateGenerator.triangular(n))


func test_two_triangles_and_odd_layers_make_squares() -> void:
	for n: int in range(2, 9):
		var triangles: Array[Dictionary] = PatternArt.proof_pieces("two_triangles", n, true)
		assert_bool(ProofFit.covers_exactly(triangles)).is_true()
		assert_vector(PatternArt.pieces_bounds(triangles).size).is_equal(Vector2(n, n))
		assert_int(_count(triangles, 0) + _count(triangles, 1)).is_equal(n * n)
		assert_int(_count(triangles, 1)).is_equal(FigurateGenerator.triangular(n - 1))
		var layers: Array[Dictionary] = PatternArt.proof_pieces("odd_layers", n, true)
		assert_bool(ProofFit.covers_exactly(layers)).is_true()
		assert_int(_count(layers, 1)).is_equal(2 * n - 1) # the outer layer is the n-th odd number


func test_the_turned_array_covers_the_same_gems_and_fibonacci_squares_fill_a_golden_rectangle() -> void:
	for n: int in range(2, 7):
		var turned: Array[Dictionary] = PatternArt.proof_pieces("array_turn", n, true)
		assert_bool(ProofFit.covers_exactly(turned)).is_true()
		assert_int(_count(turned, 0)).is_equal(_count(turned, 1))
	for n: int in range(2, 9):
		var squares: Array[Dictionary] = PatternArt.proof_pieces("fib_squares", n, true)
		assert_bool(ProofFit.covers_exactly(squares)).override_failure_message("fib squares %d" % n).is_true()
		var size: Vector2 = PatternArt.pieces_bounds(squares).size
		assert_float(maxf(size.x, size.y)).is_equal(float(FibGenerator.fib(n + 1)))
		assert_float(minf(size.x, size.y)).is_equal(float(FibGenerator.fib(n)))


func test_apart_the_loose_piece_waits_clear_of_the_rest() -> void:
	for id: String in Problem.PROOF_DIAGRAMS:
		var apart: Array[Dictionary] = PatternArt.proof_pieces(id, 4, false)
		assert_bool(ProofFit.covers_exactly(apart)).override_failure_message(id).is_false()
		assert_int(apart.size()).is_equal(PatternArt.proof_pieces(id, 4, true).size())


func test_a_drag_past_halfway_snaps_in_and_short_of_it_slides_back() -> void:
	assert_float(ProofFit.fit_after_drag(0.0, -300.0, 400.0)).is_equal(0.75)
	assert_float(ProofFit.fit_after_drag(0.0, 300.0, 400.0)).is_equal(0.0)
	assert_float(ProofFit.settle(0.75)).is_equal(1.0)
	assert_float(ProofFit.settle(0.4)).is_equal(0.0)


func _board() -> ProofBoard:
	var board: ProofBoard = load("res://scenes/zones/z09_pattern_grotto/proof_board.tscn").instantiate()
	board.router = _router
	board.speed_scale = 0.0
	board.size = Vector2(1100, 700)
	add_child(board)
	auto_free(board)
	var options: Array[Dictionary] = []
	for id: String in ["staircases", "two_triangles", "odd_layers", "array_turn"]:
		options.append({"value": id, "label": Text.get_line(StringName("z9.proof.fact_" + id))})
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	board.setup("staircases", 4, options, rng)
	await get_tree().process_frame
	await get_tree().process_frame
	return board


func test_the_fit_button_and_a_tap_slide_the_piece_in_and_out() -> void:
	var board: ProofBoard = await _board()
	assert_bool(board.is_fitted()).is_false()
	assert_str(board.fit_button().text).is_equal(Text.get_line(&"z9.proof.fit"))
	board.fit_button().pressed.emit()
	assert_bool(board.is_fitted()).is_true()
	assert_str(board.fit_button().text).is_equal(Text.get_line(&"z9.proof.apart"))
	InputSim.tap(_router, board.picture().get_global_rect().get_center())
	assert_bool(board.is_fitted()).is_false()


func test_dragging_the_piece_left_fits_it() -> void:
	var board: ProofBoard = await _board()
	var rect: Rect2 = board.picture().get_global_rect()
	InputSim.drag_path(_router, rect.get_center() + Vector2(rect.size.x * 0.3, 0), rect.get_center() - Vector2(rect.size.x * 0.3, 0), 8)
	assert_bool(board.is_fitted()).is_true()


func test_space_toggles_the_fit_on_a_keyboard() -> void:
	var board: ProofBoard = await _board()
	board._unhandled_key_input(InputSim.key(board, KEY_SPACE))
	assert_bool(board.is_fitted()).is_true()


func test_a_fact_button_hands_in_its_id_and_nothing_is_judged() -> void:
	var board: ProofBoard = await _board()
	var got: Array[String] = []
	board.chosen.connect(func(id: String) -> void: got.append(id))
	assert_int(board.fact_order().size()).is_equal(4)
	assert_bool(board.choose("odd_layers")).is_true()
	assert_array(got).contains_exactly(["odd_layers"])
	board.set_enabled(false)
	assert_bool(board.choose("staircases")).is_false()
	for id: String in board.fact_order():
		assert_float(board.fact_button(id).size.y).is_greater_equal(float(UI.min_target_px()))
	assert_float(board.get_combined_minimum_size().y).is_less(5.6 * UI.min_target_px()) # fits a landscape phone


func test_proof_problems_route_to_the_board() -> void:
	var skill: Skill = SkillCatalog.load_all().skill(&"proof.words.match")
	var problem: Problem = GeneratorRegistry.make_problem(skill, 9)
	assert_int(AnswerPanel.choose_input(problem)).is_equal(AnswerPanel.InputKind.PROOF)
	assert_float(AnswerPanel.chance_for(problem)).is_equal(0.25)
	for id: Variant in problem.meta["proof_board"]["choices"]:
		assert_str(AnswerPanel.label_for(id, problem)).is_equal(Text.get_line(StringName(problem.meta["label_lines"][id])))
