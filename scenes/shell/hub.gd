## Hub: the surface workshop (GDD section 3). Bolt's greeting, the big Dig button, then Museum,
## Garage and Settings, and the lantern streak and coins. Every button has a picture (IconArt) and
## a short label. Grown-ups (small, in the corner) opens the parent gate.
class_name HubScreen
extends ShellScreen

const DIG_WIDTH_MULTIPLE: float = 5.0
const DIG_HEIGHT_MULTIPLE: float = 2.2
const BUTTON_WIDTH_MULTIPLE: float = 3.0
const BUTTON_HEIGHT_MULTIPLE: float = 1.5

@onready var _bolt: Bolt = %Bolt
@onready var _dig_button: Button = %DigButton
@onready var _museum_button: Button = %MuseumButton
@onready var _garage_button: Button = %GarageButton
@onready var _settings_button: Button = %SettingsButton
@onready var _grownups_button: Button = %GrownupsButton
@onready var _lantern: LanternArt = %Lantern
@onready var _lantern_label: Label = %LanternLabel
@onready var _coins_label: Label = %CoinsLabel


func _ready() -> void:
	super()
	_bolt.say(&"bolt.hub.greeting")
	_dig_button.text = Text.get_line(&"ui.hub.dig")
	_museum_button.text = Text.get_line(&"ui.hub.museum")
	_garage_button.text = Text.get_line(&"ui.hub.garage")
	_settings_button.text = Text.get_line(&"ui.hub.settings")
	_grownups_button.text = Text.get_line(&"ui.hub.grownups")
	UI.make_touch_target(_grownups_button, 2.5, 1.0)
	_grownups_button.pressed.connect(request_screen.emit.bind(&"parent_gate", {}))
	UI.make_touch_target(_dig_button, DIG_WIDTH_MULTIPLE, DIG_HEIGHT_MULTIPLE)
	for button: Button in [_museum_button, _garage_button, _settings_button]:
		UI.make_touch_target(button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	UI.make_touch_target(_lantern, 1.4, 1.7)
	var backdrop: Backdrop = Backdrop.new()
	add_child(backdrop)
	move_child(backdrop, 0)
	for pair: Array in [[_dig_button, &"dig"], [_museum_button, &"museum"], [_garage_button, &"garage"], [_settings_button, &"settings"], [_grownups_button, &"grownups"]]:
		IconArt.attach(pair[0], pair[1])
	_dig_button.pressed.connect(_on_dig_pressed)
	_museum_button.pressed.connect(request_screen.emit.bind(&"museum", {}))
	_garage_button.pressed.connect(request_screen.emit.bind(&"garage", {}))
	_settings_button.pressed.connect(_on_settings_pressed)
	_refresh()


func _refresh() -> void:
	_lantern.lit = Rewards.lit_today()
	_lantern_label.text = Text.get_line(&"ui.hub.lantern", {"n": Rewards.streak()})
	_coins_label.text = Text.get_line(&"ui.hub.coins", {"n": Rewards.coins()})


func _on_dig_pressed() -> void:
	# A new miner's first dig is the placement quest ("survey the mountain").
	if Adaptive.needs_placement() and not Adaptive.placement_active():
		Adaptive.start_placement()
	request_screen.emit(&"mine", {})


func _on_settings_pressed() -> void:
	request_screen.emit(&"settings", {"back_to": &"hub"})
