## Hub: the surface workshop (GDD section 3). Bolt's greeting, the big Dig button between the
## Workshop and the Build Site doors (Sprint 16), then Museum, Garage and Settings, and the lantern
## streak and coins. Finished machines and crafted lights run along the machine shelf; their
## animation (a tween loop) runs only while the hub is on screen and stops when the app is paused. Every button has a picture (IconArt) and
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

var _workshop_button: Button
var _build_button: Button
var _shelf: HBoxContainer
var _machine_loop: Tween


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
	_add_workshop_doors()
	_add_machine_shelf()
	_dig_button.pressed.connect(_on_dig_pressed)
	_museum_button.pressed.connect(request_screen.emit.bind(&"museum", {}))
	_garage_button.pressed.connect(request_screen.emit.bind(&"garage", {}))
	_settings_button.pressed.connect(_on_settings_pressed)
	_refresh()


## The Workshop and Build Site doors sit either side of the Dig button.
func _add_workshop_doors() -> void:
	var center: Control = _dig_button.get_parent()
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "DoorRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 40)
	center.remove_child(_dig_button)
	center.add_child(row)
	_workshop_button = Button.new()
	_workshop_button.name = "WorkshopButton"
	_workshop_button.text = Text.get_line(&"ui.hub.workshop")
	_build_button = Button.new()
	_build_button.name = "BuildButton"
	_build_button.text = Text.get_line(&"ui.hub.build_site")
	for button: Button in [_workshop_button, _build_button]:
		UI.make_touch_target(button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_workshop_button)
	row.add_child(_dig_button)
	row.add_child(_build_button)
	IconArt.attach(_workshop_button, &"workshop")
	IconArt.attach(_build_button, &"build")
	_workshop_button.pressed.connect(request_screen.emit.bind(&"crafting", {}))
	_build_button.pressed.connect(request_screen.emit.bind(&"build_site", {}))


func workshop_button() -> Button:
	return _workshop_button


func build_button() -> Button:
	return _build_button


## The machines on the shelf (finished builds, crafted lights), for tests.
func shelf_items() -> Array[WorkshopArt]:
	var items: Array[WorkshopArt] = []
	for child: Node in _shelf.get_children():
		items.append(child as WorkshopArt)
	return items


func machines_running() -> bool:
	return _machine_loop != null and _machine_loop.is_running()


func _add_machine_shelf() -> void:
	_shelf = HBoxContainer.new()
	_shelf.name = "MachineShelf"
	_shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	_shelf.add_theme_constant_override(&"separation", 32)
	var column: Node = _dig_button.get_parent().get_parent().get_parent() # DoorRow -> Center -> Column
	column.add_child(_shelf)
	column.move_child(_shelf, 1)
	for build: BuildProject in Rewards.builds():
		if Rewards.is_built(build.id):
			_add_to_shelf(build.id, BuildSiteScreen.finished_params(build.id), Vector2(3.0, 1.4))
	for recipe: Recipe in Rewards.recipes():
		if recipe.output_type == "decor" and Rewards.owns(recipe.output_id):
			_add_to_shelf(recipe.output_id, {}, Vector2(2.4 if recipe.output_id == &"hub_lanterns" else 1.2, 1.2))
	_shelf.visible = _shelf.get_child_count() > 0
	_start_machines()


func _add_to_shelf(kind: StringName, params: Dictionary, multiple: Vector2) -> void:
	var art: WorkshopArt = WorkshopArt.new()
	art.custom_minimum_size = UI.target_size(multiple.x, multiple.y)
	art.show_kind(kind, params)
	_shelf.add_child(art)


## One looping tween drives every machine's phase from 0 to 1 and back to 0.
func _start_machines() -> void:
	if _shelf.get_child_count() == 0 or machines_running():
		return
	_machine_loop = create_tween().set_loops()
	for art: WorkshopArt in shelf_items():
		_machine_loop.parallel().tween_property(art, "phase", 1.0, 3.0).from(0.0)


func _stop_machines() -> void:
	if _machine_loop != null:
		_machine_loop.kill()
		_machine_loop = null


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_EXIT_TREE:
			_stop_machines()
		NOTIFICATION_APPLICATION_RESUMED:
			if is_inside_tree():
				_start_machines()


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
