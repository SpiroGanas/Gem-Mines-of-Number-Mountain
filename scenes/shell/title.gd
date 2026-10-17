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
	var picture: TitleArt = TitleArt.new()
	picture.custom_minimum_size = UI.target_size(8.0, 4.0)
	_title_label.get_parent().add_child(picture)
	_title_label.get_parent().move_child(picture, 0)
	var backdrop: Backdrop = Backdrop.new()
	add_child(backdrop)
	move_child(backdrop, 0)
	_play_button.pressed.connect(_on_play_pressed)


func _on_play_pressed() -> void:
	# A profile with no nickname yet has not met Bolt: the first run comes first.
	var first_time: bool = str(SaveSystem.data()["child"].get("nickname", "")).is_empty()
	request_screen.emit(&"first_run" if first_time else &"hub", {})
