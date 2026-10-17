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
## A recipe was crafted in the workshop (Sprint 16).
signal crafted(recipe_id: StringName)
## A build step was finished; `done` when it finished the whole build.
signal build_step_finished(build_id: StringName, step: int, done: bool)

var _session: Dictionary = {}
var _recipes: Array[Recipe] = []
var _builds: Array[BuildProject] = []


func _ready() -> void:
	_recipes = Recipe.load_all()
	_builds = BuildProject.load_all()
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


## The gem for a number: the rare gem it earns, or `common_gem` (see RewardsRules.gem_for_value).
func gem_for_value(value: int, common_gem: StringName = GemArt.QUARTZ) -> StringName:
	return RewardsRules.gem_for_value(value, common_gem)


func total_gems() -> int:
	var total: int = 0
	for gem: Variant in data().get("gems", {}):
		total += int(data()["gems"][gem])
	return total


func streak() -> int:
	return RewardsRules.streak(data())


func lit_today() -> bool:
	return RewardsRules.is_lit(data(), Adaptive.clock.today())


## Pays a cracked rock of `zone` (first try or after hints). `value` is the number the problem is
## about (0 if none); from Zone 4 on it can make the gem a rare one. Returns
## {coins, gem, count, lantern_lit}.
func pay_rock(zone: int, first_try: bool, value: int = 0) -> Dictionary:
	var paid: Dictionary = RewardsRules.pay_rock(data(), zone, first_try, Adaptive.clock.today(), value)
	_session["rocks"] += 1
	_session["coins"] += paid["coins"]
	for i: int in int(paid["count"]):
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


# --- Workshop: crafting and builds (Sprint 16) ----------------------------------------------------


func recipes() -> Array[Recipe]:
	return _recipes


func recipe(id: StringName) -> Recipe:
	for entry: Recipe in _recipes:
		if entry.id == id:
			return entry
	return null


## Recipes the workshop shows now (their unlock skill opens its successors), in file order.
func open_recipes() -> Array[Recipe]:
	var result: Array[Recipe] = []
	for entry: Recipe in _recipes:
		if WorkshopRules.is_open(entry, Adaptive.opens_successors):
			result.append(entry)
	return result


func can_craft(id: StringName) -> bool:
	var entry: Recipe = recipe(id)
	return entry != null and WorkshopRules.can_craft(SaveSystem.data(), entry, Adaptive.opens_successors)


func is_crafted(id: StringName) -> bool:
	var entry: Recipe = recipe(id)
	return entry != null and WorkshopRules.is_crafted(SaveSystem.data(), entry)


## Crafts a recipe after its problem was answered right: spends the gems, adds the output, saves.
func craft(id: StringName) -> bool:
	var entry: Recipe = recipe(id)
	if entry == null or not WorkshopRules.craft(SaveSystem.data(), entry, Adaptive.opens_successors):
		return false
	SaveSystem.save_now()
	crafted.emit(id)
	if entry.output_type == "headlamp":
		headlamp_changed.emit(headlamp())
	return true


func builds() -> Array[BuildProject]:
	return _builds


func build(id: StringName) -> BuildProject:
	for entry: BuildProject in _builds:
		if entry.id == id:
			return entry
	return null


func build_state(id: StringName) -> Dictionary:
	var entry: BuildProject = build(id)
	return WorkshopRules.build_state(SaveSystem.data(), entry) if entry != null else {"step": 0, "done": false}


func is_built(id: StringName) -> bool:
	return bool(build_state(id)["done"])


func is_build_open(id: StringName) -> bool:
	var entry: BuildProject = build(id)
	return entry != null and WorkshopRules.is_open_build(entry, Adaptive.opens_successors)


## Records a finished build step and saves at once (closing the app mid-build resumes here).
## Returns true when that step finished the build.
func finish_build_step(id: StringName) -> bool:
	var entry: BuildProject = build(id)
	if entry == null or is_built(id):
		return false
	var done: bool = WorkshopRules.finish_step(SaveSystem.data(), entry)
	SaveSystem.save_now()
	build_step_finished.emit(id, int(build_state(id)["step"]), done)
	return done


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
