## The parent dashboard v2's visual skill map (Sprint 21, P2-S21-01): one row per zone, one node per
## skill, in curriculum order. A node's state comes from Adaptive.skill_states() (the map never works
## mastery out itself) and is shown by shape as well as color, so color is never the only clue:
##   mastered      a filled green disc with a check
##   practicing    a half-filled blue disc
##   needs review  an amber ring with a bar (a missed review or the fourth hint)
##   not started   a plain grey ring
## Tapping a node names the skill and its state below the map. Grown-ups only.
class_name SkillMap
extends VBoxContainer

## A node was tapped.
signal skill_selected(skill_id: StringName)

const COLORS: Dictionary = {
	&"mastered": Color("#7BD88F"), &"practicing": Color("#8FD3FF"),
	&"needs_review": Color("#FFB454"), &"not_started": Color("#8A96B3"),
}

var _nodes: Dictionary[StringName, Button] = {}
var _detail: Label


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	refresh()


## Rebuilds every row from Adaptive's skill states.
func refresh() -> void:
	for child: Node in get_children():
		child.queue_free()
		remove_child(child)
	_nodes.clear()
	var states: Dictionary = Adaptive.skill_states()
	var rows: Dictionary = {}
	for id: StringName in states:
		var zone: int = Adaptive.catalog().skill(id).zone
		if not rows.has(zone):
			rows[zone] = _make_row(zone)
		var node: Button = _make_node(id, states[id])
		rows[zone].get_child(1).add_child(node)
	var legend: HFlowContainer = HFlowContainer.new()
	legend.add_theme_constant_override(&"h_separation", 24)
	add_child(legend)
	for state: StringName in COLORS:
		var key: HBoxContainer = HBoxContainer.new()
		var dot: _StateDot = _StateDot.new()
		dot.state = state
		dot.custom_minimum_size = Vector2(28, 28)
		key.add_child(dot)
		var words: Label = Label.new()
		words.text = Text.get_line(StringName("parent.map.%s" % state))
		key.add_child(words)
		legend.add_child(key)
	_detail = Label.new()
	_detail.name = "Detail"
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_detail)


func node_for(skill_id: StringName) -> Button:
	return _nodes.get(skill_id)


## The state a node shows (for tests).
func shown_state(skill_id: StringName) -> StringName:
	var node: Button = _nodes.get(skill_id)
	return (node.get_child(0) as _StateDot).state if node != null else &""


func detail_text() -> String:
	return _detail.text


func _make_row(zone: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Zone%d" % zone
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)
	var name_label: Label = Label.new()
	name_label.text = Text.get_line(ZoneBanner.line_for(zone))
	name_label.custom_minimum_size.x = UI.target_size(3.2, 1.0).x
	row.add_child(name_label)
	var flow: HFlowContainer = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override(&"h_separation", 4)
	flow.add_theme_constant_override(&"v_separation", 4)
	row.add_child(flow)
	return row


func _make_node(id: StringName, state: StringName) -> Button:
	var node: Button = Button.new()
	node.name = String(id).replace(".", "_")
	node.flat = true
	UI.make_touch_target(node, 1.0, 1.0)
	var dot: _StateDot = _StateDot.new()
	dot.state = state
	dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.add_child(dot)
	node.pressed.connect(_on_node_pressed.bind(id, state))
	_nodes[id] = node
	return node


func _on_node_pressed(id: StringName, state: StringName) -> void:
	var skill: Skill = Adaptive.catalog().skill(id)
	_detail.text = Text.get_line(&"parent.map.detail", {"skill": skill.name, "state": Text.get_line(StringName("parent.map.%s" % state))})
	skill_selected.emit(id)


## One state's symbol: shape and color together.
class _StateDot extends Control:
	var state: StringName = &"not_started":
		set(value):
			state = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.3
		var color: Color = SkillMap.COLORS.get(state, Color.GRAY)
		match state:
			&"mastered":
				draw_circle(center, r, color)
				draw_polyline(PackedVector2Array([center + Vector2(-r * 0.5, 0), center + Vector2(-r * 0.1, r * 0.4), center + Vector2(r * 0.55, -r * 0.4)]), Color("#1F2945"), maxf(r * 0.2, 2.0))
			&"practicing":
				draw_arc(center, r, 0.0, TAU, 24, color, maxf(r * 0.18, 2.0))
				draw_colored_polygon(_half_disc(center, r), color)
			&"needs_review":
				draw_arc(center, r, 0.0, TAU, 24, color, maxf(r * 0.3, 3.0))
				draw_line(center + Vector2(0, -r * 0.45), center + Vector2(0, r * 0.15), color, maxf(r * 0.25, 2.0))
				draw_circle(center + Vector2(0, r * 0.45), r * 0.12, color)
			_:
				draw_arc(center, r, 0.0, TAU, 24, color, maxf(r * 0.12, 1.5))

	static func _half_disc(center: Vector2, r: float) -> PackedVector2Array:
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in 13:
			var angle: float = PI * float(i) / 12.0
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		return points
