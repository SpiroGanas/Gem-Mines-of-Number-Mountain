## Reads a digit box with the digit network: StrokeRaster makes the picture, DigitNet reads it.
## Keeps nothing: the strokes and the picture are local variables that go when the call returns.
class_name NetRecognizer
extends Recognizer

var _net: DigitNet


func _init(net: DigitNet) -> void:
	_net = net


func recognize(strokes: Array[PackedVector2Array], box_size: Vector2i) -> Dictionary:
	var picture: PackedFloat32Array = StrokeRaster.rasterize(strokes, Vector2(box_size))
	if picture.is_empty():
		return Recognizer.NOTHING.duplicate()
	return _net.read(picture)
