## Unit tests for MatchSettings scene logic.
## Tests estimated duration calculation, validation, and settings management.
extends GutTest


## Zone phase data matching data/zone_phases.json for test calculations.
var _zone_data: Dictionary = {
	"phases": [
		{"phase": 1, "safe_radius_percent": 70, "wait_seconds": 120, "shrink_seconds": 60, "storm_dps": 1},
		{"phase": 2, "safe_radius_percent": 50, "wait_seconds": 90, "shrink_seconds": 50, "storm_dps": 2},
		{"phase": 3, "safe_radius_percent": 30, "wait_seconds": 60, "shrink_seconds": 40, "storm_dps": 3},
		{"phase": 4, "safe_radius_percent": 15, "wait_seconds": 45, "shrink_seconds": 30, "storm_dps": 5},
		{"phase": 5, "safe_radius_percent": 5, "wait_seconds": 30, "shrink_seconds": 20, "storm_dps": 8},
	],
	"speed_multipliers": {
		"SLOW": 1.5,
		"NORMAL": 1.0,
		"FAST": 0.6
	}
}


## Total phase seconds: (120+60) + (90+50) + (60+40) + (45+30) + (30+20) = 545 seconds.
func test_estimated_duration_default_settings() -> void:
	# Default: 50 bots, NORMAL speed
	# 545 * 1.0 * (50/50) = 545 seconds = 9.08 min -> rounds to 9
	var duration := MatchSettings.calculate_estimated_duration(
		50, Enums.ZoneShrinkSpeed.NORMAL, _zone_data
	)
	assert_eq(duration, 9, "Default settings should estimate 9 minutes")


func test_estimated_duration_slow_speed() -> void:
	# 50 bots, SLOW speed
	# 545 * 1.5 * (50/50) = 817.5 seconds = 13.625 min -> rounds to 14
	var duration := MatchSettings.calculate_estimated_duration(
		50, Enums.ZoneShrinkSpeed.SLOW, _zone_data
	)
	assert_eq(duration, 14, "Slow speed with 50 bots should estimate 14 minutes")


func test_estimated_duration_fast_speed() -> void:
	# 50 bots, FAST speed
	# 545 * 0.6 * (50/50) = 327 seconds = 5.45 min -> rounds to 5
	var duration := MatchSettings.calculate_estimated_duration(
		50, Enums.ZoneShrinkSpeed.FAST, _zone_data
	)
	assert_eq(duration, 5, "Fast speed with 50 bots should estimate 5 minutes")


func test_estimated_duration_max_bots() -> void:
	# 99 bots, NORMAL speed
	# 545 * 1.0 * (99/50) = 545 * 1.98 = 1079.1 seconds = 17.985 min -> rounds to 18
	var duration := MatchSettings.calculate_estimated_duration(
		99, Enums.ZoneShrinkSpeed.NORMAL, _zone_data
	)
	assert_eq(duration, 18, "99 bots at normal speed should estimate 18 minutes")


func test_estimated_duration_min_bots() -> void:
	# 10 bots, NORMAL speed
	# 545 * 1.0 * (10/50) = 545 * 0.2 = 109 seconds = 1.816 min -> rounds to 2
	var duration := MatchSettings.calculate_estimated_duration(
		10, Enums.ZoneShrinkSpeed.NORMAL, _zone_data
	)
	assert_eq(duration, 2, "10 bots at normal speed should estimate 2 minutes")


func test_estimated_duration_min_bots_fast_speed() -> void:
	# 10 bots, FAST speed
	# 545 * 0.6 * (10/50) = 545 * 0.6 * 0.2 = 65.4 seconds = 1.09 min -> rounds to 1
	var duration := MatchSettings.calculate_estimated_duration(
		10, Enums.ZoneShrinkSpeed.FAST, _zone_data
	)
	assert_eq(duration, 1, "10 bots at fast speed should estimate 1 minute (minimum)")


func test_estimated_duration_minimum_is_one() -> void:
	# Even with very low values, minimum should be 1
	var minimal_data: Dictionary = {
		"phases": [
			{"phase": 1, "wait_seconds": 10, "shrink_seconds": 5}
		],
		"speed_multipliers": {"SLOW": 1.5, "NORMAL": 1.0, "FAST": 0.6}
	}
	var duration := MatchSettings.calculate_estimated_duration(
		10, Enums.ZoneShrinkSpeed.FAST, minimal_data
	)
	assert_ge(duration, 1, "Duration should never be less than 1 minute")


func test_estimated_duration_empty_zone_data() -> void:
	# With empty zone data, should still return minimum 1
	var duration := MatchSettings.calculate_estimated_duration(
		50, Enums.ZoneShrinkSpeed.NORMAL, {}
	)
	assert_eq(duration, 1, "Empty zone data should return minimum 1 minute")


func test_estimated_duration_updates_with_bot_count() -> void:
	# Verify duration changes when bot count changes
	var duration_low := MatchSettings.calculate_estimated_duration(
		10, Enums.ZoneShrinkSpeed.NORMAL, _zone_data
	)
	var duration_high := MatchSettings.calculate_estimated_duration(
		99, Enums.ZoneShrinkSpeed.NORMAL, _zone_data
	)
	assert_gt(duration_high, duration_low, "Higher bot count should produce longer duration")


func test_estimated_duration_updates_with_zone_speed() -> void:
	# Verify duration changes when zone speed changes
	var duration_slow := MatchSettings.calculate_estimated_duration(
		50, Enums.ZoneShrinkSpeed.SLOW, _zone_data
	)
	var duration_fast := MatchSettings.calculate_estimated_duration(
		50, Enums.ZoneShrinkSpeed.FAST, _zone_data
	)
	assert_gt(duration_slow, duration_fast, "Slow speed should produce longer duration than fast")
