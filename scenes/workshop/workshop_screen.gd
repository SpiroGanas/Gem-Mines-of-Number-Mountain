## Base for the workshop's screens (Sprint 16: crafting, the build site, a build): the backdrop, a
## header with Back, a title and the coins, Bolt, and the Word Gem card and celebration overlays. Each
## screen fills `body` (left) and the column under Bolt (`side`).
class_name WorkshopScreen
extends ShellScreen

## Where Back goes.
var back_to: StringName = &"hub"
var back_args: Dictionary = {}

var body: VBoxContainer
var side: VBoxContainer
var bolt_node: Bolt
var sfx: SfxBank
var celebration: Celebration
var word_gem_card: WordGemCard
var back_button: Button

var _coins_label: Label


## Builds the frame. Call from _ready() after super().
func build_frame(title_line: StringName) -> void:
	sfx = SfxBank.new()
	add_child(sfx)
	add_child(Backdrop.new())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(edge, 32)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 20)
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = Text.get_line(&"ui.common.back")
	UI.make_touch_target(back_button, 2.5, 1.2)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)
	var title: Label = Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.text = Text.get_line(title_line)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	_coins_label = Label.new()
	header.add_child(_coins_label)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override(&"separation", 40)
	column.add_child(columns)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_stretch_ratio = 4.0
	body.add_theme_constant_override(&"separation", 16)
	columns.add_child(body)
	side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 5.0
	side.add_theme_constant_override(&"separation", 20)
	columns.add_child(side)
	bolt_node = load("res://scenes/mine/bolt.tscn").instantiate()
	side.add_child(bolt_node)
	celebration = Celebration.new()
	add_child(celebration)
	word_gem_card = WordGemCard.new()
	add_child(word_gem_card)
	bolt_node.term_tapped.connect(_on_term_tapped)
	refresh_coins()


func refresh_coins() -> void:
	_coins_label.text = Text.get_line(&"ui.hub.coins", {"n": Rewards.coins()})


## A problem card under Bolt, wired to him.
func make_card() -> ProblemCard:
	var card: ProblemCard = ProblemCard.new()
	card.name = "ProblemCard"
	card.bolt = bolt_node
	side.add_child(card)
	return card


func _on_term_tapped(term_id: StringName) -> void:
	sfx.play(&"select")
	word_gem_card.show_term(term_id)


func _on_back_pressed() -> void:
	sfx.play(&"tap")
	request_screen.emit(back_to, back_args)
