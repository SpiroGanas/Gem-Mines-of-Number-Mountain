## A volume level drawn as a row of bars that get taller from left to right; the bars up to the
## level are filled. The level reads from the shape alone (no number, color is not the only clue).
class_name LevelBars
extends Control

const FILLED: Color = Color("#FFD166")
const EMPTY: Color = Color("#F5F7FF")

var levels: int = 5
var level: int = 0:
	set(value):
		level = clampi(value, 0, levels)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var gap: float = 8.0
	var width: float = (size.x - gap * float(levels - 1)) / float(levels)
	for index: int in levels:
		var height: float = size.y * (0.3 + 0.7 * float(index + 1) / float(levels))
		var rect: Rect2 = Rect2(float(index) * (width + gap), size.y - height, width, height)
		if index < level:
			draw_rect(rect, FILLED)
		draw_rect(rect, EMPTY, false, 3.0)
