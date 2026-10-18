# Mirrors scripts/save/save_merge.gd (Sprint 17): newer wins, older asks, the same moment keeps this
# device's save, and a save with no saved time is refused.
class_name SaveMergeTest
extends GdUnitTestSuite


func _save(updated_at: Variant) -> Dictionary:
	var save: Dictionary = SaveSchema.new_profile("2027-01-01T00:00:00Z")
	if updated_at == null:
		save.erase("updated_at")
	else:
		save["updated_at"] = updated_at
	return save


func test_a_newer_import_replaces() -> void:
	assert_that(SaveMerge.choose(_save("2027-03-08T10:00:00Z"), _save("2027-03-09T08:00:00Z"))["action"]).is_equal(SaveMerge.REPLACE)


func test_an_older_import_asks_the_parent() -> void:
	assert_that(SaveMerge.choose(_save("2027-03-09T08:00:00Z"), _save("2027-03-08T10:00:00Z"))["action"]).is_equal(SaveMerge.ASK)


func test_equal_timestamps_keep_this_devices_save() -> void:
	assert_that(SaveMerge.choose(_save("2027-03-09T08:00:00Z"), _save("2027-03-09T08:00:00Z"))["action"]).is_equal(SaveMerge.KEEP)


func test_a_missing_or_broken_saved_time_is_refused() -> void:
	for bad: Variant in [null, "", "yesterday", 12345, "2027/03/09 08:00"]:
		assert_that(SaveMerge.choose(_save("2027-03-09T08:00:00Z"), _save(bad))["action"]).override_failure_message(str(bad)).is_equal(SaveMerge.REFUSE)


func test_a_local_save_with_no_time_takes_any_valid_import() -> void:
	assert_that(SaveMerge.choose(_save(null), _save("2027-03-09T08:00:00Z"))["action"]).is_equal(SaveMerge.REPLACE)


func test_seconds_decide() -> void:
	assert_that(SaveMerge.choose(_save("2027-03-09T08:00:00Z"), _save("2027-03-09T08:00:01Z"))["action"]).is_equal(SaveMerge.REPLACE)
