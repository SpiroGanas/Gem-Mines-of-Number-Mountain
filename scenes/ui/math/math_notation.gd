## Math notation for Zone 8 and Scholar mode (Phase 4, Sprint 35 and 37): a power (2⁵), a square root
## (√49), scientific notation (3.4 × 10⁵) or (Zone 10) a congruence (17 ≡ 5 (mod 12)) drawn with the composed notation scenes, plus, in Explorer
## mode, the same thing in words underneath ("2 to the power 5", lines z8.notation.*_words). In Scholar
## mode (ModeGate's MATH_NOTATION on for the child) the notation stands alone.
##
## The spec is a `notation` picture (Problem: {form: "power", base, exp} | {form: "root", n} |
## {form: "sci", mantissa, scale, exp} | {form: "congruence", a, b, n} | {form: "set", set: "Z"|"Q"|"R"}; the set symbols are Scholar mode only, see NotationRules). Problem pictures, answer buttons and the pads all build their
## notation here, so every screen writes math the same way. Presentation only, never interactive.
class_name MathNotation
extends VBoxContainer

## Tests: true or false to show the words or not; null asks ScholarMode (Explorer shows them).
var words_override: Variant = null
## The words for each number set symbol, from the text table.
const SET_WORDS: Dictionary = {
	"Z": &"notation.set.integers_words",
	"Q": &"notation.set.rationals_words",
	"R": &"notation.set.reals_words",
}

var spec: Dictionary = {}
var size_scale: float = 1.0

var _display: Control
var _words: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 4)


## A notation for `new_spec` at `scale` (1.0 is the theme's big number size).
static func make(new_spec: Dictionary, scale: float = 1.0) -> MathNotation:
	var notation: MathNotation = MathNotation.new()
	notation.size_scale = scale
	notation.show_spec(new_spec)
	return notation


## The notation spec for an answer value, or {} when the value has no notation of its own
## (scientific notation {mantissa, scale, exp} has one).
static func spec_for_value(value: Variant) -> Dictionary:
	if Notation.is_sci(value):
		return {"form": "sci", "mantissa": int(value["mantissa"]), "scale": int(value["scale"]), "exp": int(value["exp"])}
	return {}


## The words for a spec ("2 to the power 5"), from the text table.
static func words_for(new_spec: Dictionary) -> String:
	match str(new_spec.get("form", "")):
		"power":
			return Text.get_line(&"z8.notation.power_words", {"b": int(new_spec["base"]), "e": int(new_spec["exp"])})
		"root":
			return Text.get_line(&"z8.notation.root_words", {"n": int(new_spec["n"])})
		"sci":
			return Text.get_line(&"z8.notation.sci_words", {
				"m": {"mantissa": int(new_spec["mantissa"]), "scale": int(new_spec["scale"])}, "e": int(new_spec["exp"])})
		"congruence":
			return Text.get_line(&"z10.notation.congruence_words", {"a": int(new_spec["a"]), "b": int(new_spec["b"]), "n": int(new_spec["n"])})
		"set":
			return Text.get_line(SET_WORDS.get(str(new_spec.get("set", "")), &"notation.set.integers_words"))
	return ""


## True when the words show under the notation (Explorer mode).
func words_shown() -> bool:
	if words_override != null:
		return bool(words_override)
	return not _scholar_on()


## True when this form may be drawn as symbols now (NotationRules): the set symbols wait for Scholar mode.
func symbols_shown() -> bool:
	return NotationRules.symbols_allowed(str(spec.get("form", "")), _scholar_on())


func _scholar_on() -> bool:
	if words_override != null:
		return not bool(words_override)
	return ScholarMode.is_on(ModeGate.Feature.MATH_NOTATION)


func show_spec(new_spec: Dictionary) -> void:
	spec = new_spec.duplicate(true)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_display = null
	_words = null
	match str(spec.get("form", "")):
		"power":
			var power: ExponentDisplay = ExponentDisplay.new()
			power.size_scale = size_scale
			power.show_power(int(spec["base"]), int(spec["exp"]))
			_display = power
		"root":
			var root: RootDisplay = RootDisplay.new()
			root.size_scale = size_scale
			root.show_root(int(spec["n"]))
			_display = root
		"sci":
			var sci: SciNotationDisplay = SciNotationDisplay.new()
			sci.size_scale = size_scale
			sci.show_value(spec)
			_display = sci
		"congruence":
			var congruence: CongruenceDisplay = CongruenceDisplay.new()
			congruence.size_scale = size_scale
			congruence.show_congruence(int(spec["a"]), int(spec["b"]), int(spec["n"]))
			_display = congruence
		"set":
			var symbol: SetSymbolDisplay = SetSymbolDisplay.new()
			symbol.size_scale = size_scale
			symbol.show_symbol(StringName(str(spec.get("set", "Z"))))
			_display = symbol
	if _display == null:
		return
	_display.name = "Notation"
	_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_display)
	_words = Label.new()
	_words.name = "Words"
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.text = words_for(spec)
	_words.add_theme_font_size_override(&"font_size", maxi(roundi(40 * clampf(size_scale * 1.5, 0.6, 1.0)), 18))
	_words.modulate = Color(1, 1, 1, 0.85)
	add_child(_words)
	refresh_mode()


## Re-reads Explorer or Scholar mode (the words come and go).
func refresh_mode() -> void:
	if _words != null:
		_words.visible = words_shown() or not symbols_shown()
	if _display != null:
		_display.visible = symbols_shown()


func display() -> Control:
	return _display


func words_label() -> Label:
	return _words
