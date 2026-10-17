## One rock on the wall. A Button (so tapping, focus and keyboard activation come free) with
## a drawn body, cracks and the gem that pops out. Gray-box shapes only.
##
## States: IDLE -> SELECTED (its problem is open) -> WOBBLING (not-quite answer or first tap)
## -> CRACKED (the gem has dropped). A cracked rock is disabled and stays open.
## It never shows a number: the problem is in the panel (GDD, "What makes a rock").
class_name Rock
extends Button

## The wobble animation ended.
signal wobble_finished
## The crack animation ended (the gem is showing and ready to drop).
signal crack_finished

enum RockState { IDLE, SELECTED, WOBBLING, CRACKED }

const WIDTH_MULTIPLE: float = 2.6
const HEIGHT_MULTIPLE: float = 2.0
const WOBBLE_SECONDS: float = 0.3
const CRACK_SECONDS: float = 0.28
const PARTICLES: int = 18
const STRONG_PARTICLES: int = 36
const SQUASH: float = 0.1
const STRONG_SQUASH: float = 0.18
const BODY: Color = Color("#7B8499")
const BODY_CRACKED: Color = Color("#555C70")
const FACET: Color = Color("#6A7287")
const OUTLINE: Color = Color("#3A4258")
const SELECTED_OUTLINE: Color = Color("#FFD166")
const CRACK_LINE: Color = Color("#2B3145")

var rock_index: int = -1
var rock_state: RockState = RockState.IDLE
## 1.0 is normal speed; tests raise it so animations finish quickly.
var speed_scale: float = 1.0

var _gem: GemArt
var _particles: CPUParticles2D
var _overlay: Control
var _tween: Tween


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI.make_touch_target(self, WIDTH_MULTIPLE, HEIGHT_MULTIPLE)
	_apply_styles()
	_overlay = _RockOverlay.new(self)
	add_child(_overlay)
	_gem = GemArt.new()
	_gem.visible = false
	add_child(_gem)
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = PARTICLES
	_particles.lifetime = 0.6
	_particles.explosiveness = 1.0
	_particles.direction = Vector2(0, -1)
	_particles.spread = 180.0
	_particles.gravity = Vector2(0, 700)
	_particles.initial_velocity_min = 160.0
	_particles.initial_velocity_max = 360.0
	_particles.scale_amount_min = 4.0
	_particles.scale_amount_max = 9.0
	add_child(_particles)
	resized.connect(_on_resized)
	_on_resized()


func set_rock_state(next: RockState) -> void:
	rock_state = next
	_apply_styles()
	if _overlay != null:
		_overlay.queue_redraw()


## Rocks the rock side to side, then emits wobble_finished.
func play_wobble() -> void:
	set_rock_state(RockState.WOBBLING)
	_restart_tween()
	var step: float = WOBBLE_SECONDS / 4.0
	_tween.tween_property(self, "rotation", 0.12, step)
	_tween.tween_property(self, "rotation", -0.12, step)
	_tween.tween_property(self, "rotation", 0.06, step)
	_tween.tween_property(self, "rotation", 0.0, step)
	_tween.tween_callback(_on_wobble_done)


## Cracks the rock open and reveals `gem_type`, then emits crack_finished. `strong` is the big
## pickaxe from the garage: more sparkle and a bigger squash.
func play_crack(gem_type: StringName, strong: bool = false) -> void:
	set_rock_state(RockState.CRACKED)
	disabled = true
	_gem.gem_type = gem_type
	_gem.size = Vector2(size.x * 0.34, size.x * 0.34)
	_gem.position = (size - _gem.size) * 0.5
	_gem.visible = true
	_particles.color = GemArt.color_for(gem_type)
	_particles.amount = STRONG_PARTICLES if strong else PARTICLES
	_particles.position = size * 0.5
	_particles.restart()
	_particles.emitting = true
	_restart_tween()
	# Squash and stretch: flatten, spring up, settle (GDD "Game feel").
	var squash: float = 1.0 + (STRONG_SQUASH if strong else SQUASH)
	_tween.tween_property(self, "scale", Vector2(squash, 2.0 - squash), CRACK_SECONDS * 0.3)
	_tween.tween_property(self, "scale", Vector2(0.96, 1.06), CRACK_SECONDS * 0.3)
	_tween.tween_property(self, "scale", Vector2.ONE, CRACK_SECONDS * 0.4)
	_tween.tween_callback(crack_finished.emit)


## Where the gem is on screen (canvas coordinates), for the flight to the cart.
func gem_center() -> Vector2:
	return _gem.global_position + _gem.size * 0.5


## Hides the gem once its flying copy has left; the open rock stays.
func take_gem() -> void:
	_gem.visible = false


func gem_type() -> StringName:
	return _gem.gem_type if _gem != null else &""


func gem_is_visible() -> bool:
	return _gem != null and _gem.visible


## Draws the facets and cracks on top of the button body.
func draw_overlay(canvas: Control) -> void:
	var s: Vector2 = canvas.size
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rock_index * 7919 + 17 # each rock keeps its own look
	for i: int in 3:
		var origin: Vector2 = Vector2(rng.randf_range(0.12, 0.7), rng.randf_range(0.15, 0.7)) * s
		var facet: PackedVector2Array = PackedVector2Array([
			origin, origin + Vector2(rng.randf_range(0.1, 0.2), rng.randf_range(-0.04, 0.04)) * s,
			origin + Vector2(rng.randf_range(0.08, 0.18), rng.randf_range(0.1, 0.2)) * s,
			origin + Vector2(rng.randf_range(-0.04, 0.04), rng.randf_range(0.08, 0.16)) * s,
		])
		canvas.draw_colored_polygon(facet, FACET)
	if rock_state == RockState.CRACKED:
		var crack: PackedVector2Array = PackedVector2Array([
			Vector2(0.5, 0.05) * s, Vector2(0.42, 0.28) * s, Vector2(0.58, 0.45) * s,
			Vector2(0.4, 0.66) * s, Vector2(0.52, 0.95) * s,
		])
		canvas.draw_polyline(crack, CRACK_LINE, 5.0, true)


func _apply_styles() -> void:
	var fill: Color = BODY_CRACKED if rock_state == RockState.CRACKED else BODY
	var border: Color = SELECTED_OUTLINE if rock_state == RockState.SELECTED else OUTLINE
	var width: int = 10 if rock_state == RockState.SELECTED else 5
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = border
		box.set_border_width_all(width)
		box.set_corner_radius_all(48)
		if style_name == &"hover":
			box.bg_color = fill.lightened(0.08)
		elif style_name == &"focus":
			box.bg_color = Color(0, 0, 0, 0)
			box.border_color = Color.WHITE
		add_theme_stylebox_override(style_name, box)


func _on_resized() -> void:
	pivot_offset = size * 0.5
	if _overlay != null:
		_overlay.queue_redraw() # the overlay's full-rect anchors already resize it


func _on_wobble_done() -> void:
	# A not-quite wobble leaves the rock selected, ready for another try.
	set_rock_state(RockState.SELECTED)
	wobble_finished.emit()


func _restart_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	rotation = 0.0
	scale = Vector2.ONE
	_tween = create_tween()
	_tween.set_speed_scale(speed_scale)


## Draws the rock's facets and cracks over the button body (children draw after their parent).
class _RockOverlay extends Control:
	var _rock: Rock

	func _init(rock: Rock) -> void:
		_rock = rock
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		_rock.draw_overlay(self)
