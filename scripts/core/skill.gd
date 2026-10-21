## One skill in the curriculum, loaded from curriculum/skills/zNN_*.json (Phase 1 plan).
## A skill says WHAT is taught; its generator (scripts/generators/) makes the problems.
class_name Skill
extends Resource

## topic.subtopic.action, e.g. pv.tens_ones.build. Never renamed once shipped.
@export var id: StringName
## Parent-facing name (shown on the dashboard, never to the child).
@export var name: String
@export var zone: int
@export var prereqs: Array[StringName] = []
## The generator class, e.g. "PlaceValueGenerator".
@export var generator: StringName
## Generator settings as authored in the JSON (mode, min, max, ...). Whole numbers are ints.
@export var params: Dictionary = {}
## concrete, pictorial, abstract: the order they are introduced.
@export var representations: Array[StringName] = []
## tap, drag, number_pad, keyboard: the modes the answer may be given in.
@export var answer_modes: Array[StringName] = []
## Word Gem ids in curriculum/vocabulary.json.
@export var terms: Array[StringName] = []
## Key into curriculum/bkt_defaults.json.
@export var bkt_type: StringName = &"default"
## True enables the hidden fluency check (never shown to the child).
@export var is_fact_skill: bool = false
## How much notation the skill's pictures and prompts use (Phase 5, Scholar mode): 0 plain (+ - × ÷ =),
## 1 fractions, decimals, powers and roots, 2 the congruence sign and set symbols. See NotationRules.
@export var notation_level: int = 0
## Names from curriculum/misconceptions.json that this skill's distractors may use.
@export var misconceptions: Array[StringName] = []


## Builds a Skill from one record of a detailed zone file. `zone` is the file's zone number.
static func from_json(entry: Dictionary, zone: int) -> Skill:
	var skill: Skill = Skill.new()
	skill.id = StringName(str(entry["id"]))
	skill.name = str(entry["name"])
	skill.zone = zone
	skill.prereqs = _names(entry.get("prereqs", []))
	skill.generator = StringName(str(entry["generator"]))
	skill.params = JsonUtil.intify(entry.get("params", {}))
	skill.representations = _names(entry.get("representations", []))
	skill.answer_modes = _names(entry.get("answer_modes", []))
	skill.terms = _names(entry.get("terms", []))
	skill.bkt_type = StringName(str(entry.get("bkt_type", "default")))
	skill.is_fact_skill = bool(entry.get("is_fact_skill", false))
	skill.misconceptions = _names(entry.get("misconceptions", []))
	skill.notation_level = int(entry.get("notation_level", 0))
	return skill


## The first listed representation: the one a new learner meets first.
func first_representation() -> StringName:
	return representations[0] if not representations.is_empty() else &"concrete"


static func _names(values: Array) -> Array[StringName]:
	var names: Array[StringName] = []
	for value: Variant in values:
		names.append(StringName(str(value)))
	return names
