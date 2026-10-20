## The tower elevator's rules (Zone 8, exp.powers_of_two.list concrete): pure logic for Bolt's cab in the
## Power Tower. Floor k is base^k meters up (floor 0 is 1 meter: base⁰ = 1), so each floor up doubles the
## height in the doubling tower. The cab rides one floor per Up or Down and never leaves the tower; every
## floor it has visited shows its height, so the child sees the doubling as they ride. The tower elevator
## scene (scenes/zones/z08_power_tower/tower_elevator.gd) only draws this.
class_name TowerRide
extends RefCounted

var base: int = 2
var floors: int = 10
var floor_now: int = 0
## Floors the cab has stopped on (their heights are shown).
var visited: Array[bool] = []


static func make(tower_base: int, top_floor: int, start: int = 0) -> TowerRide:
	var ride: TowerRide = TowerRide.new()
	ride.base = maxi(tower_base, 2)
	ride.floors = clampi(top_floor, 1, ExponentGenerator.MAX_TOWER_FLOORS)
	for index: int in ride.floors + 1:
		ride.visited.append(false)
	ride.floor_now = clampi(start, 0, ride.floors)
	ride.visited[ride.floor_now] = true
	return ride


## Moves the cab `steps` floors up (positive) or down (negative), stopping at the ends. Returns the floor.
func move(steps: int) -> int:
	floor_now = clampi(floor_now + steps, 0, floors)
	visited[floor_now] = true
	return floor_now


## The height of floor k in meters: base^k.
func height_of(floor_number: int) -> int:
	return Notation.power(base, floor_number)


func can_go_up() -> bool:
	return floor_now < floors


func can_go_down() -> bool:
	return floor_now > 0


func was_visited(floor_number: int) -> bool:
	return floor_number >= 0 and floor_number < visited.size() and visited[floor_number]
