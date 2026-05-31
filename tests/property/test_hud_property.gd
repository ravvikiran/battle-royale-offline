## Property-based tests for HUD Manager.
## Generates random HUD states and event sequences, then verifies
## that HUD properties hold across all generated inputs.
##
## **Validates: Requirements 6.4, 8.4, 8.5, 8.6**
extends GutTest


## Number of random iterations per property test.
const ITERATIONS: int = 100


var _hud: HUDManager


func before_each() -> void:
	_hud = HUDManager.new()
	add_child(_hud)


func after_each() -> void:
	_hud.queue_free()


# --- Helper functions for random generation ---


## Generates a random boolean value.
func _random_bool() -> bool:
	return randi() % 2 == 0


## Generates a random normalized Vector2 direction.
func _random_direction_vector() -> Vector2:
	var angle := randf_range(0.0, TAU)
	return Vector2(cos(angle), sin(angle))


## Generates a random facing angle in degrees (0-360).
func _random_facing_angle() -> float:
	return randf_range(0.0, 360.0)


## Generates a random kill feed entry dictionary.
func _random_kill_feed_entry() -> Dictionary:
	var killers := ["Player", "Bot1", "Bot2", "Bot3", "Bot4", "Bot5"]
	var victims := ["Bot6", "Bot7", "Bot8", "Bot9", "Bot10", "Bot11"]
	var weapons := ["Volt Repeater", "Boomstick", "Buzzer", "Longshot", "Sideswipe"]
	return {
		"killer": killers[randi() % killers.size()],
		"victim": victims[randi() % victims.size()],
		"weapon": weapons[randi() % weapons.size()],
	}


## Generates a random number of kill feed entries to add (1-10).
func _random_entry_count() -> int:
	return randi_range(1, 10)


# --- Property 15: Storm indicators paired display ---
# For any HUD state while the player is in the storm, either both the damage
# indicator and directional guide are displayed, or neither is displayed.
# A state where only one is rendered SHALL NOT occur.

func test_property_15_storm_indicators_paired_display() -> void:
	gut.p("Property 15: Storm indicators paired display")
	gut.p("For any HUD state while in storm, both indicators are shown or neither.")
	gut.p("A state where only one is rendered SHALL NOT occur.")

	for i in range(ITERATIONS):
		# Generate random renderability states for both components
		var damage_renderable := _random_bool()
		var guide_renderable := _random_bool()
		var direction := _random_direction_vector()

		# Put the player in the storm
		_hud.show_storm_indicator(direction)

		# Apply random renderability states
		_hud.set_storm_damage_indicator_renderable(damage_renderable)
		_hud.set_storm_directional_guide_renderable(guide_renderable)

		# Verify paired display invariant:
		# storm_indicators_visible must be true ONLY if both are renderable
		var visible := _hud.are_storm_indicators_visible()
		var both_renderable := damage_renderable and guide_renderable

		if both_renderable:
			assert_true(visible,
				"[Iter %d] Both renderable (damage=%s, guide=%s) but indicators not visible" % [
					i, str(damage_renderable), str(guide_renderable)])
		else:
			assert_false(visible,
				"[Iter %d] Not both renderable (damage=%s, guide=%s) but indicators visible" % [
					i, str(damage_renderable), str(guide_renderable)])

		# Additional check: verify no partial state exists
		# The storm_indicators_visible flag is the single source of truth for both
		# components. If visible is true, both must be renderable. If false, at
		# least one is not renderable (or player is not in storm).
		assert_true(_hud.is_player_in_storm(),
			"[Iter %d] Player should be in storm" % [i])

		# Now test toggling back: restore both to renderable
		_hud.set_storm_damage_indicator_renderable(true)
		_hud.set_storm_directional_guide_renderable(true)
		assert_true(_hud.are_storm_indicators_visible(),
			"[Iter %d] Both restored to renderable but indicators not visible" % [i])

		# Test hiding storm (leaving storm) always hides both
		_hud.hide_storm_indicator()
		assert_false(_hud.are_storm_indicators_visible(),
			"[Iter %d] After hiding storm, indicators should not be visible" % [i])

		# Clean up and recreate for next iteration
		_hud.queue_free()
		_hud = HUDManager.new()
		add_child(_hud)


# --- Property 20: Kill feed queue management ---
# For any sequence of elimination events with timestamps, the kill feed SHALL
# display at most 5 entries at any given time, and each entry SHALL be removed
# exactly 5 seconds after it was added.

func test_property_20_kill_feed_queue_management() -> void:
	gut.p("Property 20: Kill feed queue management")
	gut.p("At most 5 entries at any time, each removed exactly 5 seconds after added.")

	for i in range(ITERATIONS):
		var entry_count := _random_entry_count()

		# Add a random number of entries
		for j in range(entry_count):
			_hud.add_kill_feed_entry(_random_kill_feed_entry())

		# Invariant: never more than 5 entries
		assert_lte(_hud.get_kill_feed_count(), HUDManager.MAX_KILL_FEED_ENTRIES,
			"[Iter %d] Kill feed has %d entries after adding %d, max is %d" % [
				i, _hud.get_kill_feed_count(), entry_count, HUDManager.MAX_KILL_FEED_ENTRIES])

		# Verify entries persist just before 5 seconds
		var count_before_timeout := _hud.get_kill_feed_count()
		if count_before_timeout > 0:
			_hud._process(4.9)
			assert_eq(_hud.get_kill_feed_count(), count_before_timeout,
				"[Iter %d] Entries should persist before 5s timeout (at 4.9s)" % [i])

		# Verify all entries are removed after 5 seconds total
		# We already advanced 4.9s, so advance 0.2 more (total 5.1s)
		_hud._process(0.2)
		assert_eq(_hud.get_kill_feed_count(), 0,
			"[Iter %d] All entries should be removed after 5.1s total" % [i])

		# Clean up and recreate for next iteration
		_hud.queue_free()
		_hud = HUDManager.new()
		add_child(_hud)


# --- Property 20 (continued): Staggered entry removal ---
# Entries added at different times should each be removed 5 seconds after
# their individual addition time.

func test_property_20_kill_feed_staggered_removal() -> void:
	gut.p("Property 20 (staggered): Each entry removed 5s after its own addition time.")

	for i in range(ITERATIONS):
		# Add first entry
		_hud.add_kill_feed_entry(_random_kill_feed_entry())
		assert_eq(_hud.get_kill_feed_count(), 1,
			"[Iter %d] Should have 1 entry after first add" % [i])

		# Advance 2.5 seconds, then add second entry
		_hud._process(2.5)
		_hud.add_kill_feed_entry(_random_kill_feed_entry())
		assert_eq(_hud.get_kill_feed_count(), 2,
			"[Iter %d] Should have 2 entries after second add" % [i])

		# Advance 2.6 seconds (total 5.1s from first entry)
		# First entry should be removed, second should remain
		_hud._process(2.6)
		assert_eq(_hud.get_kill_feed_count(), 1,
			"[Iter %d] First entry should be removed at 5.1s, second remains" % [i])

		# Advance 2.5 more seconds (total 5.1s from second entry)
		_hud._process(2.5)
		assert_eq(_hud.get_kill_feed_count(), 0,
			"[Iter %d] Second entry should be removed at its 5s mark" % [i])

		# Clean up and recreate for next iteration
		_hud.queue_free()
		_hud = HUDManager.new()
		add_child(_hud)


# --- Property 22: Compass heading calculation ---
# For any player facing direction (0-360 degrees), the compass SHALL display
# the correct degree heading and position cardinal direction markers (N, S, E, W)
# at their correct relative positions.

func test_property_22_compass_heading_calculation() -> void:
	gut.p("Property 22: Compass heading calculation")
	gut.p("For any facing angle, compass displays correct heading and cardinal positions.")

	for i in range(ITERATIONS):
		var facing := _random_facing_angle()

		_hud.update_compass(facing)

		# Verify heading is correctly normalized to [0, 360)
		var heading := _hud.get_compass_heading()
		assert_gte(heading, 0.0,
			"[Iter %d] Heading %f must be >= 0" % [i, heading])
		assert_lt(heading, 360.0,
			"[Iter %d] Heading %f must be < 360" % [i, heading])

		# Verify heading matches input (after normalization)
		var expected_heading := fmod(facing, 360.0)
		if expected_heading < 0.0:
			expected_heading += 360.0
		assert_almost_eq(heading, expected_heading, 0.001,
			"[Iter %d] Heading %f should equal normalized input %f" % [i, heading, expected_heading])

		# Verify cardinal direction is correct for the heading
		var cardinal := _hud.get_cardinal_direction(heading)
		if heading >= 315.0 or heading < 45.0:
			assert_eq(cardinal, "N",
				"[Iter %d] Heading %f should map to N, got %s" % [i, heading, cardinal])
		elif heading >= 45.0 and heading < 135.0:
			assert_eq(cardinal, "E",
				"[Iter %d] Heading %f should map to E, got %s" % [i, heading, cardinal])
		elif heading >= 135.0 and heading < 225.0:
			assert_eq(cardinal, "S",
				"[Iter %d] Heading %f should map to S, got %s" % [i, heading, cardinal])
		else:
			assert_eq(cardinal, "W",
				"[Iter %d] Heading %f should map to W, got %s" % [i, heading, cardinal])

		# Verify cardinal positions are at correct relative offsets
		var positions := _hud.get_all_cardinal_positions()
		assert_eq(positions.size(), 4,
			"[Iter %d] Should have exactly 4 cardinal positions" % [i])

		for pos_entry in positions:
			var label: String = pos_entry["label"]
			var angle: float = pos_entry["angle"]
			var position: float = pos_entry["position"]

			# Verify position is within [-180, 180]
			assert_gte(position, -180.0,
				"[Iter %d] Cardinal %s position %f must be >= -180" % [i, label, position])
			assert_lte(position, 180.0,
				"[Iter %d] Cardinal %s position %f must be <= 180" % [i, label, position])

			# Verify position calculation: diff = cardinal_angle - heading, normalized to [-180, 180]
			var expected_diff := angle - heading
			while expected_diff > 180.0:
				expected_diff -= 360.0
			while expected_diff < -180.0:
				expected_diff += 360.0
			assert_almost_eq(position, expected_diff, 0.001,
				"[Iter %d] Cardinal %s position %f should equal expected %f (angle=%f, heading=%f)" % [
					i, label, position, expected_diff, angle, heading])

		# Clean up and recreate for next iteration
		_hud.queue_free()
		_hud = HUDManager.new()
		add_child(_hud)


# --- Property 22 (continued): Compass handles edge angles ---
# Verify compass correctly handles negative angles and angles > 360.

func test_property_22_compass_normalizes_arbitrary_angles() -> void:
	gut.p("Property 22 (normalization): Compass normalizes arbitrary angles correctly.")

	for i in range(ITERATIONS):
		# Generate angles outside normal range: [-720, 720]
		var raw_angle := randf_range(-720.0, 720.0)

		_hud.update_compass(raw_angle)

		var heading := _hud.get_compass_heading()

		# Heading must always be in [0, 360)
		assert_gte(heading, 0.0,
			"[Iter %d] Heading %f must be >= 0 (input: %f)" % [i, heading, raw_angle])
		assert_lt(heading, 360.0,
			"[Iter %d] Heading %f must be < 360 (input: %f)" % [i, heading, raw_angle])

		# Verify it matches the expected normalization
		var expected := fmod(raw_angle, 360.0)
		if expected < 0.0:
			expected += 360.0
		assert_almost_eq(heading, expected, 0.001,
			"[Iter %d] Heading %f should equal normalized %f (input: %f)" % [
				i, heading, expected, raw_angle])

		# Cardinal positions should still be valid
		var positions := _hud.get_all_cardinal_positions()
		for pos_entry in positions:
			var position: float = pos_entry["position"]
			assert_gte(position, -180.0,
				"[Iter %d] Position %f must be >= -180" % [i, position])
			assert_lte(position, 180.0,
				"[Iter %d] Position %f must be <= 180" % [i, position])

		# Clean up and recreate for next iteration
		_hud.queue_free()
		_hud = HUDManager.new()
		add_child(_hud)
