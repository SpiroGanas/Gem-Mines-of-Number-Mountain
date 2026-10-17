"""Independent checkers for the exported problems (one module per generator).

These modules must stay independent of the GDScript generators: they read only the exported JSON
lines (plus the allowed-names policy list the runner hands them), and they recompute every answer
and distractor from the facts in the line. Never port generator code here.
"""
