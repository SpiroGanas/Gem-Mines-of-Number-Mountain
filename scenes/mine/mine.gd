## The mine screen: the dig loop's presentation (CLAUDE.md: scene scripts only present; the
## rules live in scripts/core/dig_flow.gd and are unit-tested there).
##
## Flow: pick a rock -> Bolt reads the problem -> build the answer -> Done ->
##   correct: the rock cracks, a gem flies into the cart, the game saves;
##   not quite: the rock wobbles and Bolt says "Not quite. Let's look again." Nothing is lost.
## When every rock is cracked Bolt offers "Head up to the surface" or "Dig more".
##
## Sprint 4 is gray-box: placeholder shapes, one hard-coded problem type (GrayBoxProblem) and the
## placeholder sounds. Sprint 5 swaps in the generators; Sprint 6 swaps in the adaptive engine.
class_name MineScreen
extends ShellScreen

## A rock finished cracking and its gem landed in the cart.
signal rock_finished(index: int)
## Every rock on the wall is cracked.
signal wall_cleared

const ZONE: int = 1
const BOARD_SCENE: PackedScene = preload("res://scenes/input/build_board.tscn")

## 1.0 is normal speed. Tests raise it so animations finish quickly.
@export var animation_speed: float = 1.0
## 0 means a different wall every time; any other value makes the walls repeatable.
@export var seed_value: int = 0

var flow: DigFlow = DigFlow.new()

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _problems: Array[Dictionary] = []
var _board: BuildBoard

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
	_start_wall()


func sfx() -> SfxBank:
	return _sfx


func wall() -> RockWall:
	return _wall


func cart() -> Cart:
	return _cart


func bolt() -> Bolt:
	return _bolt


## The build board for the open problem, or null when no rock is open.
func board() -> BuildBoard:
	return _board


## The problem behind the open rock ({} when none is open).
func current_problem() -> Dictionary:
	var index: int = flow.current_rock()
	return _problems[index] if index >= 0 and index < _problems.size() else {}


func problem_for(index: int) -> Dictionary:
	return _problems[index]


func _start_wall() -> void:
	_wall_clear_panel.visible = false
	var count: int = _rng.randi_range(RockWall.MIN_ROCKS, RockWall.MAX_ROCKS)
	_problems.clear()
	for i: int in count:
		_problems.append(GrayBoxProblem.build_number(_rng))
	_wall.build(count)
	flow.start_wall(count)


func _on_rock_selected(index: int) -> void:
	_sfx.play(&"select")
	flow.pick_rock(index)


func _on_state_changed(state: DigFlow.State, previous: DigFlow.State) -> void:
	match state:
		DigFlow.State.PICK_ROCK:
			_remove_board()
			_wall.clear_selection()
			_wall.set_interactive(true)
			# After a rock, the praise stays until the child opens the next one.
			_bolt.say(&"bolt.mine.pick_rock", {}, previous == DigFlow.State.GEM_DROP)
		DigFlow.State.SHOW_PROBLEM:
			_wall.set_interactive(false)
			_wall.mark_selected(flow.current_rock())
			var problem: Dictionary = current_problem()
			_bolt.say(problem["prompt_line_id"], problem["prompt_params"])
			_show_board()
			flow.problem_shown.call_deferred()
		DigFlow.State.AWAIT_ANSWER:
			if _board != null:
				_board.set_enabled(true)
		DigFlow.State.CRACK:
			_board.set_enabled(false)
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
			_board.set_enabled(false)
			_sfx.play(&"wobble")
			_sfx.play(&"soft_miss")
			var open_rock: Rock = _wall.rock(flow.current_rock())
			open_rock.wobble_finished.connect(flow.wobble_finished, CONNECT_ONE_SHOT)
			open_rock.play_wobble()
		DigFlow.State.HINT:
			# Sprint 6 builds the four hint rungs. Until then Bolt adds the stock line under the
			# problem, so the child can still see which number to build.
			_bolt.note(&"bolt.feedback.not_quite")
			flow.hint_shown.call_deferred()
		DigFlow.State.WALL_CLEAR:
			_remove_board()
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


func _on_board_submitted(answer: Dictionary) -> void:
	_sfx.play(&"tap")
	flow.submit_answer(GrayBoxProblem.is_correct(current_problem(), answer))


func _show_board() -> void:
	_remove_board()
	_board = BOARD_SCENE.instantiate()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_answer_host.add_child(_board)
	_board.set_enabled(false) # enabled once the problem is on screen
	_board.submitted.connect(_on_board_submitted)
	_board.item_placed.connect(func(_kind: StringName) -> void: _sfx.play(&"place"))
	_board.item_removed.connect(func(_kind: StringName) -> void: _sfx.play(&"tap"))


func _remove_board() -> void:
	if _board != null:
		_board.queue_free()
		_answer_host.remove_child(_board)
		_board = null


func _on_pause_pressed() -> void:
	_sfx.play(&"tap")
	pause_requested.emit()


func _on_head_up_pressed() -> void:
	_sfx.play(&"tap")
	request_screen.emit(&"hub", {})
