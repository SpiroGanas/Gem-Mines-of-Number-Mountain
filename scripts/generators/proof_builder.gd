## The guided proofs of Zone 12, The Infinite Core (skills proof.euclid.infinite_primes and proof.sqrt2.irrational): the rock
## is a proof to build. The child places the steps of the proof (curriculum/proofs/<id>.json) in their slots, says why
## each is true and presses Check; ProofValidator judges it. The answer is the proof's id, given when the proof is
## complete (the builder never gives it before). Pure: the problem is the same every time, so the rng is only used for the
## worked example's pick.
##
## params.proof_id  the proof of the skill (ProofLoader).
## meta.proof_builder  {proof_id}: the input the answer panel shows.
## The hint rungs: the prompt, the proof's steps as cards in order with arrows, the practice proof "even plus even"
## as the worked example, and an easier problem (the same proof: the builder has its own gentle hints).
class_name ProofBuilderGenerator
extends RefCounted

const PROMPT: StringName = &"z12.proof.prompt_build"
const PRACTICE_ID: StringName = &"proof.practice.even_plus_even"


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var proof_id: StringName = StringName(str(params.get("proof_id", PRACTICE_ID)))
	var proof: Proof = ProofLoader.load_by_id(proof_id)
	assert(proof != null, "no proof %s" % proof_id)
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	problem.prompt_line_id = PROMPT
	problem.prompt_params = {}
	problem.answer = String(proof_id)
	problem.meta = {"proof_builder": {"proof_id": String(proof_id)}}
	var model: Dictionary = model_picture(proof)
	if with_hints:
		var practice: Proof = ProofLoader.load_by_id(PRACTICE_ID)
		var example: Problem = GeneratorKit.new_problem(skill, params, problem.representation)
		example.prompt_line_id = practice.intro_line_id
		example.prompt_params = {}
		example.answer = String(PRACTICE_ID)
		example.visual = model_picture(practice)
		GeneratorKit.add_hints(problem, model, example, {"line_id": &"z12.hint.example_guided", "params": {}})
	return problem


## The proof's steps as numbered cards in order, with arrows between them.
static func model_picture(proof: Proof) -> Dictionary:
	var cards: Array[Dictionary] = []
	for index: int in proof.steps.size():
		cards.append({"line_id": proof.steps[index]["line_id"], "n": index + 1})
	return ProofStepsGenerator.statements_picture(cards, 0, true)
