## One gear (Zone 6, P4-S30-02): a code-drawn toothed wheel that fills its rectangle, with its tooth
## count in the middle. `angle` turns the drawing (the gear bench tweens it); the node itself never
## rotates, so its rectangle stays put for layout and for hit-testing a drag.
##
## A Control rather than the plan's Node2D + Sprite2D: there is no gear sprite (no artist; the art is
## drawn in code), and a Control sits in containers and gets touch-target sizes from UI.
class_name Gear
extends Control

@export var teeth: int = 12:
	set(value):
		teeth = value
		_label = str(value) # cached: a spinning gear redraws every frame and must not build strings
		queue_redraw()
## Radians; positive turns the gear clockwise on screen.
var angle: float = 0.0:
	set(value):
		angle = value
		queue_redraw()
var marked: bool = false:
	set(value):
		marked = value
		queue_redraw()
## A ring around the gear: it is the one being dragged, or the axle it would snap to.
var highlighted: bool = false:
	set(value):
		highlighted = value
		queue_redraw()

var _art: GearArt = GearArt.new()
var _label: String = "12"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.5
	if radius < 4.0:
		return
	if highlighted:
		draw_arc(size * 0.5, radius, 0.0, TAU, 48, GearArt.MARK, 6.0, true)
	_art.draw(self, size * 0.5, radius * 0.9, teeth, angle, _label, 0, marked)
