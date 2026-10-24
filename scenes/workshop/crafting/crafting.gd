## The Workshop (Sprint 16, P2-S16-02): craft tools and lights from gems by answering one problem.
## Each open recipe shows what it makes, the gems it takes and a Craft button. Craft asks a real
## problem of the recipe's skill under Bolt (ProblemCard, so the answer is learning evidence); a right
## answer spends the gems and makes the thing, a not-quite answer climbs the hint ladder and costs
## nothing. A recipe is made once. Recipes appear as their skill opens (curriculum/recipes.json).
##
## The screen shares its room like the mine's rooms (scenes/mine/mine.gd), so nothing leaves it:
##   LIST     the recipes on the left, Bolt on the right (the designed layout).
##   STACKED  Bolt above the recipes, both the whole width: the two do not fit side by side (a dense
##            tablet screen, where every target is bigger on the canvas).
##   FOCUS    a recipe's problem is up: the recipes step aside, like the mine's wall, and Bolt and the
##            problem take the whole width; the title names what is being made.
##   BESIDE   as FOCUS, and Bolt talks from the left column, where the recipes were, so the problem gets
##            the whole height (the slate with hint lines on a phone or a dense tablet). Only where the
##            two fit side by side; otherwise the problem keeps the whole width. Bolt's column scrolls
##            if his narrow bubble runs longer than the screen: the answer input never does.
## Wherever Bolt spans the width his Word Gem chips sit beside his line, so his bubble stays short; in
## BESIDE they go under it, and his line wraps narrow there, as on a phone. A recipe row narrows too:
## its words wrap and its second kind of gem moves to a new line. _check_room() measures each layout
## once it has settled and steps up only, so the screen cannot flip back and forth.
class_name CraftingScreen
extends WorkshopScreen

enum Room { LIST, STACKED, FOCUS, BESIDE }

const ROW_BUTTON_WIDTH_MULTIPLE: float = 3.5

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _scroll: ScrollContainer
## Bolt's place in BESIDE.
var _bolt_scroll: ScrollContainer
var _list: VBoxContainer
var _buttons: Dictionary[StringName, Button] = {}
var _card: ProblemCard
var _crafting: StringName = &""
## LIST, or STACKED once the recipes and Bolt were found not to fit side by side (_check_room).
var _list_room: Room = Room.LIST
## FOCUS, or BESIDE once the open problem was found short of height (_check_room).
var _problem_room: Room = Room.FOCUS
## BESIDE was too wide for this screen: the open problem stays in FOCUS.
var _beside_tried: bool = false
## The room on screen now (_fit_screen); _check_room() measures only a layout that is on screen.
var _laid_out: Room = Room.LIST
var _body_ratio: float
var _gap: int
## Tests fix the seed so the problems repeat; 0 means a different problem each time.
var seed_value: int = 0


func _ready() -> void:
	super()
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	build_frame(&"ws.bench.title")
	_body_ratio = body.size_flags_stretch_ratio
	_gap = columns.get_theme_constant(&"separation")
	bolt_node.allow_chips_beside()
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 16)
	_scroll = UI.vertical_scroll(_list)
	body.add_child(_scroll)
	_bolt_scroll = ScrollContainer.new()
	_bolt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bolt_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_bolt_scroll)
	bolt_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL # fills the scroll's width in BESIDE
	_card = make_card()
	_card.solved.connect(_on_solved)
	_card.missed.connect(_on_missed)
	celebration.closed.connect(_rebuild)
	UI.metrics_changed.connect(_on_metrics_changed)
	_rebuild()


## The Craft button of a recipe's row, for tests (null when the recipe is not shown).
func craft_button(id: StringName) -> Button:
	return _buttons.get(id)


func card() -> ProblemCard:
	return _card


## The recipe whose problem is on screen (&"" when none).
func crafting() -> StringName:
	return _crafting


## How the screen is laid out now (Room), for tests.
func room() -> Room:
	return _problem_room if _crafting != &"" else _list_room


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
	_fit_screen()
	_check_room()


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
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(name_label)
	var info: Label = Label.new()
	info.text = Text.get_line(recipe.info_line_id)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(info)
	# Each gem stays beside its count; a second kind of gem flows to a new line in a narrow column.
	var cost: HFlowContainer = HFlowContainer.new()
	cost.add_theme_constant_override(&"h_separation", 16)
	cost.add_theme_constant_override(&"v_separation", 8)
	words.add_child(cost)
	for input: Dictionary in recipe.inputs:
		var item: HBoxContainer = HBoxContainer.new()
		item.add_theme_constant_override(&"separation", 8)
		cost.add_child(item)
		var gem: GemArt = GemArt.new()
		gem.gem_type = input["gem"]
		gem.custom_minimum_size = UI.target_size(0.6, 0.6)
		item.add_child(gem)
		var count: Label = Label.new()
		count.text = Text.get_line(&"ws.recipe.gem_count", {"n": int(input["count"]), "have": Rewards.gem_count(input["gem"])})
		item.add_child(count)
	var button: Button = Button.new()
	button.name = "Craft_%s" % recipe.id
	UI.make_touch_target(button, ROW_BUTTON_WIDTH_MULTIPLE, 1.2)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # "Dig for more gems" takes two lines, not more width
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


## Lays the screen out for its room (see the notes at the top). Runs when the list is rebuilt, when a
## problem opens, when the room steps up and when the window changes.
func _fit_screen() -> void:
	var current: Room = room()
	var problem_up: bool = _crafting != &""
	_scroll.visible = not problem_up
	_card.visible = problem_up # an answered problem does not stay under Bolt
	var bolt_home: Container = _bolt_scroll if current == Room.BESIDE else side
	if bolt_node.get_parent() != bolt_home:
		bolt_node.reparent(bolt_home, false)
	if bolt_home == side:
		side.move_child(bolt_node, 0)
	_bolt_scroll.visible = current == Room.BESIDE
	var scroll_home: VBoxContainer = body if current == Room.LIST else side
	if _scroll.get_parent() != scroll_home:
		_scroll.reparent(scroll_home, false)
	if current == Room.STACKED:
		side.move_child(_scroll, bolt_node.get_index() + 1)
	# The left column holds the recipes (LIST) or Bolt (BESIDE). On a phone it also heads the screen
	# (Back, the title, the coins), so there it stays in the other rooms, only as wide as the header.
	var left_used: bool = current == Room.LIST or current == Room.BESIDE
	body.visible = left_used or UI.is_compact()
	body.size_flags_stretch_ratio = _body_ratio if left_used else 0.0
	# Beside the problem Bolt's bubble is its own edge: a narrower gap leaves the problem more width.
	columns.add_theme_constant_override(&"separation", _gap if current != Room.BESIDE else UI.spacing(16))
	# Where Bolt spans the screen his Word Gem chips sit beside his line: a shorter bubble leaves the
	# problem more height. A phone has them there in every room but BESIDE, as in the mine.
	var wide_bolt: bool = current == Room.STACKED or current == Room.FOCUS
	bolt_node.set_chips_beside(wide_bolt or (current == Room.LIST and UI.is_compact()))
	bolt_node.set_narrow_line(current == Room.BESIDE)
	title_label.text = Text.get_line(Rewards.recipe(_crafting).name_line_id if problem_up else &"ws.bench.title")
	_laid_out = current


## After the layout has settled, steps up where it does not fit: the recipes beside Bolt too wide ->
## STACKED; the problem too tall -> BESIDE, and back to FOCUS for good if Bolt beside it is too wide
## (the problem then keeps the whole width). Runs after anything that changes the layout or what is
## on screen; a window change starts over (_on_metrics_changed).
func _check_room() -> void:
	for frame: int in 2:
		await get_tree().process_frame
	var before: Room = room()
	if not is_inside_tree() or before != _laid_out: # a solved problem waits under the celebration
		return
	var over: Vector2 = overflow()
	match before:
		Room.LIST:
			if over.x > 1.0:
				_list_room = Room.STACKED
		Room.FOCUS:
			if over.y > 1.0 and not _beside_tried:
				_problem_room = Room.BESIDE
				_beside_tried = true
		Room.BESIDE:
			if over.x > 1.0:
				_problem_room = Room.FOCUS
	if room() != before:
		_fit_screen()
		_check_room()


## The window changed (a posture switch, a Chromebook window resize): the rooms start over.
func _on_metrics_changed() -> void:
	_list_room = Room.LIST
	_problem_room = Room.FOCUS
	_beside_tried = false
	_fit_screen()
	_check_room()


## A not-quite answer: Bolt's feedback lines and the hint can leave the problem short of height.
func _on_missed(_rung: HintLadder.Rung) -> void:
	sfx.play(&"soft_miss")
	_check_room()


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
	_problem_room = Room.FOCUS
	_beside_tried = false
	_fit_screen()
	_card.show_problem(problem, _rng)
	bolt_node.add_note(&"ws.bolt.craft_ask", {})
	_check_room()


func _on_solved(_problem: Problem) -> void:
	var id: StringName = _crafting
	_crafting = &""
	if Rewards.craft(id):
		sfx.play(&"craft")
		var recipe: Recipe = Rewards.recipe(id)
		celebration.celebrate([{"line_id": &"ws.craft.done", "gem": recipe.inputs[0]["gem"]}])
	else:
		_rebuild()
