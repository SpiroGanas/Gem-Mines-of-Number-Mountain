## Base for the workshop's screens (Sprint 16: crafting, the build site, a build): the backdrop, a
## header with Back, a title and the coins, Bolt, and the Word Gem card and celebration overlays. Each
## screen fills `body` (left) and the column under Bolt (`side`). On a phone (UI.is_compact) the header
## is the first child of `body`, so `side` starts at the top of the screen.
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
## On a phone the header heads the left column; there Back stands above the title and the coins
## unless the screen keeps them in one row (a wide left column, as the build screen's). Set before
## build_frame().
var one_row_header: bool = false

var _coins_label: Label


## Builds the frame. Call from _ready() after super().
func build_frame(title_line: StringName) -> void:
	sfx = SfxBank.new()
	add_child(sfx)
	add_child(Backdrop.new())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(edge, UI.spacing(32)) # half on a phone (UI.is_compact)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", UI.spacing(20))
	margin.add_child(column)
	# On a phone the header heads the narrow left column: Back above the title and the coins.
	var stacked: bool = UI.is_compact() and not one_row_header
	var header: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	column.add_child(header)
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = Text.get_line(&"ui.common.back")
	UI.make_touch_target(back_button, 2.5, 1.2)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)
	var title_row: BoxContainer = header
	if stacked:
		back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		title_row = HBoxContainer.new()
		title_row.add_theme_constant_override(&"separation", 16)
		header.add_child(title_row)
	var title: Label = Label.new()
	title.theme_type_variation = &"" if UI.is_compact() else &"HeadingLabel" # body size on a phone
	title.text = Text.get_line(title_line)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	_coins_label = Label.new()
	title_row.add_child(_coins_label)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override(&"separation", UI.spacing(40))
	column.add_child(columns)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_stretch_ratio = 4.0
	body.add_theme_constant_override(&"separation", UI.spacing(16))
	columns.add_child(body)
	if UI.is_compact():
		# On a phone the header (Back, the title, the coins) heads the left column only, so Bolt and the
		# problem card under him get the whole height of the screen.
		column.remove_child(header)
		body.add_child(header)
	side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 5.0
	side.add_theme_constant_override(&"separation", UI.spacing(20))
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
