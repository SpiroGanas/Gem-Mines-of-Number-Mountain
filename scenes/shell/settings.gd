## Settings screen: music and sound volumes (device settings, DeviceSettings) and the read-aloud
## switch. The switch is stored in the save now so profiles are ready, but it has no effect until
## narration arrives in Phase 3. Volumes use big Less / More buttons and a row of bars that grow
## taller, so the level reads without color or numbers.
class_name SettingsScreen
extends ShellScreen

const BUTTON_WIDTH_MULTIPLE: float = 3.0
const BUTTON_HEIGHT_MULTIPLE: float = 1.5

var _back_to: StringName = &"hub"
var _bars: Dictionary[String, LevelBars] = {}

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
	var column: VBoxContainer = _read_aloud_button.get_parent()
	column.add_child(_volume_row("music", &"ui.settings.music"))
	column.move_child(column.get_child(column.get_child_count() - 1), 1)
	column.add_child(_volume_row("sfx", &"ui.settings.sounds"))
	column.move_child(column.get_child(column.get_child_count() - 1), 2)


## The volume level shown for "music" or "sfx", for tests.
func volume_level(channel: String) -> int:
	return _bars[channel].level


func _volume_row(channel: String, line_id: StringName) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "%sRow" % channel.capitalize()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 24)
	var label: Label = Label.new()
	label.text = Text.get_line(line_id)
	label.custom_minimum_size.x = UI.target_size(3.0, 1.0).x
	row.add_child(label)
	var less: Button = Button.new()
	less.name = "Less"
	less.text = Text.get_line(&"ui.common.less")
	UI.make_touch_target(less, 2.0, 1.25)
	less.pressed.connect(_change_volume.bind(channel, -1))
	row.add_child(less)
	var bars: LevelBars = LevelBars.new()
	bars.levels = DeviceSettings.LEVELS
	bars.level = DeviceSettings.shared().level(channel)
	UI.make_touch_target(bars, 2.5, 1.25)
	row.add_child(bars)
	_bars[channel] = bars
	var more: Button = Button.new()
	more.name = "More"
	more.text = Text.get_line(&"ui.common.more")
	UI.make_touch_target(more, 2.0, 1.25)
	more.pressed.connect(_change_volume.bind(channel, 1))
	row.add_child(more)
	return row


func _change_volume(channel: String, delta: int) -> void:
	var settings: DeviceSettings = DeviceSettings.shared()
	settings.set_level(channel, settings.level(channel) + delta)
	_bars[channel].level = settings.level(channel)


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
