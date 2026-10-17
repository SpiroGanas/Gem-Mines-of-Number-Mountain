## Rewards autoload: coins, gems, the lantern streak, museum minerals and the garage (Rewards v1).
## The rules are in scripts/core/rewards_rules.gd (pure, tested); this script applies them to the
## save (SaveSystem.data()["rewards"]), keeps this session's tally for the wind-down recap, and
## announces what was earned so scenes can celebrate it.
##
## It listens to Adaptive.skill_mastered: a first mastery pays the amethyst and may complete a
## museum milestone.
extends Node

signal coins_changed(total: int)
signal gem_awarded(gem: StringName, total: int)
## Today's lantern was lit by the first cracked rock of the day.
signal lantern_lit(day: String, streak: int)
## A museum mineral was found (its case opens).
signal mineral_found(gem: StringName)
signal skill_celebrated(skill_id: StringName)
signal purchased(item: StringName)
signal headlamp_changed(color: String)

var _session: Dictionary = {}


func _ready() -> void:
	Adaptive.skill_mastered.connect(_on_skill_mastered)
	Adaptive.session_started.connect(func(_id: String) -> void: reset_session())
	SaveSystem.profile_loaded.connect(reset_session)
	reset_session()


func data() -> Dictionary:
	return SaveSystem.data()["rewards"]


func coins() -> int:
	return int(data().get("coins", 0))


func gem_count(gem: StringName) -> int:
	return RewardsRules.gem_count(data(), gem)


func total_gems() -> int:
	var total: int = 0
	for gem: Variant in data().get("gems", {}):
		total += int(data()["gems"][gem])
	return total


func streak() -> int:
	return RewardsRules.streak(data())


func lit_today() -> bool:
	return RewardsRules.is_lit(data(), Adaptive.clock.today())


## Pays a cracked rock of `zone` (first try or after hints). Returns {coins, gem, lantern_lit}.
func pay_rock(zone: int, first_try: bool) -> Dictionary:
	var paid: Dictionary = RewardsRules.pay_rock(data(), zone, first_try, Adaptive.clock.today())
	_session["rocks"] += 1
	_session["coins"] += paid["coins"]
	_count_session_gem(paid["gem"])
	coins_changed.emit(coins())
	gem_awarded.emit(paid["gem"], gem_count(paid["gem"]))
	if paid["lantern_lit"]:
		lantern_lit.emit(Adaptive.clock.today(), streak())
	return paid


## Buys a garage item with coins; false if it cannot be bought (not enough coins, owned already).
func buy(item: StringName) -> bool:
	if not RewardsRules.buy(data(), item):
		return false
	SaveSystem.save_now()
	purchased.emit(item)
	coins_changed.emit(coins())
	headlamp_changed.emit(headlamp())
	return true


func can_buy(item: StringName) -> bool:
	return RewardsRules.can_buy(data(), item)


func owns(item: StringName) -> bool:
	return RewardsRules.owns(data(), item)


func headlamp() -> String:
	return RewardsRules.headlamp(data())


func set_headlamp(color: String) -> bool:
	if not RewardsRules.set_headlamp(data(), color):
		return false
	SaveSystem.save_now()
	headlamp_changed.emit(color)
	return true


func pickaxe() -> StringName:
	return RewardsRules.pickaxe(data())


func museum_open(mineral: StringName) -> bool:
	return RewardsRules.museum_open(data(), mineral)


## This session's tally for the wind-down recap: {rocks, coins, gems: {type: n}, gem_total, minerals}.
func session_summary() -> Dictionary:
	return _session.duplicate(true)


func reset_session() -> void:
	_session = {"rocks": 0, "coins": 0, "gems": {}, "gem_total": 0, "minerals": []}


func _count_session_gem(gem: StringName) -> void:
	_session["gems"][String(gem)] = int(_session["gems"].get(String(gem), 0)) + 1
	_session["gem_total"] += 1


func _on_skill_mastered(skill_id: StringName, first_time: bool) -> void:
	if not first_time:
		return
	RewardsRules.add_gem(data(), RewardsRules.MASTERY_GEM)
	_count_session_gem(RewardsRules.MASTERY_GEM)
	gem_awarded.emit(RewardsRules.MASTERY_GEM, gem_count(RewardsRules.MASTERY_GEM))
	skill_celebrated.emit(skill_id)
	var zones: Dictionary = {}
	for id: StringName in Adaptive.catalog().ids():
		var skill: Skill = Adaptive.catalog().skill(id)
		if not zones.has(skill.zone):
			zones[skill.zone] = []
		zones[skill.zone].append(skill.id)
	for mineral: StringName in RewardsRules.milestones_reached(data(), Adaptive.mastered(), zones):
		RewardsRules.add_gem(data(), mineral)
		_session["minerals"].append(mineral)
		mineral_found.emit(mineral)
	SaveSystem.save_now()
