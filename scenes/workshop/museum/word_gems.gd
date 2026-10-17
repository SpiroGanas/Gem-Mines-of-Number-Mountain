## The Word Gems glossary (Sprint 19, P2-S19-02): every math word the game teaches. A Word Gem is
## collected the first time a mastered skill uses it (Rewards.sync_word_gems); a collected one opens
## its card (picture and kid-sized definition), one still to find shows dim. Reached from the Museum.
class_name WordGemsScreen
extends WorkshopScreen

var _buttons: Dictionary[StringName, Button] = {}
var _count: Label


func _ready() -> void:
	super()
	build_frame(&"glossary.screen.title")
	back_to = &"museum"
	body.size_flags_stretch_ratio = 7.0
	side.size_flags_stretch_ratio = 3.0
	var terms: Array[StringName] = Text.term_ids()
	var found: int = 0
	for term: StringName in terms:
		if Rewards.has_word_gem(term):
			found += 1
	_count = Label.new()
	_count.text = Text.get_line(&"glossary.screen.count", {"n": found, "total": terms.size()})
	body.add_child(_count)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	# A flow, not a fixed grid, so the gems wrap to fit 16:9 down to 4:3 (seen in the Sprint 20 captures).
	var grid: HFlowContainer = HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_theme_constant_override(&"v_separation", 16)
	scroll.add_child(grid)
	for term: StringName in terms:
		var button: Button = Button.new()
		button.name = "Term_%s" % term
		UI.make_touch_target(button, 2.6, 1.1)
		if Rewards.has_word_gem(term):
			button.text = Text.term_definition(term)["term"]
			button.theme_type_variation = &"WordGemButton"
			button.pressed.connect(_on_term_pressed.bind(term))
		else:
			button.text = Text.get_line(&"glossary.screen.locked")
			button.disabled = true
		grid.add_child(button)
		_buttons[term] = button
	bolt_node.say(&"glossary.screen.hello")


func term_button(term: StringName) -> Button:
	return _buttons.get(term)


func found_text() -> String:
	return _count.text


func _on_term_pressed(term: StringName) -> void:
	_on_term_tapped(term)
