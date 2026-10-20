## Master Miner ranks (Phase 5): a rank is worked out from the mastered skills, never saved (so no save change).
## The ranks come from curriculum/ranks.json, lowest first; the highest one whose conditions all hold wins.
## Pure: callers give it the mastered ids and the skill ids of each zone.
class_name RankRules
extends RefCounted

const PATH: String = "res://curriculum/ranks.json"

static var _ranks: Array[Dictionary] = []


## Every rank {id, min_mastered, line_id, needs_zone?, all_zones?}, lowest first.
static func ranks() -> Array[Dictionary]:
	if _ranks.is_empty():
		var data: Variant = JsonUtil.parse_file(PATH)
		if data is Dictionary and data.get("ranks") is Array:
			for entry: Variant in data["ranks"]:
				if entry is Dictionary:
					_ranks.append(JsonUtil.intify(entry))
	return _ranks


## The rank for `mastered` skills. `zones` maps a zone number to its skill ids (all of them are used to tell which
## zones are finished). Returns the rank record.
static func rank_for(mastered: Array[StringName], zones: Dictionary) -> Dictionary:
	var finished: Dictionary = {}
	var every_zone: bool = not zones.is_empty()
	for zone: Variant in zones:
		var done: bool = RewardsRules.zone_complete(zones[zone], mastered)
		finished[int(zone)] = done
		every_zone = every_zone and done
	var best: Dictionary = {}
	for rank: Dictionary in ranks():
		if mastered.size() < int(rank["min_mastered"]):
			continue
		if rank.has("needs_zone") and not bool(finished.get(int(rank["needs_zone"]), false)):
			continue
		if bool(rank.get("all_zones", false)) and not every_zone:
			continue
		best = rank
	return best


## The line id of a rank's name.
static func name_line(rank: Dictionary) -> StringName:
	return StringName(str(rank.get("line_id", "")))
