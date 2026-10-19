## The rules of the proof board (Zone 9, proof.words.match), pure so they are tested without a screen:
## how far a drag slides the loose piece, where it settles when let go, and whether fitted pieces really
## make the shape the fact names (no gaps, no overlaps). The board (scenes/zones/z09_pattern_grotto/
## proof_board.gd) only draws and animates these numbers.
class_name ProofFit
extends RefCounted

## Let go past this share of the way, the piece snaps into place; before it, it slides back out.
const SNAP_AT: float = 0.5


## The fit (0 apart, 1 in place) after dragging `dx` pixels from `start` along a `travel`-pixel path.
## Dragging left moves the piece toward its place (it waits on the right).
static func fit_after_drag(start: float, dx: float, travel: float) -> float:
	if travel <= 0.0:
		return start
	return clampf(start - dx / travel, 0.0, 1.0)


## Where the piece settles when let go: fully in place or fully apart.
static func settle(fit: float) -> float:
	return 1.0 if fit >= SNAP_AT else 0.0


## True when the pieces (PatternArt.proof_pieces, cell units) cover their bounding box exactly once:
## the fitted picture is a whole rectangle or square with nothing missing and nothing doubled. Pieces
## marked "overlay" (the turned copy of an array) lie on top of the first piece by design and must
## cover exactly the same cells instead.
static func covers_exactly(pieces: Array[Dictionary]) -> bool:
	var bounds: Rect2 = PatternArt.pieces_bounds(pieces)
	var area: float = 0.0
	var seen: Dictionary = {}
	var overlay: Dictionary = {}
	for entry: Dictionary in pieces:
		var spot: Rect2 = entry["rect"]
		if entry.get("overlay", false):
			overlay[Vector2i(spot.position)] = true
			continue
		area += spot.get_area()
		for other: Variant in seen:
			if (other as Rect2).intersects(spot):
				return false
		seen[spot] = true
	if not overlay.is_empty():
		for spot: Variant in seen:
			if not overlay.has(Vector2i((spot as Rect2).position)):
				return false
		if overlay.size() != seen.size():
			return false
	return is_equal_approx(area, bounds.get_area())
