## Which notation a child may see (Phase 5, Scholar mode complete). Every form of notation has a level, like a
## skill's `notation_level` in curriculum/skills: 0 plain (+ - × ÷ =), 1 fractions, decimals, powers, roots,
## scientific notation and the congruence sign (taught in Explorer mode too, always with the words underneath),
## 2 the set symbols ℤ ℚ ℝ (and any later formal notation). Explorer mode stops at level 1; Scholar mode (the
## MATH_NOTATION feature) shows level 2. Pure: callers pass whether Scholar notation is on.
class_name NotationRules
extends RefCounted

const PLAIN: int = 0
const TAUGHT: int = 1
const FORMAL: int = 2


## The level of a notation spec form ("power", "root", "sci", "congruence", "set"). Unknown forms are FORMAL.
static func form_level(form: String) -> int:
	match form:
		"power", "root", "sci", "congruence":
			return TAUGHT
		"set":
			return FORMAL
	return FORMAL


## The highest level a child sees: FORMAL in Scholar mode, TAUGHT in Explorer mode.
static func max_level(scholar_on: bool) -> int:
	return FORMAL if scholar_on else TAUGHT


## True when `form` may be drawn as symbols (otherwise only its words show).
static func symbols_allowed(form: String, scholar_on: bool) -> bool:
	return form_level(form) <= max_level(scholar_on)
