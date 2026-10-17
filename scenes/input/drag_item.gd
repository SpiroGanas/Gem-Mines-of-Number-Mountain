## A piece the child drags: a ten-bar or a one-gem. Gray-box shapes drawn in code.
##
## The item does not read input itself. BuildBoard moves it from InputRouter pointer events, so
## finger, stylus and mouse behave identically (not Godot's built-in drag and drop).
## The ten-bar is a tall bar with ten segments and the one-gem a crystal, so they differ by
## shape as well as color. Both are at least one 64 dp touch target wide.
class_name DragItem
extends Control

const TEN: StringName = &"ten"
const ONE: StringName = &"one"
const BAR_FILL: Color = Color("#4F8FDB")
const BAR_EDGE: Color = Color("#1F2945")
const BAR_SEGMENT: Color = Color("#8DB9EE")

@export var kind: StringName = ONE


## A new item of `kind`, sized from UI.min_target_px().
static func make(item_kind: StringName) -> DragItem:
	var item: DragItem = DragItem.new()
	item.kind = item_kind
	return item


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if kind == TEN:
		UI.make_touch_target(self, 1.0, 2.4)
	else:
		UI.make_touch_target(self, 1.0, 1.0)


## How many ones this piece is worth.
func value() -> int:
	return 10 if kind == TEN else 1


func _draw() -> void:
	if kind == TEN:
		var body: Rect2 = Rect2(Vector2(size.x * 0.08, 0.0), Vector2(size.x * 0.84, size.y))
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = BAR_FILL
		box.border_color = BAR_EDGE
		box.set_border_width_all(3)
		box.set_corner_radius_all(10)
		draw_style_box(box, body)
		for segment: int in range(1, 10):
			var y: float = size.y * float(segment) / 10.0
			draw_line(Vector2(body.position.x + 6.0, y), Vector2(body.end.x - 6.0, y), BAR_SEGMENT, 2.0)
	else:
		var points: PackedVector2Array = GemArt.shape_points(GemArt.QUARTZ)
		var scaled: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in points:
			scaled.append(point * size)
		draw_colored_polygon(scaled, GemArt.color_for(GemArt.QUARTZ))
		scaled.append(scaled[0])
		draw_polyline(scaled, BAR_EDGE, 3.0, true)
