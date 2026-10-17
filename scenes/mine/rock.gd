## One rock on the wall. A Button (so tapping, focus and keyboard activation come free) whose
## body is one of four Kenney CC0 meteor sprites (assets/CREDITS.md), drawn by the overlay so it
## keeps its shape at any size, with the crack line and the gem that pops out drawn on top.
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
## The four rock sprites; a rock keeps the same one for its whole life (rock_index picks it).
const TEXTURE_PATHS: Array[String] = [
	"res://assets/art/kenney/rocks/rock_01.png", "res://assets/art/kenney/rocks/rock_02.png",
	"res://assets/art/kenney/rocks/rock_03.png", "res://assets/art/kenney/rocks/rock_04.png",
]
## How much of the button the sprite fills (the rest is tap margin and room for the glow).
const SPRITE_FILL: float = 0.9
## The glow is the rock's own silhouette drawn larger behind it; the tint multiplies the brown
## sprite up to the headlamp yellow (values above 1 brighten and clamp).
const SELECTED_GLOW: Color = Color(2.6, 2.0, 0.9)
const GLOW_GROW: float = 0.07
const HOVER_TINT: Color = Color(1.1, 1.1, 1.1)
const CRACKED_TINT: Color = Color(0.6, 0.6, 0.66)
const CRACK_LINE: Color = Color("#2B3145")

static var _textures: Array[Texture2D] = []

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
	mouse_entered.connect(_overlay.queue_redraw)
	mouse_exited.connect(_overlay.queue_redraw)
	_on_resized()


## The sprite for rock `index` of the wall (the same index always gets the same rock).
static func texture_for(index: int) -> Texture2D:
	if _textures.is_empty():
		for path: String in TEXTURE_PATHS:
			_textures.append(load(path))
	return _textures[posmod(index, _textures.size())]


## Where the sprite sits inside a canvas of `canvas_size`: as large as fits, its own aspect, centred.
static func sprite_rect(texture: Texture2D, canvas_size: Vector2) -> Rect2:
	var texture_size: Vector2 = texture.get_size()
	var scale_to_fit: float = minf(canvas_size.x * SPRITE_FILL / texture_size.x, canvas_size.y * SPRITE_FILL / texture_size.y)
	var drawn: Vector2 = texture_size * scale_to_fit
	return Rect2((canvas_size - drawn) * 0.5, drawn)


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


## Draws the rock: the sprite (with a headlamp-yellow glow behind it while selected, dimmed once
## cracked, a touch brighter under the mouse) and the crack line on a cracked rock.
func draw_overlay(canvas: Control) -> void:
	var texture: Texture2D = texture_for(rock_index)
	var rect: Rect2 = sprite_rect(texture, canvas.size)
	if rock_state == RockState.SELECTED or rock_state == RockState.WOBBLING:
		canvas.draw_texture_rect(texture, rect.grow(rect.size.x * GLOW_GROW), false, SELECTED_GLOW) # the same silhouette, a little larger
	var tint: Color = Color.WHITE
	if rock_state == RockState.CRACKED:
		tint = CRACKED_TINT
	elif is_hovered() and not disabled:
		tint = HOVER_TINT
	canvas.draw_texture_rect(texture, rect, false, tint)
	if rock_state == RockState.CRACKED:
		var s: Vector2 = rect.size
		var crack: PackedVector2Array = PackedVector2Array([
			rect.position + Vector2(0.5, 0.08) * s, rect.position + Vector2(0.42, 0.3) * s, rect.position + Vector2(0.58, 0.47) * s,
			rect.position + Vector2(0.4, 0.68) * s, rect.position + Vector2(0.52, 0.93) * s,
		])
		canvas.draw_polyline(crack, CRACK_LINE, 5.0, true)


## The button itself draws nothing (the overlay draws the sprite); only keyboard focus shows a box.
func _apply_styles() -> void:
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color.WHITE
	focus.set_border_width_all(5)
	focus.set_corner_radius_all(48)
	add_theme_stylebox_override(&"focus", focus)


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
