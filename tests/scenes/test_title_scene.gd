# Smoke test: the placeholder title scene loads and instantiates.
# Mirrors scenes/shell/title.tscn. Replaced by shell tests in Phase 1, Sprint 3.
class_name TitleSceneTest
extends GdUnitTestSuite


func test_title_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/shell/title.tscn")
	assert_object(scene).is_not_null()
	var title: Control = auto_free(scene.instantiate())
	assert_object(title).is_instanceof(Control)
	assert_str(title.name).is_equal("Title")
	assert_object(title.get_node("CenterContainer/TitleLabel")).is_instanceof(Label)


func test_project_is_landscape_with_pinned_engine_features() -> void:
	var features: PackedStringArray = ProjectSettings.get_setting("application/config/features")
	assert_bool(features.has("4.7")).is_true()
	assert_bool(features.has("GL Compatibility")).is_true()
	assert_str(ProjectSettings.get_setting("display/window/stretch/mode")).is_equal("canvas_items")
