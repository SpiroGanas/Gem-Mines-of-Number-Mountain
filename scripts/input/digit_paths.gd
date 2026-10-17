## How to write each digit: the strokes in the order and direction a child writes them, as points in
## a unit box (x right, y down). The numeral-coaching demo (StrokeDemo) draws them one after the
## other. These are teaching shapes, not recognition data.
class_name DigitPaths
extends RefCounted

const PATHS: Dictionary = {
	0: [[Vector2(0.5, 0.05), Vector2(0.2, 0.2), Vector2(0.15, 0.5), Vector2(0.22, 0.8), Vector2(0.5, 0.95), Vector2(0.78, 0.8), Vector2(0.85, 0.5), Vector2(0.8, 0.2), Vector2(0.5, 0.05)]],
	1: [[Vector2(0.28, 0.3), Vector2(0.5, 0.1), Vector2(0.5, 0.5), Vector2(0.5, 0.92)]],
	2: [[Vector2(0.2, 0.28), Vector2(0.35, 0.1), Vector2(0.6, 0.08), Vector2(0.78, 0.25), Vector2(0.65, 0.5), Vector2(0.2, 0.88), Vector2(0.82, 0.88)]],
	3: [[Vector2(0.2, 0.15), Vector2(0.5, 0.06), Vector2(0.76, 0.2), Vector2(0.5, 0.46), Vector2(0.8, 0.65), Vector2(0.7, 0.86), Vector2(0.45, 0.94), Vector2(0.18, 0.85)]],
	4: [[Vector2(0.68, 0.08), Vector2(0.2, 0.62), Vector2(0.88, 0.62)], [Vector2(0.66, 0.1), Vector2(0.66, 0.93)]],
	5: [[Vector2(0.76, 0.1), Vector2(0.32, 0.1), Vector2(0.26, 0.45), Vector2(0.55, 0.4), Vector2(0.8, 0.58), Vector2(0.7, 0.85), Vector2(0.45, 0.93), Vector2(0.2, 0.85)]],
	6: [[Vector2(0.7, 0.08), Vector2(0.4, 0.28), Vector2(0.24, 0.6), Vector2(0.34, 0.88), Vector2(0.6, 0.92), Vector2(0.76, 0.72), Vector2(0.6, 0.5), Vector2(0.35, 0.55), Vector2(0.27, 0.66)]],
	7: [[Vector2(0.2, 0.12), Vector2(0.82, 0.12), Vector2(0.45, 0.92)]],
	8: [[Vector2(0.5, 0.5), Vector2(0.25, 0.3), Vector2(0.5, 0.08), Vector2(0.75, 0.3), Vector2(0.5, 0.5), Vector2(0.2, 0.72), Vector2(0.5, 0.94), Vector2(0.8, 0.72), Vector2(0.5, 0.5)]],
	9: [[Vector2(0.74, 0.36), Vector2(0.5, 0.08), Vector2(0.26, 0.3), Vector2(0.5, 0.52), Vector2(0.74, 0.36), Vector2(0.72, 0.62), Vector2(0.56, 0.93)]],
}


## The strokes of `digit` as polylines, each smoothed so the demo draws a curve rather than corners.
static func strokes_for(digit: int) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for stroke: Array in PATHS.get(digit, []):
		var line: PackedVector2Array = PackedVector2Array()
		for index: int in stroke.size() - 1:
			var p0: Vector2 = stroke[maxi(index - 1, 0)]
			var p1: Vector2 = stroke[index]
			var p2: Vector2 = stroke[index + 1]
			var p3: Vector2 = stroke[mini(index + 2, stroke.size() - 1)]
			for step: int in 8:
				line.append(p1.cubic_interpolate(p2, p0, p3, float(step) / 8.0))
		line.append(stroke[stroke.size() - 1])
		result.append(line)
	return result
