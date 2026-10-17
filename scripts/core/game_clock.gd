## Where the game gets the time and the child's calendar day.
##
## Everything that depends on days (mastery on two different days, spaced review, the lantern
## streak, the session soft limit) asks a GameClock instead of reading the system time itself, so
## tests can swap in tests/helpers/fake_clock.gd and jump days ahead in a millisecond.
## Days are the child's LOCAL calendar days ("2026-12-03"), because a lantern lights per day played.
class_name GameClock
extends RefCounted

const SECONDS_PER_DAY: int = 86400


## Seconds since the Unix epoch (UTC).
func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


## The local time zone's offset from UTC, in minutes (e.g. -300 for UTC-5).
func utc_offset_minutes() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))


## The child's calendar day today, "YYYY-MM-DD".
func today() -> String:
	return day_of(now_unix())


## The local calendar day of a Unix time.
func day_of(unix: int) -> String:
	return Time.get_date_string_from_unix_time(unix + utc_offset_minutes() * 60)


## An ISO 8601 UTC timestamp, e.g. "2026-12-03T21:10:00Z" (the save and attempt-log format).
func now_iso() -> String:
	return Time.get_datetime_string_from_unix_time(now_unix()) + "Z"


## The day `days` after `day` ("2026-12-30" + 3 is "2027-01-02"). Pure date arithmetic.
static func add_days(day: String, days: int) -> String:
	var noon: int = Time.get_unix_time_from_datetime_string(day + "T12:00:00")
	return Time.get_date_string_from_unix_time(noon + days * SECONDS_PER_DAY)


## Whole days from `from_day` to `to_day` (negative if to_day is earlier).
static func days_between(from_day: String, to_day: String) -> int:
	var start: int = Time.get_unix_time_from_datetime_string(from_day + "T12:00:00")
	var end: int = Time.get_unix_time_from_datetime_string(to_day + "T12:00:00")
	return roundi(float(end - start) / float(SECONDS_PER_DAY))
