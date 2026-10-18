## One step of a build project (Sprint 16, P2-S16-03): the machine's picture above a problem card.
## The build screen hands it a Problem with setup(); a right answer finishes the machine part in the
## picture and emits step_completed. A step knows nothing about which build it belongs to; each step
## scene (cart_track.tscn, balance_elevator.tscn) only says how to draw the problem as its machine.
class_name BuildStep
extends VBoxContainer

signal step_completed

## Bolt reads the problem (set by the build screen before setup()).
var bolt: Bolt
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Tests set these to drive the slate (see AnswerPanel).
var slate_override: Variant = null
var recognizer: Recognizer

var problem: Problem
var art: WorkshopArt
var card: ProblemCard


func _ready() -> void:
	add_theme_constant_override(&"separation", 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	art = WorkshopArt.new()
	art.name = "MachineArt"
	art.custom_minimum_size = UI.target_size(6.0, 2.6)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(art)
	card = ProblemCard.new()
	card.name = "ProblemCard"
	add_child(card)
	card.solved.connect(_on_solved)


func setup(new_problem: Problem) -> void:
	problem = new_problem
	card.bolt = bolt
	card.slate_override = slate_override
	card.recognizer = recognizer
	art.show_kind(art_kind(), art_params(problem, false))
	card.show_problem(problem, rng)


## The WorkshopArt kind this step draws. Subclasses override.
func art_kind() -> StringName:
	return &""


## The picture's numbers for the problem; `solved` draws the finished part. Subclasses override.
func art_params(_for_problem: Problem, _solved: bool) -> Dictionary:
	return {}


func _on_solved(_solved_problem: Problem) -> void:
	art.show_kind(art_kind(), art_params(problem, true))
	var roll: Tween = create_tween()
	roll.tween_property(art, "phase", 1.0, 1.2).from(0.0)
	step_completed.emit()
