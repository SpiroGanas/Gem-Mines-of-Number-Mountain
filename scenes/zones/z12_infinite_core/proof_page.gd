## One page of the Mathematician's Journal (Zone 12): the proof builder on its own, for one guided proof, with Bolt beside
## it. Reached from the journal with {proof_id}. Finishing the proof earns Bolt's cheer and nothing else: no coins, no gems,
## no saving (the proof skills are practiced and scored in the mine). Wrong steps cost nothing.
class_name ProofPageScreen
extends WorkshopScreen

var proof_id: StringName = &"proof.practice.even_plus_even"
var builder: ProofBuilder


func setup(args: Dictionary) -> void:
	proof_id = StringName(str(args.get("proof_id", proof_id)))


func _ready() -> void:
	super()
	var proof: Proof = ProofLoader.load_by_id(proof_id)
	build_frame(proof.title_line_id)
	back_to = &"journal"
	builder = load("res://scenes/zones/z12_infinite_core/proof_builder.tscn").instantiate()
	builder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(builder)
	builder.setup_proof(proof)
	builder.said.connect(func(line_id: StringName, params: Dictionary) -> void: bolt_node.say(line_id, params))
	builder.submitted.connect(_on_done)
	bolt_node.say(proof.intro_line_id)


func _on_done(_id: String) -> void:
	sfx.play(&"reward")
	bolt_node.say(&"z12.proofpage.done")


func music_id() -> StringName:
	return &""
