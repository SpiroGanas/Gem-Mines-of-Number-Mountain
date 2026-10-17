## The progress bundle a parent exports from the parent area to move progress between devices or
## to share play logs (CLAUDE.md rule 2: nothing leaves the device unless a parent does this).
## One JSON file holds the profile and the whole attempt log. Pure functions; SaveSystem does the
## file work.
##
##   {"format": "gem-mines-progress", "bundle_version": 1, "exported_at": "...Z",
##    "device_id": "...", "checksum": "sha256...",
##    "profile": {...the save...}, "attempts": [{...attempts.jsonl lines...}]}
##
## Importing: SaveMerge decides (the newer profile wins; an older one waits for the parent's choice)
## and the replaced one is backed up; the attempt logs are merged, each attempt once. The checksum
## (Sprint 17) catches a file changed or cut short after export; a bundle without one (exported
## before Sprint 17) is still accepted.
class_name ProgressBundle
extends RefCounted

const FORMAT: String = "gem-mines-progress"
const VERSION: int = 1
const ERR_NOT_A_BUNDLE: String = "not_a_bundle"
const ERR_NEWER_BUNDLE: String = "newer_bundle"
const ERR_BAD_PROFILE: String = "bad_profile"
const ERR_CHECKSUM: String = "checksum"


static func make(profile: Dictionary, attempts: Array, now_iso: String, device_id: String = "") -> Dictionary:
	var bundle: Dictionary = {"format": FORMAT, "bundle_version": VERSION, "exported_at": now_iso, "device_id": device_id, "profile": profile.duplicate(true), "attempts": attempts.duplicate(true)}
	bundle["checksum"] = checksum_of(bundle)
	return bundle


## SHA-256 of the profile and the attempts. Both are first put through JSON and back, so the sum is
## the same before writing (ints) and after reading (JSON numbers come back as floats).
static func checksum_of(bundle: Dictionary) -> String:
	var body: Variant = JSON.parse_string(JSON.stringify({"attempts": bundle.get("attempts", []), "profile": bundle.get("profile", {})}, "", false, true))
	return JSON.stringify(body, "", true, true).sha256_text()


## The file name an export suggests: gem-mines-progress-<device>-<yyyymmdd-hhmmss>.json.
static func file_name(device_id: String, now_iso: String) -> String:
	var stamp: String = now_iso.replace("-", "").replace(":", "").replace("T", "-").trim_suffix("Z")
	return "gem-mines-progress-%s-%s.json" % [device_id.substr(0, 8), stamp]


## "" when the bundle can be imported, otherwise why not.
static func problem_with(bundle: Variant) -> String:
	if not bundle is Dictionary or bundle.get("format") != FORMAT:
		return ERR_NOT_A_BUNDLE
	if int(bundle.get("bundle_version", 0)) > VERSION:
		return ERR_NEWER_BUNDLE
	if not bundle.get("profile") is Dictionary or not bundle.get("attempts") is Array:
		return ERR_NOT_A_BUNDLE
	if bundle.has("checksum") and str(bundle["checksum"]) != checksum_of(bundle):
		return ERR_CHECKSUM
	if not SaveSchema.validate(bundle["profile"]).is_empty():
		return ERR_BAD_PROFILE
	return ""


## True when `theirs` was saved after `ours` (ISO 8601 UTC strings compare in time order).
static func is_newer(theirs: Dictionary, ours: Dictionary) -> bool:
	return str(theirs.get("updated_at", "")) > str(ours.get("updated_at", ""))


## Both logs together, each attempt once, oldest first.
static func merge_attempts(ours: Array, theirs: Array) -> Array:
	var seen: Dictionary = {}
	var merged: Array = []
	for entry: Variant in ours + theirs:
		if not entry is Dictionary:
			continue
		var key: String = "%s|%s|%s|%s|%s|%s" % [entry.get("ts"), entry.get("session_id"), entry.get("skill_id"), entry.get("problem_seed"), entry.get("hints_used"), entry.get("correct")]
		if seen.has(key):
			continue
		seen[key] = true
		merged.append(entry)
	merged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("ts", "")) < str(b.get("ts", "")))
	return merged
