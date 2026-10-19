## Conveyor Sync step (Zone 6 engineering project, P4-S30-04): two conveyor belts, each driven by an
## electric motor through a gear, drop a gem every {a} and every {b} ticks. "What is the first multiple
## that {a} and {b} share?" (mul.common.first) is when both drop a gem together. Solved, the belts run
## in step and drop their gems together at the shared multiple (GearTrain.first_shared_drop).
## The machine keeps running on the hub's shelf once the build is done (BuildSiteScreen.finished_params).
class_name ConveyorSyncStep
extends BuildStep


func art_kind() -> StringName:
	return &"conveyor_sync"


func art_params(for_problem: Problem, solved: bool) -> Dictionary:
	return {"a": int(for_problem.prompt_params.get("a", 2)), "b": int(for_problem.prompt_params.get("b", 3)), "synced": solved}
