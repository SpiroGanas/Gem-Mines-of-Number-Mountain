## Proof without words for Zone 9, Pattern Grotto (skill proof.words.match). A picture made of two
## pieces (two staircases, two triangles, odd layers, a turned array, Fibonacci squares) proves a fact;
## the child fits the pieces together on the proof board and picks the fact it shows. The answer is the
## diagram's id; every wrong answer is another diagram's id (`wrong_diagram`). The diagrams, their fact
## lines and their sizes come from curriculum/proof_diagrams.json (read once). There is no arithmetic:
## the checker validates the ids against the same file.
##   params.choices  how many facts to offer (the answer and choices - 1 others, 2 to 4)
## meta.label_lines gives each id its fact line; meta.proof_board {diagram, n, choices} drives the board.
## Pure: only the passed-in rng is used.
class_name ProofGenerator
extends RefCounted

const PATH: String = "res://curriculum/proof_diagrams.json"

static var _diagrams: Array[Dictionary] = []


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## Every diagram {id, label_line_id, min_n, max_n, explains}, in file order.
static func diagrams() -> Array[Dictionary]:
	if _diagrams.is_empty():
		var data: Variant = JsonUtil.parse_file(PATH)
		if data is Dictionary and data.get("diagrams") is Array:
			for entry: Variant in data["diagrams"]:
				if entry is Dictionary:
					_diagrams.append(JsonUtil.intify(entry))
	return _diagrams


static func diagram(id: String) -> Dictionary:
	for entry: Dictionary in diagrams():
		if str(entry["id"]) == id:
			return entry
	return {}


## A `proof` picture: the diagram drawn at size n, its loose piece apart or fitted into place.
static func picture(id: String, n: int, fitted: bool) -> Dictionary:
	return {"type": "proof", "diagram": id, "n": n, "fitted": fitted}


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var all: Array[Dictionary] = diagrams()
	var chosen: Dictionary = all[rng.randi_range(0, all.size() - 1)]
	var id: String = str(chosen["id"])
	var high: int = int(chosen["max_n"])
	if GeneratorKit.difficulty_of(params) < 0:
		high = int(chosen["min_n"]) # easier: the smallest picture
	var n: int = rng.randi_range(int(chosen["min_n"]), high)
	problem.prompt_line_id = &"z9.proof.prompt"
	problem.answer = id
	var labels: Dictionary = {}
	for entry: Dictionary in all:
		labels[str(entry["id"])] = str(entry["label_line_id"])
	problem.meta = {"label_lines": labels}
	var others: Array[int] = []
	for index: int in all.size():
		if str(all[index]["id"]) != id:
			others.append(index)
	var wanted: int = clampi(int(params.get("choices", 4)), 2, 4) - 1
	for index: int in GeneratorKit.shuffled_ints(others, rng).slice(0, wanted):
		GeneratorKit.add_distractor(problem, skill, str(all[index]["id"]), &"wrong_diagram")
	var choices: Array = [id]
	choices.append_array(problem.distractor_values())
	choices.sort()
	problem.meta["proof_board"] = {"diagram": id, "n": n, "choices": choices}
	problem.visual = picture(id, n, false)
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		var line: StringName = StringName(str(diagram(str(example.answer)).get("label_line_id", "z9.proof.prompt")))
		GeneratorKit.add_hints(problem, picture(id, n, true), example, {"line_id": line, "params": {}})
	return problem
