## The Euclid machine (Zone 11, Cipher Vault): two bars, the long one a and the short one b, and the steps that find
## their GCF. Each press of Next step lays the short bar along the long bar as often as it fits and writes the step
## ("48 = 2 × 18 + 12"); what is left over becomes the next short bar. When nothing is left over the last short bar is
## the GCF. Again starts over. The picture is the `euclid` picture (VaultArt) at the step reached.
##
## Used by the toy lock (RsaDoor) to find the private key. Buttons work the same with finger, stylus and mouse; Enter
## presses Next step. All the arithmetic is EuclidGenerator.steps; this scene only shows it one step at a time.
class_name EuclidMachine
extends VBoxContainer

## The last step was shown: the GCF.
signal finished(gcd: int)
## A step was shown (for a click).
signal stepped(step_number: int)

const PICTURE_WIDTH_MULTIPLE: float = 5.0
const PICTURE_HEIGHT_MULTIPLE: float = 3.2
const BUTTON_WIDTH_MULTIPLE: float = 2.4
const BUTTON_HEIGHT_MULTIPLE: float = 1.2

var a: int = 2
var b: int = 2
## How many steps are shown (0: only the two bars).
var revealed: int = 0
var rows: Array[Dictionary] = []

var _picture: _MachinePicture
var _line: Label
var _next: Button
var _again: Button


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	alignment = BoxContainer.ALIGNMENT_CENTER


## Builds the machine for two numbers (the order does not matter).
func setup(first: int, second: int) -> void:
	a = maxi(first, second)
	b = mini(first, second)
	rows = EuclidGenerator.steps(a, b)
	revealed = 0
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_picture = _MachinePicture.new()
	_picture.name = "Machine"
	_picture.machine = self
	UI.make_touch_target(_picture, PICTURE_WIDTH_MULTIPLE, PICTURE_HEIGHT_MULTIPLE)
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_picture)
	_line = Label.new()
	_line.name = "Step"
	_line.theme_type_variation = &"NumberLabel"
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_line)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	add_child(row)
	_next = Button.new()
	_next.name = "NextButton"
	_next.text = Text.get_line(&"z11.machine.next")
	_next.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(_next, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	_next.pressed.connect(next_step)
	row.add_child(_next)
	_again = Button.new()
	_again.name = "AgainButton"
	_again.text = Text.get_line(&"z11.machine.again")
	_again.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(_again, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	_again.pressed.connect(replay)
	row.add_child(_again)
	_refresh()


## Shows the next step; at the last one says the GCF.
func next_step() -> void:
	if revealed >= rows.size():
		return
	revealed += 1
	stepped.emit(revealed)
	_refresh()
	if revealed == rows.size():
		finished.emit(gcd())


func replay() -> void:
	revealed = 0
	_refresh()


## The GCF: the last short bar.
func gcd() -> int:
	return int(rows.back()["b"]) if not rows.is_empty() else a


func is_done() -> bool:
	return revealed >= rows.size()


func next_button() -> Button:
	return _next


func again_button() -> Button:
	return _again


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and is_visible_in_tree():
		next_step()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _next == null:
		return
	_next.disabled = revealed >= rows.size()
	if revealed == 0:
		_line.text = ""
	elif revealed < rows.size():
		_line.text = Text.get_line(&"z11.machine.step", rows[revealed - 1])
	else:
		_line.text = Text.get_line(&"z11.machine.done", {"g": gcd()})
	if _picture != null:
		_picture.queue_redraw()


## The bars and the steps shown so far.
class _MachinePicture:
	extends Control

	var machine: EuclidMachine

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if machine == null:
			return
		VaultArt.draw_euclid(self, Rect2(Vector2(4, 4), size - Vector2(8, 8)), EuclidGenerator.euclid_picture(machine.a, machine.b, machine.revealed), get_theme_default_font())
