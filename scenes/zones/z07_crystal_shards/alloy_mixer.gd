## The alloy mixer (Zone 7, Sprint 33; meta.alloy = {a, b, given, max}): the recipe card (a copper to
## b tin, drawn as ore), the copper hopper already holding `given` copper, the tin hopper the child
## fills with More tin and Less tin, and the electric mixing drum. Mix hands in the tin count and spins
## the drum (an electric motor: no flame, steam or smoke anywhere). The mixer never says whether the
## mix is right; the host decides (the rule is Alloy.is_right_mix).
##
## Used for ratio.scale.alloy rocks in the mine and for every step of the Alloy Mixer build. Buttons
## work the same with finger, stylus and mouse; the Plus and Minus keys and Enter work too.
class_name AlloyMixer
extends VBoxContainer

## Mix was pressed: how many tin scoops are in the hopper.
signal submitted(tin: int)
## The tin count changed (for a sound).
signal tin_changed(tin: int)

const BUTTON_WIDTH_MULTIPLE: float = 2.6
const BUTTON_HEIGHT_MULTIPLE: float = 1.2
const PICTURE_HEIGHT_MULTIPLE: float = 3.2

var recipe_a: int = 2
var recipe_b: int = 3
var copper: int = 4
var max_tin: int = 12
var tin: int = 0
## Tests set 0 to skip the drum's spin.
var speed_scale: float = 1.0

var _picture: _MixerPicture
var _more: Button
var _less: Button
var _mix: Button
var _count: Label
var _enabled: bool = true


func _ready() -> void:
	add_theme_constant_override(&"separation", 12)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var how: Label = Label.new()
	how.name = "How"
	how.text = Text.get_line(&"z7.alloy.how")
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(how)
	_picture = _MixerPicture.new()
	_picture.name = "Mixer"
	_picture.copper_line = Text.get_line(&"z7.alloy.copper")
	_picture.tin_line = Text.get_line(&"z7.alloy.tin")
	UI.make_touch_target(_picture, 7.0, PICTURE_HEIGHT_MULTIPLE)
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_picture)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Controls"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 20)
	add_child(row)
	_less = _button(&"z7.alloy.less", "LessButton")
	_less.pressed.connect(change_tin.bind(-1))
	row.add_child(_less)
	_count = Label.new()
	_count.name = "TinCount"
	_count.theme_type_variation = &"NumberLabel"
	_count.custom_minimum_size.x = UI.target_size(1.2, 1.0).x
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_count)
	_more = _button(&"z7.alloy.more", "MoreButton")
	_more.pressed.connect(change_tin.bind(1))
	row.add_child(_more)
	_mix = _button(&"z7.alloy.mix", "MixButton")
	_mix.theme_type_variation = &"GoButton"
	_mix.pressed.connect(submit)
	row.add_child(_mix)
	_refresh()


## A recipe of a copper to b tin, `given` copper in the hopper, room for `most` tin scoops.
func setup(a: int, b: int, given: int, most: int) -> void:
	recipe_a = a
	recipe_b = b
	copper = given
	max_tin = maxi(most, 1)
	tin = 0
	_refresh()


## Adds (positive) or takes out (negative) tin scoops, between 0 and the hopper's size.
func change_tin(scoops: int) -> void:
	if not _enabled:
		return
	var before: int = tin
	tin = clampi(tin + scoops, 0, max_tin)
	if tin != before:
		_refresh()
		tin_changed.emit(tin)


## Sets the tin count directly (tests and the keyboard).
func set_tin(count: int) -> void:
	change_tin(count - tin)


func submit() -> void:
	if not _enabled:
		return
	submitted.emit(tin)
	if speed_scale > 0.0 and is_inside_tree():
		var spin: Tween = create_tween()
		spin.tween_property(_picture, "drum_turn", 1.0, 0.8 * speed_scale).from(0.0)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_refresh()


func more_button() -> Button:
	return _more


func less_button() -> Button:
	return _less


func mix_button() -> Button:
	return _mix


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not is_visible_in_tree():
		return
	match event.keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_UP:
			change_tin(1)
		KEY_MINUS, KEY_KP_SUBTRACT, KEY_DOWN:
			change_tin(-1)
		KEY_ENTER, KEY_KP_ENTER:
			submit()
		_:
			return
	get_viewport().set_input_as_handled()


func _button(line_id: StringName, node_name: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = Text.get_line(line_id)
	button.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(button, BUTTON_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	return button


func _refresh() -> void:
	if _picture == null:
		return
	_picture.set_values(Vector2i(recipe_a, recipe_b), copper, tin)
	_count.text = str(tin)
	_less.disabled = not _enabled or tin <= 0
	_more.disabled = not _enabled or tin >= max_tin
	_mix.disabled = not _enabled


## The recipe card, the two hoppers and the electric drum, in code. The drum's tween redraws it every
## frame, so _draw allocates nothing (perf_check rule 1b): the ore pictures and the hopper labels are
## built in set_values() and the polygons reuse their buffers.
class _MixerPicture:
	extends Control

	const HOPPER_COLOR: Color = Color("#56627F")
	const BOLT_COLOR: Color = Color("#FFE9A8")
	## The motor's lightning mark around its center (electric, no flame).
	const BOLT_SHAPE: Array[Vector2] = [Vector2(-4, -12), Vector2(6, -12), Vector2(1, -2), Vector2(7, -2), Vector2(-5, 12), Vector2(-1, 1), Vector2(-7, 1)]

	var recipe: Vector2i = Vector2i(2, 3)
	var copper: int = 0
	var tin: int = 0
	var copper_line: String = ""
	var tin_line: String = ""
	var drum_turn: float = 0.0:
		set(value):
			drum_turn = value
			queue_redraw()
	var _card_ore: Dictionary = {"type": "ore_mix", "a": 2, "b": 3}
	var _hopper_ore: Array[Dictionary] = [{"type": "ore_mix", "a": 0, "b": 0}, {"type": "ore_mix", "a": 0, "b": 0}]
	var _hopper_text: PackedStringArray = PackedStringArray(["", ""])
	var _hopper_points: PackedVector2Array = PackedVector2Array()
	var _bolt_points: PackedVector2Array = PackedVector2Array()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hopper_points.resize(4)
		_bolt_points.resize(BOLT_SHAPE.size())

	## The recipe and the hoppers' counts; rebuilds what _draw shows from them, then redraws.
	func set_values(new_recipe: Vector2i, new_copper: int, new_tin: int) -> void:
		recipe = new_recipe
		copper = new_copper
		tin = new_tin
		_card_ore["a"] = recipe.x
		_card_ore["b"] = recipe.y
		_hopper_ore[0]["a"] = copper
		_hopper_ore[1]["b"] = tin
		_hopper_text[0] = "%s %d" % [copper_line, copper]
		_hopper_text[1] = "%s %d" % [tin_line, tin]
		queue_redraw()

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var w: float = size.x
		var h: float = size.y
		# The recipe card on the left: a copper and b tin as ore.
		var card: Rect2 = Rect2(Vector2(8, 8), Vector2(w * 0.22, h - 16))
		draw_rect(card, Color("#F5F7FF"))
		draw_rect(card, CrystalArt.OUTLINE, false, 3.0)
		CrystalArt.draw_ore_mix(self, card.grow(-10.0), _card_ore)
		# The two hoppers.
		var hopper_w: float = w * 0.22
		for side: int in 2:
			var box: Rect2 = Rect2(Vector2(w * (0.28 + 0.25 * side), 8), Vector2(hopper_w, h * 0.72))
			_hopper_points[0] = box.position
			_hopper_points[1] = Vector2(box.end.x, box.position.y)
			_hopper_points[2] = Vector2(box.end.x - hopper_w * 0.25, box.end.y)
			_hopper_points[3] = Vector2(box.position.x + hopper_w * 0.25, box.end.y)
			draw_colored_polygon(_hopper_points, HOPPER_COLOR)
			CrystalArt.draw_ore_mix(self, box.grow(-12.0), _hopper_ore[side])
			if font != null:
				var text: String = _hopper_text[side]
				var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
				draw_string(font, Vector2(box.get_center().x - width * 0.5, h - 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, CrystalArt.LINE)
		# The mixing drum on the right, turned by an electric motor (a lightning mark, no flame).
		var center: Vector2 = Vector2(w * 0.88, h * 0.45)
		var radius: float = minf(w * 0.1, h * 0.38)
		draw_circle(center, radius, Color("#8A96B3"))
		draw_arc(center, radius, 0.0, TAU, 32, CrystalArt.OUTLINE, 3.0)
		for spoke: int in 3:
			var angle: float = drum_turn * TAU + TAU * spoke / 3.0
			draw_line(center, center + Vector2.from_angle(angle) * radius * 0.85, CrystalArt.OUTLINE, 3.0)
		var bolt_at: Vector2 = center + Vector2(0, radius + 18.0)
		for index: int in BOLT_SHAPE.size():
			_bolt_points[index] = bolt_at + BOLT_SHAPE[index]
		draw_colored_polygon(_bolt_points, BOLT_COLOR)
