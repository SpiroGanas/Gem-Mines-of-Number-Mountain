## Title screen: the game's name and one big Play button, or, on a device with two to four children
## (Phase 3 profiles), one big avatar tile per child: one tap picks who is playing and starts. No text
## entry. Adding or deleting a child is for grown-ups: the small Grown-ups button goes through the
## parental gate to the profiles page.
## All words come from the text table (rule 4); the tiles show each child's own nickname.
class_name TitleScreen
extends ShellScreen

## The Play button is three touch targets wide: easy to hit from a tablet held at arm's length.
const PLAY_WIDTH_MULTIPLE: float = 3.0
const PLAY_HEIGHT_MULTIPLE: float = 1.5
## A profile tile is a big square-ish target: the avatar plus the name under it.
const TILE_WIDTH_MULTIPLE: float = 3.2
const TILE_HEIGHT_MULTIPLE: float = 3.4

@onready var _title_label: Label = %TitleLabel
@onready var _play_button: Button = %PlayButton

var _tiles: HBoxContainer
var _who_label: Label
var _grownups_button: Button


func _ready() -> void:
	super()
	_title_label.text = Text.get_line(&"ui.title.name")
	_play_button.text = Text.get_line(&"ui.title.play")
	UI.make_touch_target(_play_button, PLAY_WIDTH_MULTIPLE, PLAY_HEIGHT_MULTIPLE)
	var picture: TitleArt = TitleArt.new()
	picture.custom_minimum_size = UI.target_size(8.0, 4.0)
	_title_label.get_parent().add_child(picture)
	_title_label.get_parent().move_child(picture, 0)
	var backdrop: Backdrop = Backdrop.new()
	add_child(backdrop)
	move_child(backdrop, 0)
	_play_button.pressed.connect(_on_play_pressed)
	_add_profile_tiles()
	_add_grownups_button()
	_refresh_tiles()


## The avatar tiles (one per child), in profile order. Empty with a single profile.
func profile_tiles() -> Array[Button]:
	var tiles: Array[Button] = []
	for child: Node in _tiles.get_children():
		tiles.append(child as Button)
	return tiles


func grownups_button() -> Button:
	return _grownups_button


func _add_profile_tiles() -> void:
	var column: VBoxContainer = _play_button.get_parent()
	_who_label = Label.new()
	_who_label.name = "WhoLabel"
	_who_label.text = Text.get_line(&"ui.title.who")
	_who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_who_label)
	_tiles = HBoxContainer.new()
	_tiles.name = "ProfileTiles"
	_tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	_tiles.add_theme_constant_override(&"separation", 40)
	column.add_child(_tiles)


func _refresh_tiles() -> void:
	for child: Node in _tiles.get_children():
		_tiles.remove_child(child)
		child.queue_free()
	var profiles: Array[Profile] = Profiles.list()
	var several: bool = profiles.size() > 1
	_play_button.visible = not several
	_who_label.visible = several
	_tiles.visible = several
	if not several:
		return
	for profile: Profile in profiles:
		_tiles.add_child(_tile(profile))


func _tile(profile: Profile) -> Button:
	var tile: Button = Button.new()
	tile.name = "ProfileTile_%s" % profile.id
	tile.focus_mode = Control.FOCUS_ALL # keyboard players can Tab to a tile and press Enter
	UI.make_touch_target(tile, TILE_WIDTH_MULTIPLE, TILE_HEIGHT_MULTIPLE)
	var inside: VBoxContainer = VBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(inside)
	var avatar: AvatarArt = AvatarArt.new()
	avatar.name = "Avatar"
	avatar.avatar_id = profile.avatar_id
	avatar.custom_minimum_size = UI.target_size(2.2, 2.2)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inside.add_child(avatar)
	var label: Label = Label.new()
	label.name = "Nickname"
	label.text = profile.nickname # the child's own name, typed by a parent (not a line of the game)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(label)
	tile.pressed.connect(choose_profile.bind(profile.id))
	return tile


## Grown-ups (small, in the corner): the gate, then the profiles page (add or delete a child).
func _add_grownups_button() -> void:
	_grownups_button = Button.new()
	_grownups_button.name = "GrownupsButton"
	_grownups_button.text = Text.get_line(&"ui.hub.grownups")
	UI.make_touch_target(_grownups_button, 2.5, 1.0)
	_grownups_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 32)
	_grownups_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_grownups_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_grownups_button)
	IconArt.attach(_grownups_button, &"grownups")
	_grownups_button.pressed.connect(func() -> void:
		request_screen.emit(&"parent_gate", {"then": &"profiles", "then_args": {"back_to": &"title"}, "back_to": &"title"}))
	_grownups_button.visible = not Profiles.needs_onboarding()


## A child tapped their tile: they are the active profile now, and they start playing.
func choose_profile(profile_id: String) -> void:
	Profiles.select(profile_id)
	_start()


func _on_play_pressed() -> void:
	_start()


func _start() -> void:
	# A new install: a grown-up sets the game up first (parent onboarding, Sprint 23).
	if Profiles.needs_onboarding():
		request_screen.emit(&"onboarding", {})
		return
	# A profile that has not met Bolt yet (no nickname, or made in the parent area) sees the first run.
	var data: Dictionary = SaveSystem.data()
	var first_time: bool = str(data["child"].get("nickname", "")).is_empty() or not bool(data["profile"].get("welcomed", true))
	request_screen.emit(&"first_run" if first_time else &"hub", {})
