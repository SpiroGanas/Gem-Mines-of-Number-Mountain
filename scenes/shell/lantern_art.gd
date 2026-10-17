## The electric lantern of the lantern streak, drawn in code (CLAUDE.md: every light in the mine is
## electric; this one has a bulb, never a flame). `lit` turns the bulb's glow on; light_up() plays
## the lighting animation used when the first rock of a day lights it.
class_name LanternArt
extends Control

const FRAME: Color = Color("#C9D1E8")
const GLASS_DARK: Color = Color("#2E3C66")
const BULB_OFF: Color = Color("#6B7393")
const BULB_ON: Color = Color("#FFE9A8")
const GLOW: Color = Color(1.0, 0.86, 0.45, 0.35)
const LIGHT_SECONDS: float = 0.6

@export var lit: bool = false:
	set(value):
		lit = value
		glow = 1.0 if value else 0.0
		queue_redraw()

## 0 (off) to 1 (fully lit); animated by light_up().
var glow: float = 0.0:
	set(value):
		glow = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Lights the lantern with a short glow-up and a little bounce.
func light_up(speed_scale: float = 1.0) -> void:
	lit = true
	glow = 0.0
	pivot_offset = size * 0.5
	var tween: Tween = create_tween()
	tween.set_speed_scale(speed_scale)
	tween.tween_property(self, "glow", 1.0, LIGHT_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(self, "scale", Vector2(1.12, 1.12), LIGHT_SECONDS * 0.5)
	tween.tween_property(self, "scale", Vector2.ONE, LIGHT_SECONDS * 0.5)


func _draw() -> void:
	var s: Vector2 = size
	if glow > 0.0:
		draw_circle(Vector2(0.5, 0.56) * s, s.x * 0.48 * glow, Color(GLOW, GLOW.a * glow))
	draw_arc(Vector2(0.5, 0.16) * s, s.x * 0.16, PI, TAU, 16, FRAME, 4.0, true) # handle
	draw_rect(Rect2(Vector2(0.28, 0.22) * s, Vector2(0.44, 0.08) * s), FRAME) # cap
	var glass: Rect2 = Rect2(Vector2(0.3, 0.3) * s, Vector2(0.4, 0.5) * s)
	draw_rect(glass, GLASS_DARK.lerp(GLOW.lightened(0.4), glow * 0.6))
	draw_rect(glass, FRAME, false, 4.0)
	draw_circle(glass.get_center(), s.x * 0.1, BULB_OFF.lerp(BULB_ON, glow)) # the electric bulb
	draw_rect(Rect2(Vector2(0.26, 0.8) * s, Vector2(0.48, 0.08) * s), FRAME) # base
