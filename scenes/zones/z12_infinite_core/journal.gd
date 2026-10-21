## The Mathematician's Journal (Zone 12, The Infinite Core; P5-S47-06), reached from the Gem Museum once the child can tell the
## parts of a proof apart (proof.parts.identify). The hub of Zone 12's free play: a page for each guided proof (the practice
## proof, Euclid's infinitely many primes, the square root of 2), the number rings room and the Unsolved Mysteries room.
## Nothing here is judged or saved; the pages are for taking one's time (the skills of Zone 12 are practiced in the mine).
class_name JournalScreen
extends WorkshopScreen

const PAGES: Array[Dictionary] = [
	{"id": &"proof.practice.even_plus_even", "title": &"z12.proof.practice.title"},
	{"id": &"proof.euclid.infinite_primes", "title": &"z12.proof.euclid.title"},
	{"id": &"proof.sqrt2.irrational", "title": &"z12.proof.sqrt2.title"},
]

var _buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	super()
	build_frame(&"z12.journal.title")
	back_to = &"museum"
	var how: Label = Label.new()
	how.text = Text.get_line(&"z12.journal.how")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(how)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 12)
	body.add_child(UI.vertical_scroll(list))
	for page: Dictionary in PAGES:
		var button: Button = Button.new()
		button.name = "Page_%s" % page["id"]
		button.text = Text.get_line(page["title"])
		button.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(button, 6.0, 1.2)
		button.pressed.connect(request_screen.emit.bind(&"proof_page", {"proof_id": String(page["id"])}))
		list.add_child(button)
		_buttons[String(page["id"])] = button
	for room: Array in [["RingsButton", &"z12.journal.rings", &"number_rings"], ["MysteriesButton", &"z12.journal.mysteries", &"mysteries"]]:
		var button: Button = Button.new()
		button.name = room[0]
		button.text = Text.get_line(room[1])
		button.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(button, 6.0, 1.2)
		button.pressed.connect(request_screen.emit.bind(room[2], {}))
		list.add_child(button)
		_buttons[room[0]] = button
	bolt_node.say(&"z12.journal.hello")


func button(name: String) -> Button:
	return _buttons[name]
