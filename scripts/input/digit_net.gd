## The digit network, run in GDScript from the weights tools/handwriting/export_weights.py writes
## (assets/handwriting/digit_net.json). No plugin, no library, no network.
##
##   28x28 picture -> conv3x3(1->C1)+ReLU -> maxpool2 -> conv3x3(C1->C2)+ReLU -> maxpool2
##                 -> flatten (C2 x 7 x 7, channel-major) -> dense(C2*49 -> H)+ReLU -> dense(H -> 11)
## The 11 outputs are 10 digit logits and a "mirrored" logit. C1, C2 and H are read from the weights
## file (the layer sizes), so a wider or narrower network needs no code change.
##
## Godot note: Marshalls.base64_to_raw(text) decodes base64 into a PackedByteArray, and
## PackedByteArray.to_float32_array() reads it as little-endian 32-bit floats.
class_name DigitNet
extends RefCounted

const PATH: String = "res://assets/handwriting/digit_net.json"
const FORMAT: String = "gem-mines-digit-net"
const FORMAT_VERSION: int = 1
const OUTPUTS: int = 11
const LAYER_NAMES: Array[String] = ["conv1_w", "conv1_b", "conv2_w", "conv2_b", "fc1_w", "fc1_b", "head_w", "head_b"]

var conv1_w: PackedFloat32Array
var conv1_b: PackedFloat32Array
var conv2_w: PackedFloat32Array
var conv2_b: PackedFloat32Array
var fc1_w: PackedFloat32Array
var fc1_b: PackedFloat32Array
var head_w: PackedFloat32Array
var head_b: PackedFloat32Array
## The training report stored beside the weights (accuracy per test set); for the parent area.
var metrics: Dictionary = {}
## Layer widths: conv1 channels, conv2 channels, hidden units (from the bias sizes).
var conv1: int = 0
var conv2: int = 0
var hidden_units: int = 0


## The network from a weights file, or null if the file is missing or not a digit-net file.
static func load_file(path: String = PATH) -> DigitNet:
	var doc: Variant = JsonUtil.parse_file(path)
	if not doc is Dictionary or doc.get("format") != FORMAT or int(doc.get("version", 0)) != FORMAT_VERSION:
		return null
	if not doc.get("layers") is Dictionary:
		return null
	var net: DigitNet = DigitNet.new()
	for name: String in LAYER_NAMES:
		var entry: Variant = doc["layers"].get(name)
		if not entry is Dictionary or not entry.has("data"):
			return null
		net.set(name, Marshalls.base64_to_raw(str(entry["data"])).to_float32_array())
	net.conv1 = net.conv1_b.size()
	net.conv2 = net.conv2_b.size()
	net.hidden_units = net.fc1_b.size()
	if net.conv1 < 1 or net.conv2 < 1 or net.hidden_units < 1 or net.head_b.size() != OUTPUTS:
		return null
	if net.conv1_w.size() != net.conv1 * 9 or net.conv2_w.size() != net.conv2 * net.conv1 * 9:
		return null
	if net.fc1_w.size() != net.hidden_units * net.conv2 * 49 or net.head_w.size() != OUTPUTS * net.hidden_units:
		return null
	net.metrics = doc.get("metrics", {})
	return net


## The 11 logits for a GRID*GRID picture.
func forward(picture: PackedFloat32Array) -> PackedFloat32Array:
	var size: int = StrokeRaster.GRID
	# conv1 + ReLU + pool: input zero-padded to 30x30, output CONV1 x 14 x 14 (zero-padded to 16x16)
	var padded: PackedFloat32Array = PackedFloat32Array()
	padded.resize(30 * 30)
	for y: int in size:
		for x: int in size:
			padded[(y + 1) * 30 + x + 1] = picture[y * size + x]
	var pooled1: PackedFloat32Array = PackedFloat32Array()
	pooled1.resize(conv1 * 16 * 16)
	for k: int in conv1:
		var bias: float = conv1_b[k]
		for py: int in 14:
			for px: int in 14:
				var best: float = -INF
				for dy: int in 2:
					for dx: int in 2:
						var y: int = py * 2 + dy
						var x: int = px * 2 + dx
						var sum: float = bias
						for ky: int in 3:
							for kx: int in 3:
								sum += conv1_w[k * 9 + ky * 3 + kx] * padded[(y + ky) * 30 + x + kx]
						best = maxf(best, sum)
				pooled1[(k * 16 + py + 1) * 16 + px + 1] = maxf(best, 0.0)
	# conv2 + ReLU + pool: output CONV2 x 7 x 7, flattened channel-major
	var flat: PackedFloat32Array = PackedFloat32Array()
	flat.resize(conv2 * 49)
	for k: int in conv2:
		var bias2: float = conv2_b[k]
		for py: int in 7:
			for px: int in 7:
				var best2: float = -INF
				for dy: int in 2:
					for dx: int in 2:
						var y2: int = py * 2 + dy
						var x2: int = px * 2 + dx
						var sum2: float = bias2
						for c: int in conv1:
							var w_base: int = (k * conv1 + c) * 9
							var in_base: int = c * 256
							for ky: int in 3:
								var row: int = in_base + (y2 + ky) * 16 + x2
								var w_row: int = w_base + ky * 3
								sum2 += conv2_w[w_row] * pooled1[row] + conv2_w[w_row + 1] * pooled1[row + 1] + conv2_w[w_row + 2] * pooled1[row + 2]
						best2 = maxf(best2, sum2)
				flat[(k * 7 + py) * 7 + px] = maxf(best2, 0.0)
	var hidden: PackedFloat32Array = PackedFloat32Array()
	hidden.resize(hidden_units)
	var inputs: int = conv2 * 49
	for j: int in hidden_units:
		var sum3: float = fc1_b[j]
		var base: int = j * inputs
		for i: int in inputs:
			sum3 += fc1_w[base + i] * flat[i]
		hidden[j] = maxf(sum3, 0.0)
	var logits: PackedFloat32Array = PackedFloat32Array()
	logits.resize(OUTPUTS)
	for o: int in OUTPUTS:
		var sum4: float = head_b[o]
		for j: int in hidden_units:
			sum4 += head_w[o * hidden_units + j] * hidden[j]
		logits[o] = sum4
	return logits


## What the game reads from a picture: {digit, confidence, mirrored, mirrored_confidence}.
func read(picture: PackedFloat32Array) -> Dictionary:
	var logits: PackedFloat32Array = forward(picture)
	var top: float = -INF
	for i: int in 10:
		top = maxf(top, logits[i])
	var total: float = 0.0
	var exps: Array[float] = []
	for i: int in 10:
		var e: float = exp(logits[i] - top)
		exps.append(e)
		total += e
	var digit: int = 0
	for i: int in 10:
		if exps[i] > exps[digit]:
			digit = i
	var mirrored_p: float = 1.0 / (1.0 + exp(-logits[10]))
	return {"digit": digit, "confidence": exps[digit] / total, "mirrored": mirrored_p >= 0.5, "mirrored_confidence": mirrored_p}
