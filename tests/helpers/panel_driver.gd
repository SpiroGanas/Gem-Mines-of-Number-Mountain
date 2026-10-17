## Drives an AnswerPanel's widget the way a child would, so tests can answer any problem.
class_name PanelDriver
extends RefCounted


## Gives `target` through whichever widget the panel built. Returns false if it could not
## (for example a value that is not among the answer buttons).
static func give(panel: AnswerPanel, target: Variant) -> bool:
	match panel.input_kind:
		AnswerPanel.InputKind.TAP_PILE:
			panel.visual_model().pile_buttons()[int(target)].pressed.emit()
			return true
		AnswerPanel.InputKind.CHOICES:
			var values: Array = panel.choices().values_in_order()
			for index: int in values.size():
				if Problem.same(values[index], target):
					panel.choices().button(index).pressed.emit()
					return true
			return false
		AnswerPanel.InputKind.NUMBER_PAD:
			panel.number_pad().clear()
			for digit: String in str(int(target)):
				panel.number_pad().press_digit(int(digit))
			panel.number_pad().submit()
			return true
		AnswerPanel.InputKind.TILES:
			var board: TileBoard = panel.tile_board()
			board.clear()
			for index: int in target.size():
				if board.tile_face(target[index]) == null:
					return false
				board.put(target[index], index)
			board.submit()
			return true
		AnswerPanel.InputKind.ARRAY:
			panel.array_builder().set_array(int(target["rows"]), int(target["cols"]))
			panel.array_builder().submit()
			return true
		AnswerPanel.InputKind.BOARD:
			var tray: DragTarget = panel.board().tray()
			tray.clear()
			for kind: StringName in [DragItem.HUNDRED, DragItem.TEN, DragItem.ONE]:
				var key: String = {DragItem.HUNDRED: "hundreds", DragItem.TEN: "tens", DragItem.ONE: "ones"}[kind]
				for i: int in int(target.get(key, 0)):
					tray.add_item(DragItem.make(kind))
			panel.board().submit()
			return true
	return false


## A value the widget can give that is certainly wrong for `problem`.
static func wrong_value(problem: Problem) -> Variant:
	if not problem.distractors.is_empty():
		return problem.distractors[0]["value"]
	if problem.answer is int:
		return problem.answer + 1
	return problem.answer
