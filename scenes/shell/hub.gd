## Hub (the surface workshop). A stub in Sprint 3: Bolt's greeting plus Dig and Settings.
## Museum, Garage and Grown-ups are added in the sprints that build those screens.
class_name HubScreen
extends ShellScreen

const BUTTON_WIDTH_MULTIPLE: float = 3.0
const BUTTON_HEIGHT_MULTIPLE: float = 1.5

@onready var _greeting_label: Label = %GreetingLabel
@onready var _dig_button: Button = %DigButton
@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
	super()
	_greeting_label.text = Text.get_line(&"bolt.hub.greeting")
	_dig_button.text = Text.get_line(&"ui.hub.dig")
	_settings_button.text = Text.get_line(&"ui.hub.settings")
	UI.make_touch_target(_dig_button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	UI.make_touch_target(_settings_button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	_dig_button.pressed.connect(_on_dig_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)


func _on_dig_pressed() -> void:
	request_screen.emit(&"mine", {})


func _on_settings_pressed() -> void:
	request_screen.emit(&"settings", {"back_to": &"hub"})
