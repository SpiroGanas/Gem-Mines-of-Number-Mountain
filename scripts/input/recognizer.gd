## What reads a digit box. The chalk slate asks a Recognizer to read the strokes in one box and
## gets back a Dictionary:
##   digit                 0..9, or -1 when there is nothing to read in the box
##   confidence            0..1, how sure the reading is (the slate asks "Did you write 7?" below
##                         its threshold)
##   mirrored              true when the digit looks backwards (a reversed 3); the digit is still
##                         the one the child meant
##   mirrored_confidence   0..1
## Strokes are normalized to the box (0..1, y down); box_size is the box in pixels. Nothing is
## stored: a Recognizer keeps no strokes after returning (CLAUDE.md rule 2).
##
## This is the abstract base. NetRecognizer reads with the digit network; FakeRecognizer is the
## deterministic stub for tests and the desktop editor.
class_name Recognizer
extends RefCounted

const NOTHING: Dictionary = {"digit": -1, "confidence": 0.0, "mirrored": false, "mirrored_confidence": 0.0}


func recognize(_strokes: Array[PackedVector2Array], _box_size: Vector2i) -> Dictionary:
	push_error("Recognizer.recognize() must be overridden")
	return NOTHING.duplicate()
