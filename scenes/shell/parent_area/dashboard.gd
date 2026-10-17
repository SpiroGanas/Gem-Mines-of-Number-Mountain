## Parent dashboard v1 (P1-S09-04): time played today and this week, skills mastered, skills that
## need practice (flagged, or 3 misses in the last 5 first tries), the last 7 sessions, settings
## (session length, nickname, re-run placement) and progress export / import. Grown-ups only: it
## sits behind the parent gate, and it is the one screen where a LineEdit (the nickname) is allowed.
## The numbers come from ProgressReport over the save and the attempt log; nothing here leaves the
## device unless the parent exports it.
class_name DashboardScreen
extends ShellScreen

const SESSION_STEP_MINUTES: int = 5
const MIN_SESSION_MINUTES: int = 5
const MAX_SESSION_MINUTES: int = 60

var _content: VBoxContainer
var _status: Label
var _session_label: Label
var _nickname: LineEdit
var _file_dialog: FileDialog


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


## Rebuilds every section from the save and the attempt log.
func refresh() -> void:
	for child: Node in _content.get_children():
		child.queue_free()
		_content.remove_child(child)
	var header: HBoxContainer = HBoxContainer.new()
	_content.add_child(header)
	var back: Button = _button(&"ui.pause.to_hub", func() -> void: request_screen.emit(&"hub", {}))
	back.name = "BackButton"
	header.add_child(back)
	var title: Label = _label(&"parent.dash.title")
	title.theme_type_variation = &"HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	if bool(SaveSystem.last_load_report.get("recovered", false)):
		_content.add_child(_label(&"parent.dash.recovered"))
	var entries: Array = SaveSystem.read_attempts()["entries"]
	var today: String = Adaptive.clock.today()
	var offset: int = Adaptive.clock.utc_offset_minutes()
	_section(&"parent.dash.time")
	_content.add_child(_label(&"parent.dash.today", {"n": ProgressReport.minutes(ProgressReport.seconds_on(entries, today, offset))}))
	_content.add_child(_label(&"parent.dash.week", {"n": ProgressReport.minutes(ProgressReport.seconds_this_week(entries, today, offset))}))
	var mastered: Array[StringName] = Adaptive.mastered()
	_section(&"parent.dash.mastered", {"n": mastered.size()})
	_content.add_child(_names(mastered))
	var struggling: Array[StringName] = Adaptive.engine.struggling(entries)
	_section(&"parent.dash.struggling", {"n": struggling.size()})
	for id: StringName in struggling:
		var record: Dictionary = Adaptive.engine.scheduler.record_of(SaveSystem.data()["skills"], id)
		var reason: StringName = &"parent.dash.reason_flagged" if bool(record.get("flagged_for_review", false)) else &"parent.dash.reason_misses"
		var row: Label = Label.new()
		row.text = Text.get_line(&"parent.dash.skill_reason", {"skill": skill_name(id), "reason": Text.get_line(reason)})
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(row)
	if struggling.is_empty():
		_content.add_child(_label(&"parent.dash.none"))
	var recent: Array[Dictionary] = ProgressReport.recent_sessions(entries, offset)
	_section(&"parent.dash.sessions", {"n": recent.size()})
	for session: Dictionary in recent:
		_content.add_child(_label(&"parent.dash.session_row", {
			"day": session["day"], "minutes": ProgressReport.minutes(session["seconds"]),
			"rocks": session["rocks"], "percent": ProgressReport.first_try_percent(session),
		}))
	if recent.is_empty():
		_content.add_child(_label(&"parent.dash.none"))
	_section(&"parent.dash.settings")
	var length_row: HBoxContainer = HBoxContainer.new()
	length_row.add_theme_constant_override(&"separation", 16)
	_content.add_child(length_row)
	var less: Button = _button(&"ui.common.less", change_session_minutes.bind(-SESSION_STEP_MINUTES))
	less.name = "LessButton"
	length_row.add_child(less)
	_session_label = Label.new()
	length_row.add_child(_session_label)
	var more: Button = _button(&"ui.common.more", change_session_minutes.bind(SESSION_STEP_MINUTES))
	more.name = "MoreButton"
	length_row.add_child(more)
	_refresh_session_label()
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 16)
	_content.add_child(name_row)
	name_row.add_child(_label(&"parent.dash.nickname"))
	_nickname = LineEdit.new() # allowed here: the parent area only (CLAUDE.md rule 6)
	_nickname.name = "NicknameField"
	_nickname.text = str(SaveSystem.data()["child"].get("nickname", ""))
	_nickname.max_length = 20
	_nickname.custom_minimum_size = UI.target_size(5.0, 1.0)
	_nickname.text_submitted.connect(set_nickname)
	_nickname.focus_exited.connect(func() -> void: set_nickname(_nickname.text))
	name_row.add_child(_nickname)
	var rerun: Button = _button(&"parent.dash.rerun", rerun_placement)
	rerun.name = "RerunButton"
	_content.add_child(rerun)
	var transfer: HBoxContainer = HBoxContainer.new()
	transfer.add_theme_constant_override(&"separation", 16)
	_content.add_child(transfer)
	var export_button: Button = _button(&"parent.dash.export", _open_export_dialog)
	export_button.name = "ExportButton"
	transfer.add_child(export_button)
	var import_button: Button = _button(&"parent.dash.import", _open_import_dialog)
	import_button.name = "ImportButton"
	transfer.add_child(import_button)
	_status = Label.new()
	_status.name = "StatusLabel"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_status)


## The parent-facing name of a skill (curriculum/skills; never shown to the child).
func skill_name(id: StringName) -> String:
	var skill: Skill = Adaptive.catalog().skill(id)
	return skill.name if skill != null else String(id)


func status_text() -> String:
	return _status.text


func change_session_minutes(delta: int) -> void:
	var settings: Dictionary = SaveSystem.data()["settings"]
	settings["session_minutes"] = clampi(int(settings["session_minutes"]) + delta, MIN_SESSION_MINUTES, MAX_SESSION_MINUTES)
	SaveSystem.save_now()
	_refresh_session_label()


func set_nickname(nickname: String) -> void:
	var cleaned: String = nickname.strip_edges().left(20)
	if cleaned == str(SaveSystem.data()["child"].get("nickname", "")):
		return
	SaveSystem.data()["child"]["nickname"] = cleaned
	SaveSystem.save_now()


func rerun_placement() -> void:
	Adaptive.rerun_placement()
	_status.text = Text.get_line(&"parent.dash.rerun_done")


## Writes the progress bundle to `path` and says where it went.
func export_to(path: String) -> Error:
	var error: Error = SaveSystem.export_bundle(path)
	_status.text = Text.get_line(&"parent.dash.exported", {"path": path}) if error == OK else Text.get_line(&"parent.dash.export_failed")
	return error


## Imports a bundle from `path` and refreshes every number.
func import_from(path: String) -> Error:
	var error: Error = SaveSystem.import_bundle(path)
	var line: StringName = &"parent.dash.import_failed"
	if error == OK:
		line = &"parent.dash.imported" if SaveSystem.last_import_report["replaced"] else &"parent.dash.import_kept"
	refresh()
	_status.text = Text.get_line(line)
	return error


func _refresh_session_label() -> void:
	_session_label.text = Text.get_line(&"parent.dash.session_length", {"n": int(SaveSystem.data()["settings"]["session_minutes"])})


func _section(line_id: StringName, params: Dictionary = {}) -> void:
	var heading: Label = _label(line_id, params)
	heading.add_theme_color_override(&"font_color", Bolt.NOTE_COLOR)
	_content.add_child(heading)


func _label(line_id: StringName, params: Dictionary = {}) -> Label:
	var label: Label = Label.new()
	label.text = Text.get_line(line_id, params)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _names(ids: Array[StringName]) -> Label:
	if ids.is_empty():
		return _label(&"parent.dash.none")
	var names: PackedStringArray = PackedStringArray()
	for id: StringName in ids:
		names.append(skill_name(id))
	var label: Label = Label.new()
	label.text = ", ".join(names)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(line_id: StringName, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = Text.get_line(line_id)
	UI.make_touch_target(button, 3.0, 1.0)
	button.pressed.connect(action)
	return button


## The system's own file picker where there is one (Godot falls back to its built-in dialog).
## Whether Android's picker hands back a path FileAccess can write is checked on the device
## (docs/decisions.md, Sprint 9).
func _dialog(mode: FileDialog.FileMode) -> FileDialog:
	if _file_dialog != null:
		_file_dialog.queue_free()
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = mode
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.filters = PackedStringArray(["*.json"])
	add_child(_file_dialog)
	return _file_dialog


func _open_export_dialog() -> void:
	var dialog: FileDialog = _dialog(FileDialog.FILE_MODE_SAVE_FILE)
	dialog.current_file = "gem-mines-progress-%s.json" % Adaptive.clock.today()
	dialog.file_selected.connect(export_to)
	dialog.popup_centered_ratio(0.8)


func _open_import_dialog() -> void:
	var dialog: FileDialog = _dialog(FileDialog.FILE_MODE_OPEN_FILE)
	dialog.file_selected.connect(import_from)
	dialog.popup_centered_ratio(0.8)
