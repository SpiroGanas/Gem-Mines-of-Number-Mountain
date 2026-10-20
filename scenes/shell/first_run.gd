## First run (P1-S10-03): the first time the game opens on a profile with no nickname, Bolt says
## hello, the child picks a miner name from big preset buttons (no typing: CLAUDE.md rule 6; a
## grown-up can enter the real name in the parent area), and Bolt hands off to the placement quest
## ("let's explore the mountain"). Three short steps, a picture (Bolt) beside every line, and one
## big button per step, so a first-grade reader can start alone.
##
## Phase 3 profiles: a child whose grown-up already typed a nickname (parent onboarding, or a profile
## made in the parent area) skips the name step: Bolt says hello and then "let's explore". Finishing
## the first run marks the profile as welcomed (profile.welcomed in the save, schema v3).
class_name FirstRunScreen
extends ShellScreen

enum Step { HELLO, NAME, READY }

## Preset miner names, each a line in the text table.
const NAME_LINES: Array[StringName] = [
	&"firstrun.name.spark", &"firstrun.name.pebble", &"firstrun.name.comet", &"firstrun.name.nova",
	&"firstrun.name.crystal", &"firstrun.name.digger", &"firstrun.name.rocket", &"firstrun.name.echo",
]

var step: Step = Step.HELLO

var _bolt: Bolt
var _body: VBoxContainer
var _sfx: SfxBank


func _ready() -> void:
	super()
	_sfx = SfxBank.new()
	add_child(_sfx)
	add_child(Backdrop.new())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 64)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 48)
	margin.add_child(column)
	_bolt = load("res://scenes/mine/bolt.tscn").instantiate()
	column.add_child(_bolt)
	_body = VBoxContainer.new()
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 24)
	column.add_child(_body)
	show_step(Step.HELLO)


func bolt() -> Bolt:
	return _bolt


## The big button that moves on from the current step (null on the name step).
func next_button() -> Button:
	return _body.find_child("NextButton", true, false)


## The preset name buttons (name step only).
func name_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for node: Node in _body.find_children("Name_*", "Button", true, false):
		buttons.append(node)
	return buttons


func show_step(next: Step) -> void:
	step = next
	for child: Node in _body.get_children():
		child.queue_free()
		_body.remove_child(child)
	match step:
		Step.HELLO:
			_bolt.say(&"bolt.first_run.hello")
			_bolt.note(&"bolt.first_run.lamp")
			_add_next(&"ui.common.next", show_step.bind(Step.READY if has_nickname() else Step.NAME))
		Step.NAME:
			_bolt.say(&"bolt.first_run.name")
			_bolt.note(&"bolt.first_run.grownup")
			var grid: GridContainer = GridContainer.new()
			grid.columns = 4
			grid.add_theme_constant_override(&"h_separation", 24)
			grid.add_theme_constant_override(&"v_separation", 24)
			grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_body.add_child(grid)
			for line_id: StringName in NAME_LINES:
				var button: Button = Button.new()
				button.name = "Name_%s" % String(line_id).get_slice(".", 2)
				button.text = Text.get_line(line_id)
				button.focus_mode = Control.FOCUS_NONE
				UI.make_touch_target(button, 3.5, 1.5)
				button.pressed.connect(choose_name.bind(line_id))
				grid.add_child(button)
		Step.READY:
			_bolt.say(&"bolt.first_run.ready")
			_add_next(&"ui.first_run.start", start_digging)


## True when a grown-up already gave this child a nickname (the name step is skipped).
func has_nickname() -> bool:
	return not str(SaveSystem.data()["child"].get("nickname", "")).is_empty()


## Saves the chosen preset name as the nickname and moves on.
func choose_name(line_id: StringName) -> void:
	_sfx.play(&"select")
	SaveSystem.data()["child"]["nickname"] = Text.get_line(line_id)
	SaveSystem.save_now()
	show_step(Step.READY)


## The hand-off: the first dig is the placement quest.
func start_digging() -> void:
	_sfx.play(&"tap")
	SaveSystem.data()["profile"]["welcomed"] = true
	SaveSystem.save_now()
	if Adaptive.needs_placement() and not Adaptive.placement_active():
		Adaptive.start_placement()
	request_screen.emit(&"mine", {})


func _add_next(line_id: StringName, action: Callable) -> void:
	var button: Button = Button.new()
	button.name = "NextButton"
	button.text = Text.get_line(line_id)
	button.theme_type_variation = &"GoButton"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(button, 4.0, 1.8)
	button.pressed.connect(func() -> void:
		_sfx.play(&"tap")
		action.call())
	_body.add_child(button)
