## Property-based tests for authentication and progress persistence.
## Tests UUID v4 generation, email/password validation, progress data integrity,
## user data isolation, guest-to-account migration, and character selection round-trip.
##
## **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5, 10.7, 2.5**
##
## Property 25: User identity and auth validation
## Property 26: Progress data integrity
## Property 27: User data isolation
## Property 28: Guest-to-account migration
## Property 4: Character selection round-trip
extends GutTest


## Number of random test iterations per property test
const NUM_ITERATIONS := 100

## Tolerance for floating point comparisons
const EPSILON := 0.01

## Valid characters and variants for generation
const VALID_CHARACTERS := ["BLITZ", "TITAN", "PHANTOM"]
const VALID_VARIANTS := ["MALE", "FEMALE"]

## Valid hex characters for UUID validation
const HEX_CHARS := "0123456789abcdef"

## Valid variant nibble characters for UUID v4
const VARIANT_CHARS := "89ab"


var _rng: RandomNumberGenerator
var _auth: AuthManager


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_auth = AuthManager.new()


# =============================================================================
# Property 25: User identity and auth validation
# =============================================================================


## Generates a random valid email address for testing.
func _generate_valid_email() -> String:
	var local_chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var local_len := _rng.randi_range(3, 20)
	var local_part := ""
	for i in range(local_len):
		local_part += local_chars[_rng.randi_range(0, local_chars.length() - 1)]

	var domains := ["example.com", "test.org", "mail.co.uk", "game.io", "player.net"]
	var domain := domains[_rng.randi_range(0, domains.size() - 1)]

	return local_part + "@" + domain


## Generates a random invalid email address for testing.
func _generate_invalid_email() -> String:
	var invalid_patterns := [
		"",                          # empty
		"nodomain",                  # no @ symbol
		"@example.com",             # empty local part
		"user@",                     # empty domain
		"user@@example.com",        # double @
		".user@example.com",        # leading dot in local
		"user.@example.com",        # trailing dot in local
		"user..name@example.com",   # consecutive dots
		"user@-example.com",        # leading hyphen in domain
		"user@example-.com",        # trailing hyphen in domain
		"user@example.c",           # TLD too short
		"user@example",             # no dot in domain
	]
	return invalid_patterns[_rng.randi_range(0, invalid_patterns.size() - 1)]


## Generates a random valid password (8-64 characters).
func _generate_valid_password() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%"
	var length := _rng.randi_range(8, 64)
	var password := ""
	for i in range(length):
		password += chars[_rng.randi_range(0, chars.length() - 1)]
	return password


## Generates a random invalid password (too short or too long).
func _generate_invalid_password() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz"
	# Either too short (0-7) or too long (65+)
	var too_short := _rng.randi_range(0, 1) == 0
	var length: int
	if too_short:
		length = _rng.randi_range(0, 7)
	else:
		length = _rng.randi_range(65, 100)

	var password := ""
	for i in range(length):
		password += chars[_rng.randi_range(0, chars.length() - 1)]
	return password


## Property test: For any generated guest ID, it SHALL conform to UUID v4 format
## (36 characters, correct hyphen positions, version nibble = 4).
func test_property_25_guest_id_uuid_v4_format() -> void:
	for i in range(NUM_ITERATIONS):
		var guest_id := _auth.generate_guest_id()

		# 36 characters total
		assert_eq(guest_id.length(), 36,
			"Iteration %d: UUID should be 36 characters, got %d" % [i, guest_id.length()])

		# Correct hyphen positions (8, 13, 18, 23)
		assert_eq(guest_id[8], "-",
			"Iteration %d: Expected hyphen at position 8, got '%s'" % [i, guest_id[8]])
		assert_eq(guest_id[13], "-",
			"Iteration %d: Expected hyphen at position 13, got '%s'" % [i, guest_id[13]])
		assert_eq(guest_id[18], "-",
			"Iteration %d: Expected hyphen at position 18, got '%s'" % [i, guest_id[18]])
		assert_eq(guest_id[23], "-",
			"Iteration %d: Expected hyphen at position 23, got '%s'" % [i, guest_id[23]])

		# Version nibble = 4 at position 14
		assert_eq(guest_id[14], "4",
			"Iteration %d: Version nibble at position 14 should be '4', got '%s'" % [i, guest_id[14]])

		# Variant nibble at position 19 must be 8, 9, a, or b
		var variant_char := guest_id[19]
		assert_true(VARIANT_CHARS.find(variant_char) != -1,
			"Iteration %d: Variant nibble at position 19 should be 8/9/a/b, got '%s'" % [i, variant_char])

		# All non-hyphen characters must be valid hex
		for j in range(36):
			if j == 8 or j == 13 or j == 18 or j == 23:
				continue
			assert_true(HEX_CHARS.find(guest_id[j]) != -1,
				"Iteration %d: Character at position %d should be hex, got '%s'" % [i, j, guest_id[j]])


## Property test: For any email input, validation SHALL accept only RFC 5322
## compliant addresses.
func test_property_25_email_validation_accepts_valid() -> void:
	for i in range(NUM_ITERATIONS):
		var email := _generate_valid_email()
		assert_true(_auth.validate_email(email),
			"Iteration %d: Valid email '%s' should be accepted" % [i, email])


## Property test: For any invalid email input, validation SHALL reject it.
func test_property_25_email_validation_rejects_invalid() -> void:
	for i in range(NUM_ITERATIONS):
		var email := _generate_invalid_email()
		assert_false(_auth.validate_email(email),
			"Iteration %d: Invalid email '%s' should be rejected" % [i, email])


## Property test: For any password input, validation SHALL accept only strings
## of length 8-64 characters.
func test_property_25_password_validation_accepts_valid() -> void:
	for i in range(NUM_ITERATIONS):
		var password := _generate_valid_password()
		assert_true(_auth.validate_password(password),
			"Iteration %d: Valid password of length %d should be accepted" % [i, password.length()])


## Property test: For any invalid password, validation SHALL reject it.
func test_property_25_password_validation_rejects_invalid() -> void:
	for i in range(NUM_ITERATIONS):
		var password := _generate_invalid_password()
		assert_false(_auth.validate_password(password),
			"Iteration %d: Invalid password of length %d should be rejected" % [i, password.length()])


# =============================================================================
# Property 26: Progress data integrity
# =============================================================================


## Creates a fresh ProgressStore initialized for a given user.
func _create_progress_store(user_id: String) -> ProgressStore:
	var store := ProgressStore.new()
	store.initialize(user_id)
	return store


## Generates a random match result dictionary with valid fields.
func _generate_match_result(index: int) -> Dictionary:
	var characters := ["BLITZ", "TITAN", "PHANTOM"]
	var variants := ["MALE", "FEMALE"]
	var difficulties := ["EASY", "MEDIUM", "HARD"]

	return {
		"match_id": "match_%d_%d" % [index, _rng.randi()],
		"timestamp": "2024-%02d-%02dT%02d:%02d:%02d" % [
			_rng.randi_range(1, 12),
			_rng.randi_range(1, 28),
			_rng.randi_range(0, 23),
			_rng.randi_range(0, 59),
			_rng.randi_range(0, 59)
		],
		"placement": _rng.randi_range(1, 100),
		"total_participants": _rng.randi_range(11, 100),
		"kills": _rng.randi_range(0, 30),
		"damage_dealt": _rng.randf_range(0.0, 5000.0),
		"survival_time_seconds": _rng.randi_range(30, 1800),
		"character_name": characters[_rng.randi_range(0, 2)],
		"character_variant": variants[_rng.randi_range(0, 1)],
		"bot_difficulty": difficulties[_rng.randi_range(0, 2)],
		"bot_count": _rng.randi_range(10, 99)
	}


## Property test: For any set of match results saved to the progress store,
## loading the match history SHALL return all saved results with identical field values,
## and the computed career statistics SHALL equal the expected values.
func test_property_26_progress_data_integrity() -> void:
	for i in range(NUM_ITERATIONS):
		var user_id := "test_user_p26_%d_%d" % [i, _rng.randi()]
		var store := _create_progress_store(user_id)

		# Generate a random number of match results (1-10)
		var num_results := _rng.randi_range(1, 10)
		var saved_results: Array = []

		for j in range(num_results):
			var result := _generate_match_result(j)
			var save_response := store.save_match_result(result)
			assert_true(save_response["success"],
				"Iteration %d: Failed to save match result %d" % [i, j])
			saved_results.append(result)

		# Load match history (with high limit to get all)
		var history := store.get_match_history(100)

		# Verify all saved results are present
		assert_eq(history.size(), saved_results.size(),
			"Iteration %d: Expected %d results in history, got %d" % [i, saved_results.size(), history.size()])

		# Verify each saved result exists in history with identical field values
		for saved in saved_results:
			var found := false
			for loaded in history:
				if loaded.get("match_id", "") == saved["match_id"]:
					found = true
					assert_eq(int(loaded["placement"]), int(saved["placement"]),
						"Iteration %d: Placement mismatch for match %s" % [i, saved["match_id"]])
					assert_eq(int(loaded["kills"]), int(saved["kills"]),
						"Iteration %d: Kills mismatch for match %s" % [i, saved["match_id"]])
					assert_eq(int(loaded["total_participants"]), int(saved["total_participants"]),
						"Iteration %d: Total participants mismatch for match %s" % [i, saved["match_id"]])
					assert_eq(int(loaded["survival_time_seconds"]), int(saved["survival_time_seconds"]),
						"Iteration %d: Survival time mismatch for match %s" % [i, saved["match_id"]])
					assert_eq(str(loaded["character_name"]), str(saved["character_name"]),
						"Iteration %d: Character name mismatch for match %s" % [i, saved["match_id"]])
					assert_eq(str(loaded["character_variant"]), str(saved["character_variant"]),
						"Iteration %d: Character variant mismatch for match %s" % [i, saved["match_id"]])
					assert_eq(str(loaded["bot_difficulty"]), str(saved["bot_difficulty"]),
						"Iteration %d: Bot difficulty mismatch for match %s" % [i, saved["match_id"]])
					assert_eq(int(loaded["bot_count"]), int(saved["bot_count"]),
						"Iteration %d: Bot count mismatch for match %s" % [i, saved["match_id"]])
					break
			assert_true(found,
				"Iteration %d: Match %s not found in history" % [i, saved["match_id"]])

		# Verify career statistics computation
		var stats := store.get_career_stats()
		var expected_total := saved_results.size()
		var expected_wins := 0
		var expected_kills := 0

		for result in saved_results:
			if int(result["placement"]) == 1:
				expected_wins += 1
			expected_kills += int(result["kills"])

		var expected_avg_kills := float(expected_kills) / float(expected_total) if expected_total > 0 else 0.0
		var expected_win_rate := snapped(float(expected_wins) / float(expected_total) * 100.0, 0.1) if expected_total > 0 else 0.0

		assert_eq(stats["total_matches"], expected_total,
			"Iteration %d: total_matches should be %d, got %d" % [i, expected_total, stats["total_matches"]])
		assert_eq(stats["wins"], expected_wins,
			"Iteration %d: wins should be %d, got %d" % [i, expected_wins, stats["wins"]])
		assert_eq(stats["total_kills"], expected_kills,
			"Iteration %d: total_kills should be %d, got %d" % [i, expected_kills, stats["total_kills"]])
		assert_almost_eq(stats["avg_kills_per_match"], expected_avg_kills, EPSILON,
			"Iteration %d: avg_kills should be %.2f, got %.2f" % [i, expected_avg_kills, stats["avg_kills_per_match"]])
		assert_almost_eq(stats["win_rate"], expected_win_rate, EPSILON,
			"Iteration %d: win_rate should be %.1f, got %.1f" % [i, expected_win_rate, stats["win_rate"]])


# =============================================================================
# Property 27: User data isolation
# =============================================================================


## Property test: For any two distinct user IDs, match results saved under one
## user ID SHALL NOT appear when querying the other user ID's match history
## or career statistics.
func test_property_27_user_data_isolation() -> void:
	for i in range(NUM_ITERATIONS):
		var user_id_a := "user_a_%d_%d" % [i, _rng.randi()]
		var user_id_b := "user_b_%d_%d" % [i, _rng.randi()]

		var store_a := _create_progress_store(user_id_a)
		var store_b := _create_progress_store(user_id_b)

		# Save random results under user A
		var num_results_a := _rng.randi_range(1, 5)
		var total_kills_a := 0
		for j in range(num_results_a):
			var result := _generate_match_result(j)
			total_kills_a += int(result["kills"])
			store_a.save_match_result(result)

		# Save different results under user B
		var num_results_b := _rng.randi_range(1, 5)
		var total_kills_b := 0
		for j in range(num_results_b):
			var result := _generate_match_result(j + 100)
			total_kills_b += int(result["kills"])
			store_b.save_match_result(result)

		# Verify user A's history only contains their results
		var history_a := store_a.get_match_history(100)
		assert_eq(history_a.size(), num_results_a,
			"Iteration %d: User A should have %d results, got %d" % [i, num_results_a, history_a.size()])

		# Verify user B's history only contains their results
		var history_b := store_b.get_match_history(100)
		assert_eq(history_b.size(), num_results_b,
			"Iteration %d: User B should have %d results, got %d" % [i, num_results_b, history_b.size()])

		# Verify career stats are isolated
		var stats_a := store_a.get_career_stats()
		var stats_b := store_b.get_career_stats()

		assert_eq(stats_a["total_matches"], num_results_a,
			"Iteration %d: User A stats should show %d matches" % [i, num_results_a])
		assert_eq(stats_b["total_matches"], num_results_b,
			"Iteration %d: User B stats should show %d matches" % [i, num_results_b])
		assert_eq(stats_a["total_kills"], total_kills_a,
			"Iteration %d: User A total_kills should be %d" % [i, total_kills_a])
		assert_eq(stats_b["total_kills"], total_kills_b,
			"Iteration %d: User B total_kills should be %d" % [i, total_kills_b])


# =============================================================================
# Property 28: Guest-to-account migration
# =============================================================================


## Property test: For any guest user with existing progress data, after successful
## migration to an authenticated account, all match history and career statistics
## SHALL be accessible under the new account ID and SHALL no longer be accessible
## under the original guest ID.
func test_property_28_guest_to_account_migration() -> void:
	for i in range(NUM_ITERATIONS):
		var guest_id := "guest_%d_%d" % [i, _rng.randi()]
		var account_id := "account_%d_%d" % [i, _rng.randi()]

		var store := _create_progress_store(guest_id)

		# Save random match results under guest ID
		var num_results := _rng.randi_range(1, 5)
		var saved_results: Array = []
		var expected_kills := 0
		var expected_wins := 0

		for j in range(num_results):
			var result := _generate_match_result(j)
			store.save_match_result(result)
			saved_results.append(result)
			expected_kills += int(result["kills"])
			if int(result["placement"]) == 1:
				expected_wins += 1

		# Verify guest has data before migration
		var guest_history_before := store.get_match_history(100)
		assert_eq(guest_history_before.size(), num_results,
			"Iteration %d: Guest should have %d results before migration" % [i, num_results])

		# Perform migration
		var migration_result := store.migrate_guest_to_account(guest_id, account_id)
		assert_true(migration_result["success"],
			"Iteration %d: Migration should succeed" % [i])

		# After migration, current_user_id should be account_id
		assert_eq(store.current_user_id, account_id,
			"Iteration %d: current_user_id should be account_id after migration" % [i])

		# Verify data is accessible under new account ID
		var account_history := store.get_match_history(100)
		assert_eq(account_history.size(), num_results,
			"Iteration %d: Account should have %d results after migration, got %d" % [i, num_results, account_history.size()])

		var account_stats := store.get_career_stats()
		assert_eq(account_stats["total_matches"], num_results,
			"Iteration %d: Account stats should show %d matches" % [i, num_results])
		assert_eq(account_stats["total_kills"], expected_kills,
			"Iteration %d: Account total_kills should be %d" % [i, expected_kills])
		assert_eq(account_stats["wins"], expected_wins,
			"Iteration %d: Account wins should be %d" % [i, expected_wins])

		# Verify data is no longer accessible under guest ID
		# Switch back to guest user to check
		store.current_user_id = guest_id
		var guest_history_after := store.get_match_history(100)
		assert_eq(guest_history_after.size(), 0,
			"Iteration %d: Guest should have 0 results after migration, got %d" % [i, guest_history_after.size()])

		var guest_stats_after := store.get_career_stats()
		assert_eq(guest_stats_after["total_matches"], 0,
			"Iteration %d: Guest stats should show 0 matches after migration" % [i])
		assert_eq(guest_stats_after["total_kills"], 0,
			"Iteration %d: Guest total_kills should be 0 after migration" % [i])


# =============================================================================
# Property 4: Character selection round-trip
# =============================================================================


## Property test: For any valid character ID and variant combination, saving the
## selection to the progress store and then loading it back SHALL return the
## identical character ID and variant.
func test_property_4_character_selection_round_trip() -> void:
	for i in range(NUM_ITERATIONS):
		var user_id := "char_test_%d_%d" % [i, _rng.randi()]
		var store := _create_progress_store(user_id)

		# Pick a random valid character and variant
		var character := VALID_CHARACTERS[_rng.randi_range(0, VALID_CHARACTERS.size() - 1)]
		var variant := VALID_VARIANTS[_rng.randi_range(0, VALID_VARIANTS.size() - 1)]

		# Save the selection
		var save_result := store.save_character_selection(character, variant)
		assert_true(save_result["success"],
			"Iteration %d: save_character_selection should succeed for %s/%s" % [i, character, variant])

		# Load it back
		var loaded := store.get_character_selection()

		# Verify round-trip
		assert_eq(loaded["character"], character,
			"Iteration %d: Loaded character should be '%s', got '%s'" % [i, character, loaded["character"]])
		assert_eq(loaded["variant"], variant,
			"Iteration %d: Loaded variant should be '%s', got '%s'" % [i, variant, loaded["variant"]])
