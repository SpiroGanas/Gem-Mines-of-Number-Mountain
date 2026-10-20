## The proof board (Zone 9, Sprint 40; meta.proof_board = {diagram, n, choices}): a proof without words.
## The picture has two pieces: the gold gems stay, the blue blocks are the loose piece waiting to the
## right. The child drags the loose piece into place (or taps Fit together), and the two pieces make the
## shape the fact is about: two staircases make a rectangle, two triangles a square... Then the child taps
## the fact the picture shows (two columns of fact buttons). The board never judges; the host compares
## the chosen id.
##
## Finger, stylus and mouse drag the same way (InputRouter pointer signals); the Fit button and the fact
## buttons work with a mouse alone, and Space toggles the fit on a keyboard. The pieces glide with a
## tween; the picture's _draw allocates nothing (it runs every frame of the glide; perf_check rule 1b).
## Reused by the Zone 12 Mathematician's Journal (Phase 5 hand-off).
class_name ProofBoard
extends VBoxContainer

## A fact was tapped: its diagram id.
signal chosen(diagram_id: String)
## The loose piece snapped into place (for a sound).
signal fitted

const PICTURE_HEIGHT_MULTIPLE: float = 2.4
## Fact buttons: two columns, one touch target tall, so the board fits a landscape phone. A fact wraps
## onto two lines inside its button (fact_label).
const FACT_WIDTH_MULTIPLE: float = 5.5
const FIT_BUTTON_WIDTH: float = 3.2
const GLIDE_SECONDS: float = 0.35

var diagram: String = "staircases"
var n: int = 3
## Tests set 0 to make the glide instant.
var speed_scale: float = 1.0
## The pointer source. Defaults to the InputRouter autoload; tests inject their own.
var router: Node

var _picture: _ProofPicture
var _fit_button: Button
var _facts: GridContainer
var _fact_buttons: Dictionary[String, Button] = {}
var _how: Label
var _enabled: bool = true
var _dragging: bool = false
var _drag_start_x: float = 0.0
var _drag_start_fit: float = 0.0
var _options: Array[Dictionary] = []
var _rng: RandomNumberGenerator


func _ready() -> void:
	add_theme_constant_override(&"separation", 12)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_how = Label.new()
	_how.name = "How"
	_how.text = Text.get_line(&"z9.proof.how")
	_how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_how)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PictureRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)
	_picture = _ProofPicture.new()
	_picture.name = "Picture"
	UI.make_touch_target(_picture, 6.0, PICTURE_HEIGHT_MULTIPLE)
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_picture)
	_fit_button = Button.new()
	_fit_button.name = "FitButton"
	_fit_button.focus_mode = Control.FOCUS_NONE
	UI.make_touch_target(_fit_button, FIT_BUTTON_WIDTH, 1.2)
	_fit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fit_button.pressed.connect(toggle_fit)
	row.add_child(_fit_button)
	_facts = GridContainer.new()
	_facts.name = "Facts"
	_facts.columns = 2
	_facts.add_theme_constant_override(&"h_separation", 12)
	_facts.add_theme_constant_override(&"v_separation", 12)
	_facts.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_facts)
	if router == null:
		router = InputRouter
	router.pointer_down.connect(_on_pointer_down)
	router.pointer_move.connect(_on_pointer_move)
	router.pointer_up.connect(_on_pointer_up)
	router.pointer_cancelled.connect(_on_pointer_cancelled)
	_apply()


func _exit_tree() -> void:
	if router != null and router.pointer_down.is_connected(_on_pointer_down):
		router.pointer_down.disconnect(_on_pointer_down)
		router.pointer_move.disconnect(_on_pointer_move)
		router.pointer_up.disconnect(_on_pointer_up)
		router.pointer_cancelled.disconnect(_on_pointer_cancelled)


## The diagram at size `size_n`, and the facts to offer as [{value: id, label: text}] (shuffled with rng).
func setup(diagram_id: String, size_n: int, options: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	diagram = diagram_id
	n = size_n
	_options = options
	_rng = rng
	_apply()


func _apply() -> void:
	if _picture == null:
		return
	_picture.set_diagram(diagram, n)
	if not _options.is_empty() and _fact_buttons.is_empty():
		_build_facts()
	_refresh()


## One button a fact, in an order shuffled with the problem's rng (the same problem shows the same order).
func _build_facts() -> void:
	var order: Array[int] = []
	for index: int in _options.size():
		order.append(index)
	order = GeneratorKit.shuffled_ints(order, _rng if _rng != null else RandomNumberGenerator.new())
	for index: int in order:
		var id: String = str(_options[index]["value"])
		var button: Button = Button.new()
		button.name = "Fact_%s" % id
		button.focus_mode = Control.FOCUS_NONE
		UI.make_touch_target(button, FACT_WIDTH_MULTIPLE, 1.0)
		button.add_child(_fact_label(str(_options[index]["label"])))
		button.pressed.connect(_on_fact_chosen.bind(id))
		_facts.add_child(button)
		_fact_buttons[id] = button


## A fact's words on two lines inside its button. A Button's own autowrap asks for the height of one
## word a line (hundreds of pixels, off every screen); a Label filling the button wraps at its width.
func _fact_label(text: String) -> Label:
	var label: Label = Label.new()
	label.name = "Words"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	return label


## The words on a fact button (its Label child).
func fact_text(diagram_id: String) -> String:
	var button: Button = fact_button(diagram_id)
	return (button.get_node("Words") as Label).text if button != null else ""


## How far the loose piece is in place: 0 apart, 1 fitted.
func fit() -> float:
	return _picture.fit


func is_fitted() -> bool:
	return is_equal_approx(_picture.fit, 1.0)


## Slides the loose piece in, or back out if it is in.
func toggle_fit() -> void:
	if _enabled:
		glide_to(0.0 if is_fitted() else 1.0)


func glide_to(target: float) -> void:
	var was_fitted: bool = is_fitted()
	if speed_scale <= 0.0 or not is_inside_tree():
		_picture.fit = target
	else:
		var glide: Tween = create_tween()
		glide.tween_property(_picture, "fit", target, GLIDE_SECONDS * speed_scale)
	if target >= 1.0 and not was_fitted:
		fitted.emit()
	_refresh_button(target)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_dragging = false
	_refresh()


## The fact button for a diagram id, or null.
func fact_button(diagram_id: String) -> Button:
	return _fact_buttons.get(diagram_id)


## The fact ids in on-screen order (left to right, top to bottom).
func fact_order() -> Array[String]:
	var ids: Array[String] = []
	for child: Node in _facts.get_children():
		ids.append(String(child.name).trim_prefix("Fact_"))
	return ids


func fit_button() -> Button:
	return _fit_button


func picture() -> Control:
	return _picture


## Taps the fact with this id (tests and tools; the child taps the button).
func choose(diagram_id: String) -> bool:
	var button: Button = fact_button(diagram_id)
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true


func _on_fact_chosen(diagram_id: String) -> void:
	if _enabled:
		chosen.emit(diagram_id)


func _refresh() -> void:
	if _fit_button == null:
		return
	_fit_button.disabled = not _enabled
	for button: Button in _fact_buttons.values():
		button.disabled = not _enabled
		button.modulate.a = 1.0 if _enabled else 0.6 # the words dim with the button
	_refresh_button(_picture.fit)


func _refresh_button(target: float) -> void:
	_fit_button.text = Text.get_line(&"z9.proof.apart" if target >= 1.0 else &"z9.proof.fit")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE and is_visible_in_tree():
		toggle_fit()
		get_viewport().set_input_as_handled()


# --- Dragging the loose piece --------------------------------------------------------------------


func _accepts_pointer() -> bool:
	return _enabled and is_visible_in_tree() and can_process()


func _on_pointer_down(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if _accepts_pointer() and _picture.get_global_rect().has_point(pos):
		_dragging = true
		_drag_start_x = pos.x
		_drag_start_fit = _picture.fit


func _on_pointer_move(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if _dragging:
		_picture.fit = ProofFit.fit_after_drag(_drag_start_fit, pos.x - _drag_start_x, _picture.travel_px())


func _on_pointer_up(pos: Vector2, _kind: InputRouter.DeviceKind, _index: int) -> void:
	if not _dragging:
		return
	_dragging = false
	if absf(pos.x - _drag_start_x) < 8.0:
		glide_to(0.0 if _drag_start_fit >= 1.0 else 1.0) # a tap on the picture toggles the fit
		return
	glide_to(ProofFit.settle(_picture.fit))


func _on_pointer_cancelled(_index: int) -> void:
	if _dragging:
		_dragging = false
		glide_to(_drag_start_fit)


## The picture: both pieces, the loose one drawn between its waiting place and its home by `fit`.
## Everything _draw needs is built in set_diagram(), so a glide allocates nothing per frame.
class _ProofPicture:
	extends Control

	var fit: float = 0.0:
		set(value):
			fit = clampf(value, 0.0, 1.0)
			queue_redraw()
	var _apart: Array[Dictionary] = []
	var _home: Array[Dictionary] = []
	var _frame: Rect2 = Rect2()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_diagram(diagram_id: String, size_n: int) -> void:
		_apart = PatternArt.proof_pieces(diagram_id, size_n, false)
		_home = PatternArt.proof_pieces(diagram_id, size_n, true)
		_frame = PatternArt.pieces_bounds(_apart).merge(PatternArt.pieces_bounds(_home))
		queue_redraw()

	## How many pixels the loose piece travels from its waiting place to its home.
	func travel_px() -> float:
		if _apart.is_empty():
			return 1.0
		var unit: float = minf(size.x / maxf(_frame.size.x, 1.0), size.y / maxf(_frame.size.y, 1.0))
		var last: int = _apart.size() - 1
		return maxf(absf((_apart[last]["rect"] as Rect2).position.x - (_home[last]["rect"] as Rect2).position.x) * unit, 1.0)

	func _draw() -> void:
		if _apart.is_empty() or size.x < 32.0:
			return
		var unit: float = minf(size.x / maxf(_frame.size.x, 1.0), size.y / maxf(_frame.size.y, 1.0))
		var origin: Vector2 = (size - _frame.size * unit) * 0.5 - _frame.position * unit
		for index: int in _apart.size():
			var away: Rect2 = _apart[index]["rect"]
			var home: Rect2 = _home[index]["rect"]
			var at: Vector2 = away.position.lerp(home.position, fit) if int(_apart[index]["piece"]) == 1 else home.position
			var box: Rect2 = Rect2(origin + at * unit, away.size * unit)
			if _apart[index].get("square", false):
				draw_rect(box.grow(-1.0), Color(PatternArt.PIECE_B if int(_apart[index]["piece"]) == 1 else PatternArt.PIECE_A, 0.4))
				draw_rect(box.grow(-1.0), PatternArt.OUTLINE, false, 2.0)
			elif int(_apart[index]["piece"]) == 0:
				draw_circle(box.get_center(), box.size.x * 0.4, PatternArt.PIECE_A)
			else:
				draw_rect(box.grow(-box.size.x * 0.12), PatternArt.PIECE_B)
