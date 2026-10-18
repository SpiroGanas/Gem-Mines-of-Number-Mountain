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
## Sprint 19: a mathematician badge, a Word Gem, family points.
signal badge_earned(badge_id: StringName)
signal word_gem_collected(term_id: StringName)
signal family_points_changed(total: int)

var _session: Dictionary = {}
var _recipes: Array[Recipe] = []
var _builds: Array[BuildProject] = []
var _badges: Array[Dictionary] = []


func _ready() -> void:
	_recipes = Recipe.load_all()
	_builds = BuildProject.load_all()
	_badges = MotivationRules.load_badges()
	SaveSystem.profile_loaded.connect(sync_word_gems)
	Adaptive.skill_mastered.connect(_on_skill_mastered)
	Adaptive.session_started.connect(func(_id: String) -> void: reset_session())
	SaveSystem.profile_loaded.connect(reset_session)
	reset_session()
	# SaveSystem loaded the save in its own _ready, before this autoload existed, so the profile_loaded
	# it emitted then reached nobody: the catch-up for a save from before Sprint 19 runs here too.
	sync_word_gems()


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
	_collect_terms(_workshop_terms())
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


# --- Long-term motivation (Sprint 19) ---------------------------------------------------------------


func badges() -> Array[Dictionary]:
	return _badges


func has_badge(badge_id: StringName) -> bool:
	return MotivationRules.has_badge(SaveSystem.data(), badge_id)


func has_word_gem(term_id: StringName) -> bool:
	return MotivationRules.has_word_gem(SaveSystem.data(), term_id)


func word_gems() -> Array:
	return MotivationRules.motivation(SaveSystem.data())["word_gems"].duplicate()


## Collects the Word Gems of every mastered skill (and the workshop's, once it was used). Runs on
## every load, so a save from before Sprint 19 gets the Word Gems its mastered skills already earned.
func sync_word_gems() -> void:
	var terms: Array[StringName] = []
	for skill_id: StringName in Adaptive.mastered():
		terms.append_array(Adaptive.catalog().skill(skill_id).terms)
	if not WorkshopRules.workshop(SaveSystem.data())["crafted"].is_empty():
		terms.append_array(_workshop_terms())
	MotivationRules.collect_word_gems(SaveSystem.data(), terms)


func family_points() -> int:
	return MotivationRules.points(SaveSystem.data())


## A play session ended properly (the wind-down, or heading up after real digging): family points,
## once per session.
func session_completed(session_id: String) -> void:
	if session_id == "":
		return
	if MotivationRules.award_points(SaveSystem.data(), "session:" + session_id, MotivationRules.POINTS_FOR_SESSION):
		SaveSystem.save_now()
		family_points_changed.emit(family_points())


func deep_dig_available() -> bool:
	return Adaptive.deep_dig_available()


## The Deep Dig's last rock: the special gem, once per week. False when no Deep Dig was due.
func finish_deep_dig() -> bool:
	if not MotivationRules.finish_deep_dig(SaveSystem.data(), Adaptive.clock.today(), Adaptive.mastered().size()):
		return false
	_count_session_gem(MotivationRules.DEEP_DIG_GEM)
	gem_awarded.emit(MotivationRules.DEEP_DIG_GEM, gem_count(MotivationRules.DEEP_DIG_GEM))
	SaveSystem.save_now()
	return true


## Parent-area family goals (the parent area is behind the gate; these never appear to the child).
func family_goals() -> Array:
	return MotivationRules.family(SaveSystem.data())["goals"].duplicate(true)


func add_family_goal(text: String, points_needed: int) -> bool:
	if not MotivationRules.add_goal(SaveSystem.data(), text, points_needed):
		return false
	SaveSystem.save_now()
	return true


func claim_family_goal(index: int) -> bool:
	if not MotivationRules.claim_goal(SaveSystem.data(), index):
		return false
	SaveSystem.save_now()
	family_points_changed.emit(family_points())
	return true


func remove_family_goal(index: int) -> bool:
	if not MotivationRules.remove_goal(SaveSystem.data(), index):
		return false
	SaveSystem.save_now()
	return true


## Word Gems the workshop teaches (vocabulary entries with "taught_by": "workshop").
func _workshop_terms() -> Array[StringName]:
	var terms: Array[StringName] = []
	for term: StringName in Text.term_ids():
		if str(Text.term_definition(term).get("taught_by", "")) == "workshop":
			terms.append(term)
	return terms


func _collect_terms(terms: Array[StringName]) -> void:
	for term: StringName in MotivationRules.collect_word_gems(SaveSystem.data(), terms):
		word_gem_collected.emit(term)


func _on_skill_mastered(skill_id: StringName, first_time: bool) -> void:
	_collect_terms(Adaptive.catalog().skill(skill_id).terms)
	# A badge is checked on every mastery: its last skill may be one won back after a lapse.
	for badge_id: StringName in MotivationRules.earn_badges(SaveSystem.data(), _badges, Adaptive.mastered()):
		badge_earned.emit(badge_id)
	if not first_time:
		SaveSystem.save_now()
		return
	if MotivationRules.award_points(SaveSystem.data(), "mastery:" + String(skill_id), MotivationRules.POINTS_FOR_MASTERY):
		family_points_changed.emit(family_points())
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
