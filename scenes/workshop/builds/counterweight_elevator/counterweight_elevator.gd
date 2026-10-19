## Counterweight Elevator step (Zone 8's engineering project, Sprint 36): Bolt's cab hangs {w} at {d}
## steps on one side of the beam; the child loads the counterweight at {r} steps on the counterweight
## lever and presses Balance (lever.counterweight.balance, concrete, so the problem card shows the
## CounterweightLever). Solved, the beam levels and the cab rides up the shaft. The rule is
## Lever.side_heavier (weight × distance on each side).
class_name CounterweightElevatorStep
extends BuildStep


func art_kind() -> StringName:
	return &"counterweight_elevator"


func art_params(for_problem: Problem, solved: bool) -> Dictionary:
	var p: Dictionary = for_problem.prompt_params
	var counter: int = int(for_problem.answer) if solved else 0
	return {"w": int(p.get("w", 8)), "d": int(p.get("d", 2)), "r": int(p.get("r", 4)), "x": counter,
		"balanced": solved and Lever.side_heavier(int(p.get("w", 8)), int(p.get("d", 2)), counter, int(p.get("r", 4))) == "level"}
