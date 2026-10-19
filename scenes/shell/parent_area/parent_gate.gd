## The parental gate in front of the grown-up area (P1-S09-03; reviewed in Sprint 23): two
## multiplication questions in a row on the NumberPad (ParentGateRules, shown by GatePanel). Three
## misses lock it for 30 seconds (longer after each lock); no countdown is shown. Passing opens the
## dashboard, or the screen named in setup's "then" (the title screen's add-a-child button opens the
## profiles page); Back returns to the hub, or to setup's "back_to". Back never skips the gate: the
## grown-up screens are only reached through `passed`.
class_name ParentGateScreen
extends ShellScreen

## Milliseconds now; tests replace it to move time.
var now_ms: Callable = func() -> int: return Time.get_ticks_msec()

var _panel: GatePanel
var _back_button: Button
var _then: StringName = &"dashboard"
var _then_args: Dictionary = {}
var _back_to: StringName = &"hub"


func setup(args: Dictionary) -> void:
	_then = args.get("then", &"dashboard")
	_then_args = args.get("then_args", {})
	_back_to = args.get("back_to", &"hub")


func _ready() -> void:
	super()
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
	_panel = GatePanel.new()
	_panel.name = "GatePanel"
	_panel.now_ms = func() -> int: return now_ms.call()
	_panel.passed.connect(func() -> void: request_screen.emit(_then, _then_args))
	column.add_child(_panel)
	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = Text.get_line(&"ui.common.back")
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_back_button, 3.0, 1.25)
	_back_button.pressed.connect(func() -> void: request_screen.emit(_back_to, {}))
	column.add_child(_back_button)


## Forgets a lock from an earlier visit (tests).
static func forget_lock() -> void:
	GatePanel.forget_lock()


## The gate's rules (the current question and the lock).
var rules: ParentGateRules:
	get:
		return _panel.rules


func gate_panel() -> GatePanel:
	return _panel


func number_pad() -> NumberPad:
	return _panel.number_pad()


func question_text() -> String:
	return _panel.question_text()


func feedback_text() -> String:
	return _panel.feedback_text()
