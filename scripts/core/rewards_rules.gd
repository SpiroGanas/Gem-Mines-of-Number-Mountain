## Rewards v1 rules (GDD section 6), pure functions over the save's `rewards` dictionary:
## coins, gems, the electric lantern streak, the Gem Museum and Bolt's Garage.
##
## The guardrails (CLAUDE.md rules 8 and 9) live here, so they are tested in one place:
##   - wrong answers never cost anything: nothing here takes coins or gems away except a purchase
##     the child chooses in the garage;
##   - every reward is earned and deterministic: a cracked rock pays 1 coin (2 on the first try)
##     and one gem of its zone; a first mastery pays an amethyst; museum minerals come from
##     mastery milestones. No randomness, no purchases with real money;
##   - missed days pause the lantern streak; it never goes down.
class_name RewardsRules
extends RefCounted

const COINS_FIRST_TRY: int = 2
const COINS_AFTER_HINT: int = 1
const MASTERY_GEM: StringName = &"amethyst"

## Museum minerals found through learning, in the order a child usually reaches them. Each needs
## either `mastered` skills in all, or every skill of a `zone` mastered.
const MILESTONES: Array[Dictionary] = [
	{"gem": &"calcite", "mastered": 5},
	{"gem": &"topaz", "mastered": 15},
	{"gem": &"malachite", "zone": 1},
	{"gem": &"fluorite", "zone": 2},
	{"gem": &"hematite", "zone": 3},
	{"gem": &"obsidian", "mastered": 30},
]

## The garage: coins only, never real money.
const SHOP: Dictionary = {
	&"pickaxe_t2": {"price": 50, "kind": "tool"},
	&"headlamp_green": {"price": 20, "kind": "headlamp", "color": "green"},
	&"headlamp_gold": {"price": 40, "kind": "headlamp", "color": "gold"},
}
const DEFAULT_HEADLAMP: String = "blue"
const HEADLAMP_ITEMS: Dictionary = {"blue": &"", "green": &"headlamp_green", "gold": &"headlamp_gold"}


static func coins_for_rock(first_try: bool) -> int:
	return COINS_FIRST_TRY if first_try else COINS_AFTER_HINT


## Pays one cracked rock: coins, one gem of the zone's type, and today's lantern.
## Returns {coins: int, gem: StringName, lantern_lit: bool}.
static func pay_rock(rewards: Dictionary, zone: int, first_try: bool, today: String) -> Dictionary:
	var coins: int = coins_for_rock(first_try)
	rewards["coins"] = int(rewards.get("coins", 0)) + coins
	var gem: StringName = GemArt.gem_for_zone(zone)
	add_gem(rewards, gem)
	return {"coins": coins, "gem": gem, "lantern_lit": light_lantern(rewards, today)}


static func add_gem(rewards: Dictionary, gem: StringName, count: int = 1) -> void:
	if not rewards.has("gems") or not rewards["gems"] is Dictionary:
		rewards["gems"] = {}
	rewards["gems"][String(gem)] = int(rewards["gems"].get(String(gem), 0)) + count


static func gem_count(rewards: Dictionary, gem: StringName) -> int:
	return int(rewards.get("gems", {}).get(String(gem), 0))


## Lights the lantern for `today` if it is not lit yet. Returns true when it was just lit.
## The streak is the number of days lit: a missed day adds nothing and takes nothing away.
static func light_lantern(rewards: Dictionary, today: String) -> bool:
	if not rewards.has("lantern") or not rewards["lantern"] is Dictionary:
		rewards["lantern"] = {"lit_days": [], "streak": 0}
	var lantern: Dictionary = rewards["lantern"]
	if lantern["lit_days"].has(today):
		return false
	lantern["lit_days"].append(today)
	lantern["streak"] = lantern["lit_days"].size()
	return true


static func streak(rewards: Dictionary) -> int:
	return int(rewards.get("lantern", {}).get("streak", 0))


static func is_lit(rewards: Dictionary, day: String) -> bool:
	return rewards.get("lantern", {}).get("lit_days", []).has(day)


## Museum minerals newly earned now that `mastered` skills are mastered. `zones` maps a zone
## number to its skill ids. Minerals already held are not given again.
static func milestones_reached(rewards: Dictionary, mastered: Array[StringName], zones: Dictionary) -> Array[StringName]:
	var found: Array[StringName] = []
	for milestone: Dictionary in MILESTONES:
		var gem: StringName = milestone["gem"]
		if gem_count(rewards, gem) > 0:
			continue
		var reached: bool = false
		if milestone.has("mastered"):
			reached = mastered.size() >= int(milestone["mastered"])
		else:
			var ids: Array = zones.get(int(milestone["zone"]), [])
			reached = not ids.is_empty()
			for id: Variant in ids:
				reached = reached and mastered.has(StringName(str(id)))
		if reached:
			found.append(gem)
	return found


## A museum case is open when the child holds at least one of that mineral.
static func museum_open(rewards: Dictionary, mineral: StringName) -> bool:
	return gem_count(rewards, mineral) > 0


static func owns(rewards: Dictionary, item: StringName) -> bool:
	return rewards.get("inventory", []).has(String(item))


static func price_of(item: StringName) -> int:
	return int(SHOP.get(item, {}).get("price", 0))


static func can_buy(rewards: Dictionary, item: StringName) -> bool:
	return SHOP.has(item) and not owns(rewards, item) and int(rewards.get("coins", 0)) >= price_of(item)


## Buys an item with coins. A headlamp is put on straight away. Returns false (and changes
## nothing) when the item is unknown, owned already or costs more than the coins held.
static func buy(rewards: Dictionary, item: StringName) -> bool:
	if not can_buy(rewards, item):
		return false
	rewards["coins"] = int(rewards["coins"]) - price_of(item)
	if not rewards.has("inventory"):
		rewards["inventory"] = []
	rewards["inventory"].append(String(item))
	if SHOP[item]["kind"] == "headlamp":
		set_headlamp(rewards, SHOP[item]["color"])
	return true


static func headlamp(rewards: Dictionary) -> String:
	return str(rewards.get("bolt", {}).get("headlamp", DEFAULT_HEADLAMP))


static func has_headlamp(rewards: Dictionary, color: String) -> bool:
	if not HEADLAMP_ITEMS.has(color):
		return false
	var item: StringName = HEADLAMP_ITEMS[color]
	return item == &"" or owns(rewards, item)


## Puts on an owned headlamp color. Returns false for one not owned.
static func set_headlamp(rewards: Dictionary, color: String) -> bool:
	if not has_headlamp(rewards, color):
		return false
	if not rewards.has("bolt"):
		rewards["bolt"] = {}
	rewards["bolt"]["headlamp"] = color
	return true


## The best pickaxe owned: tier 2 cracks rocks with a bigger effect.
static func pickaxe(rewards: Dictionary) -> StringName:
	return &"pickaxe_t2" if owns(rewards, &"pickaxe_t2") else &"pickaxe_t1"
