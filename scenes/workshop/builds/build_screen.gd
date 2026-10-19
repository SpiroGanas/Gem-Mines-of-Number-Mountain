## A build in progress (Sprint 16, P2-S16-03): runs a BuildProject's steps in order. Each step scene
## gets a Problem of its step's skill (ProblemCard: the answer is learning evidence and a miss costs
## nothing). A finished step is saved at once, so closing the app mid-build comes back to the same
## step. The last step finishes the machine: Bolt celebrates, and a build that opens a zone says so.
## The screen knows no particular build: everything comes from curriculum/builds.json.
class_name BuildScreen
extends WorkshopScreen

var build_id: StringName = &""
## Tests fix the seed; 0 means a different problem each time.
var seed_value: int = 0
## Passed on to each step (tests drive the slate).
var slate_override: Variant = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _build: BuildProject
var _progress: Label
var _step_host: Control
var _step: BuildStep
var _next_button: Button


func setup(args: Dictionary) -> void:
	build_id = StringName(str(args.get("build_id", build_id)))


func _ready() -> void:
	super()
	_build = Rewards.build(build_id)
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	one_row_header = true # the step's body column is wide; on a phone its height is what is short
	build_frame(_build.name_line_id if _build != null else &"build.site.title")
	back_to = &"build_site"
	body.size_flags_stretch_ratio = 6.0
	side.size_flags_stretch_ratio = 3.0
	_progress = Label.new()
	_progress.name = "Progress"
	body.add_child(_progress)
	_step_host = VBoxContainer.new()
	_step_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_step_host)
	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.theme_type_variation = &"GoButton"
	UI.make_touch_target(_next_button, 4.0, 1.4)
	_next_button.visible = false
	_next_button.pressed.connect(_on_next_pressed)
	side.add_child(_next_button)
	celebration.closed.connect(func() -> void: request_screen.emit(&"build_site", {}))
	if _build == null:
		bolt_node.say(&"build.site.hello")
		return
	if Rewards.is_built(build_id):
		_show_built()
		return
	bolt_node.say(_build.intro_line_id)
	_start_step()


func current_step() -> BuildStep:
	return _step


func next_button() -> Button:
	return _next_button


func _start_step() -> void:
	_next_button.visible = false
	var index: int = int(Rewards.build_state(build_id)["step"])
	_progress.text = Text.get_line(&"build.screen.progress", {"n": index + 1, "total": _build.step_count()})
	if _step != null:
		_step.queue_free()
		_step_host.remove_child(_step)
	var spec: Dictionary = _build.steps[index]
	_step = load(spec["scene"]).instantiate()
	_step.bolt = bolt_node
	_step.slate_override = slate_override
	_step.rng = _rng
	_step_host.add_child(_step)
	var skill: Skill = Adaptive.catalog().skill(spec["skill_id"])
	var overrides: Dictionary = {"representation": Adaptive.engine.scheduler.representation_for(skill, Adaptive.engine.record_for(skill.id), false)}
	overrides.merge(spec["params"], true)
	_step.setup(GeneratorRegistry.make_problem(skill, _rng.randi(), overrides))
	_step.step_completed.connect(_on_step_completed, CONNECT_ONE_SHOT)


func _on_step_completed() -> void:
	var done: bool = Rewards.finish_build_step(build_id)
	sfx.play(&"build_step")
	if done:
		var items: Array[Dictionary] = [{"line_id": _build.reward_line_id, "gem": GemArt.gem_for_zone(_build.zone_unlocks), "params": {"n": _build.zone_unlocks}}]
		celebration.celebrate(items)
		return
	_next_button.text = Text.get_line(&"build.screen.next")
	_next_button.visible = true
	_next_button.grab_focus()


func _on_next_pressed() -> void:
	sfx.play(&"tap")
	_start_step()


func _show_built() -> void:
	_progress.text = Text.get_line(&"build.site.built")
	var art: WorkshopArt = WorkshopArt.new()
	art.custom_minimum_size = UI.target_size(6.0, 3.0)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_host.add_child(art)
	art.show_kind(_build.id, BuildSiteScreen.finished_params(_build.id)) # each build's id names its machine art
	bolt_node.say(_build.reward_line_id, {"n": _build.zone_unlocks})
