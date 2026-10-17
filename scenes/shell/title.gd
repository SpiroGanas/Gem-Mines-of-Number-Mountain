## Title screen: the game's name and one big Play button.
## All words come from the text table (rule 4).
class_name TitleScreen
extends ShellScreen

## The Play button is three touch targets wide: easy to hit from a tablet held at arm's length.
const PLAY_WIDTH_MULTIPLE: float = 3.0
const PLAY_HEIGHT_MULTIPLE: float = 1.5

@onready var _title_label: Label = %TitleLabel
@onready var _play_button: Button = %PlayButton


func _ready() -> void:
	super()
	_title_label.text = Text.get_line(&"ui.title.name")
	_play_button.text = Text.get_line(&"ui.title.play")
	UI.make_touch_target(_play_button, PLAY_WIDTH_MULTIPLE, PLAY_HEIGHT_MULTIPLE)
	_play_button.pressed.connect(_on_play_pressed)


func _on_play_pressed() -> void:
	request_screen.emit(&"hub", {})
