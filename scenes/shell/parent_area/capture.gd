## Handwriting capture (debug builds only, behind the parent gate): collects digit samples so the
## digit network can be measured on real writing (Sprint 13: about 20 digits with the stylus and 10
## with a finger). Shows a digit to write, saves the strokes (never a picture) to user://capture/
## and moves on. Nothing leaves the device until a parent exports the folder. Grown-ups only; it is
## stripped from release builds (StrokeCapture.is_enabled).
class_name CaptureScreen
extends ShellScreen

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bag: Array[int] = []
var _label: int = -1
var _box: DigitBox
var _target: Label
var _status: Label
var _dir: String = StrokeCapture.DIR
var _file_dialog: FileDialog


func _ready() -> void:
	super()
	_rng.randomize()
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var back: Button = _button(&"parent.capture.back", func() -> void: request_screen.emit(&"dashboard", {}))
	back.name = "BackButton"
	header.add_child(back)
	var title: Label = Label.new()
	title.text = Text.get_line(&"parent.capture.title")
	title.theme_type_variation = &"HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	_target = Label.new()
	_target.name = "Target"
	_target.theme_type_variation = &"HeadingLabel"
	_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_target)
	_box = load("res://scenes/input/chalk_slate/digit_box.tscn").instantiate()
	_box.name = "DigitBox"
	_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_box)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 16)
	column.add_child(buttons)
	buttons.add_child(_named(_button(&"parent.capture.erase", _box.clear), "EraseButton"))
	buttons.add_child(_named(_button(&"parent.capture.save", save_and_next), "SaveButton"))
	buttons.add_child(_named(_button(&"parent.capture.skip", next_digit), "SkipButton"))
	var export_row: HBoxContainer = HBoxContainer.new()
	export_row.alignment = BoxContainer.ALIGNMENT_CENTER
	export_row.add_theme_constant_override(&"separation", 16)
	column.add_child(export_row)
	export_row.add_child(_named(_button(&"parent.capture.export", _open_export_dialog), "ExportButton"))
	export_row.add_child(_named(_button(&"parent.capture.clear_all", clear_saved), "ClearAllButton"))
	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	next_digit()


## Points the screen at another folder (tests).
func use_directory(dir: String) -> void:
	_dir = dir
	_refresh_status()


func digit_box() -> DigitBox:
	return _box


func target_label() -> int:
	return _label


func status_text() -> String:
	return _status.text


## Asks for another digit and clears the box.
func next_digit() -> void:
	_label = StrokeCapture.next_label(_bag, _rng)
	_target.text = Text.get_line(&"parent.capture.write", {"n": _label})
	_box.clear()
	_refresh_status()


## Saves what is in the box as a sample of the digit asked for, then asks for the next. An empty box
## saves nothing.
func save_and_next() -> void:
	if not _box.has_ink():
		_status.text = Text.get_line(&"parent.capture.empty")
		return
	var sample: Dictionary = StrokeCapture.make_sample(_label, StrokeCapture.device_name(InputRouter.last_device_kind()), _box.box_size(), _box.strokes(), Time.get_datetime_string_from_system(true) + "Z")
	if StrokeCapture.save(sample, _dir) == "":
		_status.text = Text.get_line(&"parent.capture.failed")
		return
	next_digit()


func export_to(target: String) -> int:
	var copied: int = StrokeCapture.export_to(target, _dir)
	_status.text = Text.get_line(&"parent.capture.exported", {"n": copied, "path": target})
	return copied


func clear_saved() -> void:
	StrokeCapture.clear_all(_dir)
	_refresh_status()


func _refresh_status() -> void:
	var counts: Dictionary = StrokeCapture.counts(_dir)
	_status.text = Text.get_line(&"parent.capture.saved", {"pen": int(counts.get("pen", 0)), "touch": int(counts.get("touch", 0)), "mouse": int(counts.get("mouse", 0))})


func _open_export_dialog() -> void:
	if _file_dialog != null:
		_file_dialog.queue_free()
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	add_child(_file_dialog)
	_file_dialog.dir_selected.connect(export_to)
	_file_dialog.popup_centered_ratio(0.8)


func _button(line_id: StringName, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = Text.get_line(line_id)
	UI.make_touch_target(button, 3.0, 1.0)
	button.pressed.connect(action)
	return button


func _named(button: Button, node_name: String) -> Button:
	button.name = node_name
	return button
