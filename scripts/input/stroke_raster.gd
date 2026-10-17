## Turns pen strokes into the 28x28 picture the digit network reads.
##
## THIS FILE AND tools/handwriting/raster.py MUST STAY IDENTICAL IN BEHAVIOUR: the network is trained
## on pictures made by the Python twin and runs here on pictures made by this one.
## tests/handwriting/test_stroke_raster.gd checks the two against fixtures the Python writes.
##
## Input: strokes as points normalized to the digit box (0..1, y down) plus the box size in pixels
## (so a tall, narrow box does not squash the digit). Steps:
##   1. points -> box pixels; the bounding box of all ink; ink smaller than MIN_EXTENT of the box's
##      shorter side is "no digit"
##   2. scale so the longer side of the ink is TARGET (20) pixels, centred on the 28x28 grid
##      (the MNIST convention: a 20x20 digit in a 28x28 frame)
##   3. sample the strokes every STEP pixels; shift so the centre of mass of the samples is at the
##      middle of the grid
##   4. stamp a soft round brush on every sample; a pixel keeps the strongest stamp
## Pixel (ix, iy) covers [ix, ix+1) x [iy, iy+1) in grid coordinates; its centre is (ix+.5, iy+.5).
class_name StrokeRaster
extends RefCounted

const GRID: int = 28
const TARGET: float = 20.0
const CENTER: float = 14.0
const STEP: float = 0.5
const BRUSH_CORE: float = 0.9
const BRUSH_RADIUS: float = 1.9
const MIN_EXTENT: float = 0.2


## The picture as GRID*GRID floats (row by row, 0..1), or an empty array when there is no digit.
static func rasterize(strokes: Array[PackedVector2Array], box_size: Vector2) -> PackedFloat32Array:
	var fitted: Array[PackedVector2Array] = fit_to_grid(strokes, box_size)
	if fitted.is_empty():
		return PackedFloat32Array()
	return render_samples(sample_polylines(fitted))


## The strokes in grid pixels, scaled so the ink is TARGET long and centred; empty for "no digit".
static func fit_to_grid(strokes: Array[PackedVector2Array], box_size: Vector2) -> Array[PackedVector2Array]:
	var fitted: Array[PackedVector2Array] = []
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	var any: bool = false
	for stroke: PackedVector2Array in strokes:
		for point: Vector2 in stroke:
			var pixel: Vector2 = point * box_size
			low = Vector2(minf(low.x, pixel.x), minf(low.y, pixel.y))
			high = Vector2(maxf(high.x, pixel.x), maxf(high.y, pixel.y))
			any = true
	if not any:
		return fitted
	var size: float = maxf(high.x - low.x, high.y - low.y)
	if size < MIN_EXTENT * minf(box_size.x, box_size.y):
		return fitted
	var scale: float = TARGET / size
	var middle: Vector2 = (low + high) / 2.0
	for stroke: PackedVector2Array in strokes:
		if stroke.is_empty():
			continue
		var line: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in stroke:
			line.append((point * box_size - middle) * scale + Vector2(CENTER, CENTER))
		fitted.append(line)
	return fitted


## Points along the polylines, one every STEP pixels (a one-point stroke is one sample).
static func sample_polylines(polylines: Array[PackedVector2Array]) -> PackedVector2Array:
	var samples: PackedVector2Array = PackedVector2Array()
	for line: PackedVector2Array in polylines:
		for i: int in line.size() - 1:
			var from: Vector2 = line[i]
			var to: Vector2 = line[i + 1]
			var count: int = maxi(1, ceili(from.distance_to(to) / STEP))
			for k: int in count:
				samples.append(from.lerp(to, float(k) / float(count)))
		samples.append(line[line.size() - 1])
	return samples


## Centre of mass of the samples to the middle of the grid, then the brush on every sample.
static func render_samples(samples: PackedVector2Array) -> PackedFloat32Array:
	var image: PackedFloat32Array = PackedFloat32Array()
	image.resize(GRID * GRID)
	if samples.is_empty():
		return image
	var sum: Vector2 = Vector2.ZERO
	for point: Vector2 in samples:
		sum += point
	var shift: Vector2 = Vector2(CENTER, CENTER) - sum / float(samples.size())
	var span: float = BRUSH_RADIUS - BRUSH_CORE
	for point: Vector2 in samples:
		var at: Vector2 = point + shift
		for iy: int in range(maxi(0, floori(at.y - BRUSH_RADIUS - 0.5)), mini(GRID - 1, floori(at.y + BRUSH_RADIUS)) + 1):
			for ix: int in range(maxi(0, floori(at.x - BRUSH_RADIUS - 0.5)), mini(GRID - 1, floori(at.x + BRUSH_RADIUS)) + 1):
				var distance: float = at.distance_to(Vector2(ix + 0.5, iy + 0.5))
				var ink: float = clampf((BRUSH_RADIUS - distance) / span, 0.0, 1.0)
				if ink > image[iy * GRID + ix]:
					image[iy * GRID + ix] = ink
	return image
