# ProofValidator, ProofLoader and the guided proofs of Zone 12 (curriculum/proofs/*.json). Table-driven: every error
# kind, partial against strict order, decoys, next_valid_tiles, and a fixture walk of each proof file.
class_name ProofValidatorTest
extends GdUnitTestSuite


func _proof(id: StringName) -> Proof:
	return ProofLoader.load_by_id(id)


func _slots(pairs: Array) -> Array[Dictionary]:
	var placement: Array[Dictionary] = []
	for pair: Array in pairs:
		placement.append({"tile": StringName(pair[0]), "why": StringName(pair[1])})
	return placement


func _canonical(proof: Proof) -> Array[Dictionary]:
	var placement: Array[Dictionary] = []
	for step: Dictionary in proof.steps:
		placement.append({"tile": step["id"], "why": step["justification"]})
	return placement


func _orders(proof: Proof) -> Array[Array]:
	var ids: Array[StringName] = []
	for step: Dictionary in proof.steps:
		ids.append(step["id"])
	var found: Array[Array] = []
	_permute(proof, ids, [] as Array[StringName], found)
	return found


func _permute(proof: Proof, remaining: Array[StringName], chosen: Array[StringName], found: Array[Array]) -> void:
	if remaining.is_empty():
		found.append(chosen.duplicate())
		return
	for index: int in remaining.size():
		var next: StringName = remaining[index]
		var ready: bool = true
		for dep: StringName in proof.depends_on(next):
			ready = ready and chosen.has(dep)
		if not ready:
			continue
		var rest: Array[StringName] = remaining.duplicate()
		rest.remove_at(index)
		chosen.append(next)
		_permute(proof, rest, chosen, found)
		chosen.pop_back()


func test_the_loader_finds_every_proof_file() -> void:
	var ids: Array[StringName] = []
	for proof: Proof in ProofLoader.load_all():
		ids.append(proof.id)
	assert_array(ids).contains([&"proof.practice.even_plus_even", &"proof.euclid.infinite_primes", &"proof.sqrt2.irrational"])


func test_the_loader_rejects_a_bad_file() -> void:
	assert_object(ProofLoader.parse({"schema_version": 2})["proof"]).is_null()
	var base: Dictionary = {
		"schema_version": 1, "id": "x", "title_line_id": "a", "intro_line_id": "b", "orderings": "strict",
		"justifications": ["assume"],
		"steps": [
			{"id": "s1", "line_id": "l", "justification": "assume", "depends_on": []},
			{"id": "s1", "line_id": "l", "justification": "assume", "depends_on": []},
			{"id": "s3", "line_id": "l", "justification": "assume", "depends_on": ["s1"]}],
		"decoys": []}
	assert_object(ProofLoader.parse(base)["proof"]).is_null() # a repeated step id
	base["steps"][1]["id"] = "s2"
	assert_object(ProofLoader.parse(base)["proof"]).is_not_null()
	base["steps"][2]["depends_on"] = ["s9"]
	assert_object(ProofLoader.parse(base)["proof"]).is_null() # depends on a step that does not exist
	base["steps"][2]["depends_on"] = ["s1"]
	base["steps"][2]["justification"] = "nonsense"
	assert_object(ProofLoader.parse(base)["proof"]).is_null() # a reason that is not offered


func test_the_canonical_walk_of_every_proof_completes() -> void:
	for proof: Proof in ProofLoader.load_all():
		var result: ProofResult = ProofValidator.validate(proof, _canonical(proof))
		assert_bool(result.complete).override_failure_message(String(proof.id)).is_true()
		assert_array(result.errors).is_empty()


func test_every_valid_order_of_a_partial_proof_completes_and_strict_proofs_have_one() -> void:
	for proof: Proof in ProofLoader.load_all():
		var orders: Array[Array] = _orders(proof)
		if proof.strict_order:
			var placement: Array[Dictionary] = _canonical(proof)
			placement.reverse()
			assert_bool(ProofValidator.validate(proof, placement).has_kind("order")).is_true()
			continue
		assert_bool(orders.size() > 1).override_failure_message(String(proof.id)).is_true()
		for order: Array in orders:
			var placement: Array[Dictionary] = []
			for id: StringName in order:
				placement.append({"tile": id, "why": proof.step(id)["justification"]})
			assert_bool(ProofValidator.validate(proof, placement).complete).override_failure_message("%s %s" % [proof.id, order]).is_true()


func test_a_step_before_one_it_needs_is_an_order_error() -> void:
	var proof: Proof = _proof(&"proof.euclid.infinite_primes")
	var placement: Array[Dictionary] = _canonical(proof)
	var held: Dictionary = placement[2]
	placement[2] = placement[1]
	placement[1] = held # s1, s3, s2: s3 before s2
	var result: ProofResult = ProofValidator.validate(proof, placement)
	assert_bool(result.complete).is_false()
	assert_str(str(result.error_at(1)["kind"])).is_equal("order")


func test_a_swap_in_a_strict_proof_is_an_order_error() -> void:
	var proof: Proof = _proof(&"proof.sqrt2.irrational")
	var placement: Array[Dictionary] = _canonical(proof)
	var held: Dictionary = placement[3]
	placement[3] = placement[4]
	placement[4] = held
	assert_bool(ProofValidator.validate(proof, placement).has_kind("order")).is_true()


func test_every_decoy_gives_its_error_and_its_mistake() -> void:
	for proof: Proof in ProofLoader.load_all():
		for decoy: Dictionary in proof.decoys:
			var placement: Array[Dictionary] = _canonical(proof)
			placement[0] = {"tile": decoy["id"], "why": &"assume"}
			var result: ProofResult = ProofValidator.validate(proof, placement)
			assert_bool(result.complete).is_false()
			assert_str(str(result.error_at(0)["kind"])).is_equal("decoy")
			assert_str(str(result.error_at(0)["misconception"])).is_equal(str(decoy["misconception"]))


func test_a_wrong_or_missing_reason_and_an_empty_slot() -> void:
	var proof: Proof = _proof(&"proof.practice.even_plus_even")
	var placement: Array[Dictionary] = _canonical(proof)
	placement[1]["why"] = &"arithmetic"
	assert_str(str(ProofValidator.validate(proof, placement).error_at(1)["kind"])).is_equal("justification")
	placement[1]["why"] = &""
	assert_bool(ProofValidator.validate(proof, placement).has_kind("justification")).is_true()
	placement[1]["tile"] = &""
	assert_str(str(ProofValidator.validate(proof, placement).error_at(1)["kind"])).is_equal("missing")
	assert_bool(ProofValidator.validate(proof, []).complete).is_false()


func test_a_tile_placed_twice_is_a_duplicate() -> void:
	var proof: Proof = _proof(&"proof.practice.even_plus_even")
	var placement: Array[Dictionary] = _canonical(proof)
	placement[2]["tile"] = &"s1"
	assert_str(str(ProofValidator.validate(proof, placement).error_at(2)["kind"])).is_equal("duplicate")


func test_next_valid_tiles() -> void:
	var euclid: Proof = _proof(&"proof.euclid.infinite_primes")
	assert_array(ProofValidator.next_valid_tiles(euclid, [] as Array[Dictionary])).contains_exactly([&"s1"])
	var after_s3: Array[Dictionary] = _canonical(euclid).slice(0, 3)
	assert_array(ProofValidator.next_valid_tiles(euclid, after_s3)).contains_exactly([&"s4", &"s5"])
	var strict: Proof = _proof(&"proof.sqrt2.irrational")
	assert_array(ProofValidator.next_valid_tiles(strict, _canonical(strict).slice(0, 2))).contains_exactly([&"s3"])
	var wrong: Array[Dictionary] = _slots([["s2", "assume"]])
	assert_array(ProofValidator.next_valid_tiles(strict, wrong)).is_empty()


## Peer review 05: a step already sitting past an empty slot is never offered for that slot (the builder's hint looped on it).
func test_next_valid_tiles_skips_steps_already_on_the_board_past_a_gap() -> void:
	var euclid: Proof = _proof(&"proof.euclid.infinite_primes")
	var gap: Array[Dictionary] = _slots([["s1", "assume"], ["", ""], ["s2", "build"]])
	assert_array(ProofValidator.next_valid_tiles(euclid, gap)).is_empty() # only s2 fits slot 1, and s2 is on the board
	var later: Array[Dictionary] = _slots([["s1", "assume"], ["s2", "build"], ["s3", "build"], ["", ""], ["s4", "arithmetic"]])
	assert_array(ProofValidator.next_valid_tiles(euclid, later)).contains_exactly([&"s5"])
	var strict: Proof = _proof(&"proof.sqrt2.irrational")
	var strict_gap: Array[Dictionary] = _slots([["s1", strict.steps[0]["justification"]], ["", ""], ["s2", strict.steps[1]["justification"]]])
	assert_array(ProofValidator.next_valid_tiles(strict, strict_gap)).is_empty()


func test_every_proof_file_is_well_formed_and_its_lines_exist() -> void:
	for proof: Proof in ProofLoader.load_all():
		assert_bool(Text.has_line(proof.title_line_id)).override_failure_message(String(proof.id)).is_true()
		assert_bool(Text.has_line(proof.intro_line_id)).is_true()
		for chip: StringName in proof.justifications:
			assert_bool(Text.has_line(StringName("z12.why." + chip))).override_failure_message(String(chip)).is_true()
		for tile: Dictionary in proof.steps + proof.decoys:
			assert_bool(Text.has_line(tile["line_id"])).override_failure_message(String(tile["line_id"])).is_true()
		for decoy: Dictionary in proof.decoys:
			assert_bool(Text.has_line(StringName("z12.proof.fb." + str(decoy["misconception"])))).override_failure_message(str(decoy["misconception"])).is_true()
		assert_bool(proof.steps.size() >= 3 and proof.steps.size() <= 7).is_true()
