## A GameClock that only moves when a test moves it. Starts at noon UTC on 2026-12-07 (Sprint 6's
## Monday) with no time-zone offset, so days in tests are predictable.
class_name FakeClock
extends GameClock

const START_UNIX: int = 1796644800 # 2026-12-07T12:00:00Z

var unix: int = START_UNIX
var offset_minutes: int = 0


func now_unix() -> int:
	return unix


func utc_offset_minutes() -> int:
	return offset_minutes


func advance(seconds: int) -> void:
	unix += seconds


func advance_days(days: int) -> void:
	unix += days * SECONDS_PER_DAY
