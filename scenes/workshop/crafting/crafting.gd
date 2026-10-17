## The Workshop (Sprint 16, P2-S16-02): craft tools and lights from gems by answering one problem.
## Each open recipe shows what it makes, the gems it takes and a Craft button. Craft asks a real
## problem of the recipe's skill under Bolt (ProblemCard, so the answer is learning evidence); a right
## answer spends the gems and makes the thing, a not-quite answer climbs the hint ladder and costs
## nothing. A recipe is made once. Recipes appear as their skill opens (curriculum/recipes.json).
class_name CraftingScreen
extends WorkshopScreen

const ROW_BUTTON_WIDTH_MULTIPLE: float = 3.5

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _list: VBoxContainer
var _buttons: Dictionary[StringName, Button] = {}
var _card: ProblemCard
var _crafting: StringName = &""
## Tests fix the seed so the problems repeat; 0 means a different problem each time.
var seed_value: int = 0


func _ready() -> void:
	super()
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	build_frame(&"ws.bench.title")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 16)
	scroll.add_child(_list)
	_card = make_card()
	_card.solved.connect(_on_solved)
	_card.missed.connect(func(_rung: HintLadder.Rung) -> void: sfx.play(&"soft_miss"))
	celebration.closed.connect(_rebuild)
	_rebuild()


## The Craft button of a recipe's row, for tests (null when the recipe is not shown).
func craft_button(id: StringName) -> Button:
	return _buttons.get(id)


func card() -> ProblemCard:
	return _card


## The recipe whose problem is on screen (&"" when none).
func crafting() -> StringName:
	return _crafting


func _rebuild() -> void:
	refresh_coins()
	for child: Node in _list.get_children():
		child.queue_free()
		_list.remove_child(child)
	_buttons.clear()
	var open: Array[Recipe] = Rewards.open_recipes()
	if _crafting == &"":
		var terms: Array[StringName] = []
		if not open.is_empty():
			terms.append(&"recipe")
		bolt_node.set_terms(terms)
		bolt_node.say(&"ws.bolt.hello" if not open.is_empty() else &"ws.bolt.nothing_yet")
	for recipe: Recipe in open:
		_list.add_child(_make_row(recipe))


func _make_row(recipe: Recipe) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	panel.add_child(row)
	var art: WorkshopArt = WorkshopArt.new()
	art.custom_minimum_size = UI.target_size(1.3, 1.3)
	art.show_kind(recipe.output_id)
	row.add_child(art)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var name_label: Label = Label.new()
	name_label.text = Text.get_line(recipe.name_line_id)
	words.add_child(name_label)
	var info: Label = Label.new()
	info.text = Text.get_line(recipe.info_line_id)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(info)
	var cost: HBoxContainer = HBoxContainer.new()
	cost.add_theme_constant_override(&"separation", 8)
	words.add_child(cost)
	for input: Dictionary in recipe.inputs:
		var gem: GemArt = GemArt.new()
		gem.gem_type = input["gem"]
		gem.custom_minimum_size = UI.target_size(0.6, 0.6)
		cost.add_child(gem)
		var count: Label = Label.new()
		count.text = Text.get_line(&"ws.recipe.gem_count", {"n": int(input["count"]), "have": Rewards.gem_count(input["gem"])})
		cost.add_child(count)
	var button: Button = Button.new()
	button.name = "Craft_%s" % recipe.id
	UI.make_touch_target(button, ROW_BUTTON_WIDTH_MULTIPLE, 1.2)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if Rewards.is_crafted(recipe.id):
		button.text = Text.get_line(&"ws.recipe.made")
		button.disabled = true
	elif Rewards.can_craft(recipe.id):
		button.text = Text.get_line(&"ws.recipe.craft")
		button.disabled = _crafting != &""
	else:
		button.text = Text.get_line(&"ws.recipe.need_gems")
		button.disabled = true
	button.pressed.connect(_on_craft_pressed.bind(recipe.id))
	row.add_child(button)
	_buttons[recipe.id] = button
	return panel


func _on_craft_pressed(id: StringName) -> void:
	if not Rewards.can_craft(id) or _crafting != &"":
		return
	sfx.play(&"select")
	_crafting = id
	var recipe: Recipe = Rewards.recipe(id)
	var skill: Skill = Adaptive.catalog().skill(recipe.skill_id)
	var overrides: Dictionary = {"representation": Adaptive.engine.scheduler.representation_for(skill, Adaptive.engine.record_for(skill.id), false)}
	overrides.merge(recipe.params, true)
	var problem: Problem = GeneratorRegistry.make_problem(skill, _rng.randi(), overrides)
	for button: Button in _buttons.values():
		button.disabled = true
	_card.show_problem(problem, _rng)
	bolt_node.add_note(&"ws.bolt.craft_ask", {})


func _on_solved(_problem: Problem) -> void:
	var id: StringName = _crafting
	_crafting = &""
	if Rewards.craft(id):
		sfx.play(&"craft")
		var recipe: Recipe = Rewards.recipe(id)
		celebration.celebrate([{"line_id": &"ws.craft.done", "gem": recipe.inputs[0]["gem"]}])
	else:
		_rebuild()
