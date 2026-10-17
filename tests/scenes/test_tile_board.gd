# Mirrors scenes/input/tile_board.gd: drag, tap, swap and take out tiles with synthetic finger,
# mouse and pen events through a private InputRouter, exactly like the drag board tests.
class_name TileBoardTest
extends GdUnitTestSuite

const ROUTER_SCRIPT: String = "res://autoload/input_router.gd"

var _router: Node
var _board: TileBoard


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_router = auto_free(load(ROUTER_SCRIPT).new())
	add_child(_router)


func after_test() -> void:
	TestWindow.restore(get_window())


func _make(tiles: Array, slots: int, ordered: bool = true, sequence: Array = []) -> TileBoard:
	var board: TileBoard = load("res://scenes/input/tile_board.tscn").instantiate()
	board.router = _router
	board.tiles = tiles
	board.slot_count = slots
	board.ordered = ordered
	board.sequence = sequence
	board.size = Vector2(1000, 600)
	add_child(board)
	auto_free(board)
	_board = board
	await get_tree().process_frame
	await get_tree().process_frame
	return board


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func test_dragging_a_tile_onto_a_slot_places_it() -> void:
	var board: TileBoard = await _make([61, 62, 63, 64], 2)
	InputSim.drag_path(_router, _center(board.tile_face(61)), _center(board.slot_face(0)))
	assert_array(board.placed()).contains_exactly([61, null])
	assert_float(board.tile_face(61).modulate.a).is_less(1.0) # used tiles dim in place
	assert_bool(board.done_button().disabled).is_true() # not full yet


func test_tapping_a_tile_fills_the_first_empty_slot_and_tapping_it_again_takes_it_out() -> void:
	var board: TileBoard = await _make([61, 62, 63, 64], 2)
	InputSim.tap(_router, _center(board.tile_face(63)))
	InputSim.tap(_router, _center(board.tile_face(61)))
	assert_array(board.placed()).contains_exactly([63, 61])
	InputSim.tap(_router, _center(board.slot_face(0)))
	assert_array(board.placed()).contains_exactly([null, 61])
	assert_float(board.tile_face(63).modulate.a).is_equal(1.0)


func test_a_used_tile_cannot_be_picked_from_the_pool_twice() -> void:
	var board: TileBoard = await _make([5, 6, 7], 3)
	InputSim.tap(_router, _center(board.tile_face(5)))
	InputSim.tap(_router, _center(board.tile_face(5)))
	assert_array(board.placed()).contains_exactly([5, null, null])


func test_dragging_a_placed_tile_to_another_slot_swaps_them_and_off_the_slots_takes_it_out() -> void:
	var board: TileBoard = await _make([12, 35, 71], 3)
	board.put(71, 0)
	board.put(12, 2)
	InputSim.drag_path(_router, _center(board.slot_face(0)), _center(board.slot_face(2)))
	assert_array(board.placed()).contains_exactly([12, null, 71])
	InputSim.drag_path(_router, _center(board.slot_face(2)), Vector2(5, 5))
	assert_array(board.placed()).contains_exactly([12, null, null])


func test_dropping_on_a_full_slot_sends_its_tile_back_to_the_pool() -> void:
	var board: TileBoard = await _make([1, 2, 3], 2)
	board.put(1, 0)
	InputSim.drag_path(_router, _center(board.tile_face(2)), _center(board.slot_face(0)))
	assert_array(board.placed()).contains_exactly([2, null])
	assert_float(board.tile_face(1).modulate.a).is_equal(1.0)


func test_done_reports_the_slots_in_order_once_every_slot_is_full() -> void:
	var board: TileBoard = await _make([12, 35, 71], 3)
	var given: Array = []
	board.submitted.connect(func(answer: Array) -> void: given.append(answer))
	board.put(35, 0)
	board.submit() # not full: nothing
	assert_array(given).is_empty()
	board.put(12, 1)
	board.put(71, 2)
	assert_bool(board.done_button().disabled).is_false()
	board.done_button().pressed.emit()
	assert_array(given).contains_exactly([[35, 12, 71]])


func test_an_unordered_board_reports_the_tiles_sorted() -> void:
	var facts: Array = ["8 - 5 = 3", "3 + 5 = 8", "5 + 3 = 8", "8 - 3 = 5", "3 - 8 = 5"]
	var board: TileBoard = await _make(facts, 4, false)
	for index: int in 4:
		board.put(facts[index], index)
	assert_array(board.answer()).contains_exactly(["3 + 5 = 8", "5 + 3 = 8", "8 - 3 = 5", "8 - 5 = 3"])


func test_mouse_and_pen_drags_work_like_a_finger() -> void:
	var board: TileBoard = await _make([10, 20, 30], 1)
	InputSim.mouse_button(_router, _center(board.tile_face(20)), true)
	InputSim.mouse_move(_router, _center(board.slot_face(0)) + Vector2(4, 4)) # mouse drags only while held
	InputSim.mouse_button(_router, _center(board.slot_face(0)), false)
	assert_array(board.placed()).contains_exactly([20])
	board.clear()
	InputSim.touch(_router, _center(board.tile_face(30)), true)
	InputSim.drag(_router, _center(board.slot_face(0)), 0, 0.6, Vector2(0.2, 0.1)) # a stylus with pressure and tilt
	InputSim.touch(_router, _center(board.slot_face(0)), false)
	assert_array(board.placed()).contains_exactly([30])


func test_a_disabled_board_ignores_drags_and_done() -> void:
	var board: TileBoard = await _make([1, 2], 1)
	board.set_enabled(false)
	InputSim.tap(_router, _center(board.tile_face(1)))
	assert_array(board.placed()).contains_exactly([null])
	assert_bool(board.done_button().disabled).is_true()


func test_a_strip_shows_its_known_numbers_between_the_slots() -> void:
	var board: TileBoard = await _make([61, 62, 63, 64], 2, true, [60, null, 62, null, 64])
	var labels: Array[String] = []
	for node: Node in board.find_children("*", "Label", true, false):
		if not node.get_parent() is TileBoard.TileFace:
			labels.append((node as Label).text)
	assert_array(labels).contains_exactly(["60", "62", "64"])
	assert_float(board.slot_face(0).global_position.x).is_less(board.slot_face(1).global_position.x)


func test_every_tile_and_slot_is_a_full_touch_target() -> void:
	var board: TileBoard = await _make(["12 - 5 = 7", "5 + 7 = 12"], 1)
	for face: TileBoard.TileFace in [board.tile_face("12 - 5 = 7"), board.slot_face(0)]:
		assert_float(face.custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()))
		assert_float(face.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))
	assert_float(board.tile_face("12 - 5 = 7").size.x).is_greater_equal(board.tile_face("12 - 5 = 7").get_minimum_size().x)
