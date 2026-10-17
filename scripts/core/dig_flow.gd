## The dig loop's state machine and tallies, with no nodes (so it is fully unit-tested).
## scenes/mine/mine.gd only presents it: it calls these methods as animations finish and
## draws whatever state this reports.
##
## PICK_ROCK -> SHOW_PROBLEM -> AWAIT_ANSWER
##   correct: CRACK -> GEM_DROP -> PICK_ROCK (or WALL_CLEAR after the last rock)
##   not quite: WOBBLE -> HINT -> AWAIT_ANSWER
##
## Rules this encodes (CLAUDE.md rules 8 and 9): a not-quite answer never costs a coin or a
## gem, there is no game-over and no timer, and rewards are the same every time: one coin per
## cracked rock (two on the first try) and one gem. The numbers follow Rewards v1 in the
## Phase 1 plan; Sprint 8 moves the persistent totals into the Rewards autoload and this
## class keeps only the per-wall tally.
class_name DigFlow
extends RefCounted

enum State { IDLE, PICK_ROCK, SHOW_PROBLEM, AWAIT_ANSWER, CRACK, GEM_DROP, WOBBLE, HINT, WALL_CLEAR }

## The state changed. `previous` is where it came from.
signal state_changed(state: State, previous: State)

const COINS_FIRST_TRY: int = 2
const COINS_AFTER_HINT: int = 1
const GEMS_PER_ROCK: int = 1
## The hint ladder has four rungs (Sprint 6 builds them); the rung never goes past this.
const MAX_HINT_RUNG: int = 4

var state: State = State.IDLE
## Coins and gems earned on this wall so far.
var coins: int = 0
var gems: int = 0

var _cracked: Array[bool] = []
var _current_rock: int = -1
var _wrong_this_rock: int = 0


## Starts a new wall of `count` rocks. Tallies carry on across walls only if the caller keeps
## this object; call reset_tally() to zero them.
func start_wall(count: int) -> void:
	assert(count > 0, "a wall needs at least one rock")
	_cracked.clear()
	for i: int in count:
		_cracked.append(false)
	_current_rock = -1
	_wrong_this_rock = 0
	_set_state(State.PICK_ROCK)


func reset_tally() -> void:
	coins = 0
	gems = 0


func rock_count() -> int:
	return _cracked.size()


func is_cracked(index: int) -> bool:
	return index >= 0 and index < _cracked.size() and _cracked[index]


func rocks_left() -> int:
	return _cracked.count(false)


func current_rock() -> int:
	return _current_rock


## How many not-quite answers the current rock has had.
func wrong_count() -> int:
	return _wrong_this_rock


## Which hint rung applies now: 0 before any miss, then 1 to 4. Not-quite answers only ever
## move this up; nothing is deducted.
func hint_rung() -> int:
	return mini(_wrong_this_rock, MAX_HINT_RUNG)


## The child picked a rock. Only valid while picking, and only for a rock still uncracked.
func pick_rock(index: int) -> bool:
	if state != State.PICK_ROCK or index < 0 or index >= _cracked.size() or _cracked[index]:
		return false
	_current_rock = index
	_wrong_this_rock = 0
	_set_state(State.SHOW_PROBLEM)
	return true


## The problem is on screen and the child may answer.
func problem_shown() -> bool:
	return _advance(State.SHOW_PROBLEM, State.AWAIT_ANSWER)


## The child submitted an answer. Correct goes to CRACK, not-quite to WOBBLE.
func submit_answer(correct: bool) -> bool:
	if state != State.AWAIT_ANSWER:
		return false
	if correct:
		_set_state(State.CRACK)
	else:
		_wrong_this_rock += 1
		_set_state(State.WOBBLE)
	return true


## The crack animation ended. The rock now pays out: coins and a gem.
func crack_finished() -> bool:
	if state != State.CRACK:
		return false
	_cracked[_current_rock] = true
	coins += COINS_FIRST_TRY if _wrong_this_rock == 0 else COINS_AFTER_HINT
	gems += GEMS_PER_ROCK
	_set_state(State.GEM_DROP)
	return true


## The gem landed in the cart. Back to picking, or the wall is clear.
func gem_dropped() -> bool:
	if state != State.GEM_DROP:
		return false
	_current_rock = -1
	_set_state(State.WALL_CLEAR if rocks_left() == 0 else State.PICK_ROCK)
	return true


## The wobble ended. The hint for this miss is shown next.
func wobble_finished() -> bool:
	return _advance(State.WOBBLE, State.HINT)


## The hint is on screen; the child may try again.
func hint_shown() -> bool:
	return _advance(State.HINT, State.AWAIT_ANSWER)


func _advance(from: State, to: State) -> bool:
	if state != from:
		return false
	_set_state(to)
	return true


func _set_state(next: State) -> void:
	var previous: State = state
	state = next
	state_changed.emit(next, previous)
