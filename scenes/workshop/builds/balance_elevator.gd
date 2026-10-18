## Balance-scale elevator step: {groups} crates of {size} gems sit on one pan; the counterweight on the
## other pan must equal them all ("There are {groups} groups of {size} gems. How many in all?",
## mult.equal_groups.total). Solved, the beam levels and the elevator cage rides up.
class_name BalanceElevatorStep
extends BuildStep


func art_kind() -> StringName:
	return &"balance_elevator"


func art_params(for_problem: Problem, solved: bool) -> Dictionary:
	return {"groups": int(for_problem.prompt_params.get("groups", 2)), "size": int(for_problem.prompt_params.get("size", 2)), "balanced": solved}
