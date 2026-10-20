## "How this game teaches" (Phase 3, plan section 3.7, P3-S23-08): a static page for grown-ups in
## parent language. It explains the skill map, mastery, spaced review, the hint ladder, the placement
## quest and what the game keeps on the device, and ends with the privacy policy's address as plain
## text: the game has no browser and no network (CLAUDE.md rule 1), so nothing here opens a link.
## The address lives in the text table (line parent.teach.privacy_url), not in code: lint rule 9 bans
## web addresses in game code. It is a placeholder until Spiro confirms it (docs/decisions.md, Sprint 23).
## Reached from the dashboard (behind the gate); Back returns there.
class_name HowItTeachesScreen
extends ShellScreen

## Each section: its heading line and its paragraph lines.
const SECTIONS: Array[Array] = [
	[&"parent.teach.map_title", [&"parent.teach.map_body"]],
	[&"parent.teach.mastery_title", [&"parent.teach.mastery_body"]],
	[&"parent.teach.review_title", [&"parent.teach.review_body"]],
	[&"parent.teach.hints_title", [&"parent.teach.hints_body"]],
	[&"parent.teach.placement_title", [&"parent.teach.placement_body"]],
	[&"parent.teach.mistakes_title", [&"parent.teach.mistakes_body"]],
	[&"parent.teach.privacy_title", [&"parent.teach.privacy_body", &"parent.teach.privacy_url"]],
]

var _back_to: StringName = &"dashboard"
var _content: VBoxContainer


func setup(args: Dictionary) -> void:
	_back_to = args.get("back_to", &"dashboard")


func _ready() -> void:
	super()
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 16)
	scroll.add_child(_content)
	var header: HBoxContainer = HBoxContainer.new()
	_content.add_child(header)
	var back: Button = Button.new()
	back.name = "BackButton"
	back.text = Text.get_line(&"ui.common.back")
	UI.make_touch_target(back, 3.0, 1.0)
	back.pressed.connect(func() -> void: request_screen.emit(_back_to, {}))
	header.add_child(back)
	var title: Label = _label(&"parent.teach.title")
	title.theme_type_variation = &"HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	_content.add_child(_label(&"parent.teach.intro"))
	for section: Array in SECTIONS:
		var heading: Label = _label(section[0])
		heading.add_theme_color_override(&"font_color", Bolt.NOTE_COLOR)
		_content.add_child(heading)
		for line_id: StringName in section[1]:
			_content.add_child(_label(line_id))


## Every text the page shows, in order (tests).
func texts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for node: Node in _content.find_children("*", "Label", true, false):
		found.append((node as Label).text)
	return found


func _label(line_id: StringName) -> Label:
	var label: Label = Label.new()
	label.text = Text.get_line(line_id)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
