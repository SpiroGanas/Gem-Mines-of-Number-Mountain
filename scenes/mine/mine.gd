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
## the picture model, rung 3 a solved "friend" of the problem, rung 4 swaps in an easier problem
## of the same skill and flags the skill for review.
##
## Cracked rocks are paid by the Rewards autoload (coins, the zone's gem, today's lantern). Between
## rocks a Celebration card marks a skill mastered, a museum mineral found or the lantern lit, and
## once the parent's soft time limit has passed the WindDown recap appears at the next rock
## boundary: the child always finishes the rock in hand.
class_name MineScreen
extends ShellScreen

## A rock finished cracking and its gem landed in the cart.
signal rock_finished(index: int)
## Every rock on the wall is cracked.
signal wall_cleared

const PANEL_SCENE: PackedScene = preload("res://scenes/mine/answer_panel.tscn")
const DEMO_SCENE: PackedScene = preload("res://scenes/input/chalk_slate/stroke_demo.tscn")

## 1.0 is normal speed. Tests raise it so animations finish quickly.
@export var animation_speed: float = 1.0
## 0 means a different wall every time; any other value makes the walls repeatable.
@export var seed_value: int = 0
## Limits the skills on the wall (tests use this); empty means the adaptive engine chooses.
@export var skill_ids: Array[StringName] = []

## Rocks the child may still crack after the soft limit before the wind-down shows (0: the wind-down
## comes at the very next rock boundary). Needs Spiro: the plan leaves "one extra rock" open.
const EXTRA_ROCKS_AFTER_LIMIT: int = 0
## The Deep Dig's ten rocks come as two walls of five.
const DEEP_DIG_WALL: int = 5
## Heading up after this many rocks counts as a finished session for family points.
const ROCKS_FOR_A_SESSION: int = 5

var flow: DigFlow = DigFlow.new()

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## One problem per rock, chosen when the rock is picked (null until then).
var _problems: Array[Problem] = []
var _panel: AnswerPanel
## When the answer area last opened for answers (for the attempt's latency).
var _answer_opened_ms: int = 0
## Not-quite answers on the problem now on screen (the chance of a lucky guess rises as options go).
var _misses_on_problem: int = 0
## The misconception the last not-quite answer matched (empty when it matched none).
var _last_misconception: StringName = &""
## The open rock already swapped in its easier problem (hint rung 4 happens once per rock).
var _eased: bool = false
var _word_gem_card: WordGemCard
var _celebration: Celebration
var _wind_down: WindDown
var _pending_celebrations: Array[Dictionary] = []
var _rocks_since_limit: int = 0
## Counts backwards digits for numeral coaching, for this visit to the mine.
var _coach: NumeralCoach = NumeralCoach.new()
var _stroke_demo: StrokeDemo
## The dimmer under the stroke demo while it is up (null otherwise); the panel sleeps under it.
var _demo_overlay: Control
## The weekly Deep Dig (Sprint 19): its problems wait here and fill the rocks as they are picked.
var deep_dig: bool = false
var _deep_queue: Array[Problem] = []
## The Challenge Door button shown after a wall when a frontier skill can be tested out (Sprint 19).
var _door_button: Button
var _door_skill: StringName = &""
var _banner: ZoneBanner

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


## Deep Dig: {"deep_dig": true} from the hub's Deep Dig button.
func setup(args: Dictionary) -> void:
	deep_dig = bool(args.get("deep_dig", false))


func _ready() -> void:
	super()
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	var backdrop: Backdrop = Backdrop.new()
	backdrop.palette = Backdrop.palette_for_zone(deepest_zone())
	add_child(backdrop)
	move_child(backdrop, 0)
	_banner = ZoneBanner.new()
	_banner.name = "ZoneBanner"
	_banner.zone = deepest_zone()
	_pause_button.get_parent().add_child(_banner)
	_wall.speed_scale = animation_speed
	_bolt.speed_scale = animation_speed
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
	_celebration = Celebration.new()
	_celebration.speed_scale = animation_speed
	add_child(_celebration)
	_celebration.closed.connect(_after_rock)
	_wind_down = WindDown.new()
	add_child(_wind_down)
	_wind_down.head_up_requested.connect(_on_wind_down_head_up)
	_word_gem_card = WordGemCard.new()
	add_child(_word_gem_card) # last: drawn over everything
	_word_gem_card.closed.connect(_on_word_gem_closed)
	_bolt.term_tapped.connect(_on_term_tapped)
	Rewards.skill_celebrated.connect(_on_skill_celebrated)
	Rewards.mineral_found.connect(_on_mineral_found)
	Rewards.zone_completed.connect(_on_zone_completed)
	Rewards.badge_earned.connect(_on_badge_earned)
	Rewards.word_gem_collected.connect(_on_word_gem_collected)
	_door_button = Button.new()
	_door_button.name = "DoorButton"
	_door_button.text = Text.get_line(&"door.mine.offer")
	UI.make_touch_target(_door_button, 5.0, 1.5)
	_door_button.visible = false
	_door_button.pressed.connect(_on_door_pressed)
	_wall_clear_panel.add_child(_door_button)
	if deep_dig and Rewards.deep_dig_available():
		_deep_queue = Adaptive.build_deep_dig(_rng)
	else:
		deep_dig = false
	_cart.strong = Rewards.pickaxe() == &"pickaxe_t2"
	_cart.set_totals(Rewards.coins(), 0)
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


func word_gem_card() -> WordGemCard:
	return _word_gem_card


func celebration() -> Celebration:
	return _celebration


func wind_down() -> WindDown:
	return _wind_down


## The deepest zone the child can dig in now (the backdrop's tint): the highest zone on the frontier.
func deepest_zone() -> int:
	var deepest: int = 1
	for id: StringName in Adaptive.frontier():
		deepest = maxi(deepest, Adaptive.catalog().skill(id).zone)
	return deepest


## Each zone group has its own loop (Sprint 20): Zones 1-3 share the first mine tune.
func music_id() -> StringName:
	match deepest_zone():
		4:
			return &"mine_z4"
		5:
			return &"mine_z5"
		6:
			return &"mine_z6"
		7:
			return &"mine_z7"
		9:
			return &"mine_z9"
	return &"mine"


## The zone a problem's skill belongs to (it decides the gem: quartz, garnet or pyrite).
func zone_of(problem: Problem) -> int:
	return Adaptive.catalog().skill(problem.skill_id).zone


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


## True while a Deep Dig is under way (its problems are not all dug yet).
func deep_dig_left() -> int:
	return _deep_queue.size() if deep_dig else 0


func zone_banner() -> ZoneBanner:
	return _banner


func door_button() -> Button:
	return _door_button


func _start_wall() -> void:
	_wall_clear_panel.visible = false
	var count: int = _rng.randi_range(RockWall.MIN_ROCKS, RockWall.MAX_ROCKS)
	if deep_dig:
		count = mini(_deep_queue.size(), DEEP_DIG_WALL)
	_problems.clear()
	_problems.resize(count)
	_wall.build(count)
	flow.start_wall(count)


func _on_rock_selected(index: int) -> void:
	if flow.state != DigFlow.State.PICK_ROCK or flow.is_cracked(index):
		return
	_sfx.play(&"select")
	if _problems[index] == null:
		_problems[index] = _deep_queue.pop_front() if deep_dig and not _deep_queue.is_empty() else Adaptive.next_problem(_rng, skill_ids)
	_misses_on_problem = 0
	_eased = false
	flow.pick_rock(index)


func _on_state_changed(state: DigFlow.State, previous: DigFlow.State) -> void:
	match state:
		DigFlow.State.PICK_ROCK:
			_remove_panel()
			_wall.clear_selection()
			_wall.set_interactive(true)
			_bolt.set_terms([])
			# After a rock, the praise stays until the child opens the next one.
			var pick_line: StringName = &"bolt.placement.intro" if Adaptive.placement_active() and skill_ids.is_empty() else &"bolt.mine.pick_rock"
			if deep_dig and previous != DigFlow.State.GEM_DROP:
				pick_line = &"deepdig.mine.intro"
			_bolt.say(pick_line, {}, previous == DigFlow.State.GEM_DROP)
		DigFlow.State.SHOW_PROBLEM:
			_wall.set_interactive(false)
			_wall.mark_selected(flow.current_rock())
			var problem: Problem = current_problem()
			_bolt.set_terms(Adaptive.catalog().skill(problem.skill_id).terms)
			_bolt.say(problem.prompt_line_id, problem.prompt_params)
			_bolt.set_pose(&"point")
			_show_panel(problem)
			flow.problem_shown.call_deferred()
		DigFlow.State.AWAIT_ANSWER:
			_answer_opened_ms = Time.get_ticks_msec()
			if _panel != null:
				_panel.set_enabled(not _overlay_up()) # a card or demo that is up keeps the panel asleep
		DigFlow.State.CRACK:
			_panel.set_enabled(false)
			_bolt.note(&"bolt.feedback.correct" if flow.wrong_count() == 0 else &"bolt.feedback.correct_hint")
			_bolt.set_pose(&"cheer")
			_sfx.play(&"crack")
			var rock: Rock = _wall.rock(flow.current_rock())
			rock.crack_finished.connect(flow.crack_finished, CONNECT_ONE_SHOT)
			rock.play_crack(gem_for(current_problem()), Rewards.pickaxe() == &"pickaxe_t2")
		DigFlow.State.GEM_DROP:
			_pay_rock() # the reward is earned the moment the rock cracks, whatever happens next
			_sfx.play(&"gem")
			var rock: Rock = _wall.rock(flow.current_rock())
			_cart.receive_gem(rock.gem_type(), rock.gem_center(), _fx_layer)
			rock.take_gem()
		DigFlow.State.WOBBLE:
			_panel.set_enabled(false)
			_sfx.play(&"wobble")
			_sfx.play(&"soft_miss")
			_bolt.set_pose(&"not_quite")
			var open_rock: Rock = _wall.rock(flow.current_rock())
			open_rock.wobble_finished.connect(flow.wobble_finished, CONNECT_ONE_SHOT)
			open_rock.play_wobble()
		DigFlow.State.HINT:
			_bolt.set_pose(&"think")
			_show_hint(HintLadder.next_rung(flow.wrong_count()))
			flow.hint_shown.call_deferred()
		DigFlow.State.WALL_CLEAR:
			_remove_panel()
			_sfx.play(&"fanfare")
			_bolt.say(&"bolt.mine.wall_clear")
			_wall_clear_panel.visible = true
			_dig_more_button.visible = true
			_door_button.visible = false
			if deep_dig:
				_deep_dig_wall_done()
			elif skill_ids.is_empty():
				_door_skill = Adaptive.challenge_candidate()
				_door_button.visible = _door_skill != &""
			wall_cleared.emit()


## Pays the cracked rock (coins, the zone's gem, today's lantern) and saves, before the gem flies.
## Leaving the mine while the gem is still in the air then loses nothing the child earned.
func _pay_rock() -> void:
	var paid: Dictionary = Rewards.pay_rock(zone_of(current_problem()), flow.wrong_count() == 0, number_of(current_problem()))
	if paid["lantern_lit"]:
		_pending_celebrations.append({"line_id": &"bolt.celebrate.lantern", "lantern": true})
	SaveSystem.save_now() # save point: after every rock


## The number a problem is about (its `n`), or 0: from Zone 4 a prime, twin prime, Mersenne prime or
## perfect square pays a rare gem (RewardsRules.gem_for_rock).
static func number_of(problem: Problem) -> int:
	return int(problem.prompt_params.get("n", 0)) if problem.prompt_params.get("n") is int else 0


## The gem this problem's rock shows and pays.
func gem_for(problem: Problem) -> StringName:
	return RewardsRules.gem_for_rock(zone_of(problem), number_of(problem))


func _on_gem_landed(_gem_type: StringName) -> void:
	_sfx.play(&"coin")
	_cart.set_totals(Rewards.coins(), flow.gems)
	var finished: int = flow.current_rock()
	flow.gem_dropped()
	rock_finished.emit(finished)
	if _pending_celebrations.is_empty():
		_after_rock()
	else:
		var lantern_only: bool = _pending_celebrations.size() == 1 and _pending_celebrations[0].get("lantern", false)
		var has_badge: bool = _pending_celebrations.any(func(item: Dictionary) -> bool: return item.has("badge"))
		_sfx.play(&"badge" if has_badge else (&"lantern" if lantern_only else &"sparkle"))
		_celebration.celebrate(_pending_celebrations.duplicate())
		_pending_celebrations.clear()


## A rock is done (and its celebration, if any, was closed): wind down if the soft limit passed.
func _after_rock() -> void:
	if not Adaptive.placement_active() and Adaptive.wind_down_due():
		_rocks_since_limit += 1
		if _rocks_since_limit > EXTRA_ROCKS_AFTER_LIMIT:
			_show_wind_down()


func _show_wind_down() -> void:
	_wall.set_interactive(false)
	_bolt.say(&"bolt.wind_down.time")
	_wind_down.show_recap(Rewards.session_summary(), Adaptive.skills_practised(), Rewards.lit_today())


## A Deep Dig wall is cleared: the next wall, or, after the last rock, the geode (once per week).
func _deep_dig_wall_done() -> void:
	if not _deep_queue.is_empty():
		_bolt.say(&"deepdig.mine.more")
		return
	_dig_more_button.visible = false
	deep_dig = false
	if Rewards.finish_deep_dig():
		# Queued, not shown here: this runs inside _on_gem_landed, which shows every celebration the
		# last rock earned in one card (a lantern or a badge would otherwise replace the geode's).
		_pending_celebrations.append({"line_id": &"deepdig.mine.done", "gem": MotivationRules.DEEP_DIG_GEM})


func _on_door_pressed() -> void:
	_sfx.play(&"select")
	request_screen.emit(&"challenge_door", {"skill_id": _door_skill})


func _on_wind_down_head_up() -> void:
	_sfx.play(&"tap")
	Rewards.session_completed(Adaptive.session_id)
	Adaptive.end_session()
	request_screen.emit(&"hub", {})


func _on_skill_celebrated(_skill_id: StringName) -> void:
	_pending_celebrations.append({"line_id": &"bolt.celebrate.mastery", "gem": RewardsRules.MASTERY_GEM})


## Every skill of a zone is mastered (Zone 6 on; RewardsRules.zone_finished): Bolt cheers with the
## zone's own line and gem when it has a zN.zone.done line (Zone 7), else with the shared zone line.
func _on_zone_completed(zone: int) -> void:
	var own: StringName = RewardsRules.zone_done_line(zone)
	if Text.has_line(own):
		_pending_celebrations.append({"line_id": own, "gem": GemArt.gem_for_zone(zone)})
	else:
		_pending_celebrations.append({"line_id": RewardsRules.ZONE_DONE_LINE, "params": {"n": zone}, "gem": RewardsRules.MASTERY_GEM})


func _on_mineral_found(gem: StringName) -> void:
	_pending_celebrations.append({"line_id": &"bolt.celebrate.mineral", "gem": gem})


func _on_badge_earned(badge_id: StringName) -> void:
	for badge: Dictionary in Rewards.badges():
		if StringName(str(badge["id"])) == badge_id:
			var name: String = Text.get_line(StringName(str(badge["name_line_id"])))
			_pending_celebrations.append({"line_id": &"badge.case.earned", "params": {"name": name}, "badge": StringName(str(badge.get("emblem", "pairs")))})


func _on_word_gem_collected(term_id: StringName) -> void:
	_pending_celebrations.append({"line_id": &"glossary.screen.found", "params": {"term": Text.term_definition(term_id).get("term", "")}, "gem": RewardsRules.MASTERY_GEM})


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
	attempt.answer_mode = AnswerPanel.answer_mode_for_kind(_panel.input_kind)
	attempt.correct = correct
	attempt.confirmed = _panel.slate_confirmed()
	attempt.hints_used = flow.wrong_count()
	attempt.latency_ms = Time.get_ticks_msec() - _answer_opened_ms
	Adaptive.record(attempt, AnswerPanel.chance_for(problem, _misses_on_problem))
	if not correct:
		_misses_on_problem += 1
		_last_misconception = misconception_of(problem, given)
	flow.submit_answer(correct)


## The child said "Try again" to the slate's "Did you write 47?". That is logged apart, as a rejected
## reading, and changes nothing: no hint, no miss, no learning evidence.
func _on_slate_rejected() -> void:
	if flow.state != DigFlow.State.AWAIT_ANSWER:
		return
	var problem: Problem = current_problem()
	var attempt: Attempt = Attempt.new()
	attempt.skill_id = problem.skill_id
	attempt.problem_seed = problem.seed
	attempt.representation = problem.representation
	attempt.answer_mode = AnswerPanel.answer_mode_for_kind(_panel.input_kind)
	attempt.correct = false
	attempt.low_confidence_rejected = true
	attempt.hints_used = flow.wrong_count()
	attempt.latency_ms = Time.get_ticks_msec() - _answer_opened_ms
	Adaptive.record(attempt, AnswerPanel.chance_for(problem, _misses_on_problem))


## A digit was accepted from the slate. With numeral coaching on (the save's settings.handwriting_coaching,
## a grown-up's switch in the parent area, off by default), the third backwards writing of a
## digit brings Bolt's stroke-order demonstration, once per digit per visit to the mine.
func _on_digit_written(digit: int, mirrored: bool) -> void:
	if _coach.note(digit, mirrored, bool(SaveSystem.data()["settings"].get("handwriting_coaching", false))):
		_show_stroke_demo(digit)


func _show_stroke_demo(digit: int) -> void:
	var overlay: Control = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = Color(0.06, 0.08, 0.14, 0.72)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dimmer)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var demo: StrokeDemo = DEMO_SCENE.instantiate()
	demo.speed_scale = animation_speed
	center.add_child(demo)
	add_child(overlay)
	_demo_overlay = overlay
	if _panel != null:
		_panel.set_enabled(false)
	demo.closed.connect(func() -> void:
		overlay.queue_free()
		_demo_overlay = null
		if _panel != null and flow.state == DigFlow.State.AWAIT_ANSWER and not _overlay_up():
			_panel.set_enabled(true))
	demo.play(digit)
	_stroke_demo = demo


## True while something sits over the answer panel (the Word Gem card or the stroke demo), so the
## panel must not take answers or strokes.
func _overlay_up() -> bool:
	return _word_gem_card.visible or _demo_overlay != null


## The named misconception whose distractor equals `given`, or &"" (GDD section 5: the targeted
## hint is keyed to the distractor the child picked or typed).
static func misconception_of(problem: Problem, given: Variant) -> StringName:
	for entry: Dictionary in problem.distractors:
		if problem.same_answer(entry["value"], given): # 2/6 typed for the 1/3 distractor is that mistake
			return StringName(entry["misconception"])
	return &""


## Hint rung `rung` for the open rock: Bolt says the problem again with its numbers highlighted,
## the not-quite line and the rung's line go under it, and the panel adds the picture from rung 2.
func _show_hint(rung: HintLadder.Rung) -> void:
	var problem: Problem = current_problem()
	if HintLadder.swaps_problem(rung, _eased):
		_ease_problem(problem)
		return
	_bolt.say(problem.prompt_line_id, problem.prompt_params, false, problem.prompt_params.keys())
	_bolt.note(&"bolt.feedback.not_quite")
	# Two lines at most, so the bubble never pushes the answer board off the screen: a named
	# mistake's targeted line says the most, otherwise the rung's line says what changed.
	var targeted: StringName = StringName("bolt.misconception.%s" % _last_misconception)
	if _last_misconception != &"" and Text.has_line(targeted):
		_bolt.add_note(targeted)
	else:
		_bolt.add_note(HintLadder.line_for(rung))
	_panel.show_hint(rung)


## Hint rung 4: an easier problem of the same skill takes the rock's place, and the skill is flagged
## so the dashboard shows it (not during the placement quest, which is only looking).
func _ease_problem(problem: Problem) -> void:
	_eased = true
	var easier: Problem = Adaptive.easier_problem(problem, _rng)
	_problems[flow.current_rock()] = easier
	if not Adaptive.placement_active():
		Adaptive.flag_for_review(problem.skill_id)
	_misses_on_problem = 0
	_bolt.say(easier.prompt_line_id, easier.prompt_params)
	_bolt.note(&"bolt.feedback.not_quite")
	_bolt.add_note(HintLadder.line_for(HintLadder.Rung.EASIER_PROBLEM))
	_show_panel(easier)


func _show_panel(problem: Problem) -> void:
	_remove_panel()
	_panel = PANEL_SCENE.instantiate()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_answer_host.add_child(_panel)
	_panel.setup(problem, _rng)
	_panel.set_enabled(false) # enabled once the problem is on screen
	_panel.answered.connect(_on_answered)
	_panel.rejected.connect(_on_slate_rejected)
	_panel.digit_written.connect(_on_digit_written)
	var sieve: SieveGrid = _panel.sieve_grid()
	if sieve != null:
		sieve.toggled.connect(func(_number: int, _crossed: bool) -> void: _sfx.play(&"sieve_mark"))
	var tree: FactorTree = _panel.factor_tree()
	if tree != null:
		tree.piece_split.connect(func(_value: int, _a: int, _b: int) -> void: _sfx.play(&"split"))
	var split: BoulderSplit = _panel.boulder_split()
	if split != null:
		split.split_chosen.connect(func(_value: int, _a: int, _b: int) -> void: _sfx.play(&"split"))
	var board: BuildBoard = _panel.board()
	if board != null:
		board.item_placed.connect(func(_kind: StringName) -> void: _sfx.play(&"place"))
		board.item_removed.connect(func(_kind: StringName) -> void: _sfx.play(&"tap"))


func _remove_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_answer_host.remove_child(_panel)
		_panel = null


## The Word Gem card covers the answer area, but InputRouter reports every tap to the drag boards
## underneath whatever is drawn over them, so the panel sleeps while the card is up.
func _on_term_tapped(term_id: StringName) -> void:
	_sfx.play(&"select")
	_word_gem_card.show_term(term_id)
	if _word_gem_card.visible and _panel != null:
		_panel.set_enabled(false)


func _on_word_gem_closed() -> void:
	if _panel != null and flow.state == DigFlow.State.AWAIT_ANSWER and not _overlay_up():
		_panel.set_enabled(true)


func _on_placement_finished(_passed: Array[StringName]) -> void:
	_bolt.add_note(&"bolt.placement.done")


func _on_pause_pressed() -> void:
	_sfx.play(&"tap")
	pause_requested.emit()


func _on_head_up_pressed() -> void:
	_sfx.play(&"tap")
	if Rewards.session_summary()["rocks"] >= ROCKS_FOR_A_SESSION:
		Rewards.session_completed(Adaptive.session_id)
	request_screen.emit(&"hub", {})
