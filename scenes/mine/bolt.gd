## Bolt, the mining robot, and his speech bubble. Bolt is Kenney's CC0 robot (Robot Pack, see
## assets/CREDITS.md) on his tracks, with his electric headlamp drawn on top in the garage's color.
## Every word comes from the text table through say(). The main line is a RichTextLabel so hint
## rung 1 can highlight the numbers in the problem (Godot note: BBCode tags such as [b] and
## [color] style parts of a RichTextLabel's text).
##
## Word Gems: set_terms() names the math terms of the problem on screen. Each one gets a chip under
## the bubble, and wherever its word appears in Bolt's line it is underlined and tappable. Either
## way term_tapped fires and the mine opens the Word Gem card (picture + kid-sized definition).
class_name Bolt
extends HBoxContainer

## The child tapped a Word Gem (a chip or an underlined word).
signal term_tapped(term_id: StringName)

const BODY_TEXTURE_PATH: String = "res://assets/art/kenney/bolt/robot_body.png"
const TRACKS_TEXTURE_PATH: String = "res://assets/art/kenney/bolt/robot_tracks.png"
## Headlamp colors (Bolt's Garage). The light is electric, always.
const LAMP_COLORS: Dictionary = {"blue": Color("#8FD3FF"), "green": Color("#7BD88F"), "gold": Color("#FFD166")}
const BUBBLE_WIDTH_MULTIPLE: float = 7.0
const NOTE_COLOR: Color = Color("#FFD166")
const OUTLINE_COLOR: Color = Color("#1F2945")
## The bubble's colors (the theme's PanelContainer style), for the tail drawn beside Bolt.
const BUBBLE_FILL: Color = ExplorerTheme.NAVY_LIGHT
const BUBBLE_EDGE: Color = ExplorerTheme.OFF_WHITE

var _line_id: StringName = &""
var _note_id: StringName = &""
var _plain: String = ""
var _highlighted: Array = []
var _params: Dictionary = {}
var _terms: Array[StringName] = []
var _links: Dictionary = {}
var _label: RichTextLabel
var _note_label: Label
var _chips: HFlowContainer
var _figure: Control


func _ready() -> void:
	add_theme_constant_override(&"separation", 0)
	var figure: Control = _BoltArt.new()
	UI.make_touch_target(figure, 2.2, 2.2) # the right part of it is the bubble's tail
	figure.size_flags_vertical = Control.SIZE_SHRINK_BEGIN # stays square when the bubble grows
	add_child(figure)
	_figure = figure
	Rewards.headlamp_changed.connect(func(_color: String) -> void: _figure.queue_redraw())
	var bubble: PanelContainer = PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(bubble)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	bubble.add_child(column)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.meta_underlined = true
	UI.make_touch_target(_label, BUBBLE_WIDTH_MULTIPLE, 1.0)
	_label.meta_clicked.connect(func(meta: Variant) -> void: term_tapped.emit(StringName(str(meta))))
	column.add_child(_label)
	# The note sits under the main line, so feedback never hides the problem.
	_note_label = Label.new()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.add_theme_color_override(&"font_color", NOTE_COLOR)
	_note_label.visible = false
	column.add_child(_note_label)
	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override(&"h_separation", 12)
	_chips.add_theme_constant_override(&"v_separation", 12)
	_chips.visible = false
	column.add_child(_chips)


## Bolt says a line from the text table. `params` fills its {placeholders}. Saying a new main
## line clears the note unless `keep_note` is true (the praise after a rock stays up while the
## child reads "Pick a rock to crack.").
## `highlight` names params whose values are drawn bold in the headlamp yellow (hint rung 1).
func say(line_id: StringName, params: Dictionary = {}, keep_note: bool = false, highlight: Array = []) -> void:
	_line_id = line_id
	_params = params.duplicate()
	_plain = Text.get_line(line_id, params)
	_highlighted = highlight.duplicate()
	_render()
	if not keep_note:
		clear_note()


## The Word Gems of the problem on screen (empty for none): a chip each, and their words in Bolt's
## line become tappable.
func set_terms(term_ids: Array[StringName]) -> void:
	_terms = term_ids.duplicate()
	_links.clear()
	for chip: Node in _chips.get_children():
		chip.queue_free()
		_chips.remove_child(chip)
	for id: StringName in _terms:
		var word: String = str(Text.term_definition(id).get("term", ""))
		if word.is_empty():
			continue
		_links[word.to_lower()] = id
		var chip: Button = Button.new()
		chip.text = word
		chip.theme_type_variation = &"WordGemButton"
		chip.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(chip, 2.0, 1.0)
		chip.pressed.connect(term_tapped.emit.bind(id))
		_chips.add_child(chip)
	_chips.visible = _chips.get_child_count() > 0
	if _line_id != &"":
		_render()


func terms() -> Array[StringName]:
	return _terms.duplicate()


## The Word Gem chips under the bubble.
func term_chips() -> Array[Button]:
	var chips: Array[Button] = []
	for chip: Node in _chips.get_children():
		chips.append(chip)
	return chips


func _render() -> void:
	_label.text = Text.get_line_bbcode(_line_id, _params, _highlighted, Text.HIGHLIGHT_COLOR, _links)


## Adds a feedback line under the main one ("Not quite. Let's look again."). The main line,
## usually the problem, stays on screen.
func note(line_id: StringName, params: Dictionary = {}) -> void:
	_note_id = line_id
	_note_label.text = Text.get_line(line_id, params)
	_note_label.visible = true


## Adds one more line under the note (the hint rung's line after "Not quite.").
func add_note(line_id: StringName, params: Dictionary = {}) -> void:
	if not _note_label.visible:
		note(line_id, params)
		return
	_note_label.text += "\n" + Text.get_line(line_id, params)


func clear_note() -> void:
	_note_id = &""
	_note_label.text = ""
	_note_label.visible = false


## The light color of a headlamp name ("blue", "green", "gold").
static func lamp_color(lamp: String) -> Color:
	return LAMP_COLORS.get(lamp, LAMP_COLORS["blue"])


func current_note_id() -> StringName:
	return _note_id


func note_text() -> String:
	return _note_label.text if _note_label.visible else ""


func current_line_id() -> StringName:
	return _line_id


## The main line as the child reads it (no BBCode tags).
func spoken_text() -> String:
	return _plain


## The params whose values are highlighted right now (empty when nothing is).
func highlighted_params() -> Array:
	return _highlighted.duplicate()


## The main line's BBCode, for tests that check the highlight.
func spoken_bbcode() -> String:
	return _label.text


class _BoltArt extends Control:
	static var _body: Texture2D
	static var _tracks: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _body == null:
			_body = load(Bolt.BODY_TEXTURE_PATH)
			_tracks = load(Bolt.TRACKS_TEXTURE_PATH)

	func _draw() -> void:
		# The bubble's tail, pointing from the bubble (at the right edge) to Bolt's head.
		var tail: PackedVector2Array = PackedVector2Array([Vector2(size.x, size.y * 0.3), Vector2(size.x, size.y * 0.52), Vector2(size.x * 0.8, size.y * 0.28)])
		draw_colored_polygon(tail, Bolt.BUBBLE_FILL)
		draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), Bolt.BUBBLE_EDGE, 3.0, true)
		# The robot: body over tracks, each at its own aspect, in the left 80% of the figure.
		var width: float = size.x * 0.8
		var body_size: Vector2 = _fit(_body, width * 0.92)
		var tracks_size: Vector2 = _fit(_tracks, width * 0.7)
		var lamp_radius: float = width * 0.08
		var stack_height: float = lamp_radius + body_size.y + tracks_size.y * 0.7
		var top: float = maxf((size.y - stack_height) * 0.5, 0.0) + lamp_radius
		var body_rect: Rect2 = Rect2(Vector2((width - body_size.x) * 0.5, top), body_size)
		var tracks_rect: Rect2 = Rect2(Vector2((width - tracks_size.x) * 0.5, body_rect.end.y - tracks_size.y * 0.3), tracks_size)
		draw_texture_rect(_tracks, tracks_rect, false)
		draw_texture_rect(_body, body_rect, false)
		# The electric headlamp, in the color from Bolt's Garage, with a soft glow.
		var lamp_center: Vector2 = Vector2(body_rect.position.x + body_size.x * 0.3, body_rect.position.y)
		var lamp: Color = Bolt.lamp_color(Rewards.headlamp())
		draw_circle(lamp_center, lamp_radius * 1.9, Color(lamp, 0.3))
		draw_circle(lamp_center, lamp_radius, lamp)
		draw_circle(lamp_center, lamp_radius, Bolt.OUTLINE_COLOR, false, 2.0, true)

	## A texture's size scaled to `width`, keeping its aspect.
	static func _fit(texture: Texture2D, width: float) -> Vector2:
		var texture_size: Vector2 = texture.get_size()
		return texture_size * (width / texture_size.x)
