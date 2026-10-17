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
## Sprint 20 poses: the Robot Pack's cheer frame, two rolling frames, a second tracks frame, and the
## question glyph for thinking (assets/CREDITS.md). The rest of each pose is a tween.
const CHEER_TEXTURE_PATH: String = "res://assets/art/kenney/bolt/robot_cheer.png"
const DRIVE_TEXTURE_PATHS: Array[String] = ["res://assets/art/kenney/bolt/robot_drive1.png", "res://assets/art/kenney/bolt/robot_drive2.png"]
const TRACKS2_TEXTURE_PATH: String = "res://assets/art/kenney/bolt/robot_tracks2.png"
const THINK_TEXTURE_PATH: String = "res://assets/art/kenney/icons/question.png"
## The six poses of the artist brief, built without an artist (docs/art/asset-inventory.md):
##   idle       standing on his tracks
##   point      leaning toward the problem in his bubble
##   cheer      the cheer frame with a hop and a squash-and-stretch
##   think      a question mark beside his head (stays until the next pose)
##   not_quite  a slow, gentle tilt; never a sad face
##   wave       rolling side to side on his tracks
const POSES: Array[StringName] = [&"idle", &"point", &"cheer", &"think", &"not_quite", &"wave"]
const POSE_SECONDS: float = 0.9
## Headlamp colors (Bolt's Garage). The light is electric, always.
const LAMP_COLORS: Dictionary = {"blue": Color("#8FD3FF"), "green": Color("#7BD88F"), "gold": Color("#FFD166"), "white": Color("#F4F7FF")}
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
var _pose: StringName = &"idle"
var _pose_tween: Tween
## 1.0 is normal speed; the mine raises it with its animation speed (tests).
var speed_scale: float = 1.0


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


## Bolt takes a pose (POSES). Every pose but think eases back to idle on its own.
func set_pose(new_pose: StringName) -> void:
	if not POSES.has(new_pose):
		return
	_pose = new_pose
	var art: _BoltArt = _figure as _BoltArt
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	art.pose = new_pose
	art.tilt = 0.0
	art.lift = 0.0
	art.squash = Vector2.ONE
	art.frame = 0
	if new_pose == &"idle" or new_pose == &"think" or not is_inside_tree():
		return
	_pose_tween = create_tween()
	_pose_tween.set_speed_scale(speed_scale)
	var step: float = POSE_SECONDS / 3.0
	match new_pose:
		&"point":
			_pose_tween.tween_property(art, "tilt", 0.12, step).set_trans(Tween.TRANS_SINE)
			_pose_tween.tween_interval(step)
			_pose_tween.tween_property(art, "tilt", 0.0, step).set_trans(Tween.TRANS_SINE)
		&"cheer":
			_pose_tween.tween_property(art, "squash", Vector2(1.12, 0.88), step * 0.5)
			_pose_tween.tween_property(art, "lift", 1.0, step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_pose_tween.parallel().tween_property(art, "squash", Vector2(0.92, 1.08), step)
			_pose_tween.tween_property(art, "lift", 0.0, step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_pose_tween.parallel().tween_property(art, "squash", Vector2.ONE, step)
		&"not_quite":
			_pose_tween.tween_property(art, "tilt", -0.08, step * 1.5).set_trans(Tween.TRANS_SINE)
			_pose_tween.tween_property(art, "tilt", 0.0, step * 1.5).set_trans(Tween.TRANS_SINE)
		&"wave":
			for swing: int in 3:
				_pose_tween.tween_property(art, "tilt", 0.07 if swing % 2 == 0 else -0.07, step * 0.6)
				_pose_tween.tween_property(art, "frame", (swing + 1) % 2, 0.0)
			_pose_tween.tween_property(art, "tilt", 0.0, step * 0.6)
	_pose_tween.tween_callback(_back_to_idle)


func _back_to_idle() -> void:
	_pose = &"idle"
	(_figure as _BoltArt).pose = &"idle"


func pose() -> StringName:
	return _pose


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
	static var _cheer: Texture2D
	static var _drive: Array[Texture2D] = []
	static var _tracks2: Texture2D
	static var _think: Texture2D

	var pose: StringName = &"idle":
		set(value):
			pose = value
			queue_redraw()
	## Lean in radians (positive: toward the bubble), hop height (0..1 of a lamp's size times 3),
	## squash-and-stretch, and the rolling frame (0 or 1). Tweened by Bolt.set_pose.
	var tilt: float = 0.0:
		set(value):
			tilt = value
			queue_redraw()
	var lift: float = 0.0:
		set(value):
			lift = value
			queue_redraw()
	var squash: Vector2 = Vector2.ONE:
		set(value):
			squash = value
			queue_redraw()
	var frame: int = 0:
		set(value):
			frame = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _body == null:
			_body = load(Bolt.BODY_TEXTURE_PATH)
			_tracks = load(Bolt.TRACKS_TEXTURE_PATH)
			_cheer = load(Bolt.CHEER_TEXTURE_PATH)
			_tracks2 = load(Bolt.TRACKS2_TEXTURE_PATH)
			_think = load(Bolt.THINK_TEXTURE_PATH)
			for path: String in Bolt.DRIVE_TEXTURE_PATHS:
				_drive.append(load(path))

	func _draw() -> void:
		# The bubble's tail, pointing from the bubble (at the right edge) to Bolt's head.
		var tail: PackedVector2Array = PackedVector2Array([Vector2(size.x, size.y * 0.3), Vector2(size.x, size.y * 0.52), Vector2(size.x * 0.8, size.y * 0.28)])
		draw_colored_polygon(tail, Bolt.BUBBLE_FILL)
		draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), Bolt.BUBBLE_EDGE, 3.0, true)
		# The robot: body over tracks, each at its own aspect, in the left 80% of the figure.
		var width: float = size.x * 0.8
		var body_texture: Texture2D = _body
		var tracks_texture: Texture2D = _tracks
		if pose == &"cheer" and _cheer != null:
			body_texture = _cheer
		elif pose == &"wave" and _drive.size() == 2:
			body_texture = _drive[frame]
			tracks_texture = _tracks2 if frame == 1 and _tracks2 != null else _tracks
		# Lean, hop and squash around the bottom of the tracks (pose tweens).
		var foot: Vector2 = Vector2(width * 0.5, size.y * 0.92)
		draw_set_transform_matrix(Transform2D(tilt, squash, 0.0, foot + Vector2(0, -lift * width * 0.18)) * Transform2D(0.0, -foot))
		var body_size: Vector2 = _fit(body_texture, width * 0.92)
		var tracks_size: Vector2 = _fit(tracks_texture, width * 0.7)
		var lamp_radius: float = width * 0.08
		var stack_height: float = lamp_radius + body_size.y + tracks_size.y * 0.7
		var top: float = maxf((size.y - stack_height) * 0.5, 0.0) + lamp_radius
		var body_rect: Rect2 = Rect2(Vector2((width - body_size.x) * 0.5, top), body_size)
		var tracks_rect: Rect2 = Rect2(Vector2((width - tracks_size.x) * 0.5, body_rect.end.y - tracks_size.y * 0.3), tracks_size)
		draw_texture_rect(tracks_texture, tracks_rect, false)
		draw_texture_rect(body_texture, body_rect, false)
		# The electric headlamp, in the color from Bolt's Garage, with a soft glow.
		var lamp_center: Vector2 = Vector2(body_rect.position.x + body_size.x * 0.3, body_rect.position.y)
		var lamp: Color = Bolt.lamp_color(Rewards.headlamp())
		draw_circle(lamp_center, lamp_radius * 1.9, Color(lamp, 0.3))
		draw_circle(lamp_center, lamp_radius, lamp)
		draw_circle(lamp_center, lamp_radius, Bolt.OUTLINE_COLOR, false, 2.0, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if pose == &"think" and _think != null:
			var bubble_center: Vector2 = Vector2(width * 0.82, body_rect.position.y)
			draw_circle(bubble_center, width * 0.16, Bolt.BUBBLE_FILL)
			draw_circle(bubble_center, width * 0.16, Bolt.BUBBLE_EDGE, false, 2.0, true)
			draw_texture_rect(_think, Rect2(bubble_center - Vector2.ONE * width * 0.1, Vector2.ONE * width * 0.2), false, Bolt.NOTE_COLOR)

	## A texture's size scaled to `width`, keeping its aspect.
	static func _fit(texture: Texture2D, width: float) -> Vector2:
		var texture_size: Vector2 = texture.get_size()
		return texture_size * (width / texture_size.x)
