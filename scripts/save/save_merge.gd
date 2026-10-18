## The cross-device merge rule (Sprint 17, "newest wins plus backup"), as a pure function so it is
## tested without devices. Charlie plays on two devices; a parent moves a progress file between them.
##
##   the imported save is newer (updated_at later)  -> replace this device's save (after a backup)
##   it is older                                    -> ask the parent; "keep this device's" is the default
##   the same moment                                -> keep this device's (nothing to gain)
##   updated_at missing or not a timestamp          -> refuse
## Never per skill: a partial merge is a decision for Spiro if the simple rule proves annoying.
class_name SaveMerge
extends RefCounted

const REPLACE: StringName = &"replace"
const ASK: StringName = &"ask"
const KEEP: StringName = &"keep"
const REFUSE: StringName = &"refuse"


## {action: REPLACE | ASK | KEEP | REFUSE, reason: String}
static func choose(local: Dictionary, imported: Dictionary) -> Dictionary:
	var theirs: String = _stamp(imported)
	if theirs == "":
		return {"action": REFUSE, "reason": "the imported save has no saved time"}
	var ours: String = _stamp(local)
	if ours == "" or theirs > ours:
		return {"action": REPLACE, "reason": "the imported save is newer"}
	if theirs == ours:
		return {"action": KEEP, "reason": "both saves are from the same moment"}
	return {"action": ASK, "reason": "the imported save is older"}


## The save's updated_at if it looks like an ISO 8601 UTC timestamp ("2027-03-08T10:00:00Z"), else "".
static func _stamp(save: Dictionary) -> String:
	var value: Variant = save.get("updated_at")
	if not value is String:
		return ""
	var text: String = value
	if text.length() < 19 or text[4] != "-" or text[10] != "T":
		return ""
	return text
