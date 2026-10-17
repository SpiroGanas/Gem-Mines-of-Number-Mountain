## The Gem Museum (P1-S08-02): one display case per mineral, ten in the MVP. A case opens when the
## child holds that mineral (Rewards.museum_open). Tapping a case shows its name and a short fact,
## or, while it is still closed, how to find it. Pieces are earned by digging and learning, never
## bought. Built in code; every word comes from the text table.
class_name MuseumScreen
extends ShellScreen

const CASE_WIDTH_MULTIPLE: float = 2.6
const CASE_HEIGHT_MULTIPLE: float = 2.6
const LOCKED_TINT: Color = Color(0.2, 0.24, 0.36, 1.0)
## How each mineral is found: a zone's rocks, a first mastery, or a milestone (RewardsRules).
const HOW_LINES: Dictionary = {
	&"quartz": &"hub.museum.quartz_how", &"garnet": &"hub.museum.garnet_how", &"pyrite": &"hub.museum.pyrite_how",
	&"amethyst": &"hub.museum.amethyst_how", &"malachite": &"hub.museum.malachite_how",
	&"fluorite": &"hub.museum.fluorite_how", &"hematite": &"hub.museum.hematite_how",
}

var _cases: Dictionary[StringName, Button] = {}
var _detail_name: Label
var _detail_text: Label
var _detail_gem: GemArt
var _back_button: Button
var _selected: StringName = &""
var _sfx: SfxBank


func _ready() -> void:
	super()
	_sfx = SfxBank.new()
	add_child(_sfx)
	add_child(Backdrop.new())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 24)
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = Text.get_line(&"ui.common.back")
	UI.make_touch_target(_back_button, 2.5, 1.2)
	_back_button.pressed.connect(request_screen.emit.bind(&"hub", {}))
	header.add_child(_back_button)
	var title: Label = Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.text = Text.get_line(&"hub.museum.title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 40)
	column.add_child(body)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override(&"h_separation", 20)
	grid.add_theme_constant_override(&"v_separation", 20)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(grid)
	for mineral: StringName in GemArt.ALL_TYPES:
		grid.add_child(_make_case(mineral))
	var detail: PanelContainer = PanelContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(detail)
	var detail_column: VBoxContainer = VBoxContainer.new()
	detail_column.add_theme_constant_override(&"separation", 16)
	detail.add_child(detail_column)
	_detail_gem = GemArt.new()
	_detail_gem.custom_minimum_size = UI.target_size(1.8, 1.8)
	_detail_gem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	detail_column.add_child(_detail_gem)
	_detail_name = Label.new()
	_detail_name.theme_type_variation = &"HeadingLabel"
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_column.add_child(_detail_name)
	_detail_text = Label.new()
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_text.custom_minimum_size.x = UI.target_size(6.0, 1.0).x
	detail_column.add_child(_detail_text)
	_detail_gem.visible = false
	_detail_text.text = Text.get_line(&"hub.museum.pick")


## The case button for a mineral, for tests.
func case_button(mineral: StringName) -> Button:
	return _cases[mineral]


func is_open(mineral: StringName) -> bool:
	return Rewards.museum_open(mineral)


func detail_text() -> String:
	return _detail_text.text


func detail_name() -> String:
	return _detail_name.text


## Shows a case's card: its name and fact if open, or how to find it if not.
func select(mineral: StringName) -> void:
	_selected = mineral
	if _sfx != null:
		_sfx.play(&"select")
	_detail_gem.visible = true
	_detail_gem.gem_type = mineral
	if is_open(mineral):
		_detail_gem.modulate = Color.WHITE
		_detail_name.text = Text.get_line(StringName("hub.museum.%s_name" % mineral))
		var fact: String = Text.get_line(StringName("hub.museum.%s_fact" % mineral))
		_detail_text.text = "\n".join(PackedStringArray([fact, Text.get_line(&"hub.museum.you_have", {"n": Rewards.gem_count(mineral)})]))
	else:
		_detail_gem.modulate = LOCKED_TINT
		_detail_name.text = Text.get_line(&"hub.museum.not_found")
		_detail_text.text = _how_to_find(mineral)


func _how_to_find(mineral: StringName) -> String:
	if HOW_LINES.has(mineral):
		return Text.get_line(HOW_LINES[mineral])
	for milestone: Dictionary in RewardsRules.MILESTONES:
		if milestone["gem"] == mineral and milestone.has("mastered"):
			return Text.get_line(&"hub.museum.how_learn_n", {"n": int(milestone["mastered"])})
	return Text.get_line(&"hub.museum.not_found")


func _make_case(mineral: StringName) -> Button:
	var button: Button = Button.new()
	button.name = "Case_%s" % mineral
	button.focus_mode = Control.FOCUS_ALL
	UI.make_touch_target(button, CASE_WIDTH_MULTIPLE, CASE_HEIGHT_MULTIPLE)
	var gem: GemArt = GemArt.new()
	gem.gem_type = mineral
	gem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gem.offset_left = 20
	gem.offset_top = 20
	gem.offset_right = -20
	gem.offset_bottom = -20
	# A closed case shows only a dark outline of its mineral: the shape is the clue.
	gem.modulate = Color.WHITE if Rewards.museum_open(mineral) else LOCKED_TINT
	button.add_child(gem)
	button.pressed.connect(select.bind(mineral))
	_cases[mineral] = button
	return button
