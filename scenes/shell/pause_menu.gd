## Pause overlay: dims the screen and offers Keep digging, Back to the workshop, Settings.
## Shows no clock and no score. Shell owns when it opens (Escape or the Android back
## gesture); this scene only reports which button was pressed.
class_name PauseMenu
extends Control

signal resume_requested
signal hub_requested
signal settings_requested

const BUTTON_WIDTH_MULTIPLE: float = 4.0
const BUTTON_HEIGHT_MULTIPLE: float = 1.25

@onready var _heading_label: Label = %HeadingLabel
@onready var _resume_button: Button = %ResumeButton
@onready var _hub_button: Button = %HubButton
@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
	# Overlays sit in a CanvasLayer, which breaks theme inheritance, so style ourselves.
	theme = UI.theme()
	_heading_label.text = Text.get_line(&"ui.pause.title")
	_resume_button.text = Text.get_line(&"ui.pause.resume")
	_hub_button.text = Text.get_line(&"ui.pause.to_hub")
	_settings_button.text = Text.get_line(&"ui.pause.settings")
	for button: Button in [_resume_button, _hub_button, _settings_button]:
		UI.make_touch_target(button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	_resume_button.pressed.connect(resume_requested.emit)
	_hub_button.pressed.connect(hub_requested.emit)
	_settings_button.pressed.connect(settings_requested.emit)


## Shows the menu and puts keyboard/gamepad focus on the first button.
func open() -> void:
	show()
	_resume_button.grab_focus()


func close() -> void:
	hide()
