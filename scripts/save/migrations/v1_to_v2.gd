## Save schema 1 -> 2 (Phase 2): adds the device id, the workshop, the long-term motivation records
## and family reward points (SaveSchema). Nothing a version-1 save holds is changed or dropped.
##
## Word Gems the child already earned are not lost. Collecting the Word Gems of skills mastered under
## version 1 needs the curriculum, so Rewards collects them on load instead
## (Rewards.sync_word_gems); this step only creates the empty records.
class_name SaveMigrationV1ToV2
extends RefCounted


static func apply(data: Dictionary) -> Dictionary:
	if not data.get("device_id") is String:
		data["device_id"] = ""
	var workshop: Dictionary = data.get("workshop", {}) if data.get("workshop") is Dictionary else {}
	if not workshop.get("crafted") is Array:
		workshop["crafted"] = []
	if not workshop.get("builds") is Dictionary:
		workshop["builds"] = {}
	data["workshop"] = workshop
	var motivation: Dictionary = data.get("motivation", {}) if data.get("motivation") is Dictionary else {}
	for key: String in ["badges", "word_gems"]:
		if not motivation.get(key) is Array:
			motivation[key] = []
	if not motivation.get("deep_dig") is Dictionary:
		motivation["deep_dig"] = {"last_week": "", "completed": 0}
	if not motivation.get("challenge") is Dictionary:
		motivation["challenge"] = {"closed_until": {}, "passed": []}
	data["motivation"] = motivation
	var family: Dictionary = data.get("family", {}) if data.get("family") is Dictionary else {}
	if not (family.get("points") is int or family.get("points") is float):
		family["points"] = 0
	for key: String in ["awarded", "goals"]:
		if not family.get(key) is Array:
			family[key] = []
	data["family"] = family
	return data
