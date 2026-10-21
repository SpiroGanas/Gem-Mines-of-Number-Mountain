## Judges a child's proof attempt (Zone 12). Pure: no nodes, no globals, no cost for a wrong try (CLAUDE.md rule 8).
##
## A placement is one Dictionary per slot, top to bottom: {tile: StringName (&"" for an empty slot), why: StringName
## (&"" for no reason chosen)}. The proof has one slot per step.
##   complete  every slot holds a different step, no decoy is placed, each step comes after every step it depends on
##             (strict proofs: exactly the file's order) and each has its right reason chip.
class_name ProofValidator
extends RefCounted


static func validate(proof: Proof, placement: Array[Dictionary]) -> ProofResult:
	var result: ProofResult = ProofResult.new()
	var seen: Array[StringName] = []
	for slot: int in proof.steps.size():
		var entry: Dictionary = placement[slot] if slot < placement.size() else {}
		var tile: StringName = StringName(str(entry.get("tile", "")))
		var why: StringName = StringName(str(entry.get("why", "")))
		if tile == &"":
			result.errors.append(_error(slot, "missing", tile, ""))
			continue
		var decoy: Dictionary = proof.decoy(tile)
		if not decoy.is_empty():
			result.errors.append(_error(slot, "decoy", tile, str(decoy["misconception"])))
			continue
		var step: Dictionary = proof.step(tile)
		if step.is_empty() or seen.has(tile):
			result.errors.append(_error(slot, "duplicate" if seen.has(tile) else "missing", tile, ""))
			continue
		if not _in_place(proof, tile, slot, seen):
			result.errors.append(_error(slot, "order", tile, ""))
		elif StringName(str(step["justification"])) != why:
			result.errors.append(_error(slot, "justification", tile, ""))
		seen.append(tile)
	result.complete = result.errors.is_empty() and placement.size() >= proof.steps.size()
	return result


## The tiles that may go in the first empty slot: the steps not yet on the board (anywhere, a later slot included)
## whose every dependency is placed before that slot (strict proofs: only the next step of the chain). Only a
## placement without mistakes before the empty slot has any.
static func next_valid_tiles(proof: Proof, placement: Array[Dictionary]) -> Array[StringName]:
	var placed: Array[StringName] = []
	var on_board: Array[StringName] = []
	for entry: Dictionary in placement:
		var tile: StringName = StringName(str(entry.get("tile", "")))
		if tile != &"":
			on_board.append(tile)
	for entry: Dictionary in placement:
		var tile: StringName = StringName(str(entry.get("tile", "")))
		if tile == &"":
			break
		placed.append(tile)
	var candidates: Array[StringName] = []
	var checked: Array[Dictionary] = []
	for index: int in placed.size():
		checked.append(placement[index])
	var so_far: ProofResult = validate_prefix(proof, checked)
	if not so_far.errors.is_empty():
		return candidates
	if proof.strict_order:
		if placed.size() < proof.steps.size():
			var next_step: StringName = StringName(str(proof.steps[placed.size()]["id"]))
			if not on_board.has(next_step):
				candidates.append(next_step)
		return candidates
	for entry: Dictionary in proof.steps:
		var id: StringName = StringName(str(entry["id"]))
		if on_board.has(id):
			continue
		var ready: bool = true
		for dep: StringName in proof.depends_on(id):
			ready = ready and placed.has(dep)
		if ready:
			candidates.append(id)
	return candidates


## Like validate(), for the slots filled so far: a missing slot after the last filled one is not an error.
static func validate_prefix(proof: Proof, placement: Array[Dictionary]) -> ProofResult:
	var result: ProofResult = validate(proof, placement)
	var kept: Array[Dictionary] = []
	for entry: Dictionary in result.errors:
		if entry["kind"] != "missing" or int(entry["slot"]) < placement.size():
			kept.append(entry)
	result.errors = kept
	result.complete = false
	return result


static func _in_place(proof: Proof, tile: StringName, slot: int, seen: Array[StringName]) -> bool:
	if proof.strict_order:
		return proof.index_of_step(tile) == slot
	for dep: StringName in proof.depends_on(tile):
		if not seen.has(dep):
			return false
	return true


static func _error(slot: int, kind: String, tile: StringName, misconception: String) -> Dictionary:
	return {"slot": slot, "kind": kind, "tile": tile, "misconception": misconception}
