## Front door of handwriting recognition: is it available here, and which Recognizer reads?
##
## Recognition runs on the device in GDScript (DigitNet, StrokeRaster): no plugin, no library, no
## network, and the strokes are discarded as soon as a box is read (docs/decisions.md, Sprint 13).
## The slate is offered only where it can work: the weights file loads, and the device has a touch
## screen (a mouse-only Chromebook uses the NumberPad). On the desktop editor, which has no touch
## screen, the project setting gem_mines/debug/force_slate (default false) turns the slate on for a
## developer with a mouse.
class_name DigitInk
extends RefCounted

const FORCE_SETTING: String = "gem_mines/debug/force_slate"

## Tests (and nothing else) set this to true or false to ignore the device. null = ask the device.
static var availability_override: Variant = null

## Tests (and nothing else) put a FakeRecognizer here so a screen reads what the test says.
static var recognizer_override: Recognizer

static var _net: DigitNet
static var _loaded: bool = false


## The network, loaded once; null if the weights file is missing or broken.
static func net() -> DigitNet:
	if not _loaded:
		_net = DigitNet.load_file()
		_loaded = true
		if _net == null:
			push_warning("DigitInk: %s did not load; answers use the number pad" % DigitNet.PATH)
	return _net


## True when handwriting answers can be offered on this device right now.
static func is_available() -> bool:
	if net() == null:
		return false
	if availability_override != null:
		return bool(availability_override)
	return DisplayServer.is_touchscreen_available() or bool(ProjectSettings.get_setting(FORCE_SETTING, false))


## The recognizer the slate should use. Without the weights it is a FakeRecognizer, which only
## happens in a broken build; is_available() is false then, so the slate is never shown.
static func make_recognizer() -> Recognizer:
	if recognizer_override != null:
		return recognizer_override
	var loaded: DigitNet = net()
	if loaded == null:
		return FakeRecognizer.new()
	return NetRecognizer.new(loaded)


## Forget the loaded network and the override (tests).
static func reset() -> void:
	_net = null
	_loaded = false
	availability_override = null
	recognizer_override = null
