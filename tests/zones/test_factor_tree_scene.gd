# Mirrors scenes/zones/z05_prime_caverns/factor_tree.gd (Sprint 18): the tree grows from BoulderSplit
# splits, a prime piece bounces the pickaxe and becomes a gem, tree_completed fires only when every
# leaf is a prime gem, Done hands in the leaves as they are, and pieces never give the answer away.
class_name FactorTreeSceneTest
extends GdUnitTestSuite

var _router: Node
var _tree: FactorTree
var _completed: Array = []
var _handed_in: Array = []


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_completed.clear()
	_handed_in.clear()
	_router = auto_free(load("res://autoload/input_router.gd").new())
	add_child(_router)


func after_test() -> void:
	TestWindow.restore(get_window())


func _make(value: int) -> FactorTree:
	_tree = load("res://scenes/zones/z05_prime_caverns/factor_tree.tscn").instantiate()
	_tree.router = _router
	_tree.speed_scale = 50.0
	_tree.pause_seconds = 0.0
	_tree.size = Vector2(1100, 760)
	add_child(_tree)
	auto_free(_tree)
	_tree.tree_completed.connect(func(leaves: Array) -> void: _completed = leaves)
	_tree.submitted.connect(func(leaves: Array) -> void: _handed_in = leaves)
	_tree.setup(value)
	await await_idle_frame()
	await await_idle_frame()
	return _tree


func test_the_tree_starts_as_one_rock_on_the_rail() -> void:
	var tree: FactorTree = await _make(12)
	assert_int(tree.node_count()).is_equal(1)
	assert_int(tree.picked()).is_equal(0)
	assert_int(tree.boulder_split().value).is_equal(12)
	assert_array(tree.leaves()).is_equal([12])


func test_a_split_grows_two_branches_and_the_next_rock_comes_up() -> void:
	var tree: FactorTree = await _make(12)
	assert_bool(tree.boulder_split().choose_pair(3)).is_true()
	assert_array(tree.leaves()).is_equal([3, 4])
	assert_int(tree.node_count()).is_equal(3)
	assert_int(tree.boulder_split().value).is_equal(3) # the left piece is next


func test_pieces_stay_rocks_until_the_pickaxe_tests_them() -> void:
	var tree: FactorTree = await _make(6)
	tree.boulder_split().choose_pair(2)
	for index: int in tree.leaf_order():
		assert_bool(tree.node(index)["gem"]).is_false()
	for piece: Control in tree.boulder_split().pieces():
		assert_bool((piece as Object).get("is_gem")).is_false()


func test_completion_fires_only_when_every_leaf_is_a_prime_gem() -> void:
	var tree: FactorTree = await _make(12)
	tree.boulder_split().choose_pair(2) # 2 and 6
	tree.boulder_split().choose_pair(1) # 2 bounces: a gem
	assert_array(_completed).is_empty()
	assert_bool(tree.is_complete()).is_false()
	tree.boulder_split().choose_pair(2) # 6 is 2 and 3
	tree.boulder_split().choose_pair(1)
	assert_array(_completed).is_empty()
	tree.boulder_split().choose_pair(1)
	assert_array(_completed).is_equal([2, 2, 3])
	assert_array(_handed_in).is_equal([2, 2, 3])
	assert_bool(tree.is_complete()).is_true()


func test_every_way_of_splitting_ends_with_the_same_primes() -> void:
	var tree: FactorTree = await _make(36)
	tree.boulder_split().choose_pair(6) # 6 x 6
	for step: int in 10:
		if tree.is_complete():
			break
		var value: int = tree.boulder_split().value
		var factors: Array[int] = FactorTree.proper_factors(value)
		tree.boulder_split().choose_pair(1 if factors.is_empty() else factors[0])
	assert_array(_completed).is_equal([2, 2, 3, 3])


func test_done_hands_in_the_leaves_with_a_rock_still_standing() -> void:
	var tree: FactorTree = await _make(12)
	tree.boulder_split().choose_pair(3) # 3 and 4
	tree.done_button().pressed.emit()
	assert_array(_handed_in).is_equal([3, 4])
	assert_array(_completed).is_empty()


func test_a_tap_on_a_rock_in_the_tree_puts_it_on_the_rail() -> void:
	var tree: FactorTree = await _make(30)
	tree.boulder_split().choose_pair(5) # 5 and 6
	var six: int = tree.leaf_order()[1]
	tree.piece_button(six).pressed.emit()
	assert_int(tree.picked()).is_equal(six)
	assert_int(tree.boulder_split().value).is_equal(6)
	assert_bool(tree.pick(0)).is_false() # the root has been split


func test_the_pickaxe_drag_works_inside_the_tree() -> void:
	var tree: FactorTree = await _make(10)
	await await_idle_frame()
	var split: BoulderSplit = tree.boulder_split()
	var start: Vector2 = split.pickaxe().get_global_rect().get_center()
	var target: Vector2 = split.notches()[0].get_global_rect().get_center()
	InputSim.mouse_button(_router, start, true)
	InputSim.mouse_move(_router, start.lerp(target, 0.5))
	InputSim.mouse_move(_router, target)
	InputSim.mouse_button(_router, target, false)
	assert_array(tree.leaves()).is_equal([2, 5])


func test_a_disabled_tree_ignores_done() -> void:
	var tree: FactorTree = await _make(12)
	tree.set_enabled(false)
	tree.submit()
	assert_array(_handed_in).is_empty()


func test_the_tree_and_its_pieces_fit_for_n_up_to_100() -> void:
	var side: float = float(UI.min_target_px())
	for n: int in [16, 24, 36, 60, 72, 81, 90, 100]:
		if MathUtil.prime_factorization(n).size() > 4:
			continue
		var tree: FactorTree = await _make(n)
		PanelDriver.grow_tree(tree, MathUtil.prime_factorization(n))
		await await_idle_frame()
		var area: Rect2 = tree.get_global_rect()
		for index: int in tree.node_count():
			var rect: Rect2 = tree.piece_button(index).get_global_rect()
			assert_bool(rect.size.x >= side).is_true()
			assert_bool(area.encloses(rect)).override_failure_message("%d: piece %d at %s outside %s" % [n, index, rect, area]).is_true()
		assert_array(_completed).is_equal(MathUtil.prime_factorization(n))
		_tree.queue_free()


func test_no_rock_can_be_picked_during_the_pause_after_a_split() -> void:
	var tree: FactorTree = await _make(30)
	tree.pause_seconds = 10.0 # at speed 50: 0.2 s, the crack is still showing
	assert_bool(tree.boulder_split().choose_pair(5)).is_true() # 5 and 6
	var six: int = tree.leaf_order()[1]
	assert_bool(tree.pick(six)).is_false() # a tap on a new piece mid-crack changes nothing
	assert_int(tree.picked()).is_equal(0)
	await get_tree().create_timer(0.5).timeout
	assert_int(tree.picked()).is_equal(tree.leaf_order()[0]) # the pause over, the first piece comes up
	assert_int(tree.boulder_split().value).is_equal(5)
	assert_bool(tree.pick(six)).is_true() # and the child may choose again
