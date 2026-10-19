## The pattern wall (Zone 9, Sprint 40; meta.pattern_wall = {terms, tiles}): a row of crystal tiles with
## one gap, and the crystal tiles that might fill it. It is the Phase 2 drag-tile framework (TileBoard)
## with one slot set in the row where the gap is: drag a tile into the gap (or tap a tile to drop it in),
## then Done. Finger, stylus and mouse behave the same (InputRouter pointer signals, like every tile
## board). The wall never says whether the number is right; the host decides (`number_chosen`).
##
## Used for the sequence, Fibonacci and figurate rocks whose problems carry meta.pattern_wall.
class_name PatternWall
extends TileBoard

## Done was pressed with a tile in the gap: the tile's number.
signal number_chosen(value: int)

## The wall's crystal tint behind the tiles (electric crystal light, no flame).
const WALL_TINT: Color = Color(0.85, 0.8, 1.0, 1.0)


## The row (null at the gap) and the tiles to drag. Call before the wall enters the tree.
func setup(terms: Array, tile_values: Array) -> void:
	sequence = terms.duplicate()
	tiles = tile_values.duplicate()
	slot_count = 1
	ordered = true


func _ready() -> void:
	super()
	add_theme_constant_override(&"separation", 12) # tighter than a plain tile board, to fit a phone
	modulate = WALL_TINT
	var how: Label = Label.new()
	how.name = "How"
	how.text = Text.get_line(&"z9.wall.how")
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(how)
	move_child(how, 0)
	submitted.connect(_on_submitted)


## Drops `value` into the gap and presses Done (tests and the keyboard; the child drags or taps).
func choose(value: int) -> bool:
	if tile_face(value) == null:
		return false
	put(value, 0)
	submit()
	return true


func _on_submitted(answer: Array) -> void:
	if not answer.is_empty() and answer[0] != null:
		number_chosen.emit(int(answer[0]))
