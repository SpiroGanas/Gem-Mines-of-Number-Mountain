## The zone's banner at the top of the mine (Sprint 20 art pass, no artist): Kenney's CC0 signpost
## beside the zone's name in the heading font, so the child sees which part of the mountain this is.
## The name is a line from the text table (zN.zone.name).
class_name ZoneBanner
extends HBoxContainer

const SIGN_PATH: String = "res://assets/art/kenney/cave/sign_post.png"

var zone: int = 1
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 12)
	var sign: TextureRect = TextureRect.new()
	sign.texture = load(SIGN_PATH) if ResourceLoader.exists(SIGN_PATH) else null
	sign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sign.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sign.custom_minimum_size = UI.target_size(0.8, 0.8)
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sign)
	_label = Label.new()
	_label.theme_type_variation = &"HeadingLabel"
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	show_zone(zone)


func show_zone(new_zone: int) -> void:
	zone = new_zone
	if _label != null:
		_label.text = Text.get_line(line_for(zone))


func text() -> String:
	return _label.text


## The zone's name line: zN.zone.name, or the deepest zone's before it that has one.
static func line_for(for_zone: int) -> StringName:
	for zone_now: int in range(clampi(for_zone, 1, Backdrop.LAST_ZONE), 0, -1):
		var line: StringName = StringName("z%d.zone.name" % zone_now)
		if Text.has_line(line):
			return line
	return &"z1.zone.name"
