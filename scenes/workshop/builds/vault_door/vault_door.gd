## Vault Door step (Zone 11's engineering project): the vault door is locked with a coded word. The child turns the
## cipher wheel until the code spells a word and presses Set (cipher.caesar.crack, concrete, so the problem card shows
## the CipherWheel). Solved, the lock's cipher letters light up and a bolt slides back; three codes open the door.
class_name VaultDoorStep
extends BuildStep


func art_kind() -> StringName:
	return &"vault_door"


func art_params(for_problem: Problem, solved: bool) -> Dictionary:
	var code: String = str(for_problem.meta.get("coded", "KEY"))
	return {"code": code, "word": str(for_problem.meta.get("word", "")) if solved else "", "open": solved}
