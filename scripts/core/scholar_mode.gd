## Where Scholar mode's inputs come from (Phase 4, Sprint 37): the active child's parent setting
## (save settings.interface_mode, the Profile's interface_mode), the reading level for "auto" (from the
## profile's grade, ModeGate.reading_level_for_grade) and whether this device has shown a keyboard
## (InputRouter.has_keyboard: only after a real key press this session). ModeGate decides; this class
## only gathers. Screens ask is_on(feature); the Text autoload asks it for longer Scholar lines.
##
## Not pure (it reads autoloads), so it holds no rules of its own. Tests force a setting with
## `forced_setting` and a keyboard with `forced_keyboard` instead of touching the save or the device.
class_name ScholarMode
extends RefCounted

## Tests: a setting to use instead of the save's ("" reads the save).
static var forced_setting: String = ""
## Tests: true or false to use instead of InputRouter.has_keyboard() (null asks the router).
static var forced_keyboard: Variant = null
## Tests: a reading level to use instead of the grade's (-1 reads the grade).
static var forced_reading_level: int = -1


## True when `feature` is on for the child playing now.
static func is_on(feature: ModeGate.Feature) -> bool:
	return ModeGate.is_enabled(feature, setting(), reading_level(), has_keyboard())


## The active child's interface setting: "explorer", "scholar" or "auto".
static func setting() -> String:
	if not forced_setting.is_empty():
		return ModeGate.clean_setting(forced_setting)
	var settings: Variant = _settings()
	return ModeGate.clean_setting(str(settings.get("interface_mode", ModeGate.EXPLORER))) if settings is Dictionary else ModeGate.EXPLORER


## 0 to 3 (see ModeGate): from the grade a grown-up gave the profile.
static func reading_level() -> int:
	if forced_reading_level >= 0:
		return forced_reading_level
	var settings: Variant = _settings()
	var grade: Variant = settings.get("starting_grade", 1) if settings is Dictionary else 1
	return ModeGate.reading_level_for_grade(int(grade) if (grade is int or grade is float) else 1)


static func has_keyboard() -> bool:
	if forced_keyboard != null:
		return bool(forced_keyboard)
	var router: Node = _autoload(&"InputRouter")
	return router != null and bool(router.call(&"has_keyboard"))


## Clears every test override.
static func reset_overrides() -> void:
	forced_setting = ""
	forced_keyboard = null
	forced_reading_level = -1


static func _settings() -> Variant:
	var save_system: Node = _autoload(&"SaveSystem")
	if save_system == null:
		return null
	var data: Variant = save_system.call(&"data")
	return data.get("settings") if data is Dictionary else null


static func _autoload(name: StringName) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null(NodePath(String(name)))
