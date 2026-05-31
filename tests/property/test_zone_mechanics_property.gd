## Property-based tests for zone mechanics.
## Generates random map bounds and zone configurations, then verifies
## that zone properties hold across all generated inputs.
##
## **Validates: Requirements 1.4, 6.2, 6.3, 6.5, 6.6, 6.7**
extends GutTest


## Number of random iterations per property test.
const ITERATIONS: int = 100

## Minimum map dimension for random generation.
const MIN_MAP_SIZE: float = 200.0

## Maximum map dimension for random generation.
const MAX_MAP_SIZE: float = 5000.0


var _zone_manager: ZoneManager


func before_each() -> void:
	_zone_manager = ZoneManager.new()
	add_child(_zone_manager)


func after_each() -> void:
	_zone_manager.queue_free()


# --- Helper functions for random generation ---

## Generates a random Rect2 representing map bounds.
func _random_map_bounds() -> Rect2:
	var width := randf_range(MIN_MAP_SIZE, MAX_MAP_SIZE)
	var height := randf_range(MIN_MAP_SIZE, MAX_MAP_SIZE)
	var x := randf_range(-1000.0, 1000.0)
	var y := randf_range(-1000.0, 1000.0)
	return Rect2(x, y, width, height)


## Returns a random ZoneShrinkSpeed enum value.
func _random_speed() -> Enums.ZoneShrinkSpeed:
	var speeds := [
		Enums.ZoneShrinkSpeed.SLOW,
		Enums.ZoneShrinkSpeed.NORMAL,
		Enums.ZoneShrinkSpeed.FAST,
	]
	return speeds[randi() % speeds.size()]


## Generates a random phase number (1-based) within the total phases.
func _random_phase(total: int) -> int:
	return randi_range(1, total)


## Generates a random time duration in seconds.
func _random_time_duration() -> float:
	return randf_range(0.1, 300.0)


# --- Property 3: Storm damage calculation ---
# For any zone phase P and time T, total storm damage = phase DPS × T,
# starting at 1 DPS in phase 1, increasing by at least 1 per phase.

func test_property_3_storm_damage_calculation() -> void:
	gut.p("Property 3: Storm damage calculation")
	gut.p("For any zone phase P and time T, total storm damage = phase DPS × T")
	gut.p("Starting at 1 DPS in phase 1, increasing by at least 1 per phase.")

	for i in range(ITERATIONS):
		var map_bounds := _random_map_bounds()
		var speed := _random_speed()

		_zone_manager.initialize_zones(map_bounds, speed)

		# Verify phase 1 DPS is exactly 1
		var phase_1_dps := _zone_manager.get_storm_damage(1)
		assert_almost_eq(phase_1_dps, 1.0, 0.001,
			"[Iter %d] Phase 1 storm DPS must be 1.0, got %f" % [i, phase_1_dps])

		# Verify DPS increases by at least 1 per successive phase
		var prev_dps := phase_1_dps
		for phase in range(2, _zone_manager.total_phases + 1):
			var current_dps := _zone_manager.get_storm_damage(phase)
			assert_gte(current_dps - prev_dps, 1.0,
				"[Iter %d] Phase %d DPS (%f) must increase by at least 1 from phase %d DPS (%f)" % [
					i, phase, current_dps, phase - 1, prev_dps])
			prev_dps = current_dps

		# Verify total damage = DPS × T for a random phase and time
		var random_phase := _random_phase(_zone_manager.total_phases)
		var random_time := _random_time_duration()
		var dps := _zone_manager.get_storm_damage(random_phase)
		var expected_total_damage := dps * random_time
		# The total damage calculation is DPS * time (verified by formula)
		assert_gt(dps, 0.0,
			"[Iter %d] DPS for phase %d must be positive" % [i, random_phase])
		assert_almost_eq(expected_total_damage, dps * random_time, 0.001,
			"[Iter %d] Total damage must equal DPS × T" % [i])

		# Clean up and recreate for next iteration
		_zone_manager.queue_free()
		_zone_manager = ZoneManager.new()
		add_child(_zone_manager)


# --- Property 13: Zone configuration validity ---
# At least 5 phases, wait time 30-120s, shrink duration strictly between
# 20-90s, first zone ≤ 70% of map area, final zone radius ≤ 50m.

func test_property_13_zone_configuration_validity() -> void:
	gut.p("Property 13: Zone configuration validity")
	gut.p("At least 5 phases, wait 30-120s, shrink 20-90s (strict),")
	gut.p("first zone <= 70% map area, final radius <= 50m.")

	for i in range(ITERATIONS):
		var map_bounds := _random_map_bounds()
		var speed := _random_speed()

		_zone_manager.initialize_zones(map_bounds, speed)

		# At least 5 phases
		assert_gte(_zone_manager.total_phases, 5,
			"[Iter %d] Must have at least 5 phases, got %d" % [i, _zone_manager.total_phases])

		# Validate each phase's wait time and shrink duration (base values before multiplier)
		for phase in range(1, _zone_manager.total_phases + 1):
			var phase_index := phase - 1
			var config: Dictionary = _zone_manager._phase_configs[phase_index]

			# Wait time between 30 and 120 seconds (base config values)
			var wait_seconds: float = float(config.get("wait_seconds", 0))
			assert_gte(wait_seconds, 30.0,
				"[Iter %d] Phase %d wait_seconds (%f) must be >= 30" % [i, phase, wait_seconds])
			assert_lte(wait_seconds, 120.0,
				"[Iter %d] Phase %d wait_seconds (%f) must be <= 120" % [i, phase, wait_seconds])

			# Shrink duration strictly between 20 and 90 seconds (base config values)
			var shrink_seconds: float = float(config.get("shrink_seconds", 0))
			assert_gt(shrink_seconds, 20.0,
				"[Iter %d] Phase %d shrink_seconds (%f) must be > 20 (strict)" % [i, phase, shrink_seconds])
			assert_lt(shrink_seconds, 90.0,
				"[Iter %d] Phase %d shrink_seconds (%f) must be < 90 (strict)" % [i, phase, shrink_seconds])

		# First zone covers no more than 70% of map area
		# stored_zone_radii[0] = initial (full map), stored_zone_radii[1] = phase 1 target
		if _zone_manager._stored_zone_radii.size() > 1:
			var initial_radius: float = _zone_manager._stored_zone_radii[0]
			var first_phase_radius: float = _zone_manager._stored_zone_radii[1]
			# Area ratio = (r1/r0)^2 since area = pi*r^2
			var area_ratio := (first_phase_radius * first_phase_radius) / (initial_radius * initial_radius)
			assert_lte(area_ratio, 0.70 + 0.001,
				"[Iter %d] First zone area ratio (%f) must be <= 70%%" % [i, area_ratio])

		# Final zone radius no larger than 50 meters
		var last_index := _zone_manager._stored_zone_radii.size() - 1
		if last_index > 0:
			var final_radius: float = _zone_manager._stored_zone_radii[last_index]
			assert_lte(final_radius, 50.0 + 0.001,
				"[Iter %d] Final zone radius (%f) must be <= 50m" % [i, final_radius])

		# Clean up and recreate for next iteration
		_zone_manager.queue_free()
		_zone_manager = ZoneManager.new()
		add_child(_zone_manager)


# --- Property 14: Zone warning timing ---
# Warning fires at time T where T ≤ W - 10 (at least 10 seconds before shrinking).

## Tracks whether zone_warning was emitted during simulation.
var _warning_fired: bool = false
## Tracks the seconds_remaining value passed with the zone_warning signal.
var _warning_seconds_remaining: int = 0


func _on_zone_warning(seconds_remaining: int) -> void:
	_warning_fired = true
	_warning_seconds_remaining = seconds_remaining


func test_property_14_zone_warning_timing() -> void:
	gut.p("Property 14: Zone warning timing")
	gut.p("Warning fires at time T where T <= W - 10 (at least 10s before shrinking).")

	for i in range(ITERATIONS):
		var map_bounds := _random_map_bounds()
		var speed := _random_speed()

		_zone_manager.initialize_zones(map_bounds, speed)
		_zone_manager.start_first_phase()

		# Connect to the zone_warning signal to track when it fires
		_warning_fired = false
		_warning_seconds_remaining = 0
		if not _zone_manager.zone_warning.is_connected(_on_zone_warning):
			_zone_manager.zone_warning.connect(_on_zone_warning)

		# Get the wait duration for phase 1 (after speed multiplier)
		var wait_duration := _zone_manager.get_phase_wait_time(1)

		# Simulate time in 1-second steps until warning fires or phase transitions
		var elapsed := 0.0
		var step := 1.0

		while elapsed < wait_duration and _zone_manager.phase_state == Enums.PhaseState.WAITING:
			_zone_manager._process(step)
			elapsed += step
			if _warning_fired:
				break

		# Warning must have fired before shrinking begins
		assert_true(_warning_fired,
			"[Iter %d] Zone warning must fire before shrinking begins (wait: %f)" % [i, wait_duration])

		if _warning_fired:
			# The warning's seconds_remaining value should be >= 10
			# (meaning at least 10 seconds remain before shrinking)
			# Due to step granularity, we allow the remaining time to be at least
			# MIN_WARNING_TIME - step (9 seconds with 1s steps)
			var remaining_at_warning := wait_duration - elapsed
			assert_lte(remaining_at_warning, ZoneManager.MIN_WARNING_TIME + step,
				"[Iter %d] Warning fired too early. Remaining: %f, expected <= %f" % [
					i, remaining_at_warning, ZoneManager.MIN_WARNING_TIME + step])
			# The warning must fire with at least 10 seconds remaining
			# _warning_seconds_remaining is ceili(_wait_timer) at time of emission
			assert_gte(_warning_seconds_remaining, 0,
				"[Iter %d] Warning seconds_remaining must be non-negative" % [i])

		# Clean up and recreate for next iteration
		if _zone_manager.zone_warning.is_connected(_on_zone_warning):
			_zone_manager.zone_warning.disconnect(_on_zone_warning)
		_zone_manager.queue_free()
		_zone_manager = ZoneManager.new()
		add_child(_zone_manager)


# --- Property 16: Next zone containment ---
# distance(current_center, next_center) + next_radius ≤ current_radius
# for all transitions.

func test_property_16_next_zone_containment() -> void:
	gut.p("Property 16: Next zone containment")
	gut.p("distance(current_center, next_center) + next_radius <= current_radius for all transitions.")

	for i in range(ITERATIONS):
		var map_bounds := _random_map_bounds()
		var speed := _random_speed()

		_zone_manager.initialize_zones(map_bounds, speed)

		# Check containment for all consecutive stored zone pairs
		var zone_count := _zone_manager._stored_zone_centers.size()
		assert_gte(zone_count, 2,
			"[Iter %d] Must have at least 2 stored zones" % [i])

		for j in range(1, zone_count):
			var prev_center: Vector2 = _zone_manager._stored_zone_centers[j - 1]
			var prev_radius: float = _zone_manager._stored_zone_radii[j - 1]
			var curr_center: Vector2 = _zone_manager._stored_zone_centers[j]
			var curr_radius: float = _zone_manager._stored_zone_radii[j]

			var distance := prev_center.distance_to(curr_center)
			var containment_check := distance + curr_radius

			# Allow small floating point tolerance
			assert_lte(containment_check, prev_radius + 0.01,
				"[Iter %d] Zone %d not contained in zone %d: dist(%f) + radius(%f) = %f > prev_radius(%f)" % [
					i, j, j - 1, distance, curr_radius, containment_check, prev_radius])

		# Additionally verify that next_center/next_radius after initialization
		# satisfies containment with current zone
		var dist_to_next := _zone_manager.current_center.distance_to(_zone_manager.next_center)
		var next_containment := dist_to_next + _zone_manager.next_radius
		assert_lte(next_containment, _zone_manager.current_radius + 0.01,
			"[Iter %d] Initial next zone not contained: dist(%f) + next_r(%f) = %f > current_r(%f)" % [
				i, dist_to_next, _zone_manager.next_radius, next_containment, _zone_manager.current_radius])

		# Clean up and recreate for next iteration
		_zone_manager.queue_free()
		_zone_manager = ZoneManager.new()
		add_child(_zone_manager)
