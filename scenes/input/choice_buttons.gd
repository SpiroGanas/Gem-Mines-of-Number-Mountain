## Two to four big answer buttons: the right answer and distractors, shuffled.
##
## The order is shuffled with the *problem's* random number generator, so the same problem seed
## always shows the same order (tests rely on it) and the right answer is not always first.
## It never knows which option is right; the host compares the chosen value.
class_name ChoiceButtons
extends HFlowContainer

## An option was tapped. `value` is the option's value as given to setup().
signal chosen(value: Variant)

const MIN_OPTIONS: int = 2
const MAX_OPTIONS: int = 4
const BUTTON_WIDTH_MULTIPLE: float = 3.0
const BUTTON_HEIGHT_MULTIPLE: float = 1.75

var _buttons: Array[Button] = []
var _values: Array = []
var _enabled: bool = true


func _ready() -> void:
	# A flow container wraps to a second row when four buttons do not fit one.
	alignment = FlowContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"h_separation", 24)
	add_theme_constant_override(&"v_separation", 24)


## options: [{value: Variant, label: String}]. The labels are already child-facing text
## (numerals, symbols or lines from the text table). Shuffled with `rng`.
func setup(options: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	assert(options.size() >= MIN_OPTIONS and options.size() <= MAX_OPTIONS, "ChoiceButtons needs 2 to 4 options")
	for button: Button in _buttons:
		button.queue_free()
		remove_child(button)
	_buttons.clear()
	_values.clear()
	for option: Dictionary in _shuffled(options, rng):
		var button: Button = Button.new()
		button.text = str(option["label"])
		button.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
		button.disabled = not _enabled
		button.pressed.connect(_on_pressed.bind(_values.size()))
		add_child(button)
		_buttons.append(button)
		_values.append(option["value"])


## The values in on-screen order (left to right).
func values_in_order() -> Array:
	return _values.duplicate()


func button(index: int) -> Button:
	return _buttons[index]


func button_count() -> int:
	return _buttons.size()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	for each: Button in _buttons:
		each.disabled = not enabled


func _on_pressed(index: int) -> void:
	if _enabled:
		chosen.emit(_values[index])


## Fisher-Yates shuffle driven only by `rng`.
func _shuffled(options: Array[Dictionary], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var items: Array[Dictionary] = options.duplicate()
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Dictionary = items[i]
		items[i] = items[j]
		items[j] = swap
	return items
