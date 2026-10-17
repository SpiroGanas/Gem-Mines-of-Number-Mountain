## Family reward points (Sprint 19, P2-S19-05), in the parent area: the points the child has earned
## (MotivationRules: a first mastery, a finished session; never speed), the parent's goals and the
## claim button. Goal text is typed by a grown-up, so a LineEdit is allowed here (parent area only,
## CLAUDE.md rule 6). Claiming spends the goal's points; it is reached only from the dashboard,
## which is behind the parent gate.
class_name FamilyRewardsScreen
extends ShellScreen

const POINTS_STEP: int = 10
const MIN_POINTS: int = 10
const MAX_POINTS: int = 500

var _content: VBoxContainer
var _text_field: LineEdit
var _new_points: int = 50
var _points_label: Label


func _ready() -> void:
	super()
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 16)
	scroll.add_child(_content)
	refresh()


func refresh() -> void:
	for child: Node in _content.get_children():
		child.queue_free()
		_content.remove_child(child)
	var header: HBoxContainer = HBoxContainer.new()
	_content.add_child(header)
	var back: Button = _button(&"ui.common.back", func() -> void: request_screen.emit(&"dashboard", {}))
	back.name = "BackButton"
	header.add_child(back)
	var title: Label = _label(&"family.screen.title")
	title.theme_type_variation = &"HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var points: Label = _label(&"family.screen.points", {"n": Rewards.family_points()})
	points.name = "PointsLabel"
	_content.add_child(points)
	_content.add_child(_label(&"family.screen.how"))
	var goals: Array = Rewards.family_goals()
	if goals.is_empty():
		_content.add_child(_label(&"family.screen.none"))
	for index: int in goals.size():
		_content.add_child(_goal_row(index, goals[index]))
	var add_row: HBoxContainer = HBoxContainer.new()
	add_row.add_theme_constant_override(&"separation", 16)
	_content.add_child(add_row)
	add_row.add_child(_label(&"family.screen.goal_text"))
	_text_field = LineEdit.new() # allowed: the parent area only (CLAUDE.md rule 6)
	_text_field.name = "GoalField"
	_text_field.max_length = 60
	_text_field.custom_minimum_size = UI.target_size(6.0, 1.0)
	add_row.add_child(_text_field)
	var less: Button = _button(&"ui.common.less", change_new_points.bind(-POINTS_STEP))
	less.name = "LessButton"
	add_row.add_child(less)
	_points_label = _label(&"family.screen.goal_points", {"n": _new_points})
	add_row.add_child(_points_label)
	var more: Button = _button(&"ui.common.more", change_new_points.bind(POINTS_STEP))
	more.name = "MoreButton"
	add_row.add_child(more)
	var add: Button = _button(&"family.screen.add", func() -> void: add_goal(_text_field.text))
	add.name = "AddButton"
	add_row.add_child(add)


func change_new_points(delta: int) -> void:
	_new_points = clampi(_new_points + delta, MIN_POINTS, MAX_POINTS)
	_points_label.text = Text.get_line(&"family.screen.goal_points", {"n": _new_points})


func add_goal(text: String) -> bool:
	var added: bool = Rewards.add_family_goal(text, _new_points)
	if added:
		refresh()
	return added


func claim(index: int) -> bool:
	var claimed: bool = Rewards.claim_family_goal(index)
	refresh()
	return claimed


func remove(index: int) -> void:
	Rewards.remove_family_goal(index)
	refresh()


func _goal_row(index: int, goal: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Goal%d" % index
	row.add_theme_constant_override(&"separation", 16)
	var words: Label = Label.new()
	words.text = Text.get_line(&"family.screen.goal_row", {"text": str(goal.get("text", "")), "n": int(goal.get("points_needed", 0))})
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(words)
	var claim_button: Button
	var missing: int = int(goal.get("points_needed", 0)) - Rewards.family_points()
	if bool(goal.get("claimed", false)):
		claim_button = _button(&"family.screen.claimed", func() -> void: pass)
		claim_button.disabled = true
	elif missing > 0:
		claim_button = _button(&"family.screen.not_enough", func() -> void: pass, {"n": missing})
		claim_button.disabled = true
	else:
		claim_button = _button(&"family.screen.claim", claim.bind(index))
	claim_button.name = "ClaimButton"
	row.add_child(claim_button)
	var remove_button: Button = _button(&"family.screen.remove", remove.bind(index))
	remove_button.name = "RemoveButton"
	row.add_child(remove_button)
	return row


func _label(line_id: StringName, params: Dictionary = {}) -> Label:
	var label: Label = Label.new()
	label.text = Text.get_line(line_id, params)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(line_id: StringName, action: Callable, params: Dictionary = {}) -> Button:
	var button: Button = Button.new()
	button.text = Text.get_line(line_id, params)
	UI.make_touch_target(button, 3.0, 1.0)
	button.pressed.connect(action)
	return button
