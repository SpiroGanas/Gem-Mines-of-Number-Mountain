## Long-term motivation rules (Sprint 19), pure functions over the save Dictionary (schema v2,
## `motivation` and `family`). Everything here is earned by learning and effort and is deterministic
## (CLAUDE.md rules 8 and 9): nothing is random-for-value, nothing is lost, nothing rewards speed.
##
##   badges         a mathematician badge is earned when every skill it lists is mastered
##   Word Gems      a term is collected the first time a mastered skill uses it (or, for a term the
##                  workshop teaches, the first time the workshop uses it)
##   Deep Dig       once per ISO week of the device clock, with enough mastered skills; a clock set
##                  backwards cannot open a second one (the last completed week is kept)
##   Challenge Door a miss closes a skill's door until the next day; three right marks mastery
##   family points  paid once per key (a first mastery, a finished session); a parent claims a goal
class_name MotivationRules
extends RefCounted

const BADGES_PATH: String = "res://curriculum/badges.json"
## The Deep Dig's problems and the mastered skills it needs before it opens.
const DEEP_DIG_PROBLEMS: int = 10
const DEEP_DIG_MIN_MASTERED: int = 3
## The special gem a finished Deep Dig pays.
const DEEP_DIG_GEM: StringName = &"geode"
const CHALLENGE_PROBLEMS: int = 3
## A blind guesser may pass the door with at most this chance (three four-way questions); a skill with
## easier-to-guess questions gets more problems, up to CHALLENGE_MOST.
const CHALLENGE_MAX_LUCK: float = 1.0 / 64.0
const CHALLENGE_MOST: int = 8
## Family reward points: a first mastery and a finished session. Never time or speed.
const POINTS_FOR_MASTERY: int = 10
const POINTS_FOR_SESSION: int = 2


static func motivation(save: Dictionary) -> Dictionary:
	if not save.get("motivation") is Dictionary:
		save["motivation"] = {}
	var data: Dictionary = save["motivation"]
	for key: String in ["badges", "word_gems"]:
		if not data.get(key) is Array:
			data[key] = []
	if not data.get("deep_dig") is Dictionary:
		data["deep_dig"] = {"last_week": "", "completed": 0}
	if not data.get("challenge") is Dictionary:
		data["challenge"] = {"closed_until": {}, "passed": []}
	if not data["challenge"].get("closed_until") is Dictionary:
		data["challenge"]["closed_until"] = {}
	if not data["challenge"].get("passed") is Array:
		data["challenge"]["passed"] = []
	return data


static func family(save: Dictionary) -> Dictionary:
	if not save.get("family") is Dictionary:
		save["family"] = {}
	var data: Dictionary = save["family"]
	if not (data.get("points") is int or data.get("points") is float):
		data["points"] = 0
	for key: String in ["awarded", "goals"]:
		if not data.get(key) is Array:
			data[key] = []
	return data


# --- Badges -----------------------------------------------------------------------------------------


## The badge list from curriculum/badges.json: [{id, name_line_id, emblem, story: [{line_id, params}],
## story_more?: {skills_mastered: [...], story: [...]}, unlock: {skills_mastered: [...]}}].
static func load_badges(path: String = BADGES_PATH) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data: Variant = JsonUtil.parse_file(path)
	if data is Dictionary and data.get("badges") is Array:
		for entry: Variant in data["badges"]:
			if entry is Dictionary:
				result.append(entry)
	return result


## The story a badge tells now: its own lines, then its `story_more` lines once every skill those
## list is mastered (Phase 4: Euclid's GCF story arrives with Zone 6). Pure.
static func story_for(badge: Dictionary, mastered: Array[StringName]) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for entry: Variant in badge.get("story", []):
		lines.append(entry)
	var more: Variant = badge.get("story_more")
	if not more is Dictionary:
		return lines
	for skill: Variant in more.get("skills_mastered", []):
		if not mastered.has(StringName(str(skill))):
			return lines
	for entry: Variant in more.get("story", []):
		lines.append(entry)
	return lines


static func has_badge(save: Dictionary, badge_id: StringName) -> bool:
	return motivation(save)["badges"].has(String(badge_id))


## Badges whose every listed skill is mastered and that were not earned yet; they are added to the
## save. Returns the new badge ids in list order.
static func earn_badges(save: Dictionary, badges: Array[Dictionary], mastered: Array[StringName]) -> Array[StringName]:
	var earned: Array[StringName] = []
	for badge: Dictionary in badges:
		var id: StringName = StringName(str(badge.get("id", "")))
		if id == &"" or has_badge(save, id):
			continue
		var needs: Array = badge.get("unlock", {}).get("skills_mastered", [])
		if needs.is_empty():
			continue # a badge must be earned by mastery, never given
		var all: bool = true
		for skill: Variant in needs:
			if not mastered.has(StringName(str(skill))):
				all = false
				break
		if all:
			motivation(save)["badges"].append(String(id))
			earned.append(id)
	return earned


# --- Word Gems ---------------------------------------------------------------------------------------


## Adds terms not collected yet; returns the new ones.
static func collect_word_gems(save: Dictionary, terms: Array[StringName]) -> Array[StringName]:
	var added: Array[StringName] = []
	var held: Array = motivation(save)["word_gems"]
	for term: StringName in terms:
		if not held.has(String(term)):
			held.append(String(term))
			added.append(term)
	return added


static func has_word_gem(save: Dictionary, term: StringName) -> bool:
	return motivation(save)["word_gems"].has(String(term))


# --- Deep Dig ----------------------------------------------------------------------------------------


## The ISO 8601 week of a day ("2027-03-08" -> "2027-W10"). Pure arithmetic, so it is the same on
## every device: weeks start on Monday, and week 1 holds the year's first Thursday.
static func iso_week_key(day: String) -> String:
	var unix: int = Time.get_unix_time_from_datetime_string(day + "T12:00:00")
	var weekday: int = (int(Time.get_datetime_dict_from_unix_time(unix)["weekday"]) + 6) % 7 # Monday 0
	var thursday: int = unix + (3 - weekday) * GameClock.SECONDS_PER_DAY
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(thursday)
	var year: int = int(date["year"])
	var jan_first: int = Time.get_unix_time_from_datetime_string("%04d-01-01T12:00:00" % year)
	var week: int = floori(float(thursday - jan_first) / float(GameClock.SECONDS_PER_DAY) / 7.0) + 1
	return "%04d-W%02d" % [year, week]


## A Deep Dig can start: enough mastered skills, and this week is later than the last finished one
## (so a clock set backwards finds an earlier week and gets nothing).
static func deep_dig_available(save: Dictionary, today: String, mastered_count: int) -> bool:
	if mastered_count < DEEP_DIG_MIN_MASTERED:
		return false
	return iso_week_key(today) > str(motivation(save)["deep_dig"].get("last_week", ""))


## Records a finished Deep Dig and pays its special gem. False (nothing paid) if none was available.
static func finish_deep_dig(save: Dictionary, today: String, mastered_count: int) -> bool:
	if not deep_dig_available(save, today, mastered_count):
		return false
	var dig: Dictionary = motivation(save)["deep_dig"]
	dig["last_week"] = iso_week_key(today)
	dig["completed"] = int(dig.get("completed", 0)) + 1
	RewardsRules.add_gem(save["rewards"], DEEP_DIG_GEM)
	return true


## The Deep Dig's skills: DEEP_DIG_PROBLEMS picks spread over the mastered skills, each one before any
## repeats. Same seed and same mastered list, same picks.
static func deep_dig_skills(mastered: Array[StringName], seed: int) -> Array[StringName]:
	var picks: Array[StringName] = []
	if mastered.is_empty():
		return picks
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var bag: Array[StringName] = []
	while picks.size() < DEEP_DIG_PROBLEMS:
		if bag.is_empty():
			bag = mastered.duplicate()
			for index: int in range(bag.size() - 1, 0, -1): # Fisher-Yates with the passed seed
				var other: int = rng.randi_range(0, index)
				var held: StringName = bag[index]
				bag[index] = bag[other]
				bag[other] = held
		picks.append(bag.pop_back())
	return picks


# --- Challenge Door ----------------------------------------------------------------------------------


static func door_closed(save: Dictionary, skill_id: StringName, today: String) -> bool:
	var until: Variant = motivation(save)["challenge"]["closed_until"].get(String(skill_id))
	return until is String and today < until


## A miss closes the door until tomorrow. It is not a wrong answer anywhere else.
static func close_door(save: Dictionary, skill_id: StringName, today: String) -> void:
	motivation(save)["challenge"]["closed_until"][String(skill_id)] = GameClock.add_days(today, 1)


static func record_door_passed(save: Dictionary, skill_id: StringName) -> void:
	var passed: Array = motivation(save)["challenge"]["passed"]
	if not passed.has(String(skill_id)):
		passed.append(String(skill_id))


# --- Family reward points ------------------------------------------------------------------------------


static func points(save: Dictionary) -> int:
	return int(family(save)["points"])


## Pays `amount` once for `key` ("mastery:<skill>", "session:<id>"). False when already paid.
static func award_points(save: Dictionary, key: String, amount: int) -> bool:
	var data: Dictionary = family(save)
	if data["awarded"].has(key) or amount <= 0:
		return false
	data["awarded"].append(key)
	data["points"] = int(data["points"]) + amount
	return true


## Adds a parent's goal. False for empty text or a goal needing no points.
static func add_goal(save: Dictionary, text: String, points_needed: int) -> bool:
	var clean: String = text.strip_edges()
	if clean == "" or points_needed < 1:
		return false
	family(save)["goals"].append({"text": clean.substr(0, 60), "points_needed": points_needed, "claimed": false})
	return true


## A parent claims a goal: its points are spent and it is marked claimed. False when it cannot be.
static func claim_goal(save: Dictionary, index: int) -> bool:
	var goals: Array = family(save)["goals"]
	if index < 0 or index >= goals.size() or bool(goals[index].get("claimed", false)):
		return false
	var needed: int = int(goals[index].get("points_needed", 0))
	if points(save) < needed:
		return false
	family(save)["points"] = points(save) - needed
	goals[index]["claimed"] = true
	return true


static func remove_goal(save: Dictionary, index: int) -> bool:
	var goals: Array = family(save)["goals"]
	if index < 0 or index >= goals.size():
		return false
	goals.remove_at(index)
	return true
