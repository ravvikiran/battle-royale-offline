## Unit tests for MatchController class covering match lifecycle,
## state transitions, elimination tracking, and victory conditions.
extends GutTest


var _controller: MatchController


func before_each() -> void:
	_controller = MatchController.new()
	add_child(_controller)


func after_each() -> void:
	_controller.queue_free()


# --- Helper to create default match settings ---

func _default_settings(bot_count: int = 50) -> Dictionary:
	return {
		"bot_count": bot_count,
		"bot_difficulty": Enums.Difficulty.MEDIUM,
		"zone_speed": Enums.ZoneShrinkSpeed.NORMAL,
		"character": "BLITZ",
		"variant": "MALE",
	}


# --- Initialization and start_match tests ---

func test_initial_state_is_lobby() -> void:
	assert_eq(_controller.match_state, Enums.MatchState.LOBBY)


func test_start_match_transitions_to_drop() -> void:
	_controller.start_match(_default_settings())
	assert_eq(_controller.match_state, Enums.MatchState.DROP)


func test_start_match_sets_alive_count() -> void:
	_controller.start_match(_default_settings(50))
	assert_eq(_controller.alive_count, 51)  # 50 bots + 1 player


func test_start_match_total_participants() -> void:
	_controller.start_match(_default_settings(30))
	assert_eq(_controller.total_participants, 31)


func test_start_match_player_alive() -> void:
	_controller.start_match(_default_settings())
	assert_true(_controller.player_alive)


func test_start_match_resets_stats() -> void:
	_controller.start_match(_default_settings())
	assert_eq(_controller.match_stats["kills"], 0)
	assert_almost_eq(_controller.match_stats["damage_dealt"], 0.0, 0.001)
	assert_almost_eq(_controller.match_stats["survival_time_seconds"], 0.0, 0.001)


func test_start_match_spawns_bots() -> void:
	_controller.start_match(_default_settings(20))
	assert_eq(_controller.bot_ai_manager.bots.size(), 20)


func test_start_match_clamps_bot_count_min() -> void:
	var settings := _default_settings()
	settings["bot_count"] = 5  # Below minimum of 10
	_controller.start_match(settings)
	assert_eq(_controller.total_participants, 11)  # Clamped to 10 + 1


func test_start_match_clamps_bot_count_max() -> void:
	var settings := _default_settings()
	settings["bot_count"] = 150  # Above maximum of 99
	_controller.start_match(settings)
	assert_eq(_controller.total_participants, 100)  # Clamped to 99 + 1


func test_start_match_emits_state_changed_signal() -> void:
	watch_signals(_controller)
	_controller.start_match(_default_settings())
	assert_signal_emitted(_controller, "match_state_changed")


# --- Drop phase tests ---

func test_begin_drop_phase_sets_timer() -> void:
	_controller.start_match(_default_settings())
	_controller.begin_drop_phase()
	assert_almost_eq(_controller.drop_timer, 60.0, 0.001)


func test_begin_drop_phase_player_not_dropped() -> void:
	_controller.start_match(_default_settings())
	_controller.begin_drop_phase()
	assert_false(_controller.player_has_dropped)


func test_player_select_drop_sets_position() -> void:
	_controller.start_match(_default_settings())
	_controller.begin_drop_phase()
	_controller.player_select_drop(Vector2(100, 200))
	assert_eq(_controller.player_position, Vector2(100, 200))
	assert_true(_controller.player_has_dropped)


func test_player_select_drop_ignored_if_not_in_drop_state() -> void:
	_controller.start_match(_default_settings())
	_controller.begin_drop_phase()
	_controller.end_drop_phase()  # Now in ACTIVE state
	_controller.player_select_drop(Vector2(999, 999))
	# Position should be whatever was set during end_drop_phase auto-drop
	assert_ne(_controller.player_position, Vector2(999, 999))


func test_end_drop_phase_transitions_to_active() -> void:
	_controller.start_match(_default_settings())
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	assert_eq(_controller.match_state, Enums.MatchState.ACTIVE)


func test_end_drop_phase_auto_drops_player_if_not_selected() -> void:
	_controller.start_match(_default_settings())
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	assert_true(_controller.player_has_dropped)
	# Player position should be set to something (not zero since map center is at 0,0 with offset)
	# Just verify the flag is set
	assert_true(_controller.player_has_dropped)


func test_end_drop_phase_keeps_player_position_if_already_selected() -> void:
	_controller.start_match(_default_settings())
	_controller.begin_drop_phase()
	_controller.player_select_drop(Vector2(300, 400))
	_controller.end_drop_phase()
	assert_eq(_controller.player_position, Vector2(300, 400))


# --- Elimination tests ---

func test_register_elimination_decrements_alive_count() -> void:
	_controller.start_match(_default_settings(10))
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	var initial_alive := _controller.alive_count
	_controller.register_elimination(1, 0)  # Bot 1 killed by player
	assert_eq(_controller.alive_count, initial_alive - 1)


func test_register_elimination_tracks_player_kills() -> void:
	_controller.start_match(_default_settings(10))
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	_controller.register_elimination(1, 0)  # Bot 1 killed by player
	_controller.register_elimination(2, 0)  # Bot 2 killed by player
	assert_eq(_controller.match_stats["kills"], 2)


func test_register_elimination_bot_kills_bot_no_player_kill() -> void:
	_controller.start_match(_default_settings(10))
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	_controller.register_elimination(1, 2)  # Bot 1 killed by Bot 2
	assert_eq(_controller.match_stats["kills"], 0)


func test_register_elimination_player_death() -> void:
	_controller.start_match(_default_settings(10))
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	_controller.register_elimination(0, 1)  # Player killed by Bot 1
	assert_false(_controller.player_alive)


func test_register_elimination_emits_signal() -> void:
	_controller.start_match(_default_settings(10))
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	watch_signals(_controller)
	_controller.register_elimination(1, 0, "Volt Repeater")
	assert_signal_emitted(_controller, "elimination_occurred")


func test_register_elimination_ignored_if_not_active() -> void:
	_controller.start_match(_default_settings(10))
	# Still in DROP state, not ACTIVE
	var initial_alive := _controller.alive_count
	_controller.register_elimination(1, 0)
	assert_eq(_controller.alive_count, initial_alive)


# --- Victory condition tests ---

func test_victory_when_player_is_last_alive() -> void:
	_controller.start_match(_default_settings(2))
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	watch_signals(_controller)
	# Eliminate both bots
	_controller.register_elimination(1, 0)
	_controller.register_elimination(2, 0)
	assert_eq(_controller.match_state, Enums.MatchState.ENDED)
	assert_signal_emitted(_controller, "match_ended")


func test_victory_simultaneous_final_elimination() -> void:
	_controller.start_match(_default_settings(1))
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	# Simulate simultaneous elimination: both player and last bot die
	# alive_count starts at 2 (1 bot + player)
	_controller.alive_count = 2
	_controller.player_alive = true
	# Kill the bot first (alive_count = 1, player alive → victory)
	# Actually for simultaneous: we need alive_count = 0 and player not alive
	# Let's manually set the state to test the simultaneous condition
	_controller.alive_count = 0
	_controller.player_alive = false
	var result := _controller.check_victory_condition()
	assert_true(result)
	assert_eq(_controller.match_state, Enums.MatchState.ENDED)


func test_defeat_when_player_eliminated_others_remain() -> void:
	_controller.start_match(_default_settings(10))
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	watch_signals(_controller)
	_controller.register_elimination(0, 5)  # Player killed by bot 5
	assert_eq(_controller.match_state, Enums.MatchState.ENDED)
	assert_signal_emitted(_controller, "match_ended")


func test_defeat_placement_calculation() -> void:
	_controller.start_match(_default_settings(10))
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	# Kill 3 bots first, then player dies
	_controller.register_elimination(1, 0)
	_controller.register_elimination(2, 0)
	_controller.register_elimination(3, 0)
	# Now alive_count = 11 - 3 = 8, player dies → placement = 8
	var match_ended_emitted := false
	var result_data: Dictionary = {}
	_controller.match_ended.connect(func(result): 
		match_ended_emitted = true
		result_data = result
	)
	_controller.register_elimination(0, 5)
	assert_true(match_ended_emitted)
	# Placement should be alive_count + 1 after player death
	# alive_count after player elimination = 7, so placement = 7 + 1 = 8
	assert_eq(result_data.get("placement", -1), 8)


# --- end_match tests ---

func test_end_match_transitions_to_ended() -> void:
	_controller.start_match(_default_settings())
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	var result := {"kills": 5, "placement": 1, "survival_time_seconds": 300.0,
		"damage_dealt": 500.0, "character": "BLITZ", "variant": "MALE",
		"bot_difficulty": Enums.Difficulty.MEDIUM, "bot_count": 50,
		"total_participants": 51}
	_controller.end_match(result)
	assert_eq(_controller.match_state, Enums.MatchState.ENDED)


func test_end_match_emits_signal() -> void:
	_controller.start_match(_default_settings())
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	watch_signals(_controller)
	var result := {"kills": 3, "placement": 1}
	_controller.end_match(result)
	assert_signal_emitted(_controller, "match_ended")


func test_end_match_only_once() -> void:
	_controller.start_match(_default_settings())
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	var emit_count := 0
	_controller.match_ended.connect(func(_r): emit_count += 1)
	var result := {"kills": 3, "placement": 1}
	_controller.end_match(result)
	_controller.end_match(result)  # Second call should be ignored
	assert_eq(emit_count, 1)


# --- Match result data tests ---

func test_match_result_contains_required_fields() -> void:
	var settings := {
		"bot_count": 30,
		"bot_difficulty": Enums.Difficulty.HARD,
		"zone_speed": Enums.ZoneShrinkSpeed.FAST,
		"character": "PHANTOM",
		"variant": "FEMALE",
	}
	_controller.start_match(settings)
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	
	var result_data: Dictionary = {}
	_controller.match_ended.connect(func(result): result_data = result)
	
	# Simulate player winning
	for i in range(30):
		_controller.register_elimination(i + 1, 0)
		if _controller.match_state == Enums.MatchState.ENDED:
			break
	
	assert_has(result_data, "kills")
	assert_has(result_data, "placement")
	assert_has(result_data, "survival_time_seconds")
	assert_has(result_data, "damage_dealt")
	assert_has(result_data, "character")
	assert_has(result_data, "variant")
	assert_has(result_data, "bot_difficulty")
	assert_has(result_data, "bot_count")
	assert_has(result_data, "total_participants")


func test_match_result_character_from_settings() -> void:
	var settings := {
		"bot_count": 10,
		"bot_difficulty": Enums.Difficulty.EASY,
		"zone_speed": Enums.ZoneShrinkSpeed.SLOW,
		"character": "TITAN",
		"variant": "FEMALE",
	}
	_controller.start_match(settings)
	_controller.begin_drop_phase()
	_controller.end_drop_phase()
	
	var result_data: Dictionary = {}
	_controller.match_ended.connect(func(result): result_data = result)
	
	# Eliminate all bots
	for i in range(10):
		_controller.register_elimination(i + 1, 0)
		if _controller.match_state == Enums.MatchState.ENDED:
			break
	
	assert_eq(result_data.get("character"), "TITAN")
	assert_eq(result_data.get("variant"), "FEMALE")


# --- Utility method tests ---

func test_record_player_damage() -> void:
	_controller.start_match(_default_settings())
	_controller.record_player_damage(50.0)
	_controller.record_player_damage(30.0)
	assert_almost_eq(_controller.match_stats["damage_dealt"], 80.0, 0.001)


func test_get_match_state() -> void:
	assert_eq(_controller.get_match_state(), Enums.MatchState.LOBBY)
	_controller.start_match(_default_settings())
	assert_eq(_controller.get_match_state(), Enums.MatchState.DROP)


func test_get_alive_count() -> void:
	_controller.start_match(_default_settings(20))
	assert_eq(_controller.get_alive_count(), 21)


func test_is_player_alive() -> void:
	_controller.start_match(_default_settings())
	assert_true(_controller.is_player_alive())
