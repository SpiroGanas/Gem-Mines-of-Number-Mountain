## The wall: a grid of 6 to 9 rocks for one dig. It owns the rocks and reports which was tapped.
class_name RockWall
extends GridContainer

## A rock was tapped (and was free to pick).
signal rock_selected(index: int)

const ROCK_SCENE: PackedScene = preload("res://scenes/mine/rock.tscn")
const MIN_ROCKS: int = 6
const MAX_ROCKS: int = 9
const COLUMNS_FOR_WALL: int = 3

var speed_scale: float = 1.0

var _rocks: Array[Rock] = []


func _ready() -> void:
	columns = COLUMNS_FOR_WALL
	add_theme_constant_override(&"h_separation", 24)
	add_theme_constant_override(&"v_separation", 24)


## Replaces the wall with `count` fresh rocks.
func build(count: int) -> void:
	for rock: Rock in _rocks:
		rock.queue_free()
		remove_child(rock)
	_rocks.clear()
	for index: int in clampi(count, 1, MAX_ROCKS):
		var rock: Rock = ROCK_SCENE.instantiate()
		rock.rock_index = index
		rock.speed_scale = speed_scale
		rock.pressed.connect(_on_rock_pressed.bind(index))
		add_child(rock)
		_rocks.append(rock)


func rock_count() -> int:
	return _rocks.size()


func rock(index: int) -> Rock:
	return _rocks[index] if index >= 0 and index < _rocks.size() else null


## Only uncracked rocks can be tapped, and only while the wall is interactive.
func set_interactive(interactive: bool) -> void:
	for rock_node: Rock in _rocks:
		rock_node.disabled = not interactive or rock_node.rock_state == Rock.RockState.CRACKED


## Marks one rock as the open one; others return to idle unless cracked.
func mark_selected(index: int) -> void:
	for rock_node: Rock in _rocks:
		if rock_node.rock_state == Rock.RockState.CRACKED:
			continue
		rock_node.set_rock_state(Rock.RockState.SELECTED if rock_node.rock_index == index else Rock.RockState.IDLE)


func clear_selection() -> void:
	mark_selected(-1)


func _on_rock_pressed(index: int) -> void:
	rock_selected.emit(index)
