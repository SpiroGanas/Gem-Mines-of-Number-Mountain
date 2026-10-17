## The mine screen: the dig loop's presentation (CLAUDE.md: scene scripts only present; the
## rules live in scripts/core/dig_flow.gd and are unit-tested there).
##
## Flow: pick a rock -> Bolt reads the problem -> answer it (the AnswerPanel picks the input) ->
##   correct: the rock cracks, a gem flies into the cart, the game saves;
##   not quite: the rock wobbles and Bolt says "Not quite. Let's look again." Nothing is lost.
## When every rock is cracked Bolt offers "Head up to the surface" or "Dig more".
##
## Each rock's problem is chosen by the Adaptive autoload when the rock is picked (so it reflects
## the answers just given), and every answer is reported back to it. A not-quite answer climbs the
## hint ladder (HintLadder): rung 1 repeats the problem with its numbers highlighted, rung 2 adds
## the picture model. Rungs 3 and 4 arrive in Sprint 8.
class_name MineScreen
extends ShellScreen

## A rock finished cracking and its gem landed in the cart.
signal rock_finished(index: int)
## Every rock on the wall is cracked.
signal wall_cleared

const ZONE: int = 1
const PANEL_SCENE: PackedScene = preload("res://scenes/mine/answer_panel.tscn")

## 1.0 is normal speed. Tests raise it so animations finish quickly.
@export var animation_speed: float = 1.0
## 0 means a different wall every time; any other value makes the walls repeatable.
@export var seed_value: int = 0
## Limits the skills on the wall (tests use this); empty means the adaptive engine chooses.
@export var skill_ids: Array[StringName] = []

## The highest hint rung shown so far (Sprint 6 builds rungs 1 and 2).
const TOP_RUNG: HintLadder.Rung = HintLadder.Rung.VISUAL_MODEL

var flow: DigFlow = DigFlow.new()

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## One problem per rock, chosen when the rock is picked (null until then).
var _problems: Array[Problem] = []
var _panel: AnswerPanel
## When the answer area last opened for answers (for the attempt's latency).
var _answer_opened_ms: int = 0
## Not-quite answers on the problem now on screen (the chance of a lucky guess rises as options go).
var _misses_on_problem: int = 0

@onready var _wall: RockWall = %RockWall
@onready var _cart: Cart = %Cart
@onready var _bolt: Bolt = %Bolt
@onready var _answer_host: Control = %AnswerHost
@onready var _wall_clear_panel: Control = %WallClear
@onready var _head_up_button: Button = %HeadUpButton
@onready var _dig_more_button: Button = %DigMoreButton
@onready var _pause_button: Button = %PauseButton
@onready var _fx_layer: Control = %FxLayer
@onready var _sfx: SfxBank = %SfxBank


func _ready() -> void:
	super()
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_wall.speed_scale = animation_speed
	_cart.speed_scale = animation_speed
	_pause_button.text = Text.get_line(&"ui.common.pause")
	_head_up_button.text = Text.get_line(&"ui.mine.head_up")
	_dig_more_button.text = Text.get_line(&"ui.mine.dig_more")
	UI.make_touch_target(_pause_button, 2.0, 1.0)
	UI.make_touch_target(_head_up_button, 5.0, 1.5)
	UI.make_touch_target(_dig_more_button, 5.0, 1.5)
	_pause_button.pressed.connect(_on_pause_pressed)
	_head_up_button.pressed.connect(_on_head_up_pressed)
	_dig_more_button.pressed.connect(_start_wall)
	_wall.rock_selected.connect(_on_rock_selected)
	_cart.gem_landed.connect(_on_gem_landed)
	flow.state_changed.connect(_on_state_changed)
	Adaptive.placement_finished.connect(_on_placement_finished)
	_start_wall()


func sfx() -> SfxBank:
	return _sfx


func wall() -> RockWall:
	return _wall


func cart() -> Cart:
	return _cart


func bolt() -> Bolt:
	return _bolt


## The answer panel for the open problem, or null when no rock is open.
func answer_panel() -> AnswerPanel:
	return _panel


## The build board, if the open problem is answered by building (otherwise null).
func board() -> BuildBoard:
	return _panel.board() if _panel != null else null


## The problem behind the open rock, or null when none is open.
func current_problem() -> Problem:
	var index: int = flow.current_rock()
	return _problems[index] if index >= 0 and index < _problems.size() else null


## The problem of rock `index`, or null if that rock has not been picked yet.
func problem_for(index: int) -> Problem:
	return _problems[index]


func _start_wall() -> void:
	_wall_clear_panel.visible = false
	var count: int = _rng.randi_range(RockWall.MIN_ROCKS, RockWall.MAX_ROCKS)
	_problems.clear()
	_problems.resize(count)
	_wall.build(count)
	flow.start_wall(count)


func _on_rock_selected(index: int) -> void:
	if flow.state != DigFlow.State.PICK_ROCK or flow.is_cracked(index):
		return
	_sfx.play(&"select")
	if _problems[index] == null:
		_problems[index] = Adaptive.next_problem(_rng, skill_ids)
	_misses_on_problem = 0
	flow.pick_rock(index)


func _on_state_changed(state: DigFlow.State, previous: DigFlow.State) -> void:
	match state:
		DigFlow.State.PICK_ROCK:
			_remove_panel()
			_wall.clear_selection()
			_wall.set_interactive(true)
			# After a rock, the praise stays until the child opens the next one.
			var pick_line: StringName = &"bolt.placement.intro" if Adaptive.placement_active() and skill_ids.is_empty() else &"bolt.mine.pick_rock"
			_bolt.say(pick_line, {}, previous == DigFlow.State.GEM_DROP)
		DigFlow.State.SHOW_PROBLEM:
			_wall.set_interactive(false)
			_wall.mark_selected(flow.current_rock())
			var problem: Problem = current_problem()
			_bolt.say(problem.prompt_line_id, problem.prompt_params)
			_show_panel(problem)
			flow.problem_shown.call_deferred()
		DigFlow.State.AWAIT_ANSWER:
			_answer_opened_ms = Time.get_ticks_msec()
			if _panel != null:
				_panel.set_enabled(true)
		DigFlow.State.CRACK:
			_panel.set_enabled(false)
			_bolt.note(&"bolt.feedback.correct" if flow.wrong_count() == 0 else &"bolt.feedback.correct_hint")
			_sfx.play(&"crack")
			var rock: Rock = _wall.rock(flow.current_rock())
			rock.crack_finished.connect(flow.crack_finished, CONNECT_ONE_SHOT)
			rock.play_crack(GemArt.gem_for_zone(ZONE))
		DigFlow.State.GEM_DROP:
			_sfx.play(&"gem")
			var rock: Rock = _wall.rock(flow.current_rock())
			_cart.receive_gem(rock.gem_type(), rock.gem_center(), _fx_layer)
			rock.take_gem()
		DigFlow.State.WOBBLE:
			_panel.set_enabled(false)
			_sfx.play(&"wobble")
			_sfx.play(&"soft_miss")
			var open_rock: Rock = _wall.rock(flow.current_rock())
			open_rock.wobble_finished.connect(flow.wobble_finished, CONNECT_ONE_SHOT)
			open_rock.play_wobble()
		DigFlow.State.HINT:
			_show_hint(mini(HintLadder.next_rung(flow.wrong_count()), TOP_RUNG) as HintLadder.Rung)
			flow.hint_shown.call_deferred()
		DigFlow.State.WALL_CLEAR:
			_remove_panel()
			_sfx.play(&"fanfare")
			_bolt.say(&"bolt.mine.wall_clear")
			_wall_clear_panel.visible = true
			wall_cleared.emit()


func _on_gem_landed(_gem_type: StringName) -> void:
	_sfx.play(&"coin")
	_cart.set_totals(flow.coins, flow.gems)
	var finished: int = flow.current_rock()
	SaveSystem.save_now() # save point: after every rock
	flow.gem_dropped()
	rock_finished.emit(finished)


func _on_answered(given: Variant) -> void:
	if flow.state != DigFlow.State.AWAIT_ANSWER:
		return
	_sfx.play(&"tap")
	var problem: Problem = current_problem()
	var correct: bool = problem.is_correct(given)
	var attempt: Attempt = Attempt.new()
	attempt.skill_id = problem.skill_id
	attempt.problem_seed = problem.seed
	attempt.representation = problem.representation
	attempt.answer_mode = AnswerPanel.answer_mode_for(problem)
	attempt.correct = correct
	attempt.hints_used = flow.wrong_count()
	attempt.latency_ms = Time.get_ticks_msec() - _answer_opened_ms
	Adaptive.record(attempt, AnswerPanel.chance_for(problem, _misses_on_problem))
	if not correct:
		_misses_on_problem += 1
	flow.submit_answer(correct)


## Hint rung `rung` for the open rock: Bolt says the problem again with its numbers highlighted,
## the not-quite line and the rung's line go under it, and the panel adds the picture from rung 2.
func _show_hint(rung: HintLadder.Rung) -> void:
	var problem: Problem = current_problem()
	_bolt.say(problem.prompt_line_id, problem.prompt_params, false, problem.prompt_params.keys())
	_bolt.note(&"bolt.feedback.not_quite")
	_bolt.add_note(HintLadder.line_for(rung))
	_panel.show_hint(rung)


func _show_panel(problem: Problem) -> void:
	_remove_panel()
	_panel = PANEL_SCENE.instantiate()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_answer_host.add_child(_panel)
	_panel.setup(problem, _rng)
	_panel.set_enabled(false) # enabled once the problem is on screen
	_panel.answered.connect(_on_answered)
	var board: BuildBoard = _panel.board()
	if board != null:
		board.item_placed.connect(func(_kind: StringName) -> void: _sfx.play(&"place"))
		board.item_removed.connect(func(_kind: StringName) -> void: _sfx.play(&"tap"))


func _remove_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_answer_host.remove_child(_panel)
		_panel = null


func _on_placement_finished(_passed: Array[StringName]) -> void:
	_bolt.add_note(&"bolt.placement.done")


func _on_pause_pressed() -> void:
	_sfx.play(&"tap")
	pause_requested.emit()


func _on_head_up_pressed() -> void:
	_sfx.play(&"tap")
	request_screen.emit(&"hub", {})
