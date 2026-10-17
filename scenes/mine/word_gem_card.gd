## A Word Gem card: the math word, its picture and its kid-sized definition (CLAUDE.md rule 5:
## "math terms are tappable for a picture and a kid-sized definition"). Opens over the screen when
## the child taps a Word Gem in Bolt's bubble; OK (or a tap outside the card) closes it.
## Words come from the text table through Text.term_definition; the picture is drawn by VisualModel
## from the term's `visual` in curriculum/vocabulary.json. Nothing is timed and nothing is scored.
class_name WordGemCard
extends Control

signal closed

const DIM: Color = Color(0.06, 0.08, 0.14, 0.72)
const CARD_WIDTH_MULTIPLE: float = 10.0

var term_id: StringName = &""

var _term_label: Label
var _definition_label: Label
var _picture: VisualModel
var _ok_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = DIM
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(_on_dimmer_input)
	add_child(dimmer)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card: PanelContainer = PanelContainer.new()
	center.add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 20)
	column.custom_minimum_size.x = UI.target_size(CARD_WIDTH_MULTIPLE, 1.0).x
	card.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override(&"separation", 16)
	column.add_child(header)
	var gem: GemArt = GemArt.new()
	gem.gem_type = GemArt.AMETHYST
	gem.custom_minimum_size = UI.target_size(0.8, 0.8)
	header.add_child(gem)
	_term_label = Label.new()
	_term_label.theme_type_variation = &"HeadingLabel"
	header.add_child(_term_label)
	_picture = load("res://scenes/mine/visual_model.tscn").instantiate()
	_picture.compact = true
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_picture)
	_definition_label = Label.new()
	_definition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_definition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_definition_label)
	_ok_button = Button.new()
	_ok_button.text = Text.get_line(&"ui.common.ok")
	_ok_button.theme_type_variation = &"GoButton"
	_ok_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_ok_button, 3.0, 1.25)
	_ok_button.pressed.connect(close)
	column.add_child(_ok_button)


## Shows the card for a Word Gem id from curriculum/vocabulary.json. Unknown ids do nothing.
func show_term(id: StringName) -> void:
	var gem: Dictionary = Text.term_definition(id)
	if gem.is_empty():
		return
	term_id = id
	_term_label.text = gem["term"]
	_definition_label.text = gem["text"]
	_picture.show_visual(gem.get("visual", {}))
	_picture.visible = not gem.get("visual", {}).is_empty()
	visible = true
	_ok_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func term_text() -> String:
	return _term_label.text


func definition_text() -> String:
	return _definition_label.text


func picture() -> VisualModel:
	return _picture


func ok_button() -> Button:
	return _ok_button


func _on_dimmer_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		close()
