## Exports seeded problems as JSON lines for the independent Python cross-checker.
##
## Run (the Godot project must be imported first):
##   "$GODOT" --headless --path . --script res://tools/crosscheck/export_problems.gd -- \
##       --skill pv.tens_ones.build --n 10000 --seed 1 --out build/crosscheck/pv.tens_ones.build.jsonl
##
## Writes one `Problem.to_json()` per line for seeds seed .. seed + n - 1, cycling through the
## skill's representations so every one is exercised. Exit codes: 0 done, 2 bad arguments or
## unknown skill, 3 the skill's generator is not built yet (the runner skips those).
## Only generator code is used here; the Python checkers see nothing but the exported lines.
extends SceneTree


func _initialize() -> void:
	var args: Dictionary = _parse(OS.get_cmdline_user_args())
	if not args.has("skill") or not args.has("out"):
		printerr("usage: --skill <id> --out <file> [--n <count>] [--seed <first seed>]")
		quit(2)
		return
	var catalog: SkillCatalog = SkillCatalog.load_all()
	var skill: Skill = catalog.skill(StringName(args["skill"]))
	if skill == null:
		printerr("unknown skill: %s" % args["skill"])
		quit(2)
		return
	if not GeneratorRegistry.callable_for(skill).is_valid():
		printerr("no generator built yet for %s (%s)" % [skill.id, skill.generator])
		quit(3)
		return
	var count: int = int(args.get("n", "1000"))
	var first_seed: int = int(args.get("seed", "1"))
	var directory: String = String(args["out"]).get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open(args["out"], FileAccess.WRITE)
	if file == null:
		printerr("cannot write %s" % args["out"])
		quit(2)
		return
	for i: int in count:
		var representation: StringName = skill.representations[i % skill.representations.size()]
		var problem: Problem = GeneratorRegistry.make_problem(skill, first_seed + i, {"representation": representation})
		file.store_line(JSON.stringify(problem.to_json()))
	file.close()
	print("exported %d problems for %s to %s" % [count, skill.id, args["out"]])
	quit(0)


## "--key value" pairs into a Dictionary.
func _parse(arguments: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var index: int = 0
	while index < arguments.size():
		var argument: String = arguments[index]
		if argument.begins_with("--") and index + 1 < arguments.size():
			result[argument.trim_prefix("--")] = arguments[index + 1]
			index += 2
		else:
			index += 1
	return result
