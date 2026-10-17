## The parental gate in front of the grown-up area (P1-S09-03): a two-digit times one-digit question
## on the NumberPad (ParentGateRules). Three misses lock it for 30 seconds; no countdown is shown.
## Passing opens the dashboard; Back returns to the workshop.
class_name ParentGateScreen
extends ShellScreen

var rules: ParentGateRules
## Milliseconds now; tests replace it to move time.
var now_ms: Callable = func() -> int: return Time.get_ticks_msec()

var _question: Label
var _feedback: Label
var _pad: NumberPad
var _back_button: Button
var _unlock_timer: Timer


func _ready() -> void:
	super()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	rules = ParentGateRules.new(rng)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 24)
	center.add_child(column)
	var title: Label = Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.text = Text.get_line(&"parent.gate.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_question = Label.new()
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_question)
	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_color_override(&"font_color", Bolt.NOTE_COLOR)
	column.add_child(_feedback)
	_pad = load("res://scenes/input/number_pad.tscn").instantiate()
	_pad.max_digits = 3
	_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_pad)
	_pad.submitted.connect(_on_submitted)
	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = Text.get_line(&"ui.common.back")
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_back_button, 3.0, 1.25)
	_back_button.pressed.connect(request_screen.emit.bind(&"hub", {}))
	column.add_child(_back_button)
	_unlock_timer = Timer.new()
	_unlock_timer.one_shot = true
	_unlock_timer.timeout.connect(_on_unlocked)
	add_child(_unlock_timer)
	_show_question()


func number_pad() -> NumberPad:
	return _pad


func question_text() -> String:
	return _question.text


func feedback_text() -> String:
	return _feedback.text


func _show_question() -> void:
	_question.text = Text.get_line(&"parent.gate.question", {"a": rules.a, "b": rules.b})


func _on_submitted(value: int) -> void:
	_pad.clear()
	match rules.submit(value, now_ms.call()):
		ParentGateRules.Result.PASSED:
			request_screen.emit(&"dashboard", {})
		ParentGateRules.Result.MISSED:
			_feedback.text = Text.get_line(&"parent.gate.missed")
			_show_question()
		ParentGateRules.Result.LOCKED:
			_feedback.text = Text.get_line(&"parent.gate.wait")
			_pad.set_enabled(false)
			_show_question()
			_unlock_timer.start(float(maxi(rules.locked_until_ms - now_ms.call(), 1)) / 1000.0)


func _on_unlocked() -> void:
	_feedback.text = ""
	_pad.set_enabled(true)
