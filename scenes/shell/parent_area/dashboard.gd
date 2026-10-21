## Parent dashboard (v1 P1-S09-04, v2 Sprint 21): the week's summary (minutes, sessions, skills
## mastered, skills that need help, the handwriting confirmation rate), time played today, the visual
## skill map (SkillMap: zones as rows, skills colored and shaped by state), skills mastered, skills
## that need practice (flagged, or 3 misses in the last 5 first tries), the last 7 sessions, settings
## (session length, nickname, re-run placement, family rewards) and progress export / import with
## its log. Grown-ups only: it
## sits behind the parent gate, and it is the one screen where a LineEdit (the nickname) is allowed.
## The numbers come from ProgressReport over the save and the attempt log; nothing here leaves the
## device unless the parent exports it.
##
## Profiles (Sprint 23): everything here is about the active child, named at the top. With two or more
## children a row of avatar buttons picks which child the page shows (it makes that child the active
## one). "Children" opens the profiles page (add, rename, delete); "How this game teaches" opens the
## parent explainer. A progress file is one child: "Import into <name>" replaces this child's progress
## (newest wins, as before) and "Import as a new child" adds it as another profile (up to four).
class_name DashboardScreen
extends ShellScreen

## Tests pretend to be the web build. The web version has no progress file (peer review 05).
static var pretend_web: bool = false

const SESSION_STEP_MINUTES: int = 5
const MIN_SESSION_MINUTES: int = 5
const MAX_SESSION_MINUTES: int = 60

var _content: VBoxContainer
var _status: Label
var _session_label: Label
var _nickname: LineEdit
var _file_dialog: FileDialog
## The older file waiting for the parent's choice (Sprint 17), or "".
var _pending_older: String = ""
var _older_row: HBoxContainer
var _skill_map: SkillMap


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
	_add_profile_picker()
	if bool(SaveSystem.last_load_report.get("recovered", false)):
		_content.add_child(_label(&"parent.dash.recovered"))
	var entries: Array = SaveSystem.read_attempts()["entries"]
	var today: String = Adaptive.clock.today()
	var offset: int = Adaptive.clock.utc_offset_minutes()
	var week: Dictionary = ProgressReport.week_summary(entries, SaveSystem.data()["skills"], today, offset)
	var struggling: Array[StringName] = Adaptive.engine.struggling(entries)
	var rank: Label = _label(&"parent.dash.rank", {"rank": Text.get_line(RankRules.name_line(Rewards.rank_for()))})
	rank.name = "RankLabel"
	_content.add_child(rank)
	_section(&"parent.week.title")
	var summary: Label = _label(&"parent.week.summary", {"minutes": week["minutes"], "sessions": week["sessions"], "mastered": week["mastered"], "struggling": struggling.size()})
	summary.name = "WeekSummary"
	_content.add_child(summary)
	var handwriting: Label = _label(&"parent.week.handwriting", {"n": week["handwriting_answers"], "confirmed": week["handwriting_confirmed"], "percent": week["confirmation_percent"], "rejected": week["handwriting_rejected"]})
	handwriting.name = "WeekHandwriting"
	_content.add_child(handwriting)
	_section(&"parent.dash.time")
	_content.add_child(_label(&"parent.dash.today", {"n": ProgressReport.minutes(ProgressReport.seconds_on(entries, today, offset))}))
	_content.add_child(_label(&"parent.dash.week", {"n": ProgressReport.minutes(ProgressReport.seconds_this_week(entries, today, offset))}))
	_section(&"parent.map.title")
	_skill_map = SkillMap.new()
	_skill_map.name = "SkillMap"
	_content.add_child(_skill_map)
	var mastered: Array[StringName] = Adaptive.mastered()
	_section(&"parent.dash.mastered", {"n": mastered.size()})
	_content.add_child(_names(mastered))
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
	_content.add_child(_switch_row(&"HandwritingSwitch", &"parent.dash.handwriting", DeviceSettings.shared().handwriting_enabled(), toggle_handwriting))
	_content.add_child(_switch_row(&"CoachingSwitch", &"parent.dash.coaching", bool(SaveSystem.data()["settings"].get("handwriting_coaching", false)), toggle_coaching))
	_add_interface_row()
	if StrokeCapture.is_enabled():
		var capture: Button = _button(&"parent.dash.capture", func() -> void: request_screen.emit(&"capture", {}))
		capture.name = "CaptureButton"
		_content.add_child(capture)
	var children: Button = _button(&"parent.dash.children", func() -> void: request_screen.emit(&"profiles", {"back_to": &"dashboard"}))
	children.name = "ChildrenButton"
	_content.add_child(children)
	var teaches: Button = _button(&"parent.dash.how_it_teaches", func() -> void: request_screen.emit(&"how_it_teaches", {"back_to": &"dashboard"}))
	teaches.name = "HowItTeachesButton"
	_content.add_child(teaches)
	var family: Button = _button(&"parent.dash.family", func() -> void: request_screen.emit(&"family_rewards", {}))
	family.name = "FamilyButton"
	_content.add_child(family)
	var rerun: Button = _button(&"parent.dash.rerun", rerun_placement)
	rerun.name = "RerunButton"
	_content.add_child(rerun)
	var transfer: HBoxContainer = HBoxContainer.new()
	transfer.add_theme_constant_override(&"separation", 16)
	_content.add_child(transfer)
	if is_web():
		# A browser cannot hand the game a file on the computer's disk or take one from it through Godot's dialog, so
		# the web version offers no progress file; progress stays in the browser's storage (docs/privacy-policy.md).
		var note: Label = Label.new()
		note.name = "WebTransferNote"
		note.text = Text.get_line(&"parent.dash.web_no_transfer")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		transfer.add_child(note)
	else:
		var export_button: Button = _button(&"parent.dash.export", _open_export_dialog)
		export_button.name = "ExportButton"
		transfer.add_child(export_button)
		var import_button: Button = _button(&"parent.dash.import", _open_import_dialog)
		import_button.text = Text.get_line(&"parent.dash.import_into", {"name": _active_name()})
		import_button.name = "ImportButton"
		transfer.add_child(import_button)
		var import_new: Button = _button(&"parent.dash.import_new", _open_import_new_dialog)
		import_new.name = "ImportNewButton"
		import_new.disabled = not Profiles.can_add()
		transfer.add_child(import_new)
	_status = Label.new()
	_status.name = "StatusLabel"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_status)
	_older_row = HBoxContainer.new()
	_older_row.name = "OlderChoice"
	_older_row.add_theme_constant_override(&"separation", 16)
	_older_row.visible = false
	_content.add_child(_older_row)
	var keep: Button = _button(&"parent.dash.keep_local", keep_local_progress)
	keep.name = "KeepLocalButton"
	_older_row.add_child(keep)
	var use_file: Button = _button(&"parent.dash.use_file", use_older_file)
	use_file.name = "UseFileButton"
	_older_row.add_child(use_file)
	_content.add_child(_label(&"parent.dash.device_id", {"id": DeviceSettings.shared().device_id().substr(0, 8)}))
	_add_sync_log()


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


## Handwriting answers on or off for this device (the child then uses the number pad).
func toggle_handwriting() -> void:
	var settings: DeviceSettings = DeviceSettings.shared()
	settings.set_handwriting_enabled(not settings.handwriting_enabled())
	refresh()


## Numeral coaching on or off for this child (Bolt shows how to write a digit they keep writing
## backwards). Kept in the save's settings.handwriting_coaching, which schema v1 already has.
func toggle_coaching() -> void:
	var settings: Dictionary = SaveSystem.data()["settings"]
	settings["handwriting_coaching"] = not bool(settings.get("handwriting_coaching", false))
	SaveSystem.save_now()
	refresh()


## Explorer, Scholar or Auto for this child (Scholar mode part 1, Phase 4 Sprint 37): three buttons, the
## current one pressed, and a note saying what each does. Kept in the save's settings.interface_mode
## (already in the schema, so no migration); ModeGate decides what each setting turns on.
func _add_interface_row() -> void:
	_content.add_child(_label(&"parent.dash.interface"))
	# A flow row: the three long buttons wrap to the next line where the width runs out (phones, 4:3).
	var row: HFlowContainer = HFlowContainer.new()
	row.name = "InterfaceRow"
	row.add_theme_constant_override(&"h_separation", 16)
	row.add_theme_constant_override(&"v_separation", 16)
	_content.add_child(row)
	var current: String = ModeGate.clean_setting(str(SaveSystem.data()["settings"].get("interface_mode", ModeGate.EXPLORER)))
	for mode: String in ModeGate.SETTINGS:
		var button: Button = _button(StringName("parent.dash.interface_" + mode), set_interface_mode.bind(mode))
		button.name = "Interface_" + mode
		button.toggle_mode = true
		button.button_pressed = mode == current
		row.add_child(button)
	var note: Label = _label(&"parent.dash.interface_note")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)


## Sets this child's interface setting ("explorer", "scholar" or "auto") and saves.
func set_interface_mode(mode: String) -> void:
	SaveSystem.data()["settings"]["interface_mode"] = ModeGate.clean_setting(mode)
	SaveSystem.save_now()
	refresh()


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


## Imports a bundle from `path` into the active child and refreshes every number. A file older than
## this child's progress changes nothing yet: the parent chooses "Keep this device's progress" (the
## default) or "Use the file anyway" (Sprint 17). `use_older` is that second choice. `as_new` adds the
## file as a new child instead (Sprint 23).
func import_from(path: String, use_older: bool = false, as_new: bool = false) -> Error:
	var error: Error = SaveSystem.import_bundle(path, use_older, as_new)
	var report: Dictionary = SaveSystem.last_import_report
	var line: StringName = &"parent.dash.import_failed"
	if as_new:
		refresh()
		if error == OK:
			var added: Profile = Profiles.get_profile(report["added"])
			_status.text = Text.get_line(&"parent.dash.import_added", {"name": added.nickname if added != null else ""})
		elif report["error"] == SaveSystem.ERR_FULL:
			_status.text = Text.get_line(&"parent.dash.import_full")
		elif report["error"] == ProgressBundle.ERR_CHECKSUM:
			_status.text = Text.get_line(&"parent.dash.import_changed")
		else:
			_status.text = Text.get_line(&"parent.dash.import_failed")
		_pending_older = ""
		_older_row.visible = false
		return error
	if error == OK and report["replaced"]:
		line = &"parent.dash.imported"
	elif error == OK and report["older"]:
		line = &"parent.dash.import_older"
	elif error == OK:
		line = &"parent.dash.import_same"
	elif report["error"] == ProgressBundle.ERR_CHECKSUM:
		line = &"parent.dash.import_changed"
	refresh()
	_status.text = Text.get_line(line)
	_pending_older = path if error == OK and report["older"] and not report["replaced"] else ""
	_older_row.visible = _pending_older != ""
	return error


## The default answer to an older file: nothing changes (its answers were already added to the log).
func keep_local_progress() -> void:
	_pending_older = ""
	_older_row.visible = false
	_status.text = Text.get_line(&"parent.dash.import_kept")


## The parent chose the older file anyway: it replaces this device's progress, after a backup.
func use_older_file() -> void:
	if _pending_older == "":
		return
	import_from(_pending_older, true)


func skill_map() -> SkillMap:
	return _skill_map


func older_choice_visible() -> bool:
	return _older_row.visible


## The import/export log, newest first.
func _add_sync_log() -> void:
	var entries: Array = SaveSystem.sync_log()
	_section(&"parent.dash.sync_log", {"n": entries.size()})
	if entries.is_empty():
		_content.add_child(_label(&"parent.dash.none"))
	for index: int in mini(entries.size(), 10):
		var entry: Dictionary = entries[index]
		var row: Label = _label(&"parent.dash.sync_row", {
			"at": str(entry.get("at", "")).replace("T", " ").trim_suffix("Z"),
			"action": Text.get_line(StringName("parent.sync.action_%s" % entry.get("action", "import"))),
			"file": str(entry.get("file", "")),
			"result": Text.get_line(StringName("parent.sync.result_%s" % entry.get("result", "failed"))),
		})
		row.name = "SyncRow%d" % index
		_content.add_child(row)


## A label with an On / Off button that flips it.
func _switch_row(node_name: StringName, line_id: StringName, is_on: bool, action: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = node_name
	row.add_theme_constant_override(&"separation", 16)
	var label: Label = _label(line_id)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button: Button = _button(&"parent.dash.on" if is_on else &"parent.dash.off", action)
	button.name = "Button"
	row.add_child(button)
	return row


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


static func is_web() -> bool:
	return pretend_web or OS.has_feature("web")


func _open_export_dialog() -> void:
	var dialog: FileDialog = _dialog(FileDialog.FILE_MODE_SAVE_FILE)
	dialog.current_file = SaveSystem.export_file_name()
	dialog.file_selected.connect(export_to)
	dialog.popup_centered_ratio(0.8)


func _open_import_dialog() -> void:
	var dialog: FileDialog = _dialog(FileDialog.FILE_MODE_OPEN_FILE)
	dialog.file_selected.connect(import_from)
	dialog.popup_centered_ratio(0.8)


func _open_import_new_dialog() -> void:
	var dialog: FileDialog = _dialog(FileDialog.FILE_MODE_OPEN_FILE)
	dialog.file_selected.connect(func(path: String) -> void: import_from(path, false, true))
	dialog.popup_centered_ratio(0.8)


## Shows a child's progress here: makes them the active child (Profiles.select) and rebuilds the page.
func show_profile(profile_id: String) -> void:
	if Profiles.select(profile_id):
		refresh()


## "Child: <name>", and with two or more children a button per child to see theirs instead.
func _add_profile_picker() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ProfilePicker"
	row.add_theme_constant_override(&"separation", 16)
	_content.add_child(row)
	var label: Label = _label(&"parent.dash.child", {"name": _active_name()})
	label.name = "ActiveChild"
	row.add_child(label)
	var profiles: Array[Profile] = Profiles.list()
	if profiles.size() < 2:
		return
	for profile: Profile in profiles:
		var button: Button = _button(&"parent.dash.no_name", show_profile.bind(profile.id))
		button.name = "Show_%s" % profile.id
		if profile.nickname != "":
			button.text = profile.nickname
		button.toggle_mode = true
		button.set_pressed_no_signal(profile.id == SaveSystem.profile_id())
		AvatarArt.attach(button, profile.avatar_id)
		row.add_child(button)


func _active_name() -> String:
	var nickname: String = str(SaveSystem.data()["child"].get("nickname", ""))
	return nickname if nickname != "" else Text.get_line(&"parent.dash.no_name")
