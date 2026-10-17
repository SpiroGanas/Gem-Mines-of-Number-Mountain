## Bolt's Garage (P1-S08-03): spend coins on the big pickaxe and Bolt's headlamp colors. Coins only,
## never real money, and nothing here can be lost. A bought headlamp goes on straight away; an
## owned one can be put back on at any time. The big pickaxe makes every crack bigger.
class_name GarageScreen
extends ShellScreen

const ROW_BUTTON_WIDTH_MULTIPLE: float = 4.0
const ITEMS: Array[Dictionary] = [
	{"id": &"headlamp_blue", "name": &"hub.garage.lamp_blue", "lamp": "blue"},
	{"id": &"headlamp_green", "name": &"hub.garage.lamp_green", "lamp": "green"},
	{"id": &"headlamp_gold", "name": &"hub.garage.lamp_gold", "lamp": "gold"},
	{"id": &"pickaxe_t2", "name": &"hub.garage.pickaxe_t2", "info": &"hub.garage.pickaxe_t2_info"},
]

var _bolt: Bolt
var _coins_label: Label
var _buttons: Dictionary[StringName, Button] = {}
var _back_button: Button
var _sfx: SfxBank


func _ready() -> void:
	super()
	_sfx = SfxBank.new()
	add_child(_sfx)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 24)
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = Text.get_line(&"ui.common.back")
	UI.make_touch_target(_back_button, 2.5, 1.2)
	_back_button.pressed.connect(request_screen.emit.bind(&"hub", {}))
	header.add_child(_back_button)
	var title: Label = Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.text = Text.get_line(&"hub.garage.title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	_coins_label = Label.new()
	header.add_child(_coins_label)
	_bolt = load("res://scenes/mine/bolt.tscn").instantiate()
	column.add_child(_bolt)
	_bolt.say(&"hub.garage.hello")
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 16)
	column.add_child(list)
	for item: Dictionary in ITEMS:
		list.add_child(_make_row(item))
	Rewards.coins_changed.connect(func(_total: int) -> void: _refresh())
	Rewards.headlamp_changed.connect(func(_color: String) -> void: _refresh())
	_refresh()


## The action button of an item's row (buy / use), for tests.
func item_button(id: StringName) -> Button:
	return _buttons[id]


func _make_row(item: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	var art: Control
	if item.has("lamp"):
		var lamp: _LampSwatch = _LampSwatch.new()
		lamp.color = Bolt.lamp_color(item["lamp"])
		art = lamp
	else:
		var gem: GemArt = GemArt.new()
		gem.gem_type = GemArt.PYRITE
		art = gem
	art.custom_minimum_size = UI.target_size(1.2, 1.2)
	row.add_child(art)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var name_label: Label = Label.new()
	name_label.text = Text.get_line(item["name"])
	words.add_child(name_label)
	if item.has("info"):
		var info: Label = Label.new()
		info.text = Text.get_line(item["info"])
		words.add_child(info)
	var button: Button = Button.new()
	button.name = "Item_%s" % item["id"]
	UI.make_touch_target(button, ROW_BUTTON_WIDTH_MULTIPLE, 1.25)
	button.pressed.connect(_on_item_pressed.bind(item))
	row.add_child(button)
	_buttons[item["id"]] = button
	return row


func _refresh() -> void:
	_coins_label.text = Text.get_line(&"ui.hub.coins", {"n": Rewards.coins()})
	for item: Dictionary in ITEMS:
		var button: Button = _buttons[item["id"]]
		if item.has("lamp"):
			var owned: bool = RewardsRules.has_headlamp(Rewards.data(), item["lamp"])
			if Rewards.headlamp() == item["lamp"]:
				button.text = Text.get_line(&"ui.garage.in_use")
				button.disabled = true
			elif owned:
				button.text = Text.get_line(&"ui.garage.use")
				button.disabled = false
			else:
				_show_price(button, item["id"])
		elif Rewards.owns(item["id"]):
			button.text = Text.get_line(&"ui.garage.owned")
			button.disabled = true
		else:
			_show_price(button, item["id"])


func _show_price(button: Button, id: StringName) -> void:
	var price: int = RewardsRules.price_of(id)
	if Rewards.can_buy(id):
		button.text = Text.get_line(&"ui.garage.buy", {"n": price})
		button.disabled = false
	else:
		button.text = Text.get_line(&"ui.garage.need", {"n": maxi(price - Rewards.coins(), 0)})
		button.disabled = true


func _on_item_pressed(item: Dictionary) -> void:
	if item.has("lamp") and RewardsRules.has_headlamp(Rewards.data(), item["lamp"]):
		_sfx.play(&"tap")
		Rewards.set_headlamp(item["lamp"])
	elif Rewards.buy(item["id"]):
		_sfx.play(&"buy")
	_refresh()


## A round swatch of a headlamp's light.
class _LampSwatch extends Control:
	var color: Color = Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.42, Color(color, 0.35))
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.26, color)
