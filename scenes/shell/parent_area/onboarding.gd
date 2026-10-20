## Parent onboarding (Phase 3, plan section 3.7, P3-S23-07): the first time the game opens on a new
## device, a grown-up sets it up in three screens, each one picture and two sentences:
##   1. The gate: what the grown-up gate is, and passing it once (GatePanel). A child alone cannot get
##      past this screen, so a child never makes or changes a profile.
##   2. The first child: a nickname (LineEdit: allowed here, the parent area; CLAUDE.md rule 6), one of
##      the eight code-drawn avatars and the school grade (generic placement, Placement.seed_from_grade).
##   3. The session limit: the soft limit after which the mine winds down (no countdown is shown).
## "Start" makes the profile (Profiles.setup_first), marks the device as set up and hands the child to
## Bolt's first run, which skips its name step because the child has a name now.
## Parent-facing words only (lines with context parent_*), so there is no reading for the child here.
class_name OnboardingScreen
extends ShellScreen

enum Step { GATE, PROFILE, SESSION }

const SESSION_STEP_MINUTES: int = 5
const MIN_SESSION_MINUTES: int = 5
const MAX_SESSION_MINUTES: int = 60

var step: Step = Step.GATE
var nickname: String = ""
var avatar_id: StringName = Profile.DEFAULT_AVATAR
var grade: int = Profile.DEFAULT_GRADE
var session_minutes: int = Profile.DEFAULT_SESSION_MINUTES

var _picture_host: Control
var _title: Label
var _body: Label
var _controls: VBoxContainer
var _buttons: HBoxContainer
var _gate: GatePanel
var _nickname_field: LineEdit
var _next_button: Button
var _minutes_label: Label
var _avatar_picture: AvatarArt


func _ready() -> void:
	super()
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 48)
	add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 48)
	scroll.add_child(row)
	_picture_host = CenterContainer.new()
	_picture_host.custom_minimum_size = UI.target_size(4.0, 4.0)
	row.add_child(_picture_host)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 24)
	row.add_child(column)
	_title = Label.new()
	_title.name = "StepTitle"
	_title.theme_type_variation = &"HeadingLabel"
	column.add_child(_title)
	_body = Label.new()
	_body.name = "StepBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_body)
	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override(&"separation", 20)
	column.add_child(_controls)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", 24)
	column.add_child(_buttons)
	show_step(Step.GATE)


func gate_panel() -> GatePanel:
	return _gate


func nickname_field() -> LineEdit:
	return _nickname_field


## The big button that moves on (null on the gate step: passing the gate moves on).
func next_button() -> Button:
	return _next_button


func avatar_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in _controls.find_children("Avatar_*", "Button", true, false):
		found.append(node)
	return found


func grade_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in _controls.find_children("Grade_*", "Button", true, false):
		found.append(node)
	return found


func show_step(next: Step) -> void:
	step = next
	for host: Node in [_picture_host, _controls, _buttons]:
		for child: Node in host.get_children():
			host.remove_child(child)
			child.queue_free()
	_gate = null
	_nickname_field = null
	_next_button = null
	match step:
		Step.GATE:
			_picture(&"grownups")
			_title.text = Text.get_line(&"parent.onboard.gate_title")
			_body.text = Text.get_line(&"parent.onboard.gate_body")
			_gate = GatePanel.new()
			_gate.name = "GatePanel"
			_gate.passed.connect(show_step.bind(Step.PROFILE))
			_controls.add_child(_gate)
		Step.PROFILE:
			_avatar_picture = AvatarArt.new()
			_avatar_picture.avatar_id = avatar_id
			_avatar_picture.custom_minimum_size = UI.target_size(3.5, 3.5)
			_picture_host.add_child(_avatar_picture)
			_title.text = Text.get_line(&"parent.onboard.profile_title")
			_body.text = Text.get_line(&"parent.onboard.profile_body")
			_add_profile_controls()
			_add_button("BackButton", &"ui.common.back", show_step.bind(Step.GATE))
			_next_button = _add_button("NextButton", &"ui.common.next", func() -> void: show_step(Step.SESSION))
			_refresh_next()
		Step.SESSION:
			_picture(&"settings")
			_title.text = Text.get_line(&"parent.onboard.session_title")
			_body.text = Text.get_line(&"parent.onboard.session_body")
			var length_row: HBoxContainer = HBoxContainer.new()
			length_row.add_theme_constant_override(&"separation", 16)
			_controls.add_child(length_row)
			length_row.add_child(_small_button("LessButton", &"ui.common.less", change_minutes.bind(-SESSION_STEP_MINUTES)))
			_minutes_label = Label.new()
			_minutes_label.name = "MinutesLabel"
			length_row.add_child(_minutes_label)
			length_row.add_child(_small_button("MoreButton", &"ui.common.more", change_minutes.bind(SESSION_STEP_MINUTES)))
			_refresh_minutes()
			_add_button("BackButton", &"ui.common.back", show_step.bind(Step.PROFILE))
			_next_button = _add_button("StartButton", &"parent.onboard.start", finish)
			_next_button.theme_type_variation = &"GoButton"


func set_nickname(text: String) -> void:
	nickname = Profile.clean_nickname(text)
	if _nickname_field != null and _nickname_field.text != text:
		_nickname_field.text = text
	_refresh_next()


func choose_avatar(id: StringName) -> void:
	if not Profile.is_valid_avatar(id):
		return
	avatar_id = id
	if _avatar_picture != null:
		_avatar_picture.avatar_id = id
	for button: Button in avatar_buttons():
		button.set_pressed_no_signal(button.name == "Avatar_%s" % id)


func choose_grade(value: int) -> void:
	grade = Profile.clamp_grade(value)
	for button: Button in grade_buttons():
		button.set_pressed_no_signal(button.name == "Grade_%d" % grade)


func change_minutes(delta: int) -> void:
	session_minutes = clampi(session_minutes + delta, MIN_SESSION_MINUTES, MAX_SESSION_MINUTES)
	_refresh_minutes()


## "Start": the first child is made, the device is set up, and Bolt says hello.
func finish() -> void:
	if nickname == "":
		show_step(Step.PROFILE)
		return
	if Profiles.setup_first(nickname, avatar_id, grade, session_minutes) == null:
		return
	Profiles.finish_onboarding()
	request_screen.emit(&"first_run", {})


func _add_profile_controls() -> void:
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 16)
	_controls.add_child(name_row)
	name_row.add_child(_label(&"parent.dash.nickname"))
	_nickname_field = LineEdit.new() # allowed here: the parent area only (CLAUDE.md rule 6)
	_nickname_field.name = "NicknameField"
	_nickname_field.max_length = Profile.NICKNAME_MAX_LENGTH
	_nickname_field.text = nickname
	_nickname_field.custom_minimum_size = UI.target_size(5.0, 1.0)
	_nickname_field.text_changed.connect(set_nickname)
	name_row.add_child(_nickname_field)
	_controls.add_child(_label(&"parent.onboard.avatar"))
	var avatars: GridContainer = GridContainer.new()
	avatars.columns = 8
	avatars.add_theme_constant_override(&"h_separation", 12)
	_controls.add_child(avatars)
	for id: StringName in Profile.AVATARS:
		avatars.add_child(avatar_button(id, choose_avatar.bind(id)))
	_controls.add_child(_label(&"parent.onboard.grade"))
	var grades: HBoxContainer = HBoxContainer.new()
	grades.add_theme_constant_override(&"separation", 12)
	_controls.add_child(grades)
	for value: int in range(Profile.MIN_GRADE, Profile.MAX_GRADE + 1):
		var button: Button = Button.new()
		button.name = "Grade_%d" % value
		button.toggle_mode = true
		button.text = grade_text(value)
		UI.make_touch_target(button, 1.2, 1.0)
		button.pressed.connect(choose_grade.bind(value))
		grades.add_child(button)
	choose_avatar(avatar_id)
	choose_grade(grade)


## One avatar choice: a toggle button with the picture on it (shared with the profiles page).
static func avatar_button(id: StringName, action: Callable) -> Button:
	var button: Button = Button.new()
	button.name = "Avatar_%s" % id
	button.toggle_mode = true
	UI.make_touch_target(button, 1.3, 1.3)
	var picture: AvatarArt = AvatarArt.new()
	picture.avatar_id = id
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	button.add_child(picture)
	button.pressed.connect(action)
	return button


## "K" for kindergarten, else the grade number (parent-facing lines).
static func grade_text(value: int) -> String:
	return Text.get_line(&"parent.onboard.grade_k") if value == 0 else Text.get_line(&"parent.onboard.grade_n", {"n": value})


func _refresh_next() -> void:
	if _next_button != null and step == Step.PROFILE:
		_next_button.disabled = nickname == ""


func _refresh_minutes() -> void:
	if _minutes_label != null:
		_minutes_label.text = Text.get_line(&"parent.dash.session_length", {"n": session_minutes})


func _picture(kind: StringName) -> void:
	var icon: IconArt = IconArt.new()
	icon.kind = kind
	icon.custom_minimum_size = UI.target_size(3.0, 3.0)
	_picture_host.add_child(icon)


func _label(line_id: StringName) -> Label:
	var label: Label = Label.new()
	label.text = Text.get_line(line_id)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _add_button(node_name: String, line_id: StringName, action: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = Text.get_line(line_id)
	UI.make_touch_target(button, 3.0, 1.25)
	button.pressed.connect(action)
	_buttons.add_child(button)
	return button


func _small_button(node_name: String, line_id: StringName, action: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = Text.get_line(line_id)
	UI.make_touch_target(button, 2.0, 1.0)
	button.pressed.connect(action)
	return button
