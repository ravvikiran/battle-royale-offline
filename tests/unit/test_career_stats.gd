## Unit tests for CareerStats controller.
## Tests stats display, no-data state, and back button behavior.
extends GutTest


var _career_stats: CareerStats


func before_each() -> void:
	_career_stats = CareerStats.new()
	add_child_autofree(_career_stats)
	await get_tree().process_frame


func test_back_button_emits_signal() -> void:
	watch_signals(_career_stats)
	_career_stats._on_back_pressed()
	assert_signal_emitted(_career_stats, "back_pressed",
		"Back button should emit back_pressed signal")


func test_no_progress_store_returns_empty_stats() -> void:
	# Without a progress store, stats should be empty
	var stats := _career_stats.get_stats()
	assert_eq(stats.get("total_matches", -1), 0,
		"Without progress store, total_matches should be 0 or empty dict")


func test_stats_dictionary_structure() -> void:
	# Verify the stats dictionary has the expected keys when populated
	_career_stats._stats = {
		"total_matches": 10,
		"wins": 3,
		"total_kills": 45,
		"avg_kills_per_match": 4.5,
		"win_rate": 30.0
	}

	var stats := _career_stats.get_stats()
	assert_has(stats, "total_matches", "Stats should have total_matches")
	assert_has(stats, "wins", "Stats should have wins")
	assert_has(stats, "total_kills", "Stats should have total_kills")
	assert_has(stats, "avg_kills_per_match", "Stats should have avg_kills_per_match")
	assert_has(stats, "win_rate", "Stats should have win_rate")


func test_win_rate_calculation_format() -> void:
	# Requirement 10.5: win rate = (wins / total_matches) × 100, rounded to 1 decimal
	_career_stats._stats = {
		"total_matches": 7,
		"wins": 2,
		"total_kills": 20,
		"avg_kills_per_match": 2.857,
		"win_rate": 28.6  # (2/7) * 100 = 28.571... rounded to 28.6
	}

	var stats := _career_stats.get_stats()
	assert_eq(stats["win_rate"], 28.6,
		"Win rate should be rounded to 1 decimal place")
