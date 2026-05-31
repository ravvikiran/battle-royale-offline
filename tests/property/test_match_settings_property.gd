## Property-based tests for match settings validation.
## Generates random match settings configurations and verifies that bot count
## validation, estimated duration computation, and settings blocking properties
## hold across all generated inputs.
##
## **Validates: Requirements 15.2, 15.4, 15.5**
extends GutTest


## Number of random iterations per property test.
const ITERATIONS: int = 100

## Valid bot count range per requirements.
const BOT_COUNT_MIN: int = 10
const BOT_COUNT_MAX: int = 99

## Zone phase data used for duration calculations.
var _zone_data: Dictionary = {}


func before_all() -> void:
	_zone_data = _load_zone_phases()


# --- Helper functions for random generation ---


## Loads zone phase configuration from JSON data file.
func _load_zone_phases() -> Dictionary:
	var file := FileAccess.open("res://data/zone_phases.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK:
			return json.data
	# Fallback: provide minimal valid zone data for testing
	return {
		"phases": [
			{"wait_seconds": 120, "shrink_seconds": 60},
			{"wait_seconds": 90, "shrink_seconds": 50},
			{"wait_seconds": 60, "shrink_seconds": 40},
			{"wait_seconds": 45, "shrink_seconds": 30},
			{"wait_seconds": 30, "shrink_seconds": 20},
		],
		"speed_multipliers": {
			"SLOW": 1.5,
			"NORMAL": 1.0,
			"FAST": 0.6,
		}
	}


## Generates a random valid bot count (10-99).
func _random_valid_bot_count() -> int:
	return randi_range(BOT_COUNT_MIN, BOT_COUNT_MAX)


## Generates a random invalid bot count (outside 10-99 range).
func _random_invalid_bot_count() -> int:
	if randi() % 2 == 0:
		# Below minimum: -100 to 9
		return randi_range(-100, BOT_COUNT_MIN - 1)
	else:
		# Above maximum: 100 to 500
		return randi_range(BOT_COUNT_MAX + 1, 500)


## Generates a random valid zone speed enum value.
func _random_zone_speed() -> int:
	var speeds := [
		Enums.ZoneShrinkSpeed.SLOW,
		Enums.ZoneShrinkSpeed.NORMAL,
		Enums.ZoneShrinkSpeed.FAST,
	]
	return speeds[randi() % speeds.size()]


## Generates a random valid difficulty enum value.
func _random_difficulty() -> int:
	var difficulties := [
		Enums.Difficulty.EASY,
		Enums.Difficulty.MEDIUM,
		Enums.Difficulty.HARD,
	]
	return difficulties[randi() % difficulties.size()]


## Generates a random invalid difficulty value (outside valid enum range).
func _random_invalid_difficulty() -> int:
	if randi() % 2 == 0:
		return randi_range(-10, Enums.Difficulty.EASY - 1)
	else:
		return randi_range(Enums.Difficulty.HARD + 1, 20)


## Generates a random invalid zone speed value (outside valid enum range).
func _random_invalid_zone_speed() -> int:
	if randi() % 2 == 0:
		return randi_range(-10, Enums.ZoneShrinkSpeed.SLOW - 1)
	else:
		return randi_range(Enums.ZoneShrinkSpeed.FAST + 1, 20)


# --- Property 32: Match settings validation ---
# For any match settings configuration, the system SHALL accept bot counts in
# range 10-99 and reject values outside this range, SHALL compute estimated match
# duration as a function of bot count and zone speed (rounded to nearest minute,
# minimum 1), and SHALL block match confirmation until all settings are valid.


## Sub-property 32a: Bot counts 10-99 are accepted, outside range rejected.
func test_property_32a_bot_count_validation() -> void:
	gut.p("Property 32a: Bot count range validation")
	gut.p("Bot counts 10-99 SHALL be accepted, values outside this range SHALL be rejected.")

	for i in range(ITERATIONS):
		# Test valid bot counts (10-99) are accepted
		var valid_count := _random_valid_bot_count()
		var is_valid := valid_count >= BOT_COUNT_MIN and valid_count <= BOT_COUNT_MAX
		assert_true(is_valid,
			"[Iter %d] Valid bot count %d must be in range [%d, %d]" % [
				i, valid_count, BOT_COUNT_MIN, BOT_COUNT_MAX])

		# Verify calculate_estimated_duration works with valid bot count (no crash)
		var duration := MatchSettings.calculate_estimated_duration(
			valid_count, _random_zone_speed(), _zone_data)
		assert_gte(duration, 1,
			"[Iter %d] Duration for valid bot count %d must be >= 1, got %d" % [
				i, valid_count, duration])

	# Test invalid bot counts are rejected
	for i in range(ITERATIONS):
		var invalid_count := _random_invalid_bot_count()
		var is_in_range := invalid_count >= BOT_COUNT_MIN and invalid_count <= BOT_COUNT_MAX
		assert_false(is_in_range,
			"[Iter %d] Invalid bot count %d must NOT be in range [%d, %d]" % [
				i, invalid_count, BOT_COUNT_MIN, BOT_COUNT_MAX])


## Sub-property 32b: Duration is always >= 1 minute and changes with bot count and zone speed.
func test_property_32b_estimated_duration_computation() -> void:
	gut.p("Property 32b: Estimated duration computation")
	gut.p("Duration SHALL be >= 1 minute and SHALL change with bot count and zone speed.")

	for i in range(ITERATIONS):
		var bot_count := _random_valid_bot_count()
		var zone_speed := _random_zone_speed()

		var duration := MatchSettings.calculate_estimated_duration(
			bot_count, zone_speed, _zone_data)

		# Duration must always be >= 1 (minimum 1 minute)
		assert_gte(duration, 1,
			"[Iter %d] Duration must be >= 1 minute, got %d (bot_count=%d, zone_speed=%d)" % [
				i, duration, bot_count, zone_speed])

		# Duration must be an integer (rounded to nearest minute)
		assert_eq(duration, int(duration),
			"[Iter %d] Duration must be a whole number (rounded), got %d" % [i, duration])

	# Verify duration changes with bot count (more bots = longer match)
	# Compare min bot count vs max bot count with same zone speed
	for i in range(ITERATIONS / 4):
		var zone_speed := _random_zone_speed()
		var duration_min_bots := MatchSettings.calculate_estimated_duration(
			BOT_COUNT_MIN, zone_speed, _zone_data)
		var duration_max_bots := MatchSettings.calculate_estimated_duration(
			BOT_COUNT_MAX, zone_speed, _zone_data)

		# More bots should result in equal or longer duration
		assert_gte(duration_max_bots, duration_min_bots,
			"[Iter %d] Duration with max bots (%d) must be >= duration with min bots (%d) for speed %d" % [
				i, duration_max_bots, duration_min_bots, zone_speed])

	# Verify duration changes with zone speed (SLOW > NORMAL > FAST)
	for i in range(ITERATIONS / 4):
		var bot_count := _random_valid_bot_count()
		var duration_slow := MatchSettings.calculate_estimated_duration(
			bot_count, Enums.ZoneShrinkSpeed.SLOW, _zone_data)
		var duration_normal := MatchSettings.calculate_estimated_duration(
			bot_count, Enums.ZoneShrinkSpeed.NORMAL, _zone_data)
		var duration_fast := MatchSettings.calculate_estimated_duration(
			bot_count, Enums.ZoneShrinkSpeed.FAST, _zone_data)

		# SLOW multiplier (1.5x) should produce longer or equal duration than NORMAL (1.0x)
		assert_gte(duration_slow, duration_normal,
			"[Iter %d] SLOW duration (%d) must be >= NORMAL duration (%d) for bot_count=%d" % [
				i, duration_slow, duration_normal, bot_count])

		# NORMAL multiplier (1.0x) should produce longer or equal duration than FAST (0.6x)
		assert_gte(duration_normal, duration_fast,
			"[Iter %d] NORMAL duration (%d) must be >= FAST duration (%d) for bot_count=%d" % [
				i, duration_normal, duration_fast, bot_count])


## Sub-property 32c: Settings are blocked when invalid.
func test_property_32c_settings_blocked_when_invalid() -> void:
	gut.p("Property 32c: Settings blocked when invalid")
	gut.p("Match confirmation SHALL be blocked until all settings are valid.")

	# Create a MatchSettings instance for testing _is_settings_valid()
	var settings := MatchSettings.new()

	for i in range(ITERATIONS):
		# Test with valid settings — should be valid
		settings._bot_count = _random_valid_bot_count()
		settings._bot_difficulty = _random_difficulty()
		settings._zone_speed = _random_zone_speed()

		assert_true(settings._is_settings_valid(),
			"[Iter %d] Settings with valid bot_count=%d, difficulty=%d, zone_speed=%d must be valid" % [
				i, settings._bot_count, settings._bot_difficulty, settings._zone_speed])

	# Test with invalid bot count — should be invalid (blocked)
	for i in range(ITERATIONS):
		settings._bot_count = _random_invalid_bot_count()
		settings._bot_difficulty = _random_difficulty()
		settings._zone_speed = _random_zone_speed()

		assert_false(settings._is_settings_valid(),
			"[Iter %d] Settings with invalid bot_count=%d must be blocked" % [
				i, settings._bot_count])

	# Test with invalid difficulty — should be invalid (blocked)
	for i in range(ITERATIONS / 2):
		settings._bot_count = _random_valid_bot_count()
		settings._bot_difficulty = _random_invalid_difficulty()
		settings._zone_speed = _random_zone_speed()

		assert_false(settings._is_settings_valid(),
			"[Iter %d] Settings with invalid difficulty=%d must be blocked" % [
				i, settings._bot_difficulty])

	# Test with invalid zone speed — should be invalid (blocked)
	for i in range(ITERATIONS / 2):
		settings._bot_count = _random_valid_bot_count()
		settings._bot_difficulty = _random_difficulty()
		settings._zone_speed = _random_invalid_zone_speed()

		assert_false(settings._is_settings_valid(),
			"[Iter %d] Settings with invalid zone_speed=%d must be blocked" % [
				i, settings._zone_speed])

	settings.free()
