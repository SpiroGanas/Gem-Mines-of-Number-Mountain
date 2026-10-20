## Clockwork Vault step (Zone 10's engineering project): Bolt's vault door has a dial of {n} marks. The child
## turns it {a}, then {b}, with the clock lock and presses Set (mod.add.wrap, concrete, so the problem card shows the
## ClockLock). Solved, the pointer rests on the right mark, the dial's lamp lights and a bolt slides back. Three steps
## open three dials; the finished vault opens the door to Zone 11. The rule is the same wrap-around as the skill's.
class_name ClockworkVaultStep
extends BuildStep


func art_kind() -> StringName:
	return &"clockwork_vault"


func art_params(for_problem: Problem, solved: bool) -> Dictionary:
	var p: Dictionary = for_problem.prompt_params
	var n: int = int(p.get("n", 6))
	return {"n": n, "x": int(for_problem.answer) if solved else 0, "open": solved}
