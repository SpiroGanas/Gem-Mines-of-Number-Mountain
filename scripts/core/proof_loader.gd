## Loads the guided proofs of Zone 12 from curriculum/proofs/*.json into Proof objects, and refuses a file that
## cannot be used: an unknown schema_version, a repeated step id, a step that depends on a step that does not come
## before it, a reason chip that is not in the file's list, or a decoy without a named mistake.
class_name ProofLoader
extends RefCounted

const FOLDER: String = "res://curriculum/proofs/"
const SCHEMA_VERSION: int = 1

static var _cache: Dictionary = {}


## The proof with this id (for example &"proof.euclid.infinite_primes"), or null when there is none.
static func load_by_id(proof_id: StringName) -> Proof:
	if _cache.is_empty():
		for found: Proof in load_all():
			_cache[found.id] = found
	return _cache.get(proof_id, null)


## Every valid proof in the folder, in file-name order.
static func load_all() -> Array[Proof]:
	var proofs: Array[Proof] = []
	for file_name: String in file_names():
		var parsed: Dictionary = parse(JsonUtil.parse_file(FOLDER + file_name))
		if parsed["proof"] != null:
			proofs.append(parsed["proof"])
		else:
			push_error("ProofLoader: %s: %s" % [file_name, parsed["errors"]])
	return proofs


static func file_names() -> Array[String]:
	var names: Array[String] = []
	for file_name: String in DirAccess.get_files_at(FOLDER):
		if file_name.ends_with(".json"):
			names.append(file_name)
	names.sort()
	return names


## {proof: Proof or null, errors: Array[String]} from one parsed JSON document.
static func parse(data: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not data is Dictionary:
		return {"proof": null, "errors": ["not a JSON object"]}
	var doc: Dictionary = JsonUtil.intify(data)
	if int(doc.get("schema_version", -1)) != SCHEMA_VERSION:
		return {"proof": null, "errors": ["unknown schema_version %s" % str(doc.get("schema_version"))]}
	var proof: Proof = Proof.new()
	proof.id = StringName(str(doc.get("id", "")))
	proof.title_line_id = StringName(str(doc.get("title_line_id", "")))
	proof.intro_line_id = StringName(str(doc.get("intro_line_id", "")))
	proof.strict_order = str(doc.get("orderings", "partial")) == "strict"
	proof.scaffold_levels = clampi(int(doc.get("scaffold_levels", 3)), 0, 3)
	for chip: Variant in doc.get("justifications", []):
		proof.justifications.append(StringName(str(chip)))
	var ids: Array[StringName] = []
	for raw: Variant in doc.get("steps", []):
		if not raw is Dictionary:
			errors.append("a step is not an object")
			continue
		var id: StringName = StringName(str(raw.get("id", "")))
		if id == &"" or ids.has(id):
			errors.append("step id '%s' is empty or repeated" % id)
		if not proof.justifications.has(StringName(str(raw.get("justification", "")))):
			errors.append("step %s: its reason is not in the justifications" % id)
		for dep: Variant in raw.get("depends_on", []):
			if not ids.has(StringName(str(dep))):
				errors.append("step %s depends on '%s', which does not come before it" % [id, dep])
		ids.append(id)
		proof.steps.append({
			"id": id, "line_id": StringName(str(raw.get("line_id", ""))),
			"justification": StringName(str(raw.get("justification", ""))),
			"depends_on": raw.get("depends_on", []).duplicate(),
		})
	for raw: Variant in doc.get("decoys", []):
		if not raw is Dictionary:
			errors.append("a decoy is not an object")
			continue
		var id: StringName = StringName(str(raw.get("id", "")))
		if id == &"" or ids.has(id):
			errors.append("decoy id '%s' is empty or repeated" % id)
		if str(raw.get("misconception", "")) == "":
			errors.append("decoy %s has no misconception" % id)
		ids.append(id)
		proof.decoys.append({"id": id, "line_id": StringName(str(raw.get("line_id", ""))), "misconception": StringName(str(raw.get("misconception", "")))})
	if proof.id == &"" or proof.steps.size() < 3:
		errors.append("a proof needs an id and at least 3 steps")
	return {"proof": proof if errors.is_empty() else null, "errors": errors}
