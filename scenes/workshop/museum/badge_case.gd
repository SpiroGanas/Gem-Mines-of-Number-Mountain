## The Badge Case (Sprint 19, P2-S19-01): the mathematician badges, earned by mastering the skills
## each one lists (MotivationRules.earn_badges). An earned badge opens its short story; a badge not
## earned yet shows dim. Reached from the Gem Museum.
class_name BadgeCaseScreen
extends WorkshopScreen

var _buttons: Dictionary[StringName, Button] = {}
var _story: VBoxContainer


func _ready() -> void:
	super()
	build_frame(&"badge.case.title")
	back_to = &"museum"
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 24)
	body.add_child(grid)
	for badge: Dictionary in Rewards.badges():
		grid.add_child(_make_badge(badge))
	_story = VBoxContainer.new()
	_story.name = "Story"
	_story.add_theme_constant_override(&"separation", 12)
	side.add_child(_story)
	bolt_node.say(&"badge.case.hello")


func badge_button(badge_id: StringName) -> Button:
	return _buttons.get(badge_id)


## The lines of the story on screen (empty when none is open).
func story_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for child: Node in _story.get_children():
		if child is Label:
			texts.append((child as Label).text)
	return texts


func _make_badge(badge: Dictionary) -> Control:
	var id: StringName = StringName(str(badge["id"]))
	var earned: bool = Rewards.has_badge(id)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	var art: BadgeArt = BadgeArt.new()
	art.emblem = StringName(str(badge.get("emblem", "pairs")))
	art.earned = earned
	art.custom_minimum_size = UI.target_size(2.6, 2.6)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(art)
	var name_label: Label = Label.new()
	name_label.text = Text.get_line(StringName(str(badge["name_line_id"])))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var button: Button = Button.new()
	button.name = "Badge_%s" % id
	button.text = Text.get_line(&"badge.case.read" if earned else &"badge.case.locked")
	button.disabled = not earned
	UI.make_touch_target(button, 3.5, 1.1)
	button.pressed.connect(_show_story.bind(badge))
	column.add_child(button)
	_buttons[id] = button
	return column


func _show_story(badge: Dictionary) -> void:
	sfx.play(&"select")
	for child: Node in _story.get_children():
		child.queue_free()
		_story.remove_child(child)
	var heading: Label = Label.new()
	heading.theme_type_variation = &"HeadingLabel"
	heading.text = Text.get_line(StringName(str(badge["name_line_id"])))
	_story.add_child(heading)
	for entry: Dictionary in badge.get("story", []):
		var line: Label = Label.new()
		line.text = Text.get_line(StringName(str(entry["line_id"])), entry.get("params", {}))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_story.add_child(line)
