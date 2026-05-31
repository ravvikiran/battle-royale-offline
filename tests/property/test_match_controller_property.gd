## Property-based tests for match controller.
## Generates random match configurations and elimination sequences, then verifies
## that match controller properties hold across all generated inputs.
##
## **Validates: Requirements 1.1, 1.2, 1.8, 8.5**
extends GutTest


## Number of random iterations per property test.
const ITERATIONS: int = 100

## Valid bot count range per requirements.
const MIN_BOT_COUNT: int = 10
const MAX_BOT_COUNT: int = 99


var _controller: MatchController


func before_each() -> void:
	_controller = MatchController.new()
	add_child(_controller)


func after_each() -> void:
	_controller.queue_free()


# --- Helper functions for random generation ---


## Generates a random valid bot count (10-99).
func _random_bot_count() -> int:
	return randi_range(MIN_BOT_COUNT, MAX_BOT_COUNT)


## Generates random match settings with a given bot count.
func _random_settings(bot_count: int) -> Dictionary:
	var difficulties := [
		Enums.Difficulty.EASY,
		Enums.Difficulty.MEDIUM,
		Enums.Difficulty.HARD,
	]
	var speeds := [
		Enums.ZoneShrinkSpeed.SLOW,
		Enums.ZoneShrinkSpeed.NORMAL,
		Enums.ZoneShrinkSpeed.FAST,
	]
	var characters := ["BLITZ", "TITAN", "PHANTOM"]
	var variants := ["MALE", "FEMALE"]

	return {
		"bot_count": bot_count,
		"bot_difficulty": difficulties[randi() % difficulties.size()],
		"zone_speed": speeds[randi() % speeds.size()],
		"character": characters[randi() % characters.size()],
		"variant": variants[randi() % variants.size()],
	}


## Generates a random number of eliminations (1 to max_eliminations).
func _random_elimination_count(max_eliminations: int) -> int:
	if max_eliminations <= 0:
		return 0
	return randi_range(1, max_eliminations)


# --- Property 1: Match spawn correctness ---
# For any valid bot count (10-99), total spawned participants = bot_count + 1,
# all bot positions within map boundaries.

func test_property_1_match_spawn_correctness() -> void:
	gut.p("Property 1: Match spawn correctness")
	gut.p("For any valid bot count (10-99), total spawned participants = bot_count + 1,")
	gut.p("all bot positions within map boundaries.")

	for i in range(ITERATIONS):
		var bot_count := _random_bot_count()
		var settings := _random_settings(bot_count)

		_controller.start_match(settings)

		# Verify total participants = bot_count + 1
		assert_eq(_controller.total_participants, bot_count + 1,
			"[Iter %d] Total participants must be bot_count(%d) + 1 = %d, got %d" % [
				i, bot_count, bot_count + 1, _controller.total_participants])

		# Verify alive count matches total participants at start
		assert_eq(_controller.alive_count, bot_count + 1,
			"[Iter %d] Alive count at start must equal total participants (%d), got %d" % [
				i, bot_count + 1, _controller.alive_count])

		# Verify the correct number of bots were spawned
		assert_eq(_controller.bot_ai_manager.bots.size(), bot_count,
			"[Iter %d] Bot count must be %d, got %d" % [
				i, bot_count, _controller.bot_ai_manager.bots.size()])

		# Distribute bots and verify positions are within map boundaries
		_controller.begin_drop_phase()
		_controller.end_drop_phase()

		var map_bounds: Rect2 = _controller.map_data.get_map_bounds()
		for bot in _controller.bot_ai_manager.bots:
			var pos: Vector2 = bot.position
			# Check position is within map bounds (with small floating point tolerance)
			assert_gte(pos.x, map_bounds.position.x - 0.01,
				"[Iter %d] Bot %d x-position (%f) must be >= map left (%f)" % [
					i, bot.id, pos.x, map_bounds.position.x])
			assert_lte(pos.x, map_bounds.position.x + map_bounds.size.x + 0.01,
				"[Iter %d] Bot %d x-position (%f) must be <= map right (%f)" % [
					i, bot.id, pos.x, map_bounds.position.x + map_bounds.size.x])
			assert_gte(pos.y, map_bounds.position.y - 0.01,
				"[Iter %d] Bot %d y-position (%f) must be >= map top (%f)" % [
					i, bot.id, pos.y, map_bounds.position.y])
			assert_lte(pos.y, map_bounds.position.y + map_bounds.size.y + 0.01,
				"[Iter %d] Bot %d y-position (%f) must be <= map bottom (%f)" % [
					i, bot.id, pos.y, map_bounds.position.y + map_bounds.size.y])

		# Clean up and recreate for next iteration
		_controller.queue_free()
		_controller = MatchController.new()
		add_child(_controller)


# --- Property 2: Auto-drop position validity ---
# For any zone config and map bounds, auto-assigned landing position
# is within current safe zone boundary.

func test_property_2_auto_drop_position_validity() -> void:
	gut.p("Property 2: Auto-drop position validity")
	gut.p("For any zone config and map bounds, auto-assigned landing position")
	gut.p("is within current safe zone boundary.")

	for i in range(ITERATIONS):
		var bot_count := _random_bot_count()
		var settings := _random_settings(bot_count)

		# Set up zone manager so auto-drop uses safe zone logic
		var zone_manager := ZoneManager.new()
		add_child(zone_manager)
		_controller.zone_manager = zone_manager

		_controller.start_match(settings)

		# Begin drop phase but do NOT select a position (simulating timeout)
		_controller.begin_drop_phase()

		# End drop phase without player selecting a position — triggers auto-drop
		assert_false(_controller.player_has_dropped,
			"[Iter %d] Player should not have dropped yet" % [i])
		_controller.end_drop_phase()

		# Verify player was auto-dropped
		assert_true(_controller.player_has_dropped,
			"[Iter %d] Player must be auto-dropped when timer expires" % [i])

		# Verify the auto-drop position is within the safe zone
		var player_pos: Vector2 = _controller.player_position

		if zone_manager.current_radius > 0.0:
			# Position must be within the zone circle
			var distance_from_center := player_pos.distance_to(zone_manager.current_center)
			assert_lte(distance_from_center, zone_manager.current_radius + 0.01,
				"[Iter %d] Auto-drop position distance (%f) must be <= zone radius (%f). Pos: %s, Center: %s" % [
					i, distance_from_center, zone_manager.current_radius,
					str(player_pos), str(zone_manager.current_center)])
		else:
			# Fallback: position should be near map center
			var map_center := _controller.map_data.get_map_bounds().get_center()
			var distance_from_map_center := player_pos.distance_to(map_center)
			# Fallback uses ±100 offset from center
			assert_lte(distance_from_map_center, 150.0,
				"[Iter %d] Fallback auto-drop position must be near map center" % [i])

		# Clean up
		zone_manager.queue_free()
		_controller.queue_free()
		_controller = MatchController.new()
		add_child(_controller)


# --- Property 21: Alive count tracking ---
# For any match starting with N participants and K eliminations,
# alive count = N - K.

func test_property_21_alive_count_tracking() -> void:
	gut.p("Property 21: Alive count tracking")
	gut.p("For any match starting with N participants and K eliminations,")
	gut.p("alive count = N - K.")

	for i in range(ITERATIONS):
		var bot_count := _random_bot_count()
		var settings := _random_settings(bot_count)

		_controller.start_match(settings)
		_controller.begin_drop_phase()
		_controller.end_drop_phase()

		var total_participants: int = _controller.total_participants
		var initial_alive: int = _controller.alive_count

		# Verify initial alive count equals total participants
		assert_eq(initial_alive, total_participants,
			"[Iter %d] Initial alive count must equal total participants (%d)" % [
				i, total_participants])

		# Generate a random number of eliminations (only bots, keep player alive)
		# Max eliminations: bot_count - 1 (leave at least 1 bot so match doesn't end)
		var max_elims := maxi(1, bot_count - 1)
		var num_eliminations := _random_elimination_count(mini(max_elims, 20))

		# Perform eliminations and verify alive count after each
		for k in range(num_eliminations):
			var victim_id: int = k + 1  # Bot IDs start at 0, but we use 1-based to avoid player (ID 0)
			var killer_id: int = 0  # Player kills

			_controller.register_elimination(victim_id, killer_id)

			var expected_alive: int = total_participants - (k + 1)
			assert_eq(_controller.alive_count, expected_alive,
				"[Iter %d] After %d eliminations, alive count must be %d, got %d" % [
					i, k + 1, expected_alive, _controller.alive_count])

			# If match ended due to victory, stop eliminating
			if _controller.match_state == Enums.MatchState.ENDED:
				break

		# Clean up and recreate for next iteration
		_controller.queue_free()
		_controller = MatchController.new()
		add_child(_controller)
