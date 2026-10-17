# Every Zone 1 skill: 10,000 seeded problems each must satisfy the shared invariants
# (Phase 1 plan: "10,000 seeded problems per generator in GdUnit4").
class_name Zone1GeneratorsTest
extends GdUnitTestSuite

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _check(skill_id: StringName) -> void:
	var skill: Skill = _catalog.skill(skill_id)
	assert_object(skill).is_not_null()
	var errors: Array[String] = GeneratorChecks.run(skill, GeneratorChecks.ZONE1_SEEDS, _allowed)
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_count_to_20_objects() -> void:
	_check(&"count.to_20.objects")


func test_count_to_120_read() -> void:
	_check(&"count.to_120.read")


func test_count_to_120_next() -> void:
	_check(&"count.to_120.next")


func test_count_to_120_between() -> void:
	_check(&"count.to_120.between")


func test_count_to_120_fill_strip() -> void:
	_check(&"count.to_120.fill_strip")


func test_count_write_numeral() -> void:
	_check(&"count.write.numeral")


func test_cmp_to_20_more_less() -> void:
	_check(&"cmp.to_20.more_less")


func test_cmp_to_100_symbols() -> void:
	_check(&"cmp.to_100.symbols")


func test_cmp_to_100_order3() -> void:
	_check(&"cmp.to_100.order3")


func test_pv_tens_ones_build() -> void:
	_check(&"pv.tens_ones.build")


func test_pv_tens_ones_read() -> void:
	_check(&"pv.tens_ones.read")


func test_pv_tens_ones_expanded() -> void:
	_check(&"pv.tens_ones.expanded")


func test_pv_tens_ones_digit_value() -> void:
	_check(&"pv.tens_ones.digit_value")


func test_pv_regroup_trade_ten() -> void:
	_check(&"pv.regroup.trade_ten")


func test_pv_regroup_untrade() -> void:
	_check(&"pv.regroup.untrade")


func test_pv_tens_ten_more_less() -> void:
	_check(&"pv.tens.ten_more_less")


func test_pv_hundred_intro() -> void:
	_check(&"pv.hundred.intro")


func test_every_zone_1_skill_has_a_test_above() -> void:
	var tested: Array[StringName] = []
	for method: Dictionary in get_script().get_script_method_list():
		if String(method["name"]).begins_with("test_") and method["name"] != "test_every_zone_1_skill_has_a_test_above":
			tested.append(StringName(String(method["name"]).trim_prefix("test_").replace("_", ".")))
	for skill: Skill in _catalog.skills_in_zone(1):
		var key: StringName = StringName(String(skill.id).replace("_", "."))
		assert_bool(tested.has(key)).override_failure_message("no 10,000-problem test for " + skill.id).is_true()
