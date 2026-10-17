## Bolt, the mining robot, and his speech bubble. Gray-box: a drawn robot and a text bubble.
## Every word comes from the text table through say(). Tappable Word Gem terms arrive in Sprint 7.
class_name Bolt
extends HBoxContainer

const BODY: Color = Color("#7FA3C7")
const HEAD: Color = Color("#A9C4E0")
const OUTLINE: Color = Color("#1F2945")
const LAMP: Color = Color("#FFD166")
const BUBBLE_WIDTH_MULTIPLE: float = 7.0
const NOTE_COLOR: Color = Color("#FFD166")

var _line_id: StringName = &""
var _note_id: StringName = &""
var _label: Label
var _note_label: Label


func _ready() -> void:
	add_theme_constant_override(&"separation", 24)
	var figure: Control = _BoltArt.new()
	UI.make_touch_target(figure, 1.8, 2.2)
	add_child(figure)
	var bubble: PanelContainer = PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(bubble)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	bubble.add_child(column)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.make_touch_target(_label, BUBBLE_WIDTH_MULTIPLE, 1.0)
	column.add_child(_label)
	# The note sits under the main line, so feedback never hides the problem.
	_note_label = Label.new()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.add_theme_color_override(&"font_color", NOTE_COLOR)
	_note_label.visible = false
	column.add_child(_note_label)


## Bolt says a line from the text table. `params` fills its {placeholders}. Saying a new main
## line clears the note unless `keep_note` is true (the praise after a rock stays up while the
## child reads "Pick a rock to crack.").
func say(line_id: StringName, params: Dictionary = {}, keep_note: bool = false) -> void:
	_line_id = line_id
	_label.text = Text.get_line(line_id, params)
	if not keep_note:
		clear_note()


## Adds a feedback line under the main one ("Not quite. Let's look again."). The main line,
## usually the problem, stays on screen.
func note(line_id: StringName, params: Dictionary = {}) -> void:
	_note_id = line_id
	_note_label.text = Text.get_line(line_id, params)
	_note_label.visible = true


func clear_note() -> void:
	_note_id = &""
	_note_label.text = ""
	_note_label.visible = false


func current_note_id() -> StringName:
	return _note_id


func note_text() -> String:
	return _note_label.text if _note_label.visible else ""


func current_line_id() -> StringName:
	return _line_id


func spoken_text() -> String:
	return _label.text


class _BoltArt extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s: Vector2 = size
		draw_rect(Rect2(Vector2(0.2, 0.42) * s, Vector2(0.6, 0.5) * s), Bolt.BODY)
		draw_rect(Rect2(Vector2(0.2, 0.42) * s, Vector2(0.6, 0.5) * s), Bolt.OUTLINE, false, 4.0)
		draw_rect(Rect2(Vector2(0.25, 0.1) * s, Vector2(0.5, 0.34) * s), Bolt.HEAD)
		draw_rect(Rect2(Vector2(0.25, 0.1) * s, Vector2(0.5, 0.34) * s), Bolt.OUTLINE, false, 4.0)
		draw_circle(Vector2(0.4, 0.26) * s, s.x * 0.05, Bolt.OUTLINE) # eyes
		draw_circle(Vector2(0.6, 0.26) * s, s.x * 0.05, Bolt.OUTLINE)
		draw_circle(Vector2(0.5, 0.06) * s, s.x * 0.09, Bolt.LAMP) # headlamp (electric)
