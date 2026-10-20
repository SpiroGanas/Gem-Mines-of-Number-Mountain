## The Unsolved Mysteries room (Zone 12, The Infinite Core; P5-S49-02), reached from the Mathematician's Journal. Two display
## cases: Goldbach's guess (every even number above 2 is two primes added) and the twin primes (are there always more
## primes that are 2 apart?). Each case lets the child try small cases, where answers can be found, and says plainly that
## nobody has proven it for every number. That is the mystery.
##
## Free play: any pair of primes that adds up to the number is right (the room checks with MysteryGenerator, which lists them
## all); a wrong try only brings Bolt's gentle line. Nothing is scored or saved. Prime buttons are at least one touch target.
class_name MysteriesScreen
extends WorkshopScreen

enum Case { GOLDBACH, TWIN }

const MAX_N: int = 100
const MAX_P: int = 190
const STEP_WIDTH_MULTIPLE: float = 1.6

var case_now: Case = Case.GOLDBACH
## The even number for Goldbach and the start for the twin primes.
var n: int = 10
var p: int = 10
## The primes tapped so far for Goldbach (at most two).
var picked: Array[int] = []

var _case_buttons: Dictionary[int, Button] = {}
var _note: Label
var _value: Label
var _primes: HFlowContainer
var _prime_buttons: Dictionary[int, Button] = {}
var _stepper_title: Label


func _ready() -> void:
	super()
	build_frame(&"z12.mysteries.title")
	back_to = &"journal"
	var cases: HBoxContainer = HBoxContainer.new()
	cases.add_theme_constant_override(&"separation", 12)
	body.add_child(cases)
	for entry: Array in [[Case.GOLDBACH, "GoldbachButton", &"z12.mysteries.goldbach_name"], [Case.TWIN, "TwinButton", &"z12.mysteries.twin_name"]]:
		var button: Button = Button.new()
		button.name = entry[1]
		button.text = Text.get_line(entry[2])
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(button, 4.0, 1.2)
		button.pressed.connect(show_case.bind(entry[0]))
		cases.add_child(button)
		_case_buttons[entry[0]] = button
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 10)
	body.add_child(UI.vertical_scroll(content))
	_note = Label.new()
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_note)
	var stepper: HBoxContainer = HBoxContainer.new()
	stepper.add_theme_constant_override(&"separation", 8)
	content.add_child(stepper)
	_stepper_title = Label.new()
	stepper.add_child(_stepper_title)
	for entry: Array in [["LessButton", &"z11.coins.less", -1], ["MoreButton", &"z11.coins.more", 1]]:
		var button: Button = Button.new()
		button.name = entry[0]
		button.text = Text.get_line(entry[1])
		button.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(button, STEP_WIDTH_MULTIPLE, 1.0)
		button.pressed.connect(change.bind(entry[2]))
		stepper.add_child(button)
		if entry[2] < 0:
			_value = Label.new()
			_value.name = "Value"
			_value.theme_type_variation = &"NumberLabel"
			_value.custom_minimum_size.x = UI.target_size(1.2, 1.0).x
			_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stepper.add_child(_value)
	_primes = HFlowContainer.new()
	_primes.name = "Primes"
	_primes.add_theme_constant_override(&"h_separation", 8)
	_primes.add_theme_constant_override(&"v_separation", 8)
	content.add_child(_primes)
	show_case(Case.GOLDBACH)


func show_case(which: Case) -> void:
	case_now = which
	picked.clear()
	for key: int in _case_buttons:
		_case_buttons[key].set_pressed_no_signal(key == which)
	_note.text = Text.get_line(&"z12.mysteries.goldbach_note" if which == Case.GOLDBACH else &"z12.mysteries.twin_note")
	_stepper_title.text = Text.get_line(&"z12.mysteries.goldbach_pick" if which == Case.GOLDBACH else &"z12.mysteries.twin_pick")
	bolt_node.say(&"z12.mysteries.goldbach_ask" if which == Case.GOLDBACH else &"z12.mysteries.twin_ask", _ask_params())
	_rebuild()


## Less and More on the number: Goldbach's even number moves by 2, the twin start by 10.
func change(direction: int) -> void:
	if case_now == Case.GOLDBACH:
		n = clampi(n + 2 * direction, 4, MAX_N)
	else:
		p = clampi(p + 10 * direction, 0, MAX_P)
	picked.clear()
	bolt_node.say(&"z12.mysteries.goldbach_ask" if case_now == Case.GOLDBACH else &"z12.mysteries.twin_ask", _ask_params())
	_rebuild()


## A prime button was tapped. Goldbach: the second tap checks the pair. Twin primes: the tap checks the pair that starts here.
func tap_prime(prime: int) -> void:
	if case_now == Case.GOLDBACH:
		if picked.has(prime):
			picked.erase(prime)
		elif picked.size() < 2:
			picked.append(prime)
		if picked.size() == 2:
			var total: int = picked[0] + picked[1]
			if total == n:
				picked.sort()
				bolt_node.say(&"z12.mysteries.goldbach_yes", {"p": picked[0], "q": picked[1], "n": n})
				sfx.play(&"select")
			else:
				bolt_node.say(&"z12.mysteries.goldbach_no", {"p": picked[0], "q": picked[1], "s": total, "n": n})
				sfx.play(&"tap")
	else:
		if prime == MysteryGenerator.next_twin(p):
			bolt_node.say(&"z12.mysteries.twin_yes", {"q": prime, "r": prime + 2})
			sfx.play(&"select")
		elif MathUtil.is_prime(prime + 2):
			bolt_node.say(&"z12.mysteries.twin_later", {"q": prime, "r": prime + 2})
		else:
			bolt_node.say(&"z12.mysteries.twin_no")
			sfx.play(&"tap")
	_refresh_picks()


## The primes offered now: Goldbach, the primes below the number; twin primes, the primes after the start up to the first
## twin pair and its partner.
func offered_primes() -> Array[int]:
	var found: Array[int] = []
	if case_now == Case.GOLDBACH:
		for prime: int in range(2, n):
			if MathUtil.is_prime(prime):
				found.append(prime)
	else:
		var last: int = MysteryGenerator.next_twin(p) + 2
		for prime: int in range(p + 1, last + 1):
			if MathUtil.is_prime(prime):
				found.append(prime)
	return found


func prime_button(prime: int) -> Button:
	return _prime_buttons[prime]


func _ask_params() -> Dictionary:
	return {"n": n} if case_now == Case.GOLDBACH else {"p": p}


func _rebuild() -> void:
	for child: Node in _primes.get_children():
		_primes.remove_child(child)
		child.queue_free()
	_prime_buttons.clear()
	_value.text = Text.display_value(n if case_now == Case.GOLDBACH else p)
	for prime: int in offered_primes():
		var button: Button = Button.new()
		button.name = "Prime_%d" % prime
		button.text = Text.display_value(prime)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(button, 1.0, 1.0)
		button.pressed.connect(tap_prime.bind(prime))
		_primes.add_child(button)
		_prime_buttons[prime] = button
	_refresh_picks()


func _refresh_picks() -> void:
	for prime: int in _prime_buttons:
		_prime_buttons[prime].set_pressed_no_signal(picked.has(prime))
