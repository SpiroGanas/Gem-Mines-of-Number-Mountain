# Mirrors the fitted-parameter loading in scripts/adaptive/bkt.gd and AdaptiveEngine.params_for():
# a skill's fitted values (tools/bkt/fit.py -> curriculum/bkt_fitted.json) are used from 30 logged
# first tries up, otherwise the defaults of the skill's type stay in charge.
class_name BKTFitLoadingTest
extends GdUnitTestSuite

const SKILL: StringName = &"count.write.numeral"
const FITTED: Dictionary = {
	"prior": 0.11, "learn": 0.33, "guess": 0.07, "slip": 0.04, "n": 30, "right": 20,
}

var _path: String = "user://test_bkt_fitted.json"


func after_test() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_a_missing_file_means_no_fit_yet() -> void:
	assert_dict(BKT.load_fitted("user://no_such_fitted_file.json")).is_empty()


func test_the_shipped_file_starts_with_no_fitted_skills() -> void:
	# No real log has been fitted yet; a fit is committed with its date in docs/decisions.md.
	var data: Variant = JsonUtil.parse_file(BKT.FITTED_PATH)
	assert_bool(data is Dictionary).is_true()
	assert_int(int(data["schema_version"])).is_equal(1)
	assert_dict(BKT.load_fitted()).is_equal(data["skills"])


func test_a_file_without_skills_is_ignored() -> void:
	_write('{"schema_version": 1}')
	assert_dict(BKT.load_fitted(_path)).is_empty()
	_write("not json")
	assert_dict(BKT.load_fitted(_path)).is_empty()


func test_the_fitted_skills_are_loaded() -> void:
	_write(JSON.stringify({"schema_version": 1, "skills": {String(SKILL): FITTED}}))
	var loaded: Dictionary = BKT.load_fitted(_path)
	assert_float(loaded[String(SKILL)]["learn"]).is_equal_approx(0.33, 0.0001)


func test_below_the_sample_floor_the_defaults_are_used() -> void:
	var defaults: Dictionary = BKT.load_defaults()
	var thin: Dictionary = FITTED.duplicate()
	thin["n"] = BKT.MIN_FITTED_SAMPLES - 1
	var params: Dictionary = BKT.params_for_skill(defaults, {String(SKILL): thin}, SKILL, &"default")
	assert_dict(params).is_equal(BKT.params_for(defaults, &"default"))


func test_at_the_sample_floor_the_fitted_values_win_but_hint_weight_and_fluency_stay() -> void:
	var defaults: Dictionary = BKT.load_defaults()
	var params: Dictionary = BKT.params_for_skill(defaults, {String(SKILL): FITTED}, SKILL, &"fact")
	assert_float(params["prior"]).is_equal_approx(0.11, 0.0001)
	assert_float(params["learn"]).is_equal_approx(0.33, 0.0001)
	assert_float(params["guess"]).is_equal_approx(0.07, 0.0001)
	assert_float(params["slip"]).is_equal_approx(0.04, 0.0001)
	assert_int(params["fluency_ms"]).is_equal(8000)
	assert_float(params["hint_weight"]).is_equal_approx(0.5, 0.0001)


func test_other_skills_keep_their_type_defaults() -> void:
	var defaults: Dictionary = BKT.load_defaults()
	var params: Dictionary = BKT.params_for_skill(defaults, {String(SKILL): FITTED}, &"cmp.to_20.more_less", &"concept")
	assert_dict(params).is_equal(BKT.params_for(defaults, &"concept"))


func test_the_engine_starts_a_skill_at_its_fitted_prior_and_learns_at_its_fitted_rate() -> void:
	var catalog: SkillCatalog = SkillCatalog.load_all()
	var defaults: Dictionary = BKT.load_defaults()
	var plain: AdaptiveEngine = AdaptiveEngine.new(catalog, defaults, FakeClock.new())
	var tuned: AdaptiveEngine = AdaptiveEngine.new(catalog, defaults, FakeClock.new(), [], {String(SKILL): FITTED})
	var type_prior: float = float(plain.record_for(SKILL)["p_learned"])
	assert_bool(absf(type_prior - 0.11) > 0.001).is_true()
	assert_float(float(tuned.record_for(SKILL)["p_learned"])).is_equal_approx(0.11, 0.0001)
	tuned.record_answer(SKILL, true, 0, 0.05, 3000)
	plain.record_answer(SKILL, true, 0, 0.05, 3000)
	var expected: float = BKT.update(0.11, true, BKT.with_chance(tuned.params_for(SKILL), 0.05))
	assert_float(float(tuned.skills()[String(SKILL)]["p_learned"])).is_equal_approx(expected, 0.0001)
	assert_bool(absf(float(tuned.skills()[String(SKILL)]["p_learned"]) - float(plain.skills()[String(SKILL)]["p_learned"])) > 0.001).is_true()
