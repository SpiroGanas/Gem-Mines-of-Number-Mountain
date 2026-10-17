## Base class for every full-screen page the Shell hosts (title, hub, settings, mine...).
##
## A screen never swaps scenes itself. It emits request_screen and the Shell does the
## fade and the swap, so the pause overlay and wind-down survive screen changes.
##
## Godot note: a *signal* is a node announcing something happened; other nodes subscribe
## with `signal_name.connect(callable)`. Here the Shell connects to every screen's
## request_screen as it creates the screen.
class_name ShellScreen
extends Control

## Ask the Shell to show another screen. `args` is passed to that screen's setup().
signal request_screen(screen_id: StringName, args: Dictionary)
## Ask the Shell to open the pause menu (the on-screen pause button; tablet posture has no Escape).
signal pause_requested


func _ready() -> void:
	# The Shell's theme normally reaches us through the scene tree; a screen opened on
	# its own (a test, or the editor's "Run Current Scene") styles itself.
	if theme == null:
		theme = UI.theme()


## Called by the Shell with the arguments of change_screen(), before the screen is shown.
func setup(_args: Dictionary) -> void:
	pass
