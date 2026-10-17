## Captures every child screen at the four aspect ratios the game supports (16:9, 16:10, 3:2, 4:3)
## for the Sprint 20 accessibility pass (P2-S20-05). Developer tool: not exported (tools/* is in the
## presets' exclude filter) and never run by the game.
##
## Run with a real renderer (headless has none), e.g. on Linux:
##   xvfb-run -s "-screen 0 1920x1200x24" "$GODOT" --path . --rendering-driver opengl3 res://tools/qa/capture_screens.tscn
## Writes docs/qa/screens-1.0/<ratio>/<screen>.jpg (half size) and docs/qa/draw-calls-1.0.md (draw
## calls and canvas items per screen, from the renderer's own counters; meaningful on any GPU, while
## frame times are only meaningful on the real devices) and quits. A demo save in a temp folder
## gives the screens something to show; the real save is never touched.
extends Node

const OUT_DIR: String = "res://docs/qa/screens-1.0"
const RATIOS: Dictionary = {
	"16x9": Vector2i(1920, 1080),
	"16x10": Vector2i(1920, 1200),
	"3x2": Vector2i(1620, 1080),
	"4x3": Vector2i(1440, 1080),
}
const SCREENS: Array[StringName] = [&"title", &"hub", &"mine", &"crafting", &"build_site", &"museum", &"badges", &"glossary", &"garage", &"settings"]
const SETTLE_FRAMES: int = 45
const DRAW_CALLS_PATH: String = "res://docs/qa/draw-calls-1.0.md"

var _rows: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_demo_save()
	await _capture_all()
	_write_draw_calls()
	get_tree().quit()


func _write_draw_calls() -> void:
	var file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(DRAW_CALLS_PATH), FileAccess.WRITE)
	file.store_string("# Draw calls per screen (Version 1.0)\n\nWritten by `tools/qa/capture_screens.tscn` on %s with the %s renderer (%s). Draw calls depend on the scene, not the GPU, so they hold on the devices too; frame times must be measured on the devices (`docs/qa/perf-1.0.md`).\n\n| Ratio | Screen | Draw calls | Objects |\n|---|---|---|---|\n%s\n" % [Time.get_date_string_from_system(), RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(), "\n".join(_rows)])
	file.close()


func _demo_save() -> void:
	SaveSystem.use_directory(OS.get_user_data_dir().path_join("qa_capture"))
	var data: Dictionary = SaveSystem.data()
	data["child"]["nickname"] = "Charlie"
	data["placement"]["done"] = true
	data["rewards"]["coins"] = 64
	data["rewards"]["gems"] = {"quartz": 14, "garnet": 12, "pyrite": 6, "amethyst": 3}
	for id: StringName in [&"add.to_10.sums", &"sub.to_10.diff", &"count.to_120.next", &"mult.equal_groups.total"]:
		var record: Dictionary = SkillRecord.fresh(0.97)
		record["mastered_at"] = "2027-03-01T00:00:00Z"
		data["skills"][String(id)] = record
	data["workshop"]["builds"]["cart_track"] = {"step": 3, "done": true}
	data["motivation"]["badges"] = ["gauss"]
	data["rewards"]["inventory"].append("hub_lanterns")
	data["family"]["points"] = 22
	Rewards.sync_word_gems()


func _capture_all() -> void:
	for ratio: String in RATIOS:
		DisplayServer.window_set_size(RATIOS[ratio])
		get_window().size = RATIOS[ratio]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR.path_join(ratio)))
		var shell: Shell = load("res://scenes/shell/shell.tscn").instantiate()
		shell.fade_seconds = 0.0
		add_child(shell)
		(shell.find_child("DebugOverlay", true, false) as CanvasItem).visible = false # a debug build shows it
		for screen_id: StringName in SCREENS:
			shell.change_screen(screen_id, {})
			for frame: int in SETTLE_FRAMES:
				await get_tree().process_frame
			var calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var items: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			_rows.append("| %s | %s | %d | %d |" % [ratio, screen_id, calls, items])
			var image: Image = get_viewport().get_texture().get_image()
			image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_LANCZOS)
			image.save_jpg(ProjectSettings.globalize_path(OUT_DIR.path_join(ratio).path_join("%s.jpg" % screen_id)), 0.82)
			print("captured %s %s" % [ratio, screen_id])
		shell.queue_free()
		await get_tree().process_frame
