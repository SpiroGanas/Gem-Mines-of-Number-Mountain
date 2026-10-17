# Mirrors scripts/input/stroke_raster.gd. The picture it makes must match tools/handwriting/raster.py
# (the network is trained on that one), so the main test compares every case in
# fixtures/raster_cases.json, written by `python tools/handwriting/make_fixtures.py`.
class_name StrokeRasterTest
extends GdUnitTestSuite

const FIXTURE: String = "res://tests/handwriting/fixtures/raster_cases.json"
const SIZE: int = 28


func _strokes_of(raw: Array) -> Array[PackedVector2Array]:
	var strokes: Array[PackedVector2Array] = []
	for stroke: Array in raw:
		var line: PackedVector2Array = PackedVector2Array()
		for point: Array in stroke:
			line.append(Vector2(point[0], point[1]))
		strokes.append(line)
	return strokes


func _line(points: Array) -> PackedVector2Array:
	var line: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		line.append(point)
	return line


func test_every_python_case_gives_the_same_picture() -> void:
	var doc: Variant = JsonUtil.parse_file(FIXTURE)
	assert_bool(doc is Dictionary).is_true()
	var cases: Array = doc["cases"]
	assert_int(cases.size()).is_greater(10)
	for entry: Dictionary in cases:
		var box: Vector2 = Vector2(entry["box"][0], entry["box"][1])
		var picture: PackedFloat32Array = StrokeRaster.rasterize(_strokes_of(entry["strokes"]), box)
		if entry["expected"] == null:
			assert_bool(picture.is_empty()).override_failure_message("%s should be 'no digit'" % entry["name"]).is_true()
			continue
		assert_int(picture.size()).override_failure_message(str(entry["name"])).is_equal(SIZE * SIZE)
		var worst: float = 0.0
		for i: int in SIZE * SIZE:
			worst = maxf(worst, absf(picture[i] - float(entry["expected"][i])))
		assert_float(worst).override_failure_message("%s differs from the Python picture by %f" % [entry["name"], worst]).is_less(0.0002)


func test_a_stroke_makes_ink_inside_the_grid_and_nothing_outside_zero_to_one() -> void:
	var strokes: Array[PackedVector2Array] = [_line([Vector2(0.2, 0.1), Vector2(0.8, 0.9)])]
	var picture: PackedFloat32Array = StrokeRaster.rasterize(strokes, Vector2(300, 400))
	assert_int(picture.size()).is_equal(SIZE * SIZE)
	var ink: float = 0.0
	for value: float in picture:
		assert_float(value).is_between(0.0, 1.0)
		ink += value
	assert_float(ink).is_greater(20.0)


func test_the_ink_is_centred_on_its_centre_of_mass() -> void:
	var strokes: Array[PackedVector2Array] = [_line([Vector2(0.1, 0.2), Vector2(0.9, 0.2), Vector2(0.9, 0.9)])]
	var picture: PackedFloat32Array = StrokeRaster.rasterize(strokes, Vector2(320, 320))
	var sum: float = 0.0
	var mx: float = 0.0
	var my: float = 0.0
	for iy: int in SIZE:
		for ix: int in SIZE:
			var v: float = picture[iy * SIZE + ix]
			sum += v
			mx += v * (ix + 0.5)
			my += v * (iy + 0.5)
	assert_float(mx / sum).is_equal_approx(14.0, 0.7)
	assert_float(my / sum).is_equal_approx(14.0, 0.7)


func test_the_same_shape_in_a_bigger_box_gives_the_same_picture() -> void:
	var shape: Array[PackedVector2Array] = [_line([Vector2(0.2, 0.2), Vector2(0.7, 0.2), Vector2(0.7, 0.85)])]
	var a: PackedFloat32Array = StrokeRaster.rasterize(shape, Vector2(100, 100))
	var b: PackedFloat32Array = StrokeRaster.rasterize(shape, Vector2(400, 400))
	assert_int(a.size()).is_equal(SIZE * SIZE)
	for i: int in SIZE * SIZE:
		assert_float(a[i]).is_equal_approx(b[i], 0.0001)


func test_a_dot_or_nothing_is_not_a_digit() -> void:
	var dot: Array[PackedVector2Array] = [_line([Vector2(0.5, 0.5)])]
	assert_bool(StrokeRaster.rasterize(dot, Vector2(300, 400)).is_empty()).is_true()
	var none: Array[PackedVector2Array] = []
	assert_bool(StrokeRaster.rasterize(none, Vector2(300, 400)).is_empty()).is_true()
	var empty_stroke: Array[PackedVector2Array] = [PackedVector2Array()]
	assert_bool(StrokeRaster.rasterize(empty_stroke, Vector2(300, 400)).is_empty()).is_true()


func test_the_pen_lifting_between_strokes_keeps_both_strokes() -> void:
	var cross: Array[PackedVector2Array] = [_line([Vector2(0.2, 0.5), Vector2(0.8, 0.5)]), _line([Vector2(0.5, 0.1), Vector2(0.5, 0.9)])]
	var picture: PackedFloat32Array = StrokeRaster.rasterize(cross, Vector2(300, 300))
	assert_float(picture[14 * SIZE + 14]).is_equal_approx(1.0, 0.001) # the crossing is in the middle
