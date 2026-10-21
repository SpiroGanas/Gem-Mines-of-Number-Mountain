# Zone 12's free-play screens (The Infinite Core): the museum's Journal button opens once the parts of a proof are known,
# the journal links to every page and room, a proof page builds a proof and cheers, the number rings room judges the
# smallest ring without any cost, and the Unsolved Mysteries room accepts any pair of primes that adds up. Nothing is saved.
class_name Zone12ScreensTest
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("zone12_screens_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)


func after_test() -> void:
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _master(skill_id: StringName) -> void:
	var record: Dictionary = SkillRecord.fresh(0.97)
	record["mastered_at"] = "2027-01-01T00:00:00Z"
	SaveSystem.data()["skills"][String(skill_id)] = record


func _screen(path: String, args: Dictionary = {}) -> ShellScreen:
	var screen: ShellScreen = load(path).instantiate()
	screen.setup(args)
	add_child(screen)
	auto_free(screen)
	return screen


func test_the_museum_shows_the_journal_once_the_parts_of_a_proof_are_known() -> void:
	var museum: ShellScreen = _screen("res://scenes/workshop/museum.tscn")
	assert_bool(museum.find_child("JournalButton", true, false) == null).is_true()
	_master(&"proof.parts.identify")
	var open: ShellScreen = _screen("res://scenes/workshop/museum.tscn")
	var button: Button = open.find_child("JournalButton", true, false)
	assert_bool(button != null).is_true()
	var asked: Array[StringName] = []
	open.request_screen.connect(func(screen_id: StringName, _args: Dictionary) -> void: asked.append(screen_id))
	button.pressed.emit()
	assert_array(asked).contains_exactly([&"journal"])


func test_the_journal_links_to_every_page_and_room() -> void:
	var journal: JournalScreen = _screen("res://scenes/zones/z12_infinite_core/journal.tscn")
	var asked: Array = []
	journal.request_screen.connect(func(screen_id: StringName, args: Dictionary) -> void: asked.append([screen_id, args]))
	for page: Dictionary in JournalScreen.PAGES:
		journal.button(String(page["id"])).pressed.emit()
	journal.button("RingsButton").pressed.emit()
	journal.button("MysteriesButton").pressed.emit()
	assert_array(asked).has_size(5)
	assert_str(str(asked[0][0])).is_equal("proof_page")
	assert_str(str(asked[2][1]["proof_id"])).is_equal("proof.sqrt2.irrational")
	assert_str(str(asked[3][0])).is_equal("number_rings")
	assert_str(str(asked[4][0])).is_equal("mysteries")
	for entry: Array in asked:
		assert_bool(Shell.SCREEN_PATHS.has(entry[0])).is_true()


func test_a_proof_page_builds_a_proof_and_bolt_cheers() -> void:
	var page: ProofPageScreen = _screen("res://scenes/zones/z12_infinite_core/proof_page.tscn", {"proof_id": "proof.practice.even_plus_even"})
	assert_bool(PanelDriver.build_proof(page.builder, "proof.practice.even_plus_even")).is_true()
	assert_bool(page.builder.is_done()).is_true()
	assert_dict(SaveSystem.data()["skills"]).is_empty() # nothing is scored here


func test_the_number_rings_room_judges_the_smallest_ring_for_free() -> void:
	var rings: NumberRingsScreen = _screen("res://scenes/zones/z12_infinite_core/number_rings.tscn")
	for round: int in 8:
		var smallest: StringName = NumberSetsGenerator.ring_of(rings.card)
		assert_bool(rings.next_button().disabled).is_true()
		for ring: StringName in NumberSetsGenerator.RINGS:
			if ring != smallest:
				rings.ring_button(ring).pressed.emit()
				assert_bool(rings.next_button().disabled).is_true() # a wrong tap changes nothing
		rings.ring_button(smallest).pressed.emit()
		assert_bool(rings.next_button().disabled).is_false()
		rings.next_button().pressed.emit()
	assert_bool(rings.ring_button(&"integer").custom_minimum_size.y >= float(UI.min_target_px())).is_true()


func test_the_mysteries_room_accepts_any_goldbach_pair() -> void:
	var room: MysteriesScreen = _screen("res://scenes/zones/z12_infinite_core/mysteries.tscn")
	room.n = 20
	room.change(0)
	for pair: Vector2i in MysteryGenerator.goldbach_pairs(20):
		room.picked.clear()
		room.tap_prime(pair.x)
		room.tap_prime(pair.y)
		assert_array(room.picked).has_size(2)
		assert_int(room.picked[0] + room.picked[1]).is_equal(20)
	room.picked.clear()
	assert_bool(room.offered_primes().has(19)).is_true()
	assert_bool(room.offered_primes().has(20)).is_false()
	for prime: int in room.offered_primes():
		assert_bool(room.prime_button(prime).custom_minimum_size.y >= float(UI.min_target_px())).is_true()


func test_the_mysteries_room_finds_the_first_twin_primes() -> void:
	var room: MysteriesScreen = _screen("res://scenes/zones/z12_infinite_core/mysteries.tscn")
	room.show_case(MysteriesScreen.Case.TWIN)
	room.p = 10
	room.change(0)
	var offered: Array[int] = room.offered_primes()
	assert_int(offered[0]).is_equal(11)
	assert_int(offered.back()).is_equal(MysteryGenerator.next_twin(10) + 2)
	room.tap_prime(11)
	assert_bool(room.bolt_node != null).is_true()


func test_euclid_s_proof_badge_comes_with_its_skill() -> void:
	var found: Dictionary = {}
	for entry: Dictionary in MotivationRules.load_badges():
		if entry["id"] == "euclid_proof":
			found = entry
	assert_dict(found).is_not_empty()
	assert_array(found["unlock"]["skills_mastered"]).contains_exactly(["proof.euclid.infinite_primes"])
	assert_int(found["story"].size()).is_equal(5)
	for line: Dictionary in found["story"]:
		assert_bool(Text.has_line(StringName(str(line["line_id"])))).is_true()
