## The number set symbols ℤ (integers), ℚ (rational numbers) and ℝ (real numbers), drawn in code as double-struck
## letters (each stroke is two thin parallel lines), so they do not depend on the font having the characters
## (like RootDisplay's √ and CongruenceDisplay's ≡). Presentation only, never interactive. Scholar mode only:
## MathNotation shows the words ("the integers") instead in Explorer mode (NotationRules).
class_name SetSymbolDisplay
extends Control

const STROKE: Color = Color("#F5F7FF")
const INTEGERS: StringName = &"Z"
const RATIONALS: StringName = &"Q"
const REALS: StringName = &"R"
const SYMBOLS: Array[StringName] = [INTEGERS, RATIONALS, REALS]
## The symbol's height at size_scale 1.0 (the theme's big number size).
const BASE_SIZE: float = 64.0
## Half the gap between a stroke's two lines, as a share of the symbol's height.
const GAP: float = 0.03

## 1.0 is the theme's big number size.
@export var size_scale: float = 1.0:
	set(value):
		size_scale = value
		_refresh()

var symbol: StringName = INTEGERS


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


## Shows one of SYMBOLS. Anything else is ignored.
func show_symbol(new_symbol: StringName) -> void:
	if not SYMBOLS.has(new_symbol):
		return
	symbol = new_symbol
	queue_redraw()


## The strokes of a symbol as polylines in a 0 to 1 box (x across, y down). Pure; tests count and bound them.
static func strokes(which: StringName) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	match which:
		INTEGERS:
			result.append(PackedVector2Array([Vector2(0.12, 0.1), Vector2(0.88, 0.1), Vector2(0.12, 0.9), Vector2(0.88, 0.9)]))
		REALS:
			result.append(PackedVector2Array([Vector2(0.16, 0.1), Vector2(0.16, 0.9)]))
			var bowl: PackedVector2Array = PackedVector2Array([Vector2(0.16, 0.1), Vector2(0.55, 0.1)])
			for step: int in range(0, 9):
				var angle: float = -PI / 2.0 + PI * step / 8.0
				bowl.append(Vector2(0.55, 0.3) + Vector2(cos(angle), sin(angle)) * 0.2)
			bowl.append(Vector2(0.16, 0.5))
			result.append(bowl)
			result.append(PackedVector2Array([Vector2(0.45, 0.5), Vector2(0.86, 0.9)]))
		RATIONALS:
			var ring: PackedVector2Array = PackedVector2Array()
			for step: int in range(0, 25):
				var angle: float = TAU * step / 24.0
				ring.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * Vector2(0.36, 0.4))
			result.append(ring)
			result.append(PackedVector2Array([Vector2(0.58, 0.68), Vector2(0.92, 0.95)]))
	return result


func _refresh() -> void:
	var height: float = maxf(BASE_SIZE * size_scale, 16.0)
	custom_minimum_size = Vector2(height * 0.8, height)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_strokes(self, Rect2(Vector2.ZERO, size), symbol, STROKE)


## Draws `which` as double-struck strokes filling `box` on any canvas (the notation card here, the number rings in
## CoreArt), so the symbols look the same everywhere.
static func draw_strokes(canvas: CanvasItem, box: Rect2, which: StringName, color: Color) -> void:
	var thin: float = maxf(box.size.y * 0.035, 1.5)
	for stroke: PackedVector2Array in strokes(which):
		for side: float in [-1.0, 1.0]:
			var line: PackedVector2Array = PackedVector2Array()
			for index: int in stroke.size():
				var before: Vector2 = stroke[maxi(index - 1, 0)]
				var after: Vector2 = stroke[mini(index + 1, stroke.size() - 1)]
				var direction: Vector2 = (after - before).normalized()
				var normal: Vector2 = Vector2(-direction.y, direction.x)
				line.append(box.position + (stroke[index] + normal * GAP * side) * box.size)
			canvas.draw_polyline(line, color, thin, true)
