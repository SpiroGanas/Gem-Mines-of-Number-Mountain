## The mine cart and its counters. Gems fly in from the rock that dropped them.
## Gray-box: the cart is a drawn trapezoid with two wheels.
class_name Cart
extends HBoxContainer

## A flying gem arrived.
signal gem_landed(gem_type: StringName)

const FLIGHT_SECONDS: float = 0.45
const BOUNCE_SECONDS: float = 0.18
const BODY: Color = Color("#8B6F47")
const BODY_RIM: Color = Color("#5E4A2F")
const WHEEL: Color = Color("#2B3145")

var speed_scale: float = 1.0
## The big pickaxe makes the cart bounce harder when a gem lands.
var strong: bool = false

var _art: Control
var _coins_label: Label
var _gems_label: Label
var _coins: int = 0
var _gems: int = 0
var _tween: Tween


func _ready() -> void:
	add_theme_constant_override(&"separation", 32)
	_art = _CartArt.new()
	UI.make_touch_target(_art, 2.5, 1.5)
	add_child(_art)
	var counters: VBoxContainer = VBoxContainer.new()
	counters.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(counters)
	_coins_label = Label.new()
	_gems_label = Label.new()
	counters.add_child(_coins_label)
	counters.add_child(_gems_label)
	_art.resized.connect(func() -> void: _art.pivot_offset = _art.size * 0.5)
	_refresh()


func set_totals(coins: int, gems: int) -> void:
	_coins = coins
	_gems = gems
	_refresh()


func coins_shown() -> int:
	return _coins


func gems_shown() -> int:
	return _gems


## Where a flying gem should land (canvas coordinates).
func landing_point() -> Vector2:
	return _art.global_position + _art.size * 0.5


## Flies a copy of the gem from `from_center` into the cart, bounces the cart, and emits
## gem_landed. The flying gem lives in `fx_layer`, a full-screen Control that does not clip.
func receive_gem(gem_type: StringName, from_center: Vector2, fx_layer: Control) -> void:
	var flying: GemArt = GemArt.new()
	flying.gem_type = gem_type
	flying.size = UI.target_size(0.9, 0.9)
	fx_layer.add_child(flying)
	flying.global_position = from_center - flying.size * 0.5
	var end: Vector2 = landing_point() - flying.size * 0.5
	var flight: Tween = create_tween()
	flight.set_speed_scale(speed_scale)
	flight.tween_property(flying, "global_position", end, FLIGHT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_callback(_on_gem_arrived.bind(flying, gem_type))


func _on_gem_arrived(flying: GemArt, gem_type: StringName) -> void:
	flying.queue_free()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_art.scale = Vector2.ONE
	_tween = create_tween()
	_tween.set_speed_scale(speed_scale)
	var bounce: Vector2 = Vector2(1.18, 0.86) if strong else Vector2(1.1, 0.92)
	_tween.tween_property(_art, "scale", bounce, BOUNCE_SECONDS * 0.5)
	_tween.tween_property(_art, "scale", Vector2.ONE, BOUNCE_SECONDS * 0.5)
	gem_landed.emit(gem_type)


func _refresh() -> void:
	if _coins_label == null:
		return
	_coins_label.text = Text.get_line(&"ui.mine.coins", {"n": _coins})
	_gems_label.text = Text.get_line(&"ui.mine.gems", {"n": _gems})


class _CartArt extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s: Vector2 = size
		var body: PackedVector2Array = PackedVector2Array([Vector2(0.05, 0.2) * s, Vector2(0.95, 0.2) * s, Vector2(0.8, 0.75) * s, Vector2(0.2, 0.75) * s])
		draw_colored_polygon(body, Cart.BODY)
		var rim: PackedVector2Array = body.duplicate()
		rim.append(body[0])
		draw_polyline(rim, Cart.BODY_RIM, 4.0, true)
		draw_circle(Vector2(0.3, 0.85) * s, s.y * 0.11, Cart.WHEEL)
		draw_circle(Vector2(0.7, 0.85) * s, s.y * 0.11, Cart.WHEEL)
