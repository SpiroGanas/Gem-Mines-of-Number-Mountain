## What ProofValidator found in one attempt: whether the proof is complete and one error per slot that is wrong.
## An error is {slot, kind, tile, misconception}: kind is "decoy" (a tile that is not a step), "duplicate" (a tile
## placed twice), "order" (a step before a step it depends on, or out of the chain), "justification" (the wrong or
## no reason chip) or "missing" (an empty slot). `misconception` is a decoy's named mistake, else "".
class_name ProofResult
extends RefCounted

var complete: bool = false
var errors: Array[Dictionary] = []


## The first error for a slot, or an empty Dictionary.
func error_at(slot: int) -> Dictionary:
	for entry: Dictionary in errors:
		if int(entry["slot"]) == slot:
			return entry
	return {}


func has_kind(kind: String) -> bool:
	for entry: Dictionary in errors:
		if entry["kind"] == kind:
			return true
	return false
