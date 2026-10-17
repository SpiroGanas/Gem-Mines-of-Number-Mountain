## Settings screen. Today it holds the read-aloud switch. The switch is stored in the save
## now so profiles are ready, but it has no effect until narration arrives in Phase 3.
## Volume controls arrive in Sprint 10 together with the music and sound pass.
class_name SettingsScreen
extends ShellScreen

const BUTTON_WIDTH_MULTIPLE: float = 3.0
const BUTTON_HEIGHT_MULTIPLE: float = 1.5

var _back_to: StringName = &"hub"

@onready var _heading_label: Label = %HeadingLabel
@onready var _read_aloud_button: Button = %ReadAloudButton
@onready var _back_button: Button = %BackButton


func setup(args: Dictionary) -> void:
	_back_to = args.get("back_to", &"hub")


func _ready() -> void:
	super()
	_heading_label.text = Text.get_line(&"ui.settings.title")
	_back_button.text = Text.get_line(&"ui.settings.back")
	UI.make_touch_target(_read_aloud_button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	UI.make_touch_target(_back_button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	_read_aloud_button.toggle_mode = true
	_read_aloud_button.set_pressed_no_signal(_read_aloud())
	_refresh_read_aloud_text()
	_read_aloud_button.toggled.connect(_on_read_aloud_toggled)
	_back_button.pressed.connect(_on_back_pressed)


func _read_aloud() -> bool:
	return SaveSystem.data()["settings"]["read_aloud"]


func _on_read_aloud_toggled(enabled: bool) -> void:
	SaveSystem.data()["settings"]["read_aloud"] = enabled
	SaveSystem.save_now()
	_refresh_read_aloud_text()


func _refresh_read_aloud_text() -> void:
	var state_line: StringName = &"ui.settings.on" if _read_aloud_button.button_pressed else &"ui.settings.off"
	_read_aloud_button.text = Text.get_line(&"ui.settings.read_aloud", {"state": Text.get_line(state_line)})


func _on_back_pressed() -> void:
	request_screen.emit(_back_to, {})
