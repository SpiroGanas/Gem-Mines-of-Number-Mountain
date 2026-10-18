## The Challenge Door (Sprint 19, P2-S19-04): a quick learner can test out of a frontier skill.
## Three problems of the skill at its hardest settings, presented like rocks, with no timer and no
## countdown. Three right: the skill is mastered (evidence "challenge"). The first miss closes the
## door until tomorrow; it is not a wrong answer anywhere (BKT never hears of door answers) and
## nothing is lost. Spiro approved this mastery path (docs/decisions.md, Sprint 19).
class_name ChallengeDoorScreen
extends WorkshopScreen

var skill_id: StringName = &""
## Tests fix the seed; 0 means different problems each time.
var seed_value: int = 0
var slate_override: Variant = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _problems: Array[Problem] = []
var _index: int = 0
var _card: ProblemCard
var _progress: Label
var _door: DoorArt
var _finished: bool = false


func setup(args: Dictionary) -> void:
	skill_id = StringName(str(args.get("skill_id", skill_id)))


func _ready() -> void:
	super()
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	build_frame(&"door.screen.title")
	back_to = &"mine"
	back_button.text = Text.get_line(&"door.screen.back")
	_door = DoorArt.new()
	_door.custom_minimum_size = UI.target_size(3.0, 4.0)
	_door.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(_door)
	_progress = Label.new()
	_progress.name = "Progress"
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_progress)
	_card = make_card()
	_card.practice = false
	_card.slate_override = slate_override
	_card.solved.connect(_on_solved)
	_card.missed.connect(_on_missed)
	celebration.closed.connect(func() -> void: request_screen.emit(&"mine", {}))
	if not Adaptive.catalog().has_skill(skill_id):
		_finished = true
		bolt_node.say(&"door.screen.intro")
		return
	_problems = Adaptive.challenge(skill_id, _rng)
	_show_problem()


func card() -> ProblemCard:
	return _card


func is_finished() -> bool:
	return _finished


func _show_problem() -> void:
	_progress.text = Text.get_line(&"door.screen.progress", {"n": _index + 1, "total": _problems.size()})
	_door.opened = float(_index) / float(_problems.size())
	_card.show_problem(_problems[_index], _rng)
	bolt_node.add_note(&"door.screen.intro")


func _on_solved(_problem: Problem) -> void:
	_index += 1
	sfx.play(&"crack")
	if _index < _problems.size():
		_show_problem()
		return
	_finished = true
	_door.opened = 1.0
	Adaptive.pass_challenge(skill_id)
	celebration.celebrate([{"line_id": &"door.screen.passed", "gem": RewardsRules.MASTERY_GEM}])


func _on_missed(_rung: HintLadder.Rung) -> void:
	_finished = true
	_card.set_enabled(false)
	Adaptive.fail_challenge(skill_id)
	bolt_node.say(&"door.screen.closed")


## The door: a stone arch whose two halves slide apart as answers come in (0 shut, 1 open), with an
## electric lamp above it.
class DoorArt extends Control:
	var opened: float = 0.0:
		set(value):
			opened = clampf(value, 0.0, 1.0)
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var arch: Rect2 = Rect2(size * Vector2(0.1, 0.15), size * Vector2(0.8, 0.85))
		draw_rect(arch, Color("#3A4466"))
		draw_circle(Vector2(size.x * 0.5, size.y * 0.15), size.x * 0.4, Color("#3A4466"))
		draw_rect(Rect2(arch.position + Vector2(arch.size.x * 0.1, arch.size.y * 0.1), arch.size * Vector2(0.8, 0.9)), Color("#FFE9A8", 0.25 + 0.6 * opened))
		var half: float = arch.size.x * 0.4 * (1.0 - opened)
		var door_top: float = arch.position.y + arch.size.y * 0.1
		draw_rect(Rect2(Vector2(arch.position.x + arch.size.x * 0.1, door_top), Vector2(half, arch.size.y * 0.9)), Color("#8A96B3"))
		draw_rect(Rect2(Vector2(arch.end.x - arch.size.x * 0.1 - half, door_top), Vector2(half, arch.size.y * 0.9)), Color("#8A96B3"))
		draw_circle(Vector2(size.x * 0.5, size.y * 0.06), size.x * 0.06, Color("#FFD166"))
