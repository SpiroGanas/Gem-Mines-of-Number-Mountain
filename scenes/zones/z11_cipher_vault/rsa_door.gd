## The toy lock door (Zone 11, Cipher Vault; P5-S45-06), reached from the Gem Museum once the child can make the keys
## of a toy lock (rsa.toy.keygen). Two small primes make n and the loop size t = (p - 1) × (q - 1); a public key e
## locks a number, a private key d unlocks it, and the child sees both on the screen, step by step: the Euclid machine
## finds d, then a chosen number is locked (m to the power e on the loop of n) and unlocked (c to the power d) and comes
## back as the same number.
##
## The child chooses p, q, e and the number with Less and More buttons; every number is worked out by RsaGenerator and
## EuclidGenerator, so this screen only shows them. Nothing is judged right or wrong here, nothing is saved, and
## nothing leaves the screen (CLAUDE.md rules 1 and 2). Primes stay at most 13 so every number fits.
##
## Only real locks are offered (RsaGenerator.is_real_key): a private key that differs from the public key and a lock
## that changes numbers. Two primes with no such key (3 and 5, 3 and 7, 5 and 7, 3 and 13: on their loops every key is
## its own undo partner) are skipped by the Less and More buttons, so the door always shows two different keys.
class_name RsaDoorScreen
extends WorkshopScreen

const PRIMES: Array[int] = [3, 5, 7, 11, 13]
const STEP_WIDTH_MULTIPLE: float = 1.6

var p_index: int = 0
var q_index: int = 3 # 3 and 11: the smallest pair with a real lock
var e_index: int = 0
var number: int = 2

var _rows: VBoxContainer
var _values: Dictionary[String, Label] = {}
var _machine: EuclidMachine
var _result_labels: Dictionary[String, Label] = {}


func _ready() -> void:
	super()
	build_frame(&"z11.door.title")
	back_to = &"museum"
	var scroll_body: VBoxContainer = body
	body = VBoxContainer.new() # the steps scroll when a phone is too short for them
	body.add_theme_constant_override(&"separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_body.add_child(UI.vertical_scroll(body))
	var how: Label = Label.new()
	how.text = Text.get_line(&"z11.door.how")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(how)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 8)
	body.add_child(_rows)
	for entry: Array in [[&"z11.door.prime_p", "P", change_p], [&"z11.door.prime_q", "Q", change_q], [&"z11.door.key_e", "E", change_e], [&"z11.door.number_m", "M", change_number]]:
		_rows.add_child(_stepper_row(entry[0], entry[1], entry[2]))
	for name: String in ["n", "t", "d", "lock", "unlock", "same"]:
		var line: Label = Label.new()
		line.name = "Result_" + name
		line.theme_type_variation = &"NumberLabel" if name != "same" else &""
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(line)
		_result_labels[name] = line
	_machine = load("res://scenes/zones/z11_cipher_vault/euclid_machine.tscn").instantiate()
	side.add_child(UI.vertical_scroll(_machine))
	bolt_node.say(&"z11.door.hello")
	_settle()


func _stepper_row(title_line: StringName, node_name: String, callback: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var title: Label = Label.new()
	title.text = Text.get_line(title_line)
	title.custom_minimum_size.x = UI.target_size(2.6, 1.0).x
	row.add_child(title)
	var less: Button = Button.new()
	less.name = node_name + "Less"
	less.text = Text.get_line(&"z11.coins.less")
	less.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(less, STEP_WIDTH_MULTIPLE, 1.0)
	less.pressed.connect(callback.bind(-1))
	row.add_child(less)
	var value: Label = Label.new()
	value.name = node_name + "Value"
	value.theme_type_variation = &"NumberLabel"
	value.custom_minimum_size.x = UI.target_size(1.0, 1.0).x
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	_values[node_name] = value
	var more: Button = Button.new()
	more.name = node_name + "More"
	more.text = Text.get_line(&"z11.coins.more")
	more.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(more, STEP_WIDTH_MULTIPLE, 1.0)
	more.pressed.connect(callback.bind(1))
	row.add_child(more)
	return row


func p() -> int:
	return PRIMES[p_index]


func q() -> int:
	return PRIMES[q_index]


## The public keys that make a real lock for this pair of primes (RsaGenerator.is_real_key).
func keys() -> Array[int]:
	return keys_for(p_index, q_index)


static func keys_for(first: int, second: int) -> Array[int]:
	var found: Array[int] = []
	for e: int in RsaGenerator.E_CHOICES:
		if RsaGenerator.is_real_key(e, PRIMES[first], PRIMES[second]):
			found.append(e)
	return found


func e() -> int:
	var found: Array[int] = keys()
	if found.is_empty():
		return 1
	return found[clampi(e_index, 0, found.size() - 1)]


func n() -> int:
	return p() * q()


func t() -> int:
	return (p() - 1) * (q() - 1)


func d() -> int:
	return RsaGenerator.private_key(e(), t())


## The number that is locked: the chosen number on the loop of n.
func locked() -> int:
	return RsaGenerator.pow_mod(number, e(), n())


func change_p(delta: int) -> void:
	p_index = _next_prime(p_index, delta, q_index)
	_settle()


func change_q(delta: int) -> void:
	q_index = _next_prime(q_index, delta, p_index)
	_settle()


func change_e(delta: int) -> void:
	e_index = clampi(e_index + delta, 0, keys().size() - 1)
	_settle()


func change_number(delta: int) -> void:
	number = clampi(number + delta, 2, n() - 1)
	_settle()


## The next prime in the list in a direction that makes a real lock with the other prime; the same index when none does.
func _next_prime(index: int, delta: int, other: int) -> int:
	var next: int = index + delta
	while next >= 0 and next < PRIMES.size():
		if next != other and not keys_for(next, other).is_empty():
			return next
		next += delta
	return index


func _settle() -> void:
	if keys().is_empty(): # a pair with no real lock (only reachable by setting the indexes directly): the first that has one
		for first: int in PRIMES.size():
			for second: int in PRIMES.size():
				if first != second and not keys_for(first, second).is_empty():
					p_index = first
					q_index = second
					break
			if not keys().is_empty():
				break
	e_index = clampi(e_index, 0, keys().size() - 1)
	number = clampi(number, 2, n() - 1)
	_refresh()


func machine() -> EuclidMachine:
	return _machine


func result_label(name: String) -> Label:
	return _result_labels[name]


func _refresh() -> void:
	if _machine == null:
		return
	_values["P"].text = Text.display_value(p())
	_values["Q"].text = Text.display_value(q())
	_values["E"].text = Text.display_value(e())
	_values["M"].text = Text.display_value(number)
	_result_labels["n"].text = Text.get_line(&"z11.door.n", {"p": p(), "q": q(), "n": n()})
	_result_labels["t"].text = Text.get_line(&"z11.door.t", {"p": p(), "q": q(), "t": t()})
	_result_labels["d"].text = Text.get_line(&"z11.door.d", {"e": e(), "d": d(), "t": t()})
	_result_labels["lock"].text = Text.get_line(&"z11.door.lock", {"m": number, "e": e(), "n": n(), "c": locked()})
	_result_labels["unlock"].text = Text.get_line(&"z11.door.unlock", {"c": locked(), "d": d(), "n": n(), "m": RsaGenerator.pow_mod(locked(), d(), n())})
	_result_labels["same"].text = Text.get_line(&"z11.door.same")
	_machine.setup(t(), e())
