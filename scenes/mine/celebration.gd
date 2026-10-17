## The celebration card shown between rocks when something was earned by learning (P1-S08-06):
## a newly mastered skill (the amethyst), a museum mineral found, or today's lantern lit.
## It celebrates the work, never speed or luck, and waits for a tap ("Keep digging"); it does not
## time out on its own.
class_name Celebration
extends Control

signal closed

const DIM: Color = Color(0.06, 0.08, 0.14, 0.6)
const POP_SECONDS: float = 0.35

var speed_scale: float = 1.0

var _lines: VBoxContainer
var _art_row: HBoxContainer
var _particles: CPUParticles2D
var _continue_button: Button
var _line_ids: Array[StringName] = []


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
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 24)
	column.custom_minimum_size.x = UI.target_size(9.0, 1.0).x
	card.add_child(column)
	_art_row = HBoxContainer.new()
	_art_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_art_row.add_theme_constant_override(&"separation", 32)
	column.add_child(_art_row)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override(&"separation", 8)
	column.add_child(_lines)
	_continue_button = Button.new()
	_continue_button.text = Text.get_line(&"ui.pause.resume")
	_continue_button.theme_type_variation = &"GoButton"
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_continue_button, 4.0, 1.5)
	_continue_button.pressed.connect(close)
	column.add_child(_continue_button)
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = 40
	_particles.lifetime = 0.9
	_particles.explosiveness = 0.9
	_particles.spread = 180.0
	_particles.gravity = Vector2(0, 500)
	_particles.initial_velocity_min = 220.0
	_particles.initial_velocity_max = 480.0
	_particles.scale_amount_min = 5.0
	_particles.scale_amount_max = 11.0
	add_child(_particles)


## Shows the card. `items` is a list of {line_id: StringName, gem: StringName} or
## {line_id, lantern: true}: one line and one picture each.
func celebrate(items: Array[Dictionary]) -> void:
	for child: Node in _lines.get_children() + _art_row.get_children():
		child.queue_free()
		child.get_parent().remove_child(child)
	_line_ids.clear()
	for item: Dictionary in items:
		var label: Label = Label.new()
		label.text = Text.get_line(item["line_id"])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lines.add_child(label)
		_line_ids.append(item["line_id"])
		var art: Control
		if item.get("lantern", false):
			var lantern: LanternArt = LanternArt.new()
			art = lantern
		else:
			var gem: GemArt = GemArt.new()
			gem.gem_type = item.get("gem", GemArt.AMETHYST)
			art = gem
		art.custom_minimum_size = UI.target_size(1.6, 1.6)
		_art_row.add_child(art)
	visible = true
	_continue_button.grab_focus()
	await get_tree().process_frame
	if not is_inside_tree():
		return # the mine was left during the wait; there is nothing left to animate
	_particles.position = size * 0.5
	_particles.color = GemArt.color_for(items[0].get("gem", GemArt.AMETHYST)) if not items.is_empty() else Color.WHITE
	_particles.restart()
	_particles.emitting = true
	for art: Node in _art_row.get_children():
		var control: Control = art
		control.pivot_offset = control.size * 0.5
		control.scale = Vector2(0.2, 0.2)
		var tween: Tween = create_tween()
		tween.set_speed_scale(speed_scale)
		tween.tween_property(control, "scale", Vector2(1.15, 1.15), POP_SECONDS * 0.7).set_trans(Tween.TRANS_BACK)
		tween.tween_property(control, "scale", Vector2.ONE, POP_SECONDS * 0.3)
		if control is LanternArt:
			(control as LanternArt).light_up(speed_scale)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func line_ids() -> Array[StringName]:
	return _line_ids.duplicate()


func continue_button() -> Button:
	return _continue_button
