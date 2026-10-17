## A recognizer for tests and the desktop editor: no network, fully predictable.
##
## It answers from `queued` first (one result per call, in order, then the rest follow `digit`), so a
## test can say "box 1 reads 4 sure, box 2 reads 7 unsure". With an empty queued it answers `digit`
## at `confidence`; with `digit` -1 it guesses from the ink's shape (nothing -> -1, tall and thin
## -> 1, anything else -> `fallback_digit`).
class_name FakeRecognizer
extends Recognizer

## What every call answers once the queued runs out; -1 means "judge by the shape".
var digit: int = -1
var fallback_digit: int = 0
var confidence: float = 0.99
var mirrored: bool = false
## Results to hand out first, one per call: Dictionaries shaped like Recognizer's result.
var queued: Array[Dictionary] = []
## How many boxes were asked so far (tests assert on it).
var calls: int = 0
## The strokes of the latest call, so a test can see what was handed in (never stored by the game).
var last_strokes: Array[PackedVector2Array] = []


func recognize(strokes: Array[PackedVector2Array], box_size: Vector2i) -> Dictionary:
	calls += 1
	last_strokes = strokes
	if not queued.is_empty():
		var next: Dictionary = queued.pop_front()
		var result: Dictionary = Recognizer.NOTHING.duplicate()
		result.merge(next, true)
		return result
	var seen: int = digit
	if seen < 0:
		seen = _guess_from_shape(strokes, box_size)
	if seen < 0:
		return Recognizer.NOTHING.duplicate()
	return {"digit": seen, "confidence": confidence, "mirrored": mirrored, "mirrored_confidence": 1.0 if mirrored else 0.0}


func _guess_from_shape(strokes: Array[PackedVector2Array], box_size: Vector2i) -> int:
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	var any: bool = false
	for stroke: PackedVector2Array in strokes:
		for point: Vector2 in stroke:
			var pixel: Vector2 = point * Vector2(box_size)
			low = Vector2(minf(low.x, pixel.x), minf(low.y, pixel.y))
			high = Vector2(maxf(high.x, pixel.x), maxf(high.y, pixel.y))
			any = true
	if not any:
		return -1
	var size: Vector2 = high - low
	if maxf(size.x, size.y) < StrokeRaster.MIN_EXTENT * float(mini(box_size.x, box_size.y)):
		return -1
	if size.y > 0.0 and size.x / size.y < 0.25:
		return 1
	return fallback_digit
