## Debug-build tool for collecting digit samples (Sprint 12/13): the logic behind the capture screen.
##
## A grown-up (or Charlie, watched) writes digits with the stylus and the finger; each one is saved
## as stroke JSON in user://capture/ so tools/handwriting/evaluate.py can measure the digit network
## on real writing. These are the only handwriting data the app ever keeps, and only in debug
## builds: the screen is stripped from release builds (is_enabled), the files stay on the device
## until a parent exports them, and no picture of the writing is ever made (strokes only).
## Charlie's exported samples go to private/handwriting/ on the developer's machine (gitignored).
##
## File: {"label": 7, "device": "pen"|"touch"|"mouse", "box": [w, h], "strokes": [[[x, y], ...], ...],
##        "captured_at": "...Z"} with x and y normalized to the box (0..1, y down).
class_name StrokeCapture
extends RefCounted

const DIR: String = "user://capture"
const SETTING: String = "gem_mines/debug/capture_enabled"


## True only in a debug build whose project setting allows it. A release export is never a debug
## build, so the capture screen cannot open there.
static func is_enabled() -> bool:
	return OS.is_debug_build() and bool(ProjectSettings.get_setting(SETTING, true))


static func device_name(kind: InputRouter.DeviceKind) -> String:
	match kind:
		InputRouter.DeviceKind.PEN:
			return "pen"
		InputRouter.DeviceKind.MOUSE:
			return "mouse"
	return "touch"


## One sample as the dictionary that is written to disk.
static func make_sample(label: int, device: String, box: Vector2i, strokes: Array[PackedVector2Array], captured_at: String) -> Dictionary:
	var lines: Array = []
	for stroke: PackedVector2Array in strokes:
		var points: Array = []
		for point: Vector2 in stroke:
			points.append([snappedf(point.x, 0.0001), snappedf(point.y, 0.0001)])
		lines.append(points)
	return {"label": label, "device": device, "box": [box.x, box.y], "strokes": lines, "captured_at": captured_at}


## Writes a sample into `dir` and returns its path ("" on failure).
static func save(sample: Dictionary, dir: String = DIR) -> String:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)) != OK:
		return ""
	var path: String = "%s/%d_%d_%s.json" % [dir, Time.get_unix_time_from_system() * 1000.0, sample["label"], sample["device"]]
	var index: int = 1
	while FileAccess.file_exists(path):
		path = "%s/%d_%d_%s_%d.json" % [dir, Time.get_unix_time_from_system() * 1000.0, sample["label"], sample["device"], index]
		index += 1
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(sample))
	file.close()
	return path


## The files in `dir`, oldest first.
static func files(dir: String = DIR) -> Array[String]:
	var found: Array[String] = []
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(".json"):
			found.append("%s/%s" % [dir, name])
	found.sort()
	return found


## How many samples there are per device name: {"pen": 3, "touch": 1}.
static func counts(dir: String = DIR) -> Dictionary:
	var result: Dictionary = {}
	for path: String in files(dir):
		var data: Variant = JsonUtil.parse_file(path)
		if data is Dictionary:
			var device: String = str(data.get("device", "touch"))
			result[device] = int(result.get(device, 0)) + 1
	return result


## Copies every sample to `target` (a folder a parent picked). Returns how many were copied.
static func export_to(target: String, dir: String = DIR) -> int:
	if DirAccess.make_dir_recursive_absolute(target) != OK:
		return 0
	var copied: int = 0
	for path: String in files(dir):
		if DirAccess.copy_absolute(path, "%s/%s" % [target, path.get_file()]) == OK:
			copied += 1
	return copied


## Deletes every sample (a parent clears the device once exported).
static func clear_all(dir: String = DIR) -> void:
	for path: String in files(dir):
		DirAccess.remove_absolute(path)


## A digit to ask for next: a shuffled bag of 0-9, so every digit comes up before any repeats.
static func next_label(bag: Array[int], rng: RandomNumberGenerator) -> int:
	if bag.is_empty():
		for digit: int in 10:
			bag.append(digit)
	var index: int = rng.randi_range(0, bag.size() - 1)
	var label: int = bag[index]
	bag.remove_at(index)
	return label
