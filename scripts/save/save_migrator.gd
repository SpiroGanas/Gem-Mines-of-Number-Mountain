## Upgrades an older save to the current schema, one version step at a time.
##
## A migration is a static function taking a save Dictionary at version N and returning
## it at version N + 1, kept in its own file under scripts/save/migrations/ (for example
## v1_to_v2.gd with `static func apply(data: Dictionary) -> Dictionary`) and registered in
## default_migrations() below. Version 1 is the baseline (the MVP).
##
## Every migration needs a fixture of the old version in tests/save/fixtures/ and a test
## that loads it (tests/save/test_save_migrator.gd walks that folder).
class_name SaveMigrator
extends RefCounted

const ERR_NONE: String = ""
const ERR_NO_VERSION: String = "no_version"
const ERR_NEWER_VERSION: String = "newer_version"
const ERR_MISSING_MIGRATION: String = "missing_migration"


## Registered migrations: from-version (int) -> Callable(data: Dictionary) -> Dictionary.
static func default_migrations() -> Dictionary:
	return {1: SaveMigrationV1ToV2.apply, 2: SaveMigrationV2ToV3.apply}


## Returns {ok: bool, data: Dictionary, from_version: int, error: String}.
## A save from a newer build is refused (ok = false, error = "newer_version") so an older
## app never overwrites progress it does not understand. `migrations` is injectable for tests.
static func migrate(data: Dictionary, migrations: Dictionary = default_migrations()) -> Dictionary:
	var raw_version: Variant = data.get("schema_version")
	if not (raw_version is int or raw_version is float):
		return _result(false, data, 0, ERR_NO_VERSION)
	var from_version: int = int(raw_version)
	if from_version > SaveSchema.CURRENT_VERSION:
		return _result(false, data, from_version, ERR_NEWER_VERSION)
	var current: Dictionary = data.duplicate(true)
	var version: int = from_version
	while version < SaveSchema.CURRENT_VERSION:
		if not migrations.has(version):
			return _result(false, data, from_version, ERR_MISSING_MIGRATION)
		var step: Callable = migrations[version]
		current = step.call(current)
		version += 1
		current["schema_version"] = version
	return _result(true, current, from_version, ERR_NONE)


static func _result(ok: bool, data: Dictionary, from_version: int, error: String) -> Dictionary:
	return {"ok": ok, "data": data, "from_version": from_version, "error": error}
