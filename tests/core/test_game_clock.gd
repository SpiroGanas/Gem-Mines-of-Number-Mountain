# Mirrors scripts/core/game_clock.gd and the test clock in tests/helpers/fake_clock.gd.
class_name GameClockTest
extends GdUnitTestSuite


func test_days_add_across_month_and_year_ends() -> void:
	assert_str(GameClock.add_days("2026-12-30", 3)).is_equal("2027-01-02")
	assert_str(GameClock.add_days("2027-02-28", 1)).is_equal("2027-03-01")
	assert_str(GameClock.add_days("2026-12-07", 0)).is_equal("2026-12-07")
	assert_str(GameClock.add_days("2026-12-07", -7)).is_equal("2026-11-30")


func test_days_between_counts_calendar_days() -> void:
	assert_int(GameClock.days_between("2026-12-07", "2026-12-08")).is_equal(1)
	assert_int(GameClock.days_between("2026-12-30", "2027-01-02")).is_equal(3)
	assert_int(GameClock.days_between("2026-12-08", "2026-12-07")).is_equal(-1)


func test_the_fake_clock_starts_on_a_known_day_and_moves_on_request() -> void:
	var clock: FakeClock = FakeClock.new()
	assert_str(clock.today()).is_equal("2026-12-07")
	assert_str(clock.now_iso()).is_equal("2026-12-07T12:00:00Z")
	clock.advance_days(1)
	assert_str(clock.today()).is_equal("2026-12-08")
	clock.advance(11 * 3600 + 59 * 60)
	assert_str(clock.today()).is_equal("2026-12-08") # 23:59 is still the same day
	clock.advance(60)
	assert_str(clock.today()).is_equal("2026-12-09")


func test_the_childs_day_follows_the_local_time_zone() -> void:
	var clock: FakeClock = FakeClock.new()
	clock.unix = FakeClock.START_UNIX + 11 * 3600 # 23:00 UTC on Dec 7
	clock.offset_minutes = 120 # UTC+2: already 01:00 on Dec 8
	assert_str(clock.today()).is_equal("2026-12-08")
	clock.offset_minutes = -300
	assert_str(clock.today()).is_equal("2026-12-07")


func test_the_real_clock_gives_well_formed_values() -> void:
	var clock: GameClock = GameClock.new()
	assert_int(clock.now_unix()).is_greater(1_700_000_000)
	assert_int(clock.today().length()).is_equal(10)
	assert_str(clock.now_iso()).ends_with("Z")
