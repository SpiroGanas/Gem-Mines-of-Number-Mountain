# Mirrors scenes/input/drag_item.gd, drag_target.gd and build_board.tscn (P1-S04-02).
# Drags are fed through a test InputRouter with synthetic events, the same code path a
# finger, a stylus or a mouse takes in the game.
class_name DragAndBuildTest
extends GdUnitTestSuite

const BOARD_SCENE: String = "res://scenes/input/build_board.tscn"
const ROUTER_SCRIPT: String = "res://autoload/input_router.gd"

## An empty corner of the 1400x1000 test host: below the piles, away from the tray.
const OUTSIDE: Vector2 = Vector2(1390, 990)

var _router: Node
var _board: BuildBoard
var _host: Control


func before_test() -> void:
	TestWindow.use_design_size(get_window()) # the headless window is 64x64; see TestWindow
	_router = auto_free(load(ROUTER_SCRIPT).new())
	add_child(_router)
	_host = auto_free(Control.new())
	_host.size = Vector2(1400, 1000)
	add_child(_host)
	_board = load(BOARD_SCENE).instantiate()
	_board.router = _router
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(_board)
	await get_tree().process_frame
	await get_tree().process_frame


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _drag_from_pile(kind: StringName) -> void:
	InputSim.drag_path(_router, _center(_board.source(kind)), _center(_board.tray()), 6)


func after_test() -> void:
	TestWindow.restore(get_window())


# --- DragTarget -----------------------------------------------------------------------


func test_the_tray_counts_pieces_by_kind() -> void:
	_board.tray().add_item(DragItem.make(DragItem.TEN))
	_board.tray().add_item(DragItem.make(DragItem.TEN))
	_board.tray().add_item(DragItem.make(DragItem.ONE))
	assert_dict(_board.tray().counts()).is_equal({DragItem.HUNDRED: 0, DragItem.TEN: 2, DragItem.ONE: 1})
	assert_dict(_board.answer()).is_equal({"tens": 2, "ones": 1})


func test_the_tray_keeps_tens_ahead_of_ones() -> void:
	var tray: DragTarget = _board.tray()
	tray.add_item(DragItem.make(DragItem.ONE))
	tray.add_item(DragItem.make(DragItem.TEN))
	tray.add_item(DragItem.make(DragItem.ONE))
	tray.add_item(DragItem.make(DragItem.TEN))
	var kinds: Array[StringName] = []
	for item: DragItem in tray.items():
		kinds.append(item.kind)
	assert_array(kinds).contains_exactly([DragItem.TEN, DragItem.TEN, DragItem.ONE, DragItem.ONE])


func test_the_tray_refuses_kinds_it_does_not_accept() -> void:
	var tray: DragTarget = auto_free(DragTarget.new())
	tray.accepts = PackedStringArray(["one"])
	add_child(tray)
	var ten: DragItem = auto_free(DragItem.make(DragItem.TEN))
	assert_bool(tray.add_item(ten)).is_false()
	assert_bool(tray.add_item(auto_free(DragItem.make(DragItem.ONE)))).is_true()


func test_changed_fires_on_add_remove_and_clear() -> void:
	var tray: DragTarget = _board.tray()
	var changes: Array[int] = [0]
	tray.changed.connect(func() -> void: changes[0] += 1)
	var item: DragItem = DragItem.make(DragItem.ONE)
	tray.add_item(item)
	tray.remove_item(item)
	tray.add_item(DragItem.make(DragItem.ONE))
	tray.clear()
	assert_int(changes[0]).is_equal(4)
	item.queue_free()


func test_the_empty_tray_shows_its_hint_and_hides_it_when_filled() -> void:
	var hint: Label = _board.tray().find_children("*", "Label", true, false)[0]
	assert_str(hint.text).is_equal("Drop them here")
	assert_bool(hint.visible).is_true()
	_board.tray().add_item(DragItem.make(DragItem.ONE))
	assert_bool(hint.visible).is_false()


func test_pieces_are_at_least_one_touch_target_wide() -> void:
	var ten: DragItem = auto_free(DragItem.make(DragItem.TEN))
	var one: DragItem = auto_free(DragItem.make(DragItem.ONE))
	add_child(ten)
	add_child(one)
	assert_float(ten.custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()))
	assert_float(one.custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()))
	assert_float(one.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))
	assert_float(ten.custom_minimum_size.y).is_greater(one.custom_minimum_size.y) # a bar is taller than a gem
	assert_int(ten.value()).is_equal(10)
	assert_int(one.value()).is_equal(1)


# --- Dragging with finger, mouse and pen ----------------------------------------------


func test_dragging_from_a_pile_into_the_tray_adds_a_piece_with_a_finger() -> void:
	_drag_from_pile(DragItem.TEN)
	_drag_from_pile(DragItem.ONE)
	_drag_from_pile(DragItem.ONE)
	assert_dict(_board.answer()).is_equal({"tens": 1, "ones": 2})
	assert_bool(_board.is_dragging()).is_false()


func test_a_mouse_drag_does_exactly_the_same() -> void:
	InputSim.mouse_button(_router, _center(_board.source(DragItem.TEN)), true)
	InputSim.mouse_move(_router, _center(_board.tray()))
	InputSim.mouse_button(_router, _center(_board.tray()), false)
	assert_dict(_board.answer()).is_equal({"tens": 1, "ones": 0})


func test_a_stylus_drag_with_pressure_and_tilt_does_exactly_the_same() -> void:
	var from: Vector2 = _center(_board.source(DragItem.ONE))
	var to: Vector2 = _center(_board.tray())
	InputSim.touch(_router, from, true)
	for step: int in range(1, 6):
		InputSim.drag(_router, from.lerp(to, float(step) / 5.0), 0, 0.4, Vector2(0.2, 0.1))
	InputSim.touch(_router, to, false)
	assert_dict(_board.answer()).is_equal({"tens": 0, "ones": 1})
	assert_int(_router.last_device_kind()).is_equal(InputRouter.DeviceKind.PEN)


func test_the_piece_follows_the_pointer_while_dragging() -> void:
	var from: Vector2 = _center(_board.source(DragItem.ONE))
	InputSim.touch(_router, from, true)
	InputSim.drag(_router, Vector2(700, 650))
	assert_bool(_board.is_dragging()).is_true()
	var dragged: DragItem = _board.find_children("*", "DragItem", true, false).back()
	assert_vector(dragged.get_global_rect().get_center()).is_equal_approx(Vector2(700, 650), Vector2(2, 2))
	InputSim.touch(_router, Vector2(700, 650), false)
	assert_bool(_board.is_dragging()).is_false()


func test_dropping_outside_the_tray_throws_the_piece_away() -> void:
	InputSim.drag_path(_router, _center(_board.source(DragItem.ONE)), OUTSIDE, 4)
	assert_dict(_board.answer()).is_equal({"tens": 0, "ones": 0})


func test_dragging_a_piece_out_of_the_tray_removes_it() -> void:
	_drag_from_pile(DragItem.ONE)
	_drag_from_pile(DragItem.ONE)
	await get_tree().process_frame
	var removed: Array[StringName] = []
	_board.item_removed.connect(func(kind: StringName) -> void: removed.append(kind))
	var piece: DragItem = _board.tray().items()[0]
	InputSim.drag_path(_router, piece.get_global_rect().get_center(), OUTSIDE, 4)
	assert_dict(_board.answer()).is_equal({"tens": 0, "ones": 1})
	assert_array(removed).contains_exactly([DragItem.ONE])


func test_picking_a_piece_up_and_dropping_it_back_in_the_tray_keeps_it() -> void:
	_drag_from_pile(DragItem.TEN)
	await get_tree().process_frame
	var piece: DragItem = _board.tray().items()[0]
	var start: Vector2 = piece.get_global_rect().get_center()
	InputSim.drag_path(_router, start, start + Vector2(20, 10), 3)
	assert_dict(_board.answer()).is_equal({"tens": 1, "ones": 0})


func test_tapping_a_pile_adds_one_piece_without_dragging() -> void:
	InputSim.tap(_router, _center(_board.source(DragItem.TEN)))
	InputSim.tap(_router, _center(_board.source(DragItem.ONE)))
	InputSim.tap(_router, _center(_board.source(DragItem.ONE)))
	assert_dict(_board.answer()).is_equal({"tens": 1, "ones": 2})


func test_placing_announces_the_piece_kind() -> void:
	var placed: Array[StringName] = []
	_board.item_placed.connect(func(kind: StringName) -> void: placed.append(kind))
	_drag_from_pile(DragItem.TEN)
	_drag_from_pile(DragItem.ONE)
	assert_array(placed).contains_exactly([DragItem.TEN, DragItem.ONE])


func test_a_second_finger_does_not_start_a_second_drag() -> void:
	InputSim.touch(_router, _center(_board.source(DragItem.ONE)), true, 0)
	InputSim.touch(_router, _center(_board.source(DragItem.TEN)), true, 1) # ignored by the router
	InputSim.drag(_router, _center(_board.tray()), 1)
	InputSim.touch(_router, _center(_board.tray()), false, 0)
	assert_dict(_board.answer()).is_equal({"tens": 0, "ones": 1})


# --- Done and enabling ----------------------------------------------------------------


func test_done_reports_tens_and_ones() -> void:
	var heard: Array[Dictionary] = []
	_board.submitted.connect(func(answer: Dictionary) -> void: heard.append(answer))
	_drag_from_pile(DragItem.TEN)
	_drag_from_pile(DragItem.TEN)
	_drag_from_pile(DragItem.ONE)
	_board.done_button().pressed.emit()
	assert_array(heard).has_size(1)
	assert_dict(heard[0]).is_equal({"tens": 2, "ones": 1})


func test_done_with_an_empty_tray_reports_zero_zero() -> void:
	var heard: Array[Dictionary] = []
	_board.submitted.connect(func(answer: Dictionary) -> void: heard.append(answer))
	_board.done_button().pressed.emit()
	assert_dict(heard[0]).is_equal({"tens": 0, "ones": 0})


func test_a_disabled_board_ignores_drags_and_done() -> void:
	_board.set_enabled(false)
	var heard: Array[Dictionary] = []
	_board.submitted.connect(func(answer: Dictionary) -> void: heard.append(answer))
	_drag_from_pile(DragItem.ONE)
	_board.done_button().pressed.emit()
	assert_dict(_board.answer()).is_equal({"tens": 0, "ones": 0})
	assert_array(heard).is_empty()
	assert_bool(_board.done_button().disabled).is_true()


func test_disabling_mid_drag_drops_the_piece() -> void:
	InputSim.touch(_router, _center(_board.source(DragItem.ONE)), true)
	assert_bool(_board.is_dragging()).is_true()
	_board.set_enabled(false)
	assert_bool(_board.is_dragging()).is_false()


func test_the_board_has_no_text_field_and_stops_listening_when_removed() -> void:
	for forbidden: String in ["LineEdit", "TextEdit", "SpinBox"]:
		assert_array(_board.find_children("*", forbidden, true, false)).is_empty()
	var count_before: int = _router.pointer_down.get_connections().size()
	_host.remove_child(_board)
	_board.queue_free()
	assert_int(_router.pointer_down.get_connections().size()).is_equal(count_before - 1)


# --- Hundreds, a pre-filled tray and tap to remove (Sprint 5) -------------------------


func _board_with(tools: Array[StringName], initial: Dictionary) -> BuildBoard:
	var board: BuildBoard = load(BOARD_SCENE).instantiate()
	board.router = _router
	board.tools = tools
	board.initial = initial
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	var host: Control = auto_free(Control.new())
	host.size = Vector2(1400, 1000)
	add_child(host)
	host.add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame
	return board


func test_a_hundred_pile_adds_hundreds_to_the_answer() -> void:
	var board: BuildBoard = await _board_with([DragItem.HUNDRED, DragItem.TEN, DragItem.ONE], {})
	assert_dict(board.answer()).is_equal({"tens": 0, "ones": 0, "hundreds": 0})
	InputSim.tap(_router, _center(board.source(DragItem.HUNDRED)))
	InputSim.tap(_router, _center(board.source(DragItem.TEN)))
	InputSim.tap(_router, _center(board.source(DragItem.ONE)))
	InputSim.tap(_router, _center(board.source(DragItem.ONE)))
	assert_dict(board.answer()).is_equal({"hundreds": 1, "tens": 1, "ones": 2})
	var kinds: Array[StringName] = []
	for item: DragItem in board.tray().items():
		kinds.append(item.kind)
	assert_array(kinds).contains_exactly([DragItem.HUNDRED, DragItem.TEN, DragItem.ONE, DragItem.ONE]) # always in order


func test_a_board_without_a_hundred_pile_has_no_hundreds_key() -> void:
	assert_bool(_board.answer().has("hundreds")).is_false()
	assert_bool(_board.source(DragItem.TEN) != null).is_true()


func test_the_tray_can_start_filled_for_regrouping() -> void:
	var board: BuildBoard = await _board_with([DragItem.TEN, DragItem.ONE], {"tens": 3, "ones": 13})
	assert_dict(board.answer()).is_equal({"tens": 3, "ones": 13})


func test_regrouping_by_tapping_pieces_out_and_a_bar_in() -> void:
	var board: BuildBoard = await _board_with([DragItem.TEN, DragItem.ONE], {"tens": 3, "ones": 13})
	for i: int in 10:
		var piece: DragItem = board.tray().items().back() # the last one is a gem
		InputSim.tap(_router, piece.get_global_rect().get_center())
	InputSim.tap(_router, _center(board.source(DragItem.TEN)))
	assert_dict(board.answer()).is_equal({"tens": 4, "ones": 3}) # 43 before and after: nothing was lost


func test_tapping_a_placed_piece_removes_it_and_announces_it() -> void:
	_drag_from_pile(DragItem.ONE)
	await get_tree().process_frame
	var removed: Array[StringName] = []
	_board.item_removed.connect(func(kind: StringName) -> void: removed.append(kind))
	var piece: DragItem = _board.tray().items()[0]
	InputSim.tap(_router, piece.get_global_rect().get_center())
	assert_dict(_board.answer()).is_equal({"tens": 0, "ones": 0})
	assert_array(removed).contains_exactly([DragItem.ONE])


func test_the_hundred_block_is_big_and_worth_a_hundred() -> void:
	var block: DragItem = auto_free(DragItem.make(DragItem.HUNDRED))
	add_child(block)
	assert_int(block.value()).is_equal(100)
	assert_float(block.custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()) * 2.0)


func test_a_gem_next_to_a_ten_bar_keeps_its_own_square_size() -> void:
	# Regression: a flow container used to stretch gems to the height of the ten-bars in their row.
	var board: BuildBoard = await _board_with([DragItem.TEN, DragItem.ONE], {"tens": 2, "ones": 3})
	await get_tree().process_frame
	for item: DragItem in board.tray().items():
		if item.kind == DragItem.ONE:
			assert_float(item.size.y).is_equal_approx(item.custom_minimum_size.y, 1.0)
			assert_float(item.size.y).is_equal_approx(item.size.x, 1.0)
