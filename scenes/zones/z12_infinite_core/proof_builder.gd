## The proof builder (Zone 12, The Infinite Core; meta.proof_builder = {proof_id}): a column of numbered slots (the proof)
## above a tray of steps. Tap a step to put it in the next empty slot (or the slot you picked), then tap a reason chip to
## say why the step is true. Tap a filled slot to pick it, and tap it again to take its step back. Check asks
## ProofValidator whether the proof is complete; Hint climbs the proof's scaffold ladder (light the next step, place it,
## then pick its reason).
##
## Nothing costs anything: a step that does not belong (a decoy) slides back to the tray with Bolt's gentle line, a step
## out of order or with the wrong reason is marked "!" and left for the child to fix, and the hint count is only a note
## for the adaptive engine (a proof finished with hints is partial evidence). The widget never decides what is right:
## ProofValidator does, and the proof file is data (curriculum/proofs/*.json).
##
## Buttons only (no dragging), so finger, stylus and mouse behave the same; every button is at least one touch target.
## The slots and the tray scroll on a small screen.
class_name ProofBuilder
extends VBoxContainer

## The proof is complete: its id. The host decides what it is worth.
signal submitted(proof_id: String)
## Something on the board changed (a step placed, taken back, a reason chosen).
signal changed()
## Bolt has something to say: the line id and its parameters. The host may show it in its own bubble.
signal said(line_id: StringName, params: Dictionary)

const BUTTON_HEIGHT_MULTIPLE: float = 1.0
const SLOT_WIDTH_MULTIPLE: float = 5.0
const CHIP_WIDTH_MULTIPLE: float = 2.6

var proof: Proof
## One entry per slot: {tile: StringName, why: StringName}; &"" for empty.
var placement: Array[Dictionary] = []
## The slot picked, or -1.
var selected: int = -1
## How many times Hint was pressed (a note for the adaptive engine).
var hints_used: int = 0
## Slot indexes marked "!" by the last Check.
var marked: Array[int] = []

var _tray_order: Array[StringName] = []
var _slot_buttons: Array[Button] = []
var _why_buttons: Array[Button] = []
var _tile_buttons: Dictionary = {}
var _chip_buttons: Dictionary = {}
var _chip_row: HFlowContainer
var _feedback: Label
var _check: Button
var _hint: Button
var _lit_tile: StringName = &""
var _enabled: bool = true
var _done: bool = false


func _init() -> void:
	add_theme_constant_override(&"separation", 8)


## Builds the board for `spec` = meta.proof_builder ({proof_id}).
func setup(spec: Dictionary) -> void:
	setup_proof(ProofLoader.load_by_id(StringName(str(spec["proof_id"]))))


func setup_proof(new_proof: Proof) -> void:
	proof = new_proof
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_slot_buttons.clear()
	_why_buttons.clear()
	_tile_buttons.clear()
	_chip_buttons.clear()
	placement.clear()
	marked.clear()
	selected = -1
	hints_used = 0
	_lit_tile = &""
	_done = false
	_enabled = true
	for slot: int in proof.steps.size():
		placement.append({"tile": &"", "why": &""})
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = String(proof.id).hash()
	_tray_order = proof.tray_order(rng)
	if not UI.is_compact(): # a phone has no room for the line of help
		var how: Label = Label.new()
		how.name = "How"
		how.text = Text.get_line(&"z12.builder.how")
		how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(how)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 6)
	scroll.add_child(column)
	var slots: VBoxContainer = VBoxContainer.new()
	slots.name = "Slots"
	slots.add_theme_constant_override(&"separation", 6)
	column.add_child(slots)
	for slot: int in proof.steps.size():
		slots.add_child(_make_slot(slot))
	_chip_row = HFlowContainer.new()
	_chip_row.name = "Chips"
	_chip_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_chip_row.add_theme_constant_override(&"h_separation", 8)
	column.add_child(_chip_row)
	for chip: StringName in proof.justifications:
		var button: Button = _button(StringName("z12.why." + chip), "Chip_%s" % chip, CHIP_WIDTH_MULTIPLE)
		button.pressed.connect(choose_why.bind(chip))
		_chip_row.add_child(button)
		_chip_buttons[chip] = button
	var tray: VBoxContainer = VBoxContainer.new()
	tray.name = "Tray"
	tray.add_theme_constant_override(&"separation", 6)
	column.add_child(tray)
	for tile: StringName in _tray_order:
		var tile_button: Button = Button.new()
		tile_button.name = "Tile_%s" % tile
		tile_button.text = Text.get_line(proof.line_of(tile))
		tile_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tile_button.focus_mode = Control.FOCUS_NONE
		tile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.make_touch_target(tile_button, SLOT_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
		tile_button.pressed.connect(place.bind(tile))
		tray.add_child(tile_button)
		_tile_buttons[tile] = tile_button
	_feedback = Label.new()
	_feedback.name = "Feedback"
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_feedback)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.name = "Bottom"
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override(&"separation", 16)
	add_child(bottom)
	_hint = _button(&"z12.builder.hint", "HintButton", 2.0)
	_hint.pressed.connect(hint)
	bottom.add_child(_hint)
	_check = _button(&"z12.builder.check", "CheckButton", 2.0)
	_check.theme_type_variation = &"GoButton"
	_check.pressed.connect(check)
	bottom.add_child(_check)
	_refresh()


func _make_slot(slot: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Slot%d" % slot
	row.add_theme_constant_override(&"separation", 8)
	var button: Button = Button.new()
	button.name = "SlotButton"
	button.toggle_mode = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UI.make_touch_target(button, SLOT_WIDTH_MULTIPLE, BUTTON_HEIGHT_MULTIPLE)
	button.pressed.connect(select.bind(slot))
	row.add_child(button)
	var why: Button = _button(&"z12.builder.why", "WhyButton", CHIP_WIDTH_MULTIPLE)
	why.pressed.connect(select.bind(slot))
	row.add_child(why)
	_slot_buttons.append(button)
	_why_buttons.append(why)
	return row


func _button(line_id: StringName, node_name: String, width_multiple: float) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = Text.get_line(line_id)
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.make_touch_target(button, width_multiple, BUTTON_HEIGHT_MULTIPLE)
	return button


# --- Playing ---------------------------------------------------------------------------------------


## Picks slot `slot`; picking the picked slot again takes its step back to the tray.
func select(slot: int) -> void:
	if not _enabled or slot < 0 or slot >= placement.size():
		return
	if selected == slot and placement[slot]["tile"] != &"":
		take_back(slot)
		selected = -1
	else:
		selected = slot
	_refresh()


## Puts the step (or decoy) `tile` in the picked slot if it is empty, else in the first empty slot.
func place(tile: StringName) -> void:
	if not _enabled or _slot_of(tile) >= 0:
		return
	var slot: int = selected if selected >= 0 and placement[selected]["tile"] == &"" else _first_empty()
	if slot < 0:
		return
	placement[slot] = {"tile": tile, "why": &""}
	selected = slot
	marked.erase(slot)
	_clear_hint_light()
	changed.emit()
	_refresh()


## Takes the step in `slot` back to the tray.
func take_back(slot: int) -> void:
	if not _enabled or slot < 0 or slot >= placement.size():
		return
	placement[slot] = {"tile": &"", "why": &""}
	marked.erase(slot)
	changed.emit()
	_refresh()


## Sets the reason of the picked slot.
func choose_why(chip: StringName) -> void:
	if not _enabled or selected < 0 or placement[selected]["tile"] == &"":
		return
	placement[selected]["why"] = chip
	marked.erase(selected)
	changed.emit()
	_refresh()


## Asks ProofValidator about the board. A complete proof is handed in; otherwise every problem is marked "!" and Bolt says
## the first, kindly. A decoy slides back to the tray (the tile returns; nothing is lost).
func check() -> ProofResult:
	var result: ProofResult = ProofValidator.validate(proof, placement)
	if not _enabled:
		return result
	marked.clear()
	if result.complete:
		_done = true
		_enabled = false
		_say(&"z12.builder.done")
		_refresh()
		submitted.emit(String(proof.id))
		return result
	var line: StringName = &""
	var params: Dictionary = {}
	for entry: Dictionary in result.errors:
		var slot: int = int(entry["slot"])
		if entry["kind"] == "missing":
			continue
		marked.append(slot)
		if line == &"":
			line = StringName("z12.proof.fb." + str(entry["misconception"])) if entry["kind"] == "decoy" else StringName("z12.builder.fb_" + str(entry["kind"]))
	for entry: Dictionary in result.errors:
		if entry["kind"] == "decoy":
			placement[int(entry["slot"])] = {"tile": &"", "why": &""}
			marked.erase(int(entry["slot"]))
	if line == &"":
		line = &"z12.builder.fb_missing"
	_say(line, params)
	_refresh()
	return result


## One press of Hint, by what the board needs: a mistake on the board is fixed first (a wrong step goes back, a wrong reason
## is set right); then a step placed with no reason gets its reason; otherwise the next step is lit, and a second press
## places it. The proof's scaffold levels say how far the ladder goes (1 light, 2 place, 3 reason).
func hint() -> void:
	if not _enabled or proof.scaffold_levels < 1:
		return
	var prefix: Array[Dictionary] = []
	for entry: Dictionary in placement:
		if entry["tile"] == &"":
			break
		prefix.append(entry)
	var result: ProofResult = ProofValidator.validate_prefix(proof, prefix)
	hints_used += 1
	if not result.errors.is_empty():
		var wrong: int = int(result.errors[0]["slot"])
		if result.errors[0]["kind"] == "justification" and proof.scaffold_levels >= 3:
			placement[wrong]["why"] = proof.step(placement[wrong]["tile"])["justification"]
			_say(&"z12.builder.hint3")
		else:
			take_back(wrong)
			_say(&"z12.builder.hint2")
		_refresh()
		return
	if not prefix.is_empty() and prefix.back()["why"] == &"" and proof.scaffold_levels >= 3:
		prefix.back()["why"] = proof.step(prefix.back()["tile"])["justification"]
		_say(&"z12.builder.hint3")
		_refresh()
		return
	var next: Array[StringName] = ProofValidator.next_valid_tiles(proof, prefix)
	if next.is_empty():
		hints_used -= 1
		return
	if _lit_tile != next[0] or proof.scaffold_levels < 2:
		_lit_tile = next[0]
		_say(&"z12.builder.hint1")
	else:
		selected = -1
		place(next[0])
		_say(&"z12.builder.hint2")
	_refresh()


func _clear_hint_light() -> void:
	_lit_tile = &""


# --- Reading it ------------------------------------------------------------------------------------


func _first_empty() -> int:
	for slot: int in placement.size():
		if placement[slot]["tile"] == &"":
			return slot
	return -1


func _slot_of(tile: StringName) -> int:
	for slot: int in placement.size():
		if placement[slot]["tile"] == tile:
			return slot
	return -1


func is_done() -> bool:
	return _done


func slot_button(slot: int) -> Button:
	return _slot_buttons[slot]


func why_button(slot: int) -> Button:
	return _why_buttons[slot]


func tile_button(tile: StringName) -> Button:
	return _tile_buttons[tile]


func chip_button(chip: StringName) -> Button:
	return _chip_buttons[chip]


func check_button() -> Button:
	return _check


func hint_button() -> Button:
	return _hint


func feedback_text() -> String:
	return _feedback.text


func lit_tile() -> StringName:
	return _lit_tile


func set_enabled(enabled: bool) -> void:
	_enabled = enabled and not _done
	_refresh()


func _say(line_id: StringName, params: Dictionary = {}) -> void:
	_feedback.text = Text.get_line(line_id, params)
	said.emit(line_id, params)


func _refresh() -> void:
	if _check == null:
		return
	for slot: int in placement.size():
		var tile: StringName = placement[slot]["tile"]
		var button: Button = _slot_buttons[slot]
		var prefix: String = "! " if marked.has(slot) else ""
		var body: String = Text.get_line(proof.line_of(tile)) if tile != &"" else Text.get_line(&"z12.builder.empty")
		button.text = Text.get_line(&"z12.builder.slot", {"mark": prefix, "step": Text.get_line(&"z12.builder.step", {"n": slot + 1}), "body": body})
		button.set_pressed_no_signal(selected == slot)
		button.disabled = not _enabled
		var why: StringName = placement[slot]["why"]
		_why_buttons[slot].text = Text.get_line(StringName("z12.why." + why)) if why != &"" else Text.get_line(&"z12.builder.why")
		_why_buttons[slot].disabled = not _enabled or tile == &""
	for tile: StringName in _tile_buttons:
		var button: Button = _tile_buttons[tile]
		button.visible = _slot_of(tile) < 0
		button.disabled = not _enabled
		button.set_pressed_no_signal(false)
		button.text = Text.get_line(&"z12.builder.tile", {"mark": "* " if tile == _lit_tile else "", "body": Text.get_line(proof.line_of(tile))})
	var show_chips: bool = _enabled and selected >= 0 and placement[selected]["tile"] != &""
	_chip_row.visible = show_chips
	for chip: StringName in _chip_buttons:
		_chip_buttons[chip].disabled = not _enabled
		_chip_buttons[chip].set_pressed_no_signal(show_chips and placement[selected]["why"] == chip)
	_check.disabled = not _enabled
	_hint.disabled = not _enabled or proof.scaffold_levels < 1
