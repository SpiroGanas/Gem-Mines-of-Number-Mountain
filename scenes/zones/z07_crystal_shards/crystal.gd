## The crystal splitting mechanic (Zone 7, Sprint 33; meta.crystal = {den, match?}): a crystal cut into
## `den` equal wedge shards that the child lights by tapping, then Done. With `match`, a second, smaller
## crystal shows a fraction already lit ("Match this one."), for equivalent fractions: lighting 4 of 8
## shards matches 1 of 2. Done hands in the lit shards as a fraction in lowest terms (CrystalShards);
## it never says whether that is right, the host decides.
##
## Lit shards glow and carry a gem mark, so color is never the only clue. Mouse-only devices click the
## shards; keyboards use Left, Right and Space (ShardCrystal).
class_name CrystalPicker
extends VBoxContainer

## Done was pressed: the lit shards as {num, den} in lowest terms ({0, 1} when none is lit).
signal submitted(value: Dictionary)
## A shard was lit or turned off (for a sound).
signal shard_toggled(index: int, lit: bool)

const DONE_WIDTH_MULTIPLE: float = 3.0
const DONE_HEIGHT_MULTIPLE: float = 1.2
## The crystal to copy is drawn smaller than the one to light.
const MATCH_SIDE_TARGETS: float = 2.6

var _row: HBoxContainer
var _match_art: _MatchCrystal
var _crystal: ShardCrystal
var _how: Label
var _done: Button
var _enabled: bool = true


func _ready() -> void:
	add_theme_constant_override(&"separation", 12)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_how = Label.new()
	_how.name = "How"
	_how.text = Text.get_line(&"z7.crystal.tap_hint")
	_how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_how)
	_row = HBoxContainer.new()
	_row.name = "Crystals"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override(&"separation", 32)
	add_child(_row)
	_crystal = ShardCrystal.new()
	_crystal.name = "Crystal"
	_crystal.shard_toggled.connect(func(index: int, lit: bool) -> void: shard_toggled.emit(index, lit))
	_row.add_child(_crystal)
	_done = Button.new()
	_done.name = "DoneButton"
	_done.theme_type_variation = &"GoButton"
	_done.text = Text.get_line(&"z7.crystal.done")
	_done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.make_touch_target(_done, DONE_WIDTH_MULTIPLE, DONE_HEIGHT_MULTIPLE)
	_done.pressed.connect(submit)
	add_child(_done)
	if UI.is_compact():
		# On a phone a crystal of twelve shards is almost as tall as the room under Bolt: the hint and
		# Done stand beside the crystal instead of above and below it.
		var side: VBoxContainer = VBoxContainer.new()
		side.name = "Side"
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		side.add_theme_constant_override(&"separation", 24)
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		remove_child(_how)
		remove_child(_done)
		side.add_child(_how)
		side.add_child(_done)
		_row.add_child(side)


## A crystal of `den` shards to light; `match` ({num, den}, may be empty) is the fraction to copy.
func setup(den: int, match: Dictionary = {}) -> void:
	_crystal.setup(den)
	if _match_art != null:
		_match_art.queue_free()
		_row.remove_child(_match_art)
		_match_art = null
	if not match.is_empty():
		_match_art = _MatchCrystal.new()
		_match_art.name = "MatchCrystal"
		_match_art.fraction = match.duplicate()
		_match_art.caption = Text.get_line(&"z7.crystal.match")
		_match_art.custom_minimum_size = UI.target_size(MATCH_SIDE_TARGETS, MATCH_SIDE_TARGETS + 0.6)
		_row.add_child(_match_art)
		_row.move_child(_match_art, 0)


func crystal() -> ShardCrystal:
	return _crystal


func done_button() -> Button:
	return _done


## The lit shards now, in lowest terms.
func value() -> Dictionary:
	return _crystal.crystal.fraction()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_crystal.set_enabled(enabled)
	_done.disabled = not enabled


func submit() -> void:
	if _enabled:
		submitted.emit(value())


## The small crystal to copy: `fraction` lit, with its caption underneath. Not interactive.
class _MatchCrystal:
	extends Control

	var fraction: Dictionary = {"num": 0, "den": 1}
	var caption: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var den: int = maxi(int(fraction["den"]), 1)
		var lit: Array[bool] = []
		for index: int in den:
			lit.append(index < int(fraction["num"]))
		var label_room: float = 40.0
		var radius: float = minf(size.x, size.y - label_room) * 0.45
		CrystalArt.draw_crystal(self, Vector2(size.x * 0.5, (size.y - label_room) * 0.5), radius, den, lit)
		var font: Font = get_theme_default_font()
		if font != null and caption != "":
			var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			draw_string(font, Vector2((size.x - width) * 0.5, size.y - 8.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, CrystalArt.LINE)
