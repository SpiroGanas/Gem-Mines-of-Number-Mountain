## The children on this device (Phase 3, Sprint 23), for grown-ups only: behind the parental gate,
## reached from the dashboard or from the title screen's Grown-ups button. Each child has a row: their
## avatar, their nickname (a LineEdit: allowed in the parent area), "Change picture", "Play as" (makes
## them the active child) and "Delete". Below: "Add a child" (up to four) and the trash, from which a
## deleted child can be brought back for 30 days.
##
## Deleting is the only destructive action in the game, so it asks twice: Delete, then "Yes, delete",
## then "Delete for good". Even then the files go to the trash, not away (ProfileIndex.trash). The last
## child cannot be deleted.
class_name ProfilesScreen
extends ShellScreen

enum Confirm { NONE, FIRST, SECOND }

var _back_to: StringName = &"dashboard"
var _content: VBoxContainer
var _status: Label
## The profile a delete is being confirmed for, and how far.
var _deleting: String = ""
var _confirm: Confirm = Confirm.NONE
## The "Add a child" form.
var _new_nickname: LineEdit
var _new_avatar: StringName = Profile.DEFAULT_AVATAR
var _new_grade: int = Profile.DEFAULT_GRADE


func setup(args: Dictionary) -> void:
	_back_to = args.get("back_to", &"dashboard")


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
	var status_text: String = _status.text if _status != null else ""
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var header: HBoxContainer = HBoxContainer.new()
	_content.add_child(header)
	var back: Button = _button("BackButton", &"ui.common.back", func() -> void: request_screen.emit(_back_to, {}))
	header.add_child(back)
	var title: Label = _label(&"parent.profiles.title")
	title.theme_type_variation = &"HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	_content.add_child(_label(&"parent.profiles.count", {"n": Profiles.count(), "max": Profiles.MAX_PROFILES}))
	for profile: Profile in Profiles.list():
		_content.add_child(_row(profile))
		if profile.id == _deleting and _confirm != Confirm.NONE:
			_content.add_child(_confirm_row(profile))
	_status = Label.new()
	_status.name = "StatusLabel"
	_status.text = status_text
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_status)
	_add_new_child_form()
	_add_trash()


func status_text() -> String:
	return _status.text


## The row of buttons for one child.
func row_for(profile_id: String) -> HBoxContainer:
	return _content.find_child("Row_%s" % profile_id, true, false) as HBoxContainer


# --- Actions (buttons call these; tests call them directly too) -----------------------------------


func play_as(profile_id: String) -> void:
	Profiles.select(profile_id)
	refresh()


func rename(profile_id: String, nickname: String) -> void:
	var profile: Profile = Profiles.get_profile(profile_id)
	if profile == null or Profile.clean_nickname(nickname) == profile.nickname:
		return
	if Profiles.rename(profile_id, nickname):
		_status.text = Text.get_line(&"parent.profiles.renamed")


## The next avatar in the list for this child.
func next_avatar(profile_id: String) -> void:
	var profile: Profile = Profiles.get_profile(profile_id)
	if profile == null:
		return
	var index: int = Profile.AVATARS.find(profile.avatar_id)
	Profiles.set_avatar(profile_id, Profile.AVATARS[(index + 1) % Profile.AVATARS.size()])
	refresh()


## Delete, first press: asks "Delete <name>?".
func ask_delete(profile_id: String) -> void:
	if Profiles.count() <= 1:
		_status.text = Text.get_line(&"parent.profiles.last_one")
		return
	_deleting = profile_id
	_confirm = Confirm.FIRST
	refresh()


## "Yes, delete": asks a second time, saying what goes.
func confirm_delete() -> void:
	if _confirm == Confirm.FIRST:
		_confirm = Confirm.SECOND
		refresh()


## "Delete for good" (the second confirmation): the child goes to the trash.
func delete_for_good() -> void:
	if _confirm != Confirm.SECOND or _deleting == "":
		return
	var profile: Profile = Profiles.get_profile(_deleting)
	var nickname: String = profile.nickname if profile != null else ""
	var ok: bool = Profiles.delete(_deleting)
	_deleting = ""
	_confirm = Confirm.NONE
	refresh()
	_status.text = Text.get_line(&"parent.profiles.deleted", {"name": nickname}) if ok else Text.get_line(&"parent.profiles.delete_failed")


func cancel_delete() -> void:
	_deleting = ""
	_confirm = Confirm.NONE
	refresh()


func confirm_state() -> Confirm:
	return _confirm


## "Add a child": makes the profile from the form (it does not switch to it).
func add_child_profile(nickname: String = "") -> Profile:
	var name_text: String = nickname if nickname != "" else (_new_nickname.text if _new_nickname != null else "")
	if Profile.clean_nickname(name_text) == "":
		_status.text = Text.get_line(&"parent.profiles.need_name")
		return null
	var made: Profile = Profiles.create(name_text, _new_avatar, _new_grade)
	refresh()
	_status.text = Text.get_line(&"parent.profiles.added", {"name": made.nickname}) if made != null else Text.get_line(&"parent.profiles.full")
	return made


func set_new_avatar(id: StringName) -> void:
	_new_avatar = id
	for node: Node in _content.find_children("Avatar_*", "Button", true, false):
		(node as Button).set_pressed_no_signal(node.name == "Avatar_%s" % id)


func set_new_grade(value: int) -> void:
	_new_grade = Profile.clamp_grade(value)
	for node: Node in _content.find_children("Grade_*", "Button", true, false):
		(node as Button).set_pressed_no_signal(node.name == "Grade_%d" % _new_grade)


func restore(trash_folder: String) -> void:
	var back: Profile = Profiles.restore(trash_folder)
	refresh()
	_status.text = Text.get_line(&"parent.profiles.restored", {"name": back.nickname}) if back != null else Text.get_line(&"parent.profiles.full")


# --- Building the page ----------------------------------------------------------------------------


func _row(profile: Profile) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row_%s" % profile.id
	row.add_theme_constant_override(&"separation", 16)
	var picture: AvatarArt = AvatarArt.new()
	picture.avatar_id = profile.avatar_id
	picture.custom_minimum_size = UI.target_size(1.2, 1.2)
	row.add_child(picture)
	var field: LineEdit = LineEdit.new() # allowed here: the parent area only (CLAUDE.md rule 6)
	field.name = "NicknameField"
	field.text = profile.nickname
	field.max_length = Profile.NICKNAME_MAX_LENGTH
	field.custom_minimum_size = UI.target_size(4.0, 1.0)
	field.text_submitted.connect(func(text: String) -> void: rename(profile.id, text))
	field.focus_exited.connect(func() -> void: rename(profile.id, field.text))
	row.add_child(field)
	if profile.id == Profiles.active.id:
		row.add_child(_label(&"parent.profiles.playing"))
	else:
		row.add_child(_button("PlayAsButton", &"parent.profiles.play_as", play_as.bind(profile.id)))
	row.add_child(_button("AvatarButton", &"parent.profiles.change_avatar", next_avatar.bind(profile.id)))
	var delete: Button = _button("DeleteButton", &"parent.profiles.delete", ask_delete.bind(profile.id))
	delete.disabled = Profiles.count() <= 1
	row.add_child(delete)
	return row


func _confirm_row(profile: Profile) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ConfirmRow"
	row.add_theme_constant_override(&"separation", 16)
	var question: Label = _label(&"parent.profiles.ask_first" if _confirm == Confirm.FIRST else &"parent.profiles.ask_second", {"name": profile.nickname})
	question.name = "ConfirmQuestion"
	question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question.add_theme_color_override(&"font_color", Bolt.NOTE_COLOR)
	row.add_child(question)
	if _confirm == Confirm.FIRST:
		row.add_child(_button("YesButton", &"parent.profiles.yes_delete", confirm_delete))
	else:
		row.add_child(_button("ForGoodButton", &"parent.profiles.delete_for_good", delete_for_good))
	row.add_child(_button("KeepButton", &"parent.profiles.keep", cancel_delete))
	return row


func _add_new_child_form() -> void:
	_new_nickname = null
	var heading: Label = _label(&"parent.profiles.add_title")
	heading.add_theme_color_override(&"font_color", Bolt.NOTE_COLOR)
	_content.add_child(heading)
	if not Profiles.can_add():
		_content.add_child(_label(&"parent.profiles.full"))
		return
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 16)
	_content.add_child(name_row)
	name_row.add_child(_label(&"parent.dash.nickname"))
	_new_nickname = LineEdit.new() # allowed here: the parent area only (CLAUDE.md rule 6)
	_new_nickname.name = "NewNicknameField"
	_new_nickname.max_length = Profile.NICKNAME_MAX_LENGTH
	_new_nickname.custom_minimum_size = UI.target_size(5.0, 1.0)
	name_row.add_child(_new_nickname)
	_content.add_child(_label(&"parent.onboard.avatar"))
	var avatars: GridContainer = GridContainer.new()
	avatars.columns = 8
	avatars.add_theme_constant_override(&"h_separation", 12)
	_content.add_child(avatars)
	for id: StringName in Profile.AVATARS:
		avatars.add_child(OnboardingScreen.avatar_button(id, set_new_avatar.bind(id)))
	_content.add_child(_label(&"parent.onboard.grade"))
	var grades: HBoxContainer = HBoxContainer.new()
	grades.add_theme_constant_override(&"separation", 12)
	_content.add_child(grades)
	for value: int in range(Profile.MIN_GRADE, Profile.MAX_GRADE + 1):
		var button: Button = Button.new()
		button.name = "Grade_%d" % value
		button.toggle_mode = true
		button.text = OnboardingScreen.grade_text(value)
		UI.make_touch_target(button, 1.2, 1.0)
		button.pressed.connect(set_new_grade.bind(value))
		grades.add_child(button)
	set_new_avatar(_new_avatar)
	set_new_grade(_new_grade)
	_content.add_child(_button("AddButton", &"parent.profiles.add", func() -> void: add_child_profile()))


func _add_trash() -> void:
	var trashed: Array[Dictionary] = Profiles.trashed()
	if trashed.is_empty():
		return
	var heading: Label = _label(&"parent.profiles.trash_title")
	heading.add_theme_color_override(&"font_color", Bolt.NOTE_COLOR)
	_content.add_child(heading)
	_content.add_child(_label(&"parent.profiles.trash_body"))
	for item: Dictionary in trashed:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Trash_%s" % item["id"]
		row.add_theme_constant_override(&"separation", 16)
		var nickname: String = _trashed_nickname(item["folder"])
		var label: Label = Label.new()
		label.text = nickname
		row.add_child(label)
		var bring_back: Button = _button("RestoreButton", &"parent.profiles.restore", restore.bind(item["folder"]))
		bring_back.disabled = not Profiles.can_add()
		row.add_child(bring_back)
		_content.add_child(row)


func _trashed_nickname(folder: String) -> String:
	var read: Dictionary = SaveStore.new(folder).read_profile()
	return Profile.from_save(read["data"]).nickname if read["ok"] else ""


func _label(line_id: StringName, params: Dictionary = {}) -> Label:
	var label: Label = Label.new()
	label.text = Text.get_line(line_id, params)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(node_name: String, line_id: StringName, action: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = Text.get_line(line_id)
	UI.make_touch_target(button, 2.6, 1.0)
	button.pressed.connect(action)
	return button
