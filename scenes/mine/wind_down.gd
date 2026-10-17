## The wind-down (GDD section 2, step 7): when the parent's soft session limit has passed, the mine
## shows this at the next rock boundary, so the child always finishes the rock in hand. Bolt says
## it is time to head up and a short recap shows what was done today. There is never a countdown,
## and nothing is lost by stopping.
class_name WindDown
extends Control

signal head_up_requested

const DIM: Color = Color(0.06, 0.08, 0.14, 0.75)

var _recap: VBoxContainer
var _head_up_button: Button
var _lantern: LanternArt


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = DIM
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card: PanelContainer = PanelContainer.new()
	center.add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 20)
	column.custom_minimum_size.x = UI.target_size(10.0, 1.0).x
	card.add_child(column)
	var heading: Label = Label.new()
	heading.theme_type_variation = &"HeadingLabel"
	heading.text = Text.get_line(&"ui.recap.title")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	for line_id: StringName in [&"bolt.wind_down.time", &"bolt.wind_down.great"]:
		var line: Label = Label.new()
		line.text = Text.get_line(line_id)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(line)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 32)
	column.add_child(row)
	_lantern = LanternArt.new()
	_lantern.custom_minimum_size = UI.target_size(1.5, 1.8)
	row.add_child(_lantern)
	_recap = VBoxContainer.new()
	_recap.add_theme_constant_override(&"separation", 6)
	row.add_child(_recap)
	_head_up_button = Button.new()
	_head_up_button.text = Text.get_line(&"ui.mine.head_up")
	_head_up_button.theme_type_variation = &"GoButton"
	_head_up_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_head_up_button, 5.0, 1.5)
	_head_up_button.pressed.connect(head_up_requested.emit)
	column.add_child(_head_up_button)


## Shows the recap: Rewards.session_summary() plus how many skills were practised.
func show_recap(summary: Dictionary, skills_practised: int, lantern_lit: bool) -> void:
	for child: Node in _recap.get_children():
		child.queue_free()
		_recap.remove_child(child)
	for entry: Array in [[&"ui.recap.rocks", summary.get("rocks", 0)], [&"ui.recap.gems", summary.get("gem_total", 0)], [&"ui.recap.coins", summary.get("coins", 0)], [&"ui.recap.skills", skills_practised]]:
		var label: Label = Label.new()
		label.text = Text.get_line(entry[0], {"n": int(entry[1])})
		_recap.add_child(label)
	_lantern.lit = lantern_lit
	visible = true
	_head_up_button.grab_focus()


## The recap lines as shown, for tests.
func recap_lines() -> Array[String]:
	var lines: Array[String] = []
	for child: Node in _recap.get_children():
		lines.append((child as Label).text)
	return lines


func head_up_button() -> Button:
	return _head_up_button
