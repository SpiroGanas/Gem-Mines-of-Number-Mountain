## The Build Site (Sprint 16): the mine-engineering projects. Each row shows the machine, how far the
## build has come and a button to start or go on. A build appears once its skill opens; a build that
## opens a zone tells the child so (the balance elevator opens Zone 4, Conveyor Sync Zone 6). Finished
## machines also run in the hub.
class_name BuildSiteScreen
extends WorkshopScreen

const ROW_BUTTON_WIDTH_MULTIPLE: float = 3.5
## Bolt's line pointing at a build that keeps its zone closed (locks_zone), by build id.
const ZONE_HINT_LINES: Dictionary[StringName, StringName] = {
	&"balance_elevator": &"build.site.elevator_hint",
	&"conveyor_sync": &"build.site.conveyor_hint",
}

var _buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	super()
	build_frame(&"build.site.title")
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 20)
	body.add_child(UI.vertical_scroll(list)) # every zone adds builds: the list scrolls when it is long
	var any_open: bool = false
	for build: BuildProject in Rewards.builds():
		list.add_child(_make_row(build))
		any_open = any_open or Rewards.is_build_open(build.id)
	var hint: BuildProject = _zone_hint_build()
	if hint != null:
		bolt_node.say(ZONE_HINT_LINES[hint.id], {"n": hint.zone_unlocks})
	else:
		bolt_node.say(&"build.site.hello" if any_open else &"build.site.nothing_yet")


## The machine picture of a finished build, as the hub and the build site draw it.
static func finished_params(build_id: StringName) -> Dictionary:
	match build_id:
		&"cart_track":
			return {"a": 6, "c": 10, "filled": true}
		&"balance_elevator":
			return {"groups": 3, "size": 4, "balanced": true}
		&"conveyor_sync":
			return {"a": 4, "b": 6, "synced": true}
		&"alloy_mixer":
			return {"a": 2, "b": 3, "copper": 8, "tin": 12, "mixed": true}
		&"counterweight_elevator":
			return {"w": 8, "d": 2, "r": 4, "x": 4, "balanced": true}
	return {}


func button_for(build_id: StringName) -> Button:
	return _buttons.get(build_id)


## The open build that still keeps its zone closed, the earliest first (Bolt points the way), or null.
func _zone_hint_build() -> BuildProject:
	var locked: Array[int] = Adaptive.locked_zones()
	for build: BuildProject in Rewards.builds():
		if ZONE_HINT_LINES.has(build.id) and locked.has(build.zone_unlocks) and Rewards.is_build_open(build.id):
			return build
	return null


func _make_row(build: BuildProject) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 20)
	panel.add_child(row)
	var built: bool = Rewards.is_built(build.id)
	var art: WorkshopArt = WorkshopArt.new()
	art.custom_minimum_size = UI.target_size(3.0, 1.6)
	var preview: Dictionary = finished_params(build.id)
	if not built:
		preview["filled"] = false
		preview["balanced"] = false
		preview["synced"] = false
		preview["mixed"] = false
	art.show_kind(build.id, preview)
	row.add_child(art)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var name_label: Label = Label.new()
	name_label.text = Text.get_line(build.name_line_id)
	words.add_child(name_label)
	var status: Label = Label.new()
	status.name = "Status"
	var state: Dictionary = Rewards.build_state(build.id)
	if built:
		status.text = Text.get_line(&"build.site.built")
	elif int(state["step"]) > 0:
		status.text = Text.get_line(&"build.screen.progress", {"n": int(state["step"]) + 1, "total": build.step_count()})
	else:
		status.text = Text.get_line(&"build.site.opens_zone", {"n": build.zone_unlocks})
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(status)
	var button: Button = Button.new()
	button.name = "Build_%s" % build.id
	UI.make_touch_target(button, ROW_BUTTON_WIDTH_MULTIPLE, 1.2)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if built:
		button.text = Text.get_line(&"build.site.look")
	elif not Rewards.is_build_open(build.id):
		button.text = Text.get_line(&"build.site.not_yet")
		button.disabled = true
	elif int(state["step"]) > 0:
		button.text = Text.get_line(&"build.site.go_on")
	else:
		button.text = Text.get_line(&"build.site.start")
	button.pressed.connect(_on_build_pressed.bind(build.id))
	row.add_child(button)
	_buttons[build.id] = button
	return panel


func _on_build_pressed(build_id: StringName) -> void:
	sfx.play(&"select")
	request_screen.emit(&"build", {"build_id": build_id})
