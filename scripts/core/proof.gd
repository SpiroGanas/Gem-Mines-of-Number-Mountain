## One guided proof from curriculum/proofs/*.json (Zone 12, The Infinite Core): a chain of statements in which every
## step is justified by something already known. Plain data, no nodes; ProofLoader builds it, ProofValidator judges a
## child's attempt, and the proof builder scene (scenes/zones/z12_infinite_core/) only draws it.
##
## A step is {id, line_id, justification, depends_on: [step ids]}; a decoy is {id, line_id, misconception}. Every
## line_id is in text/lines.csv. `strict_order` means the steps must be placed exactly in file order (a chain, like the
## square root of 2); otherwise any order that puts every step after the steps it depends on is accepted (Euclid).
class_name Proof
extends RefCounted

var id: StringName = &""
var title_line_id: StringName = &""
var intro_line_id: StringName = &""
var steps: Array[Dictionary] = []
var decoys: Array[Dictionary] = []
## The justification chips, in the order they are offered; each has the line `z12.why.<id>`.
var justifications: Array[StringName] = []
var strict_order: bool = false
## How far the builder's hint ladder goes (1 highlight the next tile, 2 place it, 3 also pick its reason).
var scaffold_levels: int = 3


## The step with this id, or an empty Dictionary.
func step(step_id: StringName) -> Dictionary:
	for entry: Dictionary in steps:
		if StringName(str(entry["id"])) == step_id:
			return entry
	return {}


## The decoy with this id, or an empty Dictionary.
func decoy(decoy_id: StringName) -> Dictionary:
	for entry: Dictionary in decoys:
		if StringName(str(entry["id"])) == decoy_id:
			return entry
	return {}


## The line id of a tile (step or decoy), or &"" for an unknown tile.
func line_of(tile_id: StringName) -> StringName:
	var found: Dictionary = step(tile_id)
	if found.is_empty():
		found = decoy(tile_id)
	return StringName(str(found.get("line_id", "")))


func index_of_step(step_id: StringName) -> int:
	for index: int in steps.size():
		if StringName(str(steps[index]["id"])) == step_id:
			return index
	return -1


func depends_on(step_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for dep: Variant in step(step_id).get("depends_on", []):
		result.append(StringName(str(dep)))
	return result


## Every tile id (steps then decoys) in a fixed pseudo-random order for the tray, driven only by `rng`.
func tray_order(rng: RandomNumberGenerator) -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: Dictionary in steps:
		ids.append(StringName(str(entry["id"])))
	for entry: Dictionary in decoys:
		ids.append(StringName(str(entry["id"])))
	for index: int in range(ids.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: StringName = ids[index]
		ids[index] = ids[other]
		ids[other] = held
	return ids
