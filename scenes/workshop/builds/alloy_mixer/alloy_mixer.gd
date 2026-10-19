## Alloy Mixer step (Zone 7's engineering project, Sprint 33): the recipe says {a} copper to {b} tin and
## the hopper holds {c} copper; the child sets the tin scoops on the alloy mixer and presses Mix
## (ratio.scale.alloy, concrete, so the problem card shows the AlloyMixer). Solved, the drum spins and
## alloy bars fill the rack. The rule is Alloy.is_right_mix.
class_name AlloyMixerStep
extends BuildStep


func art_kind() -> StringName:
	return &"alloy_mixer"


func art_params(for_problem: Problem, solved: bool) -> Dictionary:
	var p: Dictionary = for_problem.prompt_params
	var copper: int = int(p.get("c", 4))
	var tin: int = Alloy.tin_for(int(p.get("a", 2)), int(p.get("b", 3)), copper) if solved else 0
	return {"a": int(p.get("a", 2)), "b": int(p.get("b", 3)), "copper": copper, "tin": maxi(tin, 0), "mixed": solved}
