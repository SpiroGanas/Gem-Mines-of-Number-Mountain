## The hint ladder (GDD section 5): each not-quite answer on a rock climbs one rung. Nothing is ever
## deducted; the rungs only add help. The content of each rung is built by the problem's generator
## (Problem.hint_steps); this class says which rung applies and what it shows.
##
##   1 REPEAT_HIGHLIGHT  Bolt says the problem again with its numbers highlighted
##   2 VISUAL_MODEL      a picture of the problem appears (ten-frame, piles, number line...)
##   3 WORKED_EXAMPLE    a solved "friend" of the problem: the same skill, other numbers
##   4 EASIER_PROBLEM    an easier problem of the same skill; the skill is flagged for review
class_name HintLadder
extends RefCounted

enum Rung { REPEAT_HIGHLIGHT, VISUAL_MODEL, WORKED_EXAMPLE, EASIER_PROBLEM }

## Bolt's line for each rung, in rung order.
const LINES: Array[StringName] = [&"bolt.hint.look_again", &"bolt.hint.show_model", &"bolt.hint.worked_example", &"bolt.hint.easier"]


## The rung after `wrong_count` not-quite answers on this rock (1 or more). Past the fourth miss the
## ladder stays on its last rung.
static func next_rung(wrong_count: int) -> Rung:
	return clampi(wrong_count - 1, Rung.REPEAT_HIGHLIGHT, Rung.EASIER_PROBLEM) as Rung


static func line_for(rung: Rung) -> StringName:
	return LINES[rung]


## The picture stays up from rung 2 on, so later rungs keep everything the earlier ones gave.
static func shows_model(rung: Rung) -> bool:
	return rung >= Rung.VISUAL_MODEL


static func shows_example(rung: Rung) -> bool:
	return rung >= Rung.WORKED_EXAMPLE


## Rung 4 swaps in an easier problem once per rock; later misses keep the help on screen.
static func swaps_problem(rung: Rung, already_swapped: bool) -> bool:
	return rung == Rung.EASIER_PROBLEM and not already_swapped
