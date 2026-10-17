## Bayesian Knowledge Tracing: the probability that the child has learned a skill, P(L), updated
## after each answer (Phase 1 plan, "Adaptive engine"). Pure math, no state.
##
## Four parameters per skill type, from curriculum/bkt_defaults.json (do not change without Spiro):
##   prior  P(L) before any answer          learn  chance of learning at each opportunity
##   guess  right without knowing it        slip   wrong despite knowing it
##   posterior_correct = pL(1-slip) / (pL(1-slip) + (1-pL)guess)
##   posterior_wrong   = pL*slip    / (pL*slip    + (1-pL)(1-guess))
##   P(L) next = posterior + (1 - posterior) * learn
class_name BKT
extends RefCounted

const DEFAULTS_PATH: String = "res://curriculum/bkt_defaults.json"
## Per-skill values fitted offline by tools/bkt/fit.py from a parent-exported play log.
const FITTED_PATH: String = "res://curriculum/bkt_fitted.json"
## A skill's fitted values are used only from this many logged first tries up; fewer than that
## and the defaults of its type stay in charge (a short log cannot pin down four numbers).
const MIN_FITTED_SAMPLES: int = 30
const PARAM_KEYS: Array[String] = ["prior", "learn", "guess", "slip"]
## A guess can be raised to the item's chance, but never to certainty (the formulas divide by it).
const MAX_GUESS: float = 0.99


## P(L) after one answer.
static func update(p_learned: float, correct: bool, p: Dictionary) -> float:
	var slip: float = p["slip"]
	var guess: float = p["guess"]
	var posterior: float
	if correct:
		posterior = p_learned * (1.0 - slip) / (p_learned * (1.0 - slip) + (1.0 - p_learned) * guess)
	else:
		posterior = p_learned * slip / (p_learned * slip + (1.0 - p_learned) * (1.0 - guess))
	return posterior + (1.0 - posterior) * float(p["learn"])


## A correct answer reached with hints is partial evidence: P(L) moves only `hint_weight` (0.5 by
## default) of the way from where it was toward the full "correct" update. Without hints, or for
## a wrong answer, this is update().
static func update_with_hints(p_learned: float, correct: bool, hints_used: int, p: Dictionary) -> float:
	if not correct or hints_used <= 0:
		return update(p_learned, correct, p)
	var full: float = update(p_learned, true, p)
	return p_learned + float(p.get("hint_weight", 0.5)) * (full - p_learned)


## The parameters with `guess` raised to the item's chance of being right by luck. Tapping one of
## two piles is right half the time whatever the skill's guess parameter says, and BKT must not
## read that as knowledge.
static func with_chance(p: Dictionary, chance: float) -> Dictionary:
	var adjusted: Dictionary = p.duplicate()
	adjusted["guess"] = minf(maxf(float(p["guess"]), chance), MAX_GUESS)
	return adjusted


## curriculum/bkt_defaults.json as {type: {prior, learn, guess, slip, ...}, hint_weight: float}.
static func load_defaults(path: String = DEFAULTS_PATH) -> Dictionary:
	var data: Variant = JsonUtil.parse_file(path)
	if not data is Dictionary:
		push_error("BKT: cannot read %s" % path)
		return {"default": {"prior": 0.3, "learn": 0.2, "guess": 0.2, "slip": 0.1}, "hint_weight": 0.5}
	return data


## One skill type's parameters plus hint_weight. An unknown type falls back to "default".
static func params_for(defaults: Dictionary, bkt_type: StringName) -> Dictionary:
	var source: Dictionary = defaults.get(String(bkt_type), defaults.get("default", {}))
	var params: Dictionary = {}
	for key: String in PARAM_KEYS:
		params[key] = float(source[key])
	if source.has("fluency_ms"):
		params["fluency_ms"] = int(source["fluency_ms"])
	params["hint_weight"] = float(defaults.get("hint_weight", 0.5))
	return params


## curriculum/bkt_fitted.json as {skill_id: {prior, learn, guess, slip, n, ...}}. A missing or
## unreadable file is not an error: no fit has been made yet, so every skill uses its defaults.
static func load_fitted(path: String = FITTED_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JsonUtil.parse_file(path)
	if not data is Dictionary or not data.get("skills") is Dictionary:
		push_warning("BKT: %s is not a fitted-parameters file; using the defaults" % path)
		return {}
	return data["skills"]


## One skill's parameters: its fitted values when it has MIN_FITTED_SAMPLES or more (the other
## fields, fluency_ms and hint_weight, always come from the defaults), else params_for().
static func params_for_skill(defaults: Dictionary, fitted: Dictionary, skill_id: StringName, bkt_type: StringName) -> Dictionary:
	var params: Dictionary = params_for(defaults, bkt_type)
	var entry: Variant = fitted.get(String(skill_id))
	if not entry is Dictionary or int(entry.get("n", 0)) < MIN_FITTED_SAMPLES:
		return params
	for key: String in PARAM_KEYS:
		if entry.has(key):
			params[key] = float(entry[key])
	return params
