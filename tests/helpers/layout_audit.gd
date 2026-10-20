## Checks a screen's interactive controls the way a child's finger meets them (Rule 7 and the phone
## layout pass): every visible tappable control lies fully on screen, measures at least
## UI.min_target_px() on both sides, and does not overlap another tappable control.
##
## "Tappable" means a visible BaseButton (Button, TextureButton...), a drag item or drop target, a
## handwriting box, or any control registered with UI.make_touch_target(). A control inside a
## ScrollContainer only has to fit inside that container across its scroll direction (the child can
## scroll to it), and only the part of it the container shows can overlap something else.
class_name LayoutAudit
extends RefCounted

## Rounding slack in canvas pixels (containers place controls on fractional positions).
const SLACK: float = 1.5


## Every visible tappable control under `root` (root included), in tree order.
static func tappables(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	_collect(root, found)
	return found


## Every problem found under `root`, one line each (empty when the layout is fine). `where` names the
## screen and the window in the messages.
static func problems(root: Node, where: String) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var viewport: Rect2 = root.get_viewport().get_visible_rect().grow(SLACK)
	var side: float = float(UI.min_target_px()) - SLACK
	var controls: Array[Control] = tappables(root)
	var shown: Array[Rect2] = []
	for control: Control in controls:
		var rect: Rect2 = control.get_global_rect()
		var scroll: ScrollContainer = _scroll_parent(control)
		var bounds: Rect2 = viewport
		if scroll != null:
			var area: Rect2 = scroll.get_global_rect()
			if not viewport.encloses(area):
				issues.append("%s: the scroll area %s leaves the screen (%s)" % [where, _name(scroll), area])
			# Across the scroll direction the control must fit; along it the child can scroll.
			if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				bounds = Rect2(area.position.x, rect.position.y, area.size.x, rect.size.y).grow(SLACK)
			if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				bounds = Rect2(rect.position.x, bounds.position.y, rect.size.x, bounds.size.y).grow(SLACK)
		if not bounds.encloses(rect):
			issues.append("%s: %s at %s leaves the screen" % [where, _name(control), rect])
		if rect.size.x < side or rect.size.y < side:
			issues.append("%s: %s is %s, below the %d px target" % [where, _name(control), rect.size, UI.min_target_px()])
		shown.append(rect.intersection(scroll.get_global_rect()) if scroll != null else rect)
	for i: int in controls.size():
		for j: int in range(i + 1, controls.size()):
			if controls[i].is_ancestor_of(controls[j]) or controls[j].is_ancestor_of(controls[i]):
				continue
			var overlap: Rect2 = shown[i].intersection(shown[j])
			if overlap.size.x > SLACK and overlap.size.y > SLACK:
				issues.append("%s: %s %s overlaps %s %s" % [where, _name(controls[i]), shown[i], _name(controls[j]), shown[j]])
	return issues


static func _collect(node: Node, found: Array[Control]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Control and _is_tappable(node):
		found.append(node)
	for child: Node in node.get_children():
		_collect(child, found)


static func _is_tappable(control: Control) -> bool:
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE and not control.is_in_group(UI.TARGET_GROUP):
		return false
	return control is BaseButton or control is DragItem or control is DragTarget or control is DigitBox or control is ShardCrystal or control.is_in_group(UI.TARGET_GROUP)


static func _scroll_parent(control: Control) -> ScrollContainer:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null


static func _name(control: Control) -> String:
	var label: String = ""
	if control is Button and (control as Button).text != "":
		label = " \"%s\"" % (control as Button).text.left(18)
	var owner_name: String = control.owner.name if control.owner != null else ""
	return "%s/%s%s" % [owner_name, control.name, label]
