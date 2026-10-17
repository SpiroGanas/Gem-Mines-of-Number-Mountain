# Mirrors scenes/mine/visual_model.gd: the geometry is pure, so it is tested without drawing.
class_name VisualModelTest
extends GdUnitTestSuite

const BOX: Rect2 = Rect2(0, 0, 500, 300)


func _pile(hundreds: int, tens: int, ones: int) -> Dictionary:
	return {"hundreds": hundreds, "tens": tens, "ones": ones}


func _count(pieces: Array[Dictionary], kind: StringName) -> int:
	var total: int = 0
	for piece: Dictionary in pieces:
		if piece["kind"] == kind:
			total += 1
	return total


# --- Pile layout -------------------------------------------------------------------------


func test_a_pile_places_exactly_the_pieces_it_holds() -> void:
	var pieces: Array[Dictionary] = VisualModel.pile_layout(_pile(1, 3, 14), BOX)
	assert_int(_count(pieces, &"hundred")).is_equal(1)
	assert_int(_count(pieces, &"ten")).is_equal(3)
	assert_int(_count(pieces, &"one")).is_equal(14)


func test_every_piece_stays_inside_its_box_for_every_pile_we_can_generate() -> void:
	for hundreds: int in 2:
		for tens: int in range(0, 10):
			for ones: int in range(0, 20):
				if hundreds == 1 and tens > 2:
					continue
				var pieces: Array[Dictionary] = VisualModel.pile_layout(_pile(hundreds, tens, ones), BOX)
				for piece: Dictionary in pieces:
					assert_bool(BOX.encloses(piece["rect"])).override_failure_message("%d/%d/%d spills: %s" % [hundreds, tens, ones, piece["rect"]]).is_true()


func test_pieces_never_overlap() -> void:
	var pieces: Array[Dictionary] = VisualModel.pile_layout(_pile(0, 9, 19), BOX)
	for a: int in pieces.size():
		for b: int in range(a + 1, pieces.size()):
			assert_bool((pieces[a]["rect"] as Rect2).intersects(pieces[b]["rect"])).override_failure_message("pieces %d and %d overlap" % [a, b]).is_false()


func test_a_small_box_shrinks_the_pieces_instead_of_spilling() -> void:
	var tiny: Rect2 = Rect2(0, 0, 160, 110)
	var big: Array[Dictionary] = VisualModel.pile_layout(_pile(0, 5, 9), BOX)
	var small: Array[Dictionary] = VisualModel.pile_layout(_pile(0, 5, 9), tiny)
	assert_float((small[0]["rect"] as Rect2).size.x).is_less((big[0]["rect"] as Rect2).size.x)
	for piece: Dictionary in small:
		assert_bool(tiny.encloses(piece["rect"])).is_true()


func test_an_empty_pile_has_no_pieces() -> void:
	assert_array(VisualModel.pile_layout(_pile(0, 0, 0), BOX)).is_empty()


func test_ones_sit_in_rows_of_five() -> void:
	var pieces: Array[Dictionary] = VisualModel.pile_layout(_pile(0, 0, 12), BOX)
	var rows: Dictionary = {}
	for piece: Dictionary in pieces:
		rows[snappedf((piece["rect"] as Rect2).position.y, 0.01)] = true
	assert_int(rows.size()).is_equal(3) # 5 + 5 + 2


func test_piles_sit_side_by_side_without_overlapping() -> void:
	var area: Rect2 = Rect2(0, 0, 900, 300)
	var first: Rect2 = VisualModel.pile_box(area, 0, 2)
	var second: Rect2 = VisualModel.pile_box(area, 1, 2)
	assert_bool(first.intersects(second)).is_false()
	assert_bool(area.encloses(first) and area.encloses(second)).is_true()
	assert_float(first.size.x).is_equal_approx(second.size.x, 0.001)


# --- Ten frames ----------------------------------------------------------------------------


func test_a_ten_frame_has_ten_cells_per_frame_in_two_rows_of_five() -> void:
	var cells: Array[Rect2] = VisualModel.frame_cells(2, BOX)
	assert_int(cells.size()).is_equal(20)
	for cell: Rect2 in cells:
		assert_bool(BOX.encloses(cell)).is_true()
	assert_float(cells[0].position.y).is_equal_approx(cells[4].position.y, 0.001) # first row
	assert_float(cells[5].position.y).is_greater(cells[0].position.y) # second row
	assert_float(cells[10].position.x).is_greater(cells[9].position.x) # the second frame is to the right


# --- Number line ---------------------------------------------------------------------------


func test_line_x_maps_the_ends_to_the_margins() -> void:
	assert_float(VisualModel.line_x(30, 30, 60, 600, 40)).is_equal_approx(40.0, 0.001)
	assert_float(VisualModel.line_x(60, 30, 60, 600, 40)).is_equal_approx(560.0, 0.001)
	assert_float(VisualModel.line_x(45, 30, 60, 600, 40)).is_equal_approx(300.0, 0.001)


func test_minor_ticks_get_sparser_on_longer_lines() -> void:
	assert_int(VisualModel.minor_tick_step(0, 30)).is_equal(1)
	assert_int(VisualModel.minor_tick_step(0, 40)).is_equal(1)
	assert_int(VisualModel.minor_tick_step(0, 100)).is_equal(5)
	assert_int(VisualModel.minor_tick_step(0, 120)).is_equal(10)


# --- The control itself --------------------------------------------------------------------


func _model(visual: Dictionary, tappable: bool = false) -> VisualModel:
	var model: VisualModel = load("res://scenes/mine/visual_model.tscn").instantiate()
	add_child(model)
	auto_free(model)
	model.size = Vector2(900, 300)
	model.show_visual(visual, tappable)
	return model


func test_it_reports_the_visual_it_shows_and_clears() -> void:
	var model: VisualModel = _model({"type": "ten_frame", "count": 7, "frames": 1})
	assert_str(model.visual_type()).is_equal("ten_frame")
	model.show_visual({})
	assert_str(model.visual_type()).is_empty()


func test_every_visual_type_draws_without_errors() -> void:
	for visual: Dictionary in [
		{"type": "gem_piles", "piles": [_pile(1, 2, 3), _pile(0, 0, 9)]},
		{"type": "ten_frame", "count": 13, "frames": 2},
		{"type": "number_line", "min": 30, "max": 60, "labeled_every": 10, "markers": [47], "blanks": []},
		{"type": "number_line", "min": 60, "max": 64, "labeled_every": 1, "markers": [], "blanks": [61, 63]},
		{"type": "gem_piles", "piles": [_pile(0, 4, 13)], "group_ones": 10},
		{"type": "gem_piles", "piles": [_pile(0, 4, 3)], "group_tens": 1},
	]:
		var model: VisualModel = _model(visual)
		await get_tree().process_frame # lets _draw run
		assert_str(model.visual_type()).is_equal(visual["type"])


func test_tappable_piles_get_one_big_button_each_that_reports_its_index() -> void:
	var model: VisualModel = _model({"type": "gem_piles", "piles": [_pile(0, 0, 5), _pile(0, 0, 9)]}, true)
	var buttons: Array[Button] = model.pile_buttons()
	assert_int(buttons.size()).is_equal(2)
	var tapped: Array[int] = []
	model.pile_tapped.connect(func(index: int) -> void: tapped.append(index))
	buttons[1].pressed.emit()
	buttons[0].pressed.emit()
	assert_array(tapped).contains_exactly([1, 0])
	for button: Button in buttons:
		assert_float(button.size.x).is_greater_equal(float(UI.min_target_px()))
		assert_float(button.size.y).is_greater_equal(float(UI.min_target_px()))
	assert_bool(buttons[0].get_global_rect().intersects(buttons[1].get_global_rect())).is_false()


func test_untappable_visuals_have_no_buttons() -> void:
	assert_array(_model({"type": "gem_piles", "piles": [_pile(0, 0, 5)]}).pile_buttons()).is_empty()
	assert_array(_model({"type": "ten_frame", "count": 3, "frames": 1}, true).pile_buttons()).is_empty()


func test_showing_a_new_visual_replaces_old_buttons() -> void:
	var model: VisualModel = _model({"type": "gem_piles", "piles": [_pile(0, 0, 5), _pile(0, 0, 9)]}, true)
	model.show_visual({"type": "gem_piles", "piles": [_pile(0, 0, 4), _pile(0, 0, 2)]}, true)
	await get_tree().process_frame
	assert_int(model.pile_buttons().size()).is_equal(2)
	assert_int(model.get_child_count()).is_equal(2)


func test_a_pile_is_centred_in_its_box() -> void:
	var pieces: Array[Dictionary] = VisualModel.pile_layout(_pile(0, 2, 3), BOX)
	var offset: Vector2 = VisualModel.centering_offset(pieces, BOX)
	var bounds: Rect2 = pieces[0]["rect"]
	for piece: Dictionary in pieces:
		bounds = bounds.merge(piece["rect"])
	assert_vector(Rect2(bounds.position + offset, bounds.size).get_center()).is_equal_approx(BOX.get_center(), Vector2(0.01, 0.01))
	for piece: Dictionary in pieces:
		assert_bool(BOX.encloses(Rect2(piece["rect"].position + offset, piece["rect"].size))).is_true() # still inside after centring
	assert_vector(VisualModel.centering_offset([] as Array[Dictionary], BOX)).is_equal(Vector2.ZERO)


func test_each_kind_of_picture_is_sized_to_its_content() -> void:
	var line: VisualModel = _model({"type": "number_line", "min": 0, "max": 30, "labeled_every": 10, "markers": [], "blanks": []})
	var piles: VisualModel = _model({"type": "gem_piles", "piles": [_pile(0, 0, 5)]})
	assert_float(piles.custom_minimum_size.y).is_greater(line.custom_minimum_size.y)
