## Scholar mode's gate (Phase 4, Sprint 37; master plan section 3.3): Scholar mode unlocks per feature,
## not all at once, from a parent setting and the child's reading level. Pure logic, no autoloads:
## ScholarMode (scripts/core/scholar_mode.gd) feeds it the profile's setting and the device's keyboard.
##
## parent_setting: "explorer" (every feature off), "scholar" (every feature on; typing only once a
## keyboard is known to be there) or "auto" (by reading level; below).
## reading_level: 0 to 3. The plan takes it from reading checks that the game does not have (Spiro: no
## narration, so no read-aloud checks were built in Phase 3). Until they exist the level comes from the
## grade a grown-up gave the profile (reading_level_for_grade), which is deliberately conservative: an
## "auto" profile in grade 2 or below stays in Explorer mode.
##
## Phase 5 kept the Feature enum as it is (its notation levels live in NotationRules and the Master Miner ranks use no
## gate); there is never a second gate.
class_name ModeGate
extends RefCounted

enum Feature { KEYBOARD_ENTRY, MATH_NOTATION, LONGER_TEXT, REDUCED_NARRATION }

const EXPLORER: String = "explorer"
const SCHOLAR: String = "scholar"
const AUTO: String = "auto"
const SETTINGS: Array[String] = [EXPLORER, SCHOLAR, AUTO]
## In "auto", typing and notation start at this reading level, longer text at the next.
const NOTATION_LEVEL: int = 2
const LONGER_TEXT_LEVEL: int = 3


## True when `feature` is on for a profile with this parent setting and reading level, on a device that
## has (or has not) shown a keyboard. An unknown setting counts as "auto".
static func is_enabled(feature: Feature, parent_setting: String, reading_level: int, has_keyboard: bool) -> bool:
	match parent_setting:
		EXPLORER:
			return false
		SCHOLAR:
			return feature != Feature.KEYBOARD_ENTRY or has_keyboard
		_:
			match feature:
				Feature.KEYBOARD_ENTRY:
					return has_keyboard and reading_level >= NOTATION_LEVEL
				Feature.MATH_NOTATION:
					return reading_level >= NOTATION_LEVEL
				Feature.LONGER_TEXT:
					return reading_level >= LONGER_TEXT_LEVEL
				Feature.REDUCED_NARRATION:
					return reading_level >= LONGER_TEXT_LEVEL
	return false


## The reading level "auto" uses until the game has reading checks: grade 2 and below 0 to 1 (Explorer),
## grade 3 is 2 (notation and typing), grade 4 and up 3 (longer text too). Grade 0 is kindergarten.
static func reading_level_for_grade(grade: int) -> int:
	if grade >= 4:
		return 3
	if grade == 3:
		return 2
	return 1 if grade == 2 else 0


## A setting as stored: one of SETTINGS, anything else read as "explorer" (the safe default).
static func clean_setting(value: String) -> String:
	return value if SETTINGS.has(value) else EXPLORER
