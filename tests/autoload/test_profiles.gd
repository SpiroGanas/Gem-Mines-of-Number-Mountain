# Mirrors autoload/profiles.gd and the profile half of autoload/save_system.gd (Phase 3, Sprint 23):
# create, select, rename, delete (to the trash and back), the four-profile limit, onboarding's first
# profile, generic placement seeding, and no leaking of one child's progress into another's.
# Uses a fresh SaveSystem and Profiles on a temp folder, never the global autoloads, except the last
# section, which plays through the real Adaptive and Rewards autoloads on a temp folder.
class_name ProfilesTest
extends GdUnitTestSuite

const SYSTEM_SCRIPT: String = "res://autoload/save_system.gd"
const PROFILES_SCRIPT: String = "res://autoload/profiles.gd"

var _dir: String


func before_test() -> void:
	_dir = create_temp_dir("profiles_" + str(Time.get_ticks_usec()))
	DeviceSettings.use_shared(DeviceSettings.new(_dir.path_join("device_settings.cfg")))


func after_test() -> void:
	DeviceSettings.use_shared(null)


func _system(dir: String = _dir) -> Node:
	var system: Node = auto_free(load(SYSTEM_SCRIPT).new())
	system.use_directory(dir)
	return system


func _profiles(system: Node) -> Node:
	var profiles: Node = auto_free(load(PROFILES_SCRIPT).new())
	profiles.use_save_system(system)
	return profiles


# --- Profile (the data class) ------------------------------------------------------------------


func test_a_profile_id_is_p_and_eight_random_hex_characters() -> void:
	var seen: Dictionary = {}
	for i: int in 50:
		var id: String = Profile.new_id()
		assert_bool(Profile.is_valid_id(id)).override_failure_message(id).is_true()
		seen[id] = true
	assert_int(seen.size()).is_equal(50)
	for bad: String in ["", "p_123", "p_GGGGGGGG", "x_12345678", "p_12345678/..", "../p_1234567"]:
		assert_bool(Profile.is_valid_id(bad)).override_failure_message(bad).is_false()


func test_a_profile_round_trips_through_a_save_document_and_the_index() -> void:
	var profile: Profile = Profile.new()
	profile.id = "p_0123abcd"
	profile.nickname = "Ada"
	profile.avatar_id = &"rocket"
	profile.created_at = "2027-04-19T10:00:00Z"
	profile.last_played_at = "2027-04-20"
	profile.starting_grade = 3
	profile.session_minutes = 35
	profile.handwriting_coaching = true
	var save: Dictionary = SaveSchema.new_profile("t")
	profile.apply_to_save(save)
	assert_str(save["child"]["nickname"]).is_equal("Ada")
	assert_int(save["settings"]["session_minutes"]).is_equal(35)
	assert_dict(Profile.from_save(save).to_dict()).is_equal(profile.to_dict())
	assert_dict(Profile.from_dict(profile.to_dict()).to_dict()).is_equal(profile.to_dict())
	assert_bool(profile.to_dict().has("read_aloud")).is_false() # no narration (Spiro, Phase 3)


func test_bad_profile_fields_fall_back_to_safe_values() -> void:
	var profile: Profile = Profile.from_dict({"avatar_id": "photo.jpg", "starting_grade": 42, "nickname": "  a very long nickname that goes on  ", "session_minutes": -3})
	assert_str(profile.avatar_id).is_equal(Profile.DEFAULT_AVATAR)
	assert_int(profile.starting_grade).is_equal(Profile.MAX_GRADE)
	assert_int(profile.nickname.length()).is_equal(Profile.NICKNAME_MAX_LENGTH)
	assert_bool(profile.nickname.begins_with("a very")).is_true()
	assert_int(profile.session_minutes).is_equal(1)
	assert_int(Profile.AVATARS.size()).is_equal(8)


# --- Create, select, rename, the limit ------------------------------------------------------------


func test_a_new_device_has_one_blank_profile_that_needs_onboarding() -> void:
	var system: Node = _system()
	var profiles: Node = _profiles(system)
	assert_int(profiles.count()).is_equal(1)
	assert_bool(profiles.needs_onboarding()).is_true()
	assert_bool(profiles.is_blank()).is_true()
	assert_bool(Profile.is_valid_id(profiles.active.id)).is_true()
	assert_bool(FileAccess.file_exists(_dir.path_join("profiles/index.json"))).is_false() # nothing written yet


func test_create_select_and_rename() -> void:
	var system: Node = _system()
	var profiles: Node = _profiles(system)
	system.data()["child"]["nickname"] = "Charlie"
	system.save_now()
	var first_id: String = profiles.active.id
	monitor_signals(profiles)
	var ada: Profile = profiles.create("  Ada ", &"gem", 2)
	assert_object(ada).is_not_null()
	assert_str(ada.nickname).is_equal("Ada")
	assert_str(ada.avatar_id).is_equal("gem")
	assert_int(ada.starting_grade).is_equal(2)
	await assert_signal(profiles).is_emitted("profiles_changed")
	assert_int(profiles.count()).is_equal(2)
	assert_str(profiles.active.id).is_equal(first_id) # creating does not switch
	assert_bool(profiles.select(ada.id)).is_true()
	await assert_signal(profiles).is_emitted("active_profile_changed", [any_object()])
	assert_str(profiles.active.nickname).is_equal("Ada")
	assert_str(system.data()["child"]["nickname"]).is_equal("Ada")
	assert_str(system.profile_dir()).is_equal(_dir.path_join("profiles").path_join(ada.id))
	assert_bool(profiles.rename(first_id, "Charles")).is_true() # renaming the other (inactive) child
	assert_str(profiles.get_profile(first_id).nickname).is_equal("Charles")
	assert_bool(profiles.rename(ada.id, "   ")).is_false() # a blank name is refused
	assert_bool(profiles.set_avatar(ada.id, &"cart")).is_true()
	# A fresh start reads the index back: two children, Ada active, the new names.
	var reopened: Node = _profiles(_system())
	assert_int(reopened.count()).is_equal(2)
	assert_str(reopened.active.id).is_equal(ada.id)
	assert_str(reopened.active.avatar_id).is_equal("cart")
	assert_str(reopened.get_profile(first_id).nickname).is_equal("Charles")
	assert_bool(reopened.select(first_id)).is_true()
	assert_str(reopened.active.nickname).is_equal("Charles")


func test_there_are_never_more_than_four_profiles() -> void:
	var profiles: Node = _profiles(_system())
	for name: String in ["B", "C", "D"]:
		assert_object(profiles.create(name, &"bolt", 1)).is_not_null()
	assert_int(profiles.count()).is_equal(Profiles.MAX_PROFILES)
	assert_bool(profiles.can_add()).is_false()
	assert_object(profiles.create("E", &"bolt", 1)).is_null()
	assert_int(profiles.count()).is_equal(4)
	assert_int(DirAccess.get_directories_at(_dir.path_join("profiles")).size()).is_equal(4)


func test_selecting_an_unknown_profile_changes_nothing() -> void:
	var system: Node = _system()
	var profiles: Node = _profiles(system)
	var before: String = profiles.active.id
	assert_bool(profiles.select("p_00000000")).is_false()
	assert_bool(profiles.select("../../etc")).is_false()
	assert_str(profiles.active.id).is_equal(before)


func test_a_switch_saves_the_child_being_left() -> void:
	var system: Node = _system()
	var profiles: Node = _profiles(system)
	var other: Profile = profiles.create("Ada", &"gem", 1)
	system.data()["rewards"]["coins"] = 31 # not saved yet
	var first_id: String = system.profile_id()
	profiles.select(other.id)
	var on_disk: Dictionary = SaveStore.new(_dir.path_join("profiles").path_join(first_id)).read_profile()["data"]
	assert_int(on_disk["rewards"]["coins"]).is_equal(31)


# --- Delete (parent area only) -------------------------------------------------------------------


func test_deleting_moves_the_child_to_the_trash_and_they_can_come_back() -> void:
	var system: Node = _system()
	var profiles: Node = _profiles(system)
	system.data()["child"]["nickname"] = "Charlie"
	system.data()["rewards"]["coins"] = 12
	system.save_now()
	var charlie: String = system.profile_id()
	var ada: Profile = profiles.create("Ada", &"gem", 1)
	assert_bool(profiles.delete(charlie)).is_true() # the active child: the game switches to Ada first
	assert_str(profiles.active.id).is_equal(ada.id)
	assert_int(profiles.count()).is_equal(1)
	assert_bool(DirAccess.dir_exists_absolute(_dir.path_join("profiles").path_join(charlie))).is_false()
	var trashed: Array[Dictionary] = profiles.trashed()
	assert_int(trashed.size()).is_equal(1)
	assert_str(trashed[0]["id"]).is_equal(charlie)
	var back: Profile = profiles.restore(trashed[0]["folder"])
	assert_str(back.nickname).is_equal("Charlie")
	assert_int(profiles.count()).is_equal(2)
	profiles.select(charlie)
	assert_int(system.data()["rewards"]["coins"]).is_equal(12)
	assert_array(profiles.trashed()).is_empty()


func test_the_last_profile_cannot_be_deleted() -> void:
	var profiles: Node = _profiles(_system())
	assert_bool(profiles.delete(profiles.active.id)).is_false()
	assert_int(profiles.count()).is_equal(1)


func test_the_trash_is_emptied_after_thirty_days() -> void:
	var system: Node = _system()
	var profiles: Node = _profiles(system)
	var ada: Profile = profiles.create("Ada", &"gem", 1)
	profiles.delete(ada.id)
	var index: ProfileIndex = ProfileIndex.new(_dir)
	index.load_or_migrate("t")
	var deleted_unix: int = int(Time.get_unix_time_from_system())
	assert_int(index.purge_trash(deleted_unix + 29 * 86400)).is_equal(0)
	assert_int(index.trashed().size()).is_equal(1)
	assert_int(index.purge_trash(deleted_unix + 31 * 86400)).is_equal(1)
	assert_array(index.trashed()).is_empty()


# --- Onboarding and generic placement --------------------------------------------------------------


func test_onboarding_turns_the_blank_first_profile_into_the_child() -> void:
	var system: Node = _system()
	var profiles: Node = _profiles(system)
	var blank_id: String = profiles.active.id
	var child: Profile = profiles.setup_first("Mia", &"crystal", 0, 25)
	assert_str(child.id).is_equal(blank_id) # the same profile, no second folder
	assert_int(profiles.count()).is_equal(1)
	assert_str(child.nickname).is_equal("Mia")
	assert_int(child.session_minutes).is_equal(25)
	assert_str(system.data()["placement"]["seed"]).is_equal("grade_0")
	assert_bool(system.data()["profile"]["welcomed"]).is_false() # Bolt says hello next
	assert_bool(profiles.needs_onboarding()).is_false() # she has a name now
	profiles.finish_onboarding()
	var reopened: Node = _profiles(_system())
	assert_bool(reopened.needs_onboarding()).is_false()
	assert_str(reopened.active.nickname).is_equal("Mia")


func test_onboarding_over_a_profile_with_progress_makes_a_new_one() -> void:
	var system: Node = _system()
	var profiles: Node = _profiles(system)
	system.data()["child"]["nickname"] = "Charlie"
	system.save_now()
	var charlie: String = system.profile_id()
	var child: Profile = profiles.setup_first("Mia", &"crystal", 1, 20)
	assert_str(child.id).is_not_equal(charlie)
	assert_int(profiles.count()).is_equal(2)
	assert_str(profiles.active.id).is_equal(child.id)


func test_a_new_profile_starts_from_its_grade_priors() -> void:
	var system: Node = _system()
	var profiles: Node = _profiles(system)
	var older: Profile = profiles.create("Sam", &"pickaxe", 3)
	profiles.select(older.id)
	var skills: Dictionary = system.data()["skills"]
	var catalog: SkillCatalog = SkillCatalog.load_all()
	assert_float(float(skills["count.to_20.objects"]["p_learned"])).is_equal_approx(0.85, 0.0001) # zone 1
	assert_float(float(skills["add.to_100.regroup"]["p_learned"])).is_equal_approx(0.85, 0.0001) # zone 2
	assert_float(float(skills["mult.facts.0_5"]["p_learned"])).is_equal_approx(0.5, 0.0001) # zone 4
	assert_float(float(skills["pf.fta.unique"]["p_learned"])).is_equal_approx(0.3, 0.0001) # zone 5
	for id: String in skills:
		assert_int(int(skills[id]["attempts"])).is_equal(0)
		assert_bool(skills[id]["mastered_at"] == null).is_true() # priors only: nothing is mastered
		assert_bool(bool(skills[id]["placement_passed"])).is_false()
		assert_int(catalog.skill(StringName(id)).zone).is_less_equal(5)
	assert_str(system.data()["placement"]["seed"]).is_equal("grade_3")
	assert_bool(system.data()["placement"]["done"]).is_false() # the quest still runs, from the grade seed


# --- No leaking between children (through the real autoloads) --------------------------------------


func test_two_children_keep_their_own_skills_rewards_and_attempts() -> void:
	var dir: String = create_temp_dir("profiles_live_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(dir)
	var clock: FakeClock = FakeClock.new()
	clock.unix = Time.get_unix_time_from_datetime_string("2027-04-20T17:00:00")
	Adaptive.use_clock(clock)
	SaveSystem.data()["child"]["nickname"] = "Charlie"
	SaveSystem.data()["placement"]["done"] = true
	SaveSystem.save_now()
	var charlie: String = Profiles.active.id
	var ada: Profile = Profiles.create("Ada", &"gem", 1)
	# Charlie answers and gets paid.
	var attempt: Attempt = Attempt.new()
	attempt.skill_id = &"count.to_20.objects"
	attempt.correct = true
	Adaptive.record(attempt, 0.1)
	Rewards.pay_rock(1, true)
	var charlie_coins: int = Rewards.coins()
	var charlie_p: float = float(SaveSystem.data()["skills"]["count.to_20.objects"]["p_learned"])
	assert_int(charlie_coins).is_greater(0)
	# Ada starts from her own (grade 1) state: nothing of Charlie's.
	assert_bool(Profiles.select(ada.id)).is_true()
	assert_int(Rewards.coins()).is_equal(0)
	assert_int(Rewards.streak()).is_equal(0)
	assert_bool(Rewards.lit_today()).is_false()
	assert_array(SaveSystem.read_attempts()["entries"]).is_empty()
	assert_int(int(SaveSystem.data()["skills"]["count.to_20.objects"]["attempts"])).is_equal(0)
	assert_float(float(SaveSystem.data()["skills"]["count.to_20.objects"]["p_learned"])).is_equal_approx(0.5, 0.0001)
	assert_bool(Adaptive.has_session()).is_false() # the session was Charlie's
	assert_dict(Rewards.session_summary()["gems"]).is_empty()
	Rewards.pay_rock(1, false)
	var ada_coins: int = Rewards.coins()
	# The app closes mid-dig and opens again: each child is as they were, and distinct.
	SaveSystem.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	SaveSystem.use_directory(dir)
	assert_str(Profiles.active.id).is_equal(ada.id)
	assert_int(Rewards.coins()).is_equal(ada_coins)
	assert_bool(Profiles.select(charlie)).is_true()
	assert_int(Rewards.coins()).is_equal(charlie_coins)
	assert_float(float(SaveSystem.data()["skills"]["count.to_20.objects"]["p_learned"])).is_equal_approx(charlie_p, 0.000001)
	assert_array(SaveSystem.read_attempts()["entries"]).has_size(1)
	assert_str(SaveSystem.data()["profile"]["last_played_at"]).is_equal(clock.today())
	Adaptive.use_clock(GameClock.new())
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
