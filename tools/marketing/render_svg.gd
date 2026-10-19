## Renders one SVG to a PNG with Godot's own SVG rasterizer (ThorVG), for the store graphics
## (P3-S26-01). Developer tool: tools/* is excluded from exports, and nothing is downloaded.
##
##   "$GODOT" --headless --path . --script res://tools/marketing/render_svg.gd -- \
##       marketing/src/icon.svg marketing/export/icon-512.png 512 512 [--opaque]
##
## Paths are relative to the project folder (or absolute). The SVG is scaled to the width, then
## must come out at exactly the given height (the source's aspect ratio is part of the spec).
## --opaque drops the alpha channel (the feature graphic may not be transparent). marketing/ holds a
## .gdignore, so Godot never imports or exports the sources or the PNGs.
extends SceneTree


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var opaque: bool = args.has("--opaque")
	var positional: PackedStringArray = PackedStringArray()
	for arg: String in args:
		if not arg.begins_with("--"):
			positional.append(arg)
	if positional.size() != 4:
		printerr("usage: render_svg.gd -- <in.svg> <out.png> <width> <height> [--opaque]")
		quit(2)
		return
	quit(_render(_path(positional[0]), _path(positional[1]), int(positional[2]), int(positional[3]), opaque))


func _path(path: String) -> String:
	return path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)


func _render(source: String, target: String, width: int, height: int, opaque: bool) -> int:
	var text: String = FileAccess.get_file_as_string(source)
	if text.is_empty():
		printerr("render_svg: cannot read %s" % source)
		return 1
	var probe: Image = Image.new()
	if probe.load_svg_from_string(text, 1.0) != OK:
		printerr("render_svg: %s is not an SVG Godot can read" % source)
		return 1
	var image: Image = Image.new()
	image.load_svg_from_string(text, float(width) / float(probe.get_width()))
	if image.get_width() != width or image.get_height() != height:
		printerr("render_svg: %s renders at %dx%d, expected %dx%d" % [source, image.get_width(), image.get_height(), width, height])
		return 1
	if opaque:
		image.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var error: Error = image.save_png(target)
	if error != OK:
		printerr("render_svg: cannot write %s (%s)" % [target, error_string(error)])
		return 1
	print("render_svg: %s -> %s (%dx%d%s)" % [source.get_file(), target, width, height, ", opaque" if opaque else ""])
	return 0
