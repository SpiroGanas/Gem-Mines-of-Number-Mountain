## The parent dashboard's numbers (P1-S09-04), worked out from the attempt log and the save.
## Pure: no files, no autoloads, so tests feed it a fixture log (tests/save/fixtures/).
##
## Time played is counted from the attempt log, so the save needs no extra fields: within a
## session, each answer adds the time since the previous answer, but never more than IDLE_CAP
## seconds (a tablet left on the table is not play); a session's first answer adds its own latency.
## A rock is counted for each correct answer (every rock ends with one).
class_name ProgressReport
extends RefCounted

const IDLE_CAP_SECONDS: int = 120
const SESSIONS_SHOWN: int = 7
const DAYS_IN_WEEK: int = 7


## Unix time of an attempt timestamp such as "2026-12-07T15:04:05Z".
static func unix_of(ts: String) -> int:
	return Time.get_unix_time_from_datetime_string(ts.trim_suffix("Z"))


## Each session in the log, oldest first:
## {session_id, start_ts, day, seconds, answers, rocks, first_tries, first_try_correct}.
## `offset_minutes` turns UTC timestamps into the child's local calendar day.
static func sessions(entries: Array, offset_minutes: int = 0) -> Array[Dictionary]:
	var by_id: Dictionary = {}
	var order: Array[String] = []
	var last_unix: Dictionary = {}
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var id: String = str(entry.get("session_id", ""))
		var unix: int = unix_of(str(entry.get("ts", "")))
		if not by_id.has(id):
			order.append(id)
			by_id[id] = {
				"session_id": id, "start_ts": str(entry.get("ts", "")),
				"day": Time.get_date_string_from_unix_time(unix + offset_minutes * 60),
				"seconds": mini(floori(float(entry.get("latency_ms", 0)) / 1000.0), IDLE_CAP_SECONDS),
				"answers": 0, "rocks": 0, "first_tries": 0, "first_try_correct": 0,
			}
		else:
			by_id[id]["seconds"] += clampi(unix - int(last_unix[id]), 0, IDLE_CAP_SECONDS)
		last_unix[id] = unix
		var session: Dictionary = by_id[id]
		session["answers"] += 1
		if bool(entry.get("correct", false)):
			session["rocks"] += 1
		if int(entry.get("hints_used", 0)) == 0:
			session["first_tries"] += 1
			if bool(entry.get("correct", false)):
				session["first_try_correct"] += 1
	var result: Array[Dictionary] = []
	for id: String in order:
		result.append(by_id[id])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["start_ts"] < b["start_ts"])
	return result


## The last SESSIONS_SHOWN sessions, newest first.
static func recent_sessions(entries: Array, offset_minutes: int = 0) -> Array[Dictionary]:
	var all: Array[Dictionary] = sessions(entries, offset_minutes)
	all.reverse()
	return all.slice(0, SESSIONS_SHOWN)


## Seconds played on `day` (sessions that started that day).
static func seconds_on(entries: Array, day: String, offset_minutes: int = 0) -> int:
	var total: int = 0
	for session: Dictionary in sessions(entries, offset_minutes):
		if session["day"] == day:
			total += int(session["seconds"])
	return total


## Seconds played in the week ending on `today` (today and the six days before it).
static func seconds_this_week(entries: Array, today: String, offset_minutes: int = 0) -> int:
	var first_day: String = GameClock.add_days(today, -(DAYS_IN_WEEK - 1))
	var total: int = 0
	for session: Dictionary in sessions(entries, offset_minutes):
		if session["day"] >= first_day and session["day"] <= today:
			total += int(session["seconds"])
	return total


## Whole minutes, rounded to the nearest (a 20-minute session shows as 20).
static func minutes(seconds: int) -> int:
	return roundi(float(seconds) / 60.0)


## Percent of first tries answered right (0 with none).
static func first_try_percent(session: Dictionary) -> int:
	if int(session["first_tries"]) == 0:
		return 0
	return roundi(100.0 * float(session["first_try_correct"]) / float(session["first_tries"]))
