## The number rings room (Zone 12, The Infinite Core; P5-S48-04), reached from the Mathematician's Journal. Three rings sit
## inside each other: the integers inside the rational numbers inside the real numbers. A number is written on a card and the
## child taps the smallest ring it fits in. Free play: any number of tries, no coins, nothing saved, and a wrong tap only
## brings Bolt's "Not quite. Let's look again." The cards come from NumberSetsGenerator (mode real), so this room and the
## sets.real.classify skill agree.
class_name NumberRingsScreen
extends WorkshopScreen

const RING_BUTTONS: Array[Array] = [[&"integer", &"z12.sets.ring_integer"], [&"rational", &"z12.sets.ring_rational"], [&"real", &"z12.sets.ring_real"]]

var seed_counter: int = 1
var card: Dictionary = {}
var _picture: VisualModel
var _buttons: Dictionary[StringName, Button] = {}
var _next: Button
var _skill: Skill


func _ready() -> void:
	super()
	build_frame(&"z12.rings.title")
	back_to = &"journal"
	_skill = SkillCatalog.load_all().skill(&"sets.real.classify")
	_picture = load("res://scenes/mine/visual_model.tscn").instantiate()
	_picture.compact = UI.is_compact()
	body.add_child(_picture)
	var row: HFlowContainer = HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"h_separation", 12)
	body.add_child(row)
	for entry: Array in RING_BUTTONS:
		var button: Button = Button.new()
		button.name = "Ring_%s" % entry[0]
		button.text = Text.get_line(entry[1])
		button.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(button, 4.0, 1.2)
		button.pressed.connect(choose.bind(entry[0]))
		row.add_child(button)
		_buttons[entry[0]] = button
	_next = Button.new()
	_next.name = "NextButton"
	_next.text = Text.get_line(&"z12.rings.next")
	_next.focus_mode = Control.FOCUS_NONE
	_next.theme_type_variation = &"GoButton"
	UI.make_touch_target(_next, 3.0, 1.2)
	_next.pressed.connect(next_number)
	row.add_child(_next)
	bolt_node.say(&"z12.rings.hello")
	next_number()


## A new number card.
func next_number() -> void:
	var problem: Problem = GeneratorRegistry.make_problem(_skill, seed_counter, {"difficulty": -1 if seed_counter < 4 else 0})
	seed_counter += 1
	card = problem.visual.duplicate()
	var shown: Dictionary = card.duplicate()
	shown["rings"] = true
	_picture.show_visual(shown)
	for button: Button in _buttons.values():
		button.disabled = false
	_next.disabled = true


## The child tapped a ring.
func choose(ring: StringName) -> void:
	var smallest: StringName = NumberSetsGenerator.ring_of(card)
	if ring == smallest:
		var shown: Dictionary = card.duplicate()
		shown["rings"] = true
		shown["lit"] = String(smallest)
		_picture.show_visual(shown)
		bolt_node.say(&"z12.rings.right")
		sfx.play(&"select")
		_next.disabled = false
	else:
		bolt_node.say(&"z12.rings.wrong")
		sfx.play(&"tap")


func ring_button(ring: StringName) -> Button:
	return _buttons[ring]


func next_button() -> Button:
	return _next
