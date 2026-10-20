## Short proofs for Zone 12, The Infinite Core (skills proof.parts.identify, proof.order.chain, proof.justify.step and
## proof.contradiction.recognize). A proof is a chain of statements in which every step has a reason; here the chains are
## three or four steps long (curriculum/mini_proofs.json, read once). The statements are drawn as numbered cards (the
## `statements` picture) and every question is answered by a card's number, so the prompts need no words of the proof.
## Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   parts          "Which step is where the proof starts / ends?" The cards are shuffled; the answer is the number on the
##                  first (or last) step of the proof.
##   order          "Put the steps in the order of the proof." The cards are shuffled; the answer is their numbers in the
##                  order of the proof (a tile board, `ordered`).
##   justify        "Why is step {k} true?" The cards are in proof order; the answer is the reason (assume, meaning,
##                  arithmetic or previous), a choice whose buttons read `z12.why.<reason>`.
##   contradiction  "Which step cannot be true if step 1 is true?" The cards are in order; the answer is the number of the
##                  step that clashes with step 1.
##
## The named mistakes:
##   picked_conclusion_as_assumption  the last step for "where it starts";
##   picked_assumption_as_conclusion  the first step for "where it ends";
##   picked_middle_step               a step in the middle;
##   reversed_chain                   the steps in backward order;
##   swapped_two_steps                two neighbouring steps the wrong way round;
##   circular_reasoning               "it follows from the steps before" for the first step, or a made-up start for a
##                                    step that follows;
##   mixed_up_reason                  any other wrong reason;
##   missed_contradiction             a step that fits with step 1.
class_name ProofStepsGenerator
extends RefCounted

const PATH: String = "res://curriculum/mini_proofs.json"
const MAX_CARDS: int = 8
const REASONS: Array[String] = ["assume", "meaning", "arithmetic", "previous"]
const PROMPT_ASSUMPTION: StringName = &"z12.proof.prompt_assumption"
const PROMPT_CONCLUSION: StringName = &"z12.proof.prompt_conclusion"
const PROMPT_ORDER: StringName = &"z12.proof.prompt_order"
const PROMPT_JUSTIFY: StringName = &"z12.proof.prompt_justify"
const PROMPT_CONTRADICTION: StringName = &"z12.proof.prompt_contradiction"

static var _data: Dictionary = {}


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## The mini proofs: {reasons, chains: [{id, steps: [{line_id, reason}]}], clashes: [{id, clash, steps: [line_id]}]}.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JsonUtil.parse_file(PATH)
		if parsed is Dictionary:
			_data = JsonUtil.intify(parsed)
	return _data


## A `statements` picture: the cards (each {line_id, n}), optionally one lit and arrows between the cards.
static func statements_picture(cards: Array[Dictionary], lit: int = 0, arrows: bool = false) -> Dictionary:
	var picture: Dictionary = {"type": "statements", "cards": cards}
	if lit > 0:
		picture["lit"] = lit
	if arrows:
		picture["arrows"] = true
	return picture


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "parts"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var easy: bool = GeneratorKit.difficulty_of(params) < 0
	var model: Dictionary
	match mode:
		"parts":
			model = _parts(problem, skill, rng, easy)
		"order":
			model = _order(problem, skill, rng, easy)
		"justify":
			model = _justify(problem, skill, rng, easy)
		"contradiction":
			model = _contradiction(problem, skill, rng, easy)
		_:
			push_error("ProofStepsGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


## A chain (3 or 4 steps; the easier problems prefer the 3-step ones) chosen by the rng.
static func _chain(rng: RandomNumberGenerator, easy: bool) -> Dictionary:
	var chains: Array = data()["chains"]
	var pool: Array = []
	for entry: Dictionary in chains:
		if not easy or entry["steps"].size() == 3:
			pool.append(entry)
	return pool[rng.randi_range(0, pool.size() - 1)]


## The cards for `line_ids` shown in the order of `order` (indexes into line_ids): card n is the n-th card on the table.
static func _cards(line_ids: Array[StringName], order: Array[int]) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for shown: int in order.size():
		cards.append({"line_id": line_ids[order[shown]], "n": shown + 1})
	return cards


static func _in_order(count: int) -> Array[int]:
	var order: Array[int] = []
	for index: int in count:
		order.append(index)
	return order


static func _line_ids(chain: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for step: Dictionary in chain["steps"]:
		ids.append(StringName(str(step["line_id"])))
	return ids


## A shuffle of 0..count-1 that is never the proof's own order.
static func _scrambled(count: int, rng: RandomNumberGenerator) -> Array[int]:
	var order: Array[int] = GeneratorKit.shuffled_ints(_in_order(count), rng)
	for attempt: int in 20:
		if order != _in_order(count):
			break
		order = GeneratorKit.shuffled_ints(_in_order(count), rng)
	if order == _in_order(count):
		order.reverse()
	return order


static func _parts(problem: Problem, skill: Skill, rng: RandomNumberGenerator, easy: bool) -> Dictionary:
	var chain: Dictionary = _chain(rng, easy)
	var ids: Array[StringName] = _line_ids(chain)
	var order: Array[int] = _scrambled(ids.size(), rng)
	var starts: bool = rng.randi_range(0, 1) == 0
	var first_card: int = order.find(0) + 1
	var last_card: int = order.find(ids.size() - 1) + 1
	problem.prompt_line_id = PROMPT_ASSUMPTION if starts else PROMPT_CONCLUSION
	problem.prompt_params = {}
	problem.answer = first_card if starts else last_card
	problem.meta = {"chain": chain["id"], "starts": starts, "order": order}
	problem.visual = statements_picture(_cards(ids, order))
	GeneratorKit.add_distractor(problem, skill, last_card if starts else first_card,
		&"picked_conclusion_as_assumption" if starts else &"picked_assumption_as_conclusion")
	for card: int in range(1, ids.size() + 1):
		if card != first_card and card != last_card:
			GeneratorKit.add_distractor(problem, skill, card, &"picked_middle_step")
	return statements_picture(_cards(ids, _in_order(ids.size())), 1 if starts else ids.size(), true)


static func _order(problem: Problem, skill: Skill, rng: RandomNumberGenerator, easy: bool) -> Dictionary:
	var chain: Dictionary = _chain(rng, easy)
	var ids: Array[StringName] = _line_ids(chain)
	var count: int = ids.size()
	var order: Array[int] = _scrambled(count, rng)
	var answer: Array[int] = []
	for step: int in count:
		answer.append(order.find(step) + 1)
	problem.prompt_line_id = PROMPT_ORDER
	problem.prompt_params = {}
	problem.answer = answer
	problem.meta = {"chain": chain["id"], "order": order}
	var tiles: Array[int] = []
	for card: int in range(1, count + 1):
		tiles.append(card)
	problem.meta["tile_board"] = {"tiles": tiles, "slots": count, "ordered": true}
	problem.visual = statements_picture(_cards(ids, order))
	var reversed: Array[int] = answer.duplicate()
	reversed.reverse()
	GeneratorKit.add_distractor(problem, skill, reversed, &"reversed_chain")
	for first: int in range(count - 1):
		var swapped: Array[int] = answer.duplicate()
		var held: int = swapped[first]
		swapped[first] = swapped[first + 1]
		swapped[first + 1] = held
		GeneratorKit.add_distractor(problem, skill, swapped, &"swapped_two_steps")
	return statements_picture(_cards(ids, _in_order(count)), 0, true)


static func _justify(problem: Problem, skill: Skill, rng: RandomNumberGenerator, easy: bool) -> Dictionary:
	var chain: Dictionary = _chain(rng, easy)
	var ids: Array[StringName] = _line_ids(chain)
	var steps: Array = chain["steps"]
	var k: int = rng.randi_range(1, ids.size())
	var reason: String = str(steps[k - 1]["reason"])
	problem.prompt_line_id = PROMPT_JUSTIFY
	problem.prompt_params = {"k": k}
	problem.answer = StringName(reason)
	var labels: Dictionary = {}
	for each: String in REASONS:
		labels[each] = "z12.why." + each
	problem.meta = {"chain": chain["id"], "label_lines": labels}
	problem.visual = statements_picture(_cards(ids, _in_order(ids.size())), k)
	for each: String in REASONS:
		if each == reason:
			continue
		var circular: bool = (each == "previous" and reason == "assume") or (each == "assume" and reason == "previous")
		GeneratorKit.add_distractor(problem, skill, StringName(each), &"circular_reasoning" if circular else &"mixed_up_reason")
	return statements_picture(_cards(ids, _in_order(ids.size())), k, true)


static func _contradiction(problem: Problem, skill: Skill, rng: RandomNumberGenerator, easy: bool) -> Dictionary:
	var sets: Array = data()["clashes"]
	var pool: Array = []
	for entry: Dictionary in sets:
		if not easy or entry["steps"].size() == 3:
			pool.append(entry)
	var chosen: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var ids: Array[StringName] = []
	for line: Variant in chosen["steps"]:
		ids.append(StringName(str(line)))
	var clash: int = int(chosen["clash"])
	problem.prompt_line_id = PROMPT_CONTRADICTION
	problem.prompt_params = {}
	problem.answer = clash
	problem.meta = {"set": chosen["id"]}
	problem.visual = statements_picture(_cards(ids, _in_order(ids.size())))
	for step: int in range(2, ids.size() + 1):
		GeneratorKit.add_distractor(problem, skill, step, &"missed_contradiction")
	return statements_picture(_cards(ids, _in_order(ids.size())), clash, true)


static func _example_line(mode: String, example: Problem) -> Dictionary:
	match mode:
		"parts":
			if example.meta.get("starts", true):
				return {"line_id": &"z12.hint.example_parts_assumption", "params": {"n": example.answer}}
			return {"line_id": &"z12.hint.example_parts_conclusion", "params": {"n": example.answer}}
		"order":
			return {"line_id": &"z12.hint.example_order", "params": {"n": int(example.answer[0])}}
		"justify":
			return {"line_id": StringName("z12.hint.example_justify_" + str(example.answer)), "params": {"k": int(example.prompt_params["k"])}}
	return {"line_id": &"z12.hint.example_contradiction", "params": {"k": int(example.answer)}}
