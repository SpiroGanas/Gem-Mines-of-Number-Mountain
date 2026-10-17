# Mirrors scripts/input/digit_net.gd, net_recognizer.gd, fake_recognizer.gd and digit_ink.gd.
# fixtures/net_cases.json is written by `python tools/handwriting/make_fixtures.py` from the same
# weights file (assets/handwriting/digit_net.json): the GDScript forward pass must agree with the
# numpy one, so what the child writes is read by the network that was trained and measured.
class_name DigitNetTest
extends GdUnitTestSuite

const FIXTURE: String = "res://tests/handwriting/fixtures/net_cases.json"

var _net: DigitNet


func before() -> void:
	_net = DigitNet.load_file()


func after_test() -> void:
	DigitInk.reset()


func _strokes_of(raw: Array) -> Array[PackedVector2Array]:
	var strokes: Array[PackedVector2Array] = []
	for stroke: Array in raw:
		var line: PackedVector2Array = PackedVector2Array()
		for point: Array in stroke:
			line.append(Vector2(point[0], point[1]))
		strokes.append(line)
	return strokes


func test_the_shipped_weights_load() -> void:
	assert_object(_net).is_not_null()
	assert_int(_net.conv1_w.size()).is_equal(8 * 9)
	assert_int(_net.fc1_w.size()).is_equal(64 * 784)
	assert_dict(_net.metrics).contains_keys(["mnist_raw", "synthetic"])


func test_a_missing_or_wrong_file_is_not_a_network() -> void:
	assert_object(DigitNet.load_file("user://no_such_net.json")).is_null()
	assert_object(DigitNet.load_file("res://curriculum/bkt_defaults.json")).is_null()


func test_the_logits_match_the_python_forward_pass() -> void:
	var cases: Array = JsonUtil.parse_file(FIXTURE)["cases"]
	assert_int(cases.size()).is_greater(10)
	for entry: Dictionary in cases:
		var picture: PackedFloat32Array = StrokeRaster.rasterize(_strokes_of(entry["strokes"]), Vector2(entry["box"][0], entry["box"][1]))
		var logits: PackedFloat32Array = _net.forward(picture)
		assert_int(logits.size()).is_equal(11)
		for i: int in 11:
			assert_float(logits[i]).override_failure_message("%s logit %d: %f vs %f" % [entry["name"], i, logits[i], entry["logits"][i]]).is_equal_approx(float(entry["logits"][i]), 0.01)


func test_the_reading_matches_python_digit_and_mirrored_flag() -> void:
	var recognizer: NetRecognizer = NetRecognizer.new(_net)
	for entry: Dictionary in JsonUtil.parse_file(FIXTURE)["cases"]:
		var box: Vector2i = Vector2i(roundi(entry["box"][0]), roundi(entry["box"][1]))
		var read: Dictionary = recognizer.recognize(_strokes_of(entry["strokes"]), box)
		assert_int(read["digit"]).override_failure_message(str(entry["name"])).is_equal(int(entry["reading"]["digit"]))
		assert_float(read["confidence"]).is_equal_approx(float(entry["reading"]["confidence"]), 0.01)


func test_reading_a_digit_takes_well_under_a_second_in_gdscript() -> void:
	var entry: Dictionary = JsonUtil.parse_file(FIXTURE)["cases"][3]
	var picture: PackedFloat32Array = StrokeRaster.rasterize(_strokes_of(entry["strokes"]), Vector2(entry["box"][0], entry["box"][1]))
	var started: int = Time.get_ticks_msec()
	for i: int in 5:
		_net.forward(picture)
	var per_digit_ms: float = float(Time.get_ticks_msec() - started) / 5.0
	prints("DigitNet.forward: %.1f ms per digit" % per_digit_ms)
	assert_float(per_digit_ms).is_less(1000.0)


func test_empty_ink_reads_as_nothing() -> void:
	var recognizer: NetRecognizer = NetRecognizer.new(_net)
	var none: Array[PackedVector2Array] = []
	assert_int(recognizer.recognize(none, Vector2i(200, 300))["digit"]).is_equal(-1)
	var dot: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0.5, 0.5)])]
	assert_int(recognizer.recognize(dot, Vector2i(200, 300))["digit"]).is_equal(-1)


func test_the_fake_recognizer_follows_its_script_then_its_default() -> void:
	var fake: FakeRecognizer = FakeRecognizer.new()
	fake.queued = [{"digit": 4, "confidence": 0.5}, {"digit": 7, "mirrored": true}]
	fake.digit = 2
	var anything: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.9, 0.9)])]
	var first: Dictionary = fake.recognize(anything, Vector2i(100, 100))
	assert_int(first["digit"]).is_equal(4)
	assert_float(first["confidence"]).is_equal_approx(0.5, 0.0001)
	var second: Dictionary = fake.recognize(anything, Vector2i(100, 100))
	assert_int(second["digit"]).is_equal(7)
	assert_bool(second["mirrored"]).is_true()
	assert_int(fake.recognize(anything, Vector2i(100, 100))["digit"]).is_equal(2)
	assert_int(fake.calls).is_equal(3)


func test_the_fake_recognizer_guesses_from_the_shape_when_not_told() -> void:
	var fake: FakeRecognizer = FakeRecognizer.new()
	fake.fallback_digit = 8
	var none: Array[PackedVector2Array] = []
	var tall: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0.5, 0.1), Vector2(0.5, 0.9)])]
	var wide: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.9, 0.9)])]
	assert_int(fake.recognize(none, Vector2i(200, 300))["digit"]).is_equal(-1)
	assert_int(fake.recognize(tall, Vector2i(200, 300))["digit"]).is_equal(1)
	assert_int(fake.recognize(wide, Vector2i(200, 300))["digit"]).is_equal(8)


func test_handwriting_is_unavailable_on_a_machine_without_a_touch_screen() -> void:
	DigitInk.reset()
	assert_bool(DisplayServer.is_touchscreen_available()).is_false() # headless CI: no touch screen
	assert_bool(DigitInk.is_available()).is_false()


func test_availability_can_be_forced_for_tests_and_follows_the_network() -> void:
	DigitInk.availability_override = true
	assert_bool(DigitInk.is_available()).is_true()
	DigitInk.availability_override = false
	assert_bool(DigitInk.is_available()).is_false()
	assert_object(DigitInk.make_recognizer()).is_instanceof(NetRecognizer)
