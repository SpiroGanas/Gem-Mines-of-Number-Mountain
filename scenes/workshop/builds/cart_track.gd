## Cart track step: a rail of {a} is laid, the gap runs to {c}; the missing rail is the answer to
## "{a} + ? = {c}" (eq.missing_addend.to_20). Solved, the new rail fills the gap and the cart rolls.
class_name CartTrackStep
extends BuildStep


func art_kind() -> StringName:
	return &"cart_track"


func art_params(for_problem: Problem, solved: bool) -> Dictionary:
	return {"a": int(for_problem.prompt_params.get("a", 0)), "c": int(for_problem.prompt_params.get("c", 10)), "filled": solved}
