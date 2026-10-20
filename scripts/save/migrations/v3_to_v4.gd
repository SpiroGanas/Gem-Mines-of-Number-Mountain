## Save schema 3 -> 4 (Phase 4, Sprint 40): saved Fib poems. Adds the `poems` block (SaveSchema) with
## no poems in it and changes nothing else: every skill record, the rewards, the workshop, the motivation
## records, the family points and the profile block are kept exactly as they were. Additive, as Spiro
## approved (docs/decisions.md, "Save schema v4: saved Fib poems").
##
##   saved   [] here; FibPoem.add_poem appends {made_at, lines} when the child saves a poem.
## A block a save already has (a build that wrote poems before this migration existed) is kept, with any
## entry that is not a poem of word-id lines dropped, so the poem maker never reads a broken poem.
class_name SaveMigrationV3ToV4
extends RefCounted


static func apply(data: Dictionary) -> Dictionary:
	var block: Dictionary = data.get("poems", {}) if data.get("poems") is Dictionary else {}
	var kept: Array = []
	if block.get("saved") is Array:
		for poem: Variant in block["saved"]:
			if FibPoem.is_saved_poem(poem):
				kept.append(poem)
	block["saved"] = kept
	data["poems"] = block
	return data
