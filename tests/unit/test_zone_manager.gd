## Unit tests for ZoneManager: zone initialization, phase transitions,
## storm damage, spatial queries, and containment invariants.
extends GutTest


var _zone_manager: ZoneManager
var _map_bounds: Rect2


func before_each() -> void:
	_zone_manager = ZoneManager.new()
	add_child(_zone_manager)
	# Standard map: 1000x1000 centered at (500, 500)
	_map_bounds = Rect2(0, 0, 1000, 1000)


func after_each() -> void:
	_zone_manager.queue_free()


# --- Initialization tests ---

func test_initialize_zones_sets_total_phases_minimum_5() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	assert_gte(_zone_manager.total_phases, 5, "Should have at least 5 phases")


func test_initialize_zones_sets_initial_center_to_map_center() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	assert_almost_eq(_zone_manager.current_center.x, 500.0, 0.001)
	assert_almost_eq(_zone_manager.current_center.y, 500.0, 0.001)


func test_initialize_zones_sets_initial_radius_to_half_map_size() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	assert_almost_eq(_zone_manager.current_radius, 500.0, 0.001)


func test_initialize_zones_slow_speed() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.SLOW)
	assert_eq(_zone_manager.shrink_speed, Enums.ZoneShrinkSpeed.SLOW)


func test_initialize_zones_fast_speed() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.FAST)
	assert_eq(_zone_manager.shrink_speed, Enums.ZoneShrinkSpeed.FAST)


func test_initialize_zones_normal_speed() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	assert_eq(_zone_manager.shrink_speed, Enums.ZoneShrinkSpeed.NORMAL)


# --- Next zone containment tests ---

func test_next_zone_fully_contained_within_current() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	# Check that distance(current_center, next_center) + next_radius <= current_radius
	var distance := _zone_manager.current_center.distance_to(_zone_manager.next_center)
	var containment := distance + _zone_manager.next_radius
	assert_lte(containment, _zone_manager.current_radius + 0.001,
		"Next zone must be fully contained within current zone")


func test_all_stored_zones_satisfy_containment() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	# Check containment for all consecutive zone pairs
	for i in range(1, _zone_manager._stored_zone_centers.size()):
		var prev_center: Vector2 = _zone_manager._stored_zone_centers[i - 1]
		var prev_radius: float = _zone_manager._stored_zone_radii[i - 1]
		var curr_center: Vector2 = _zone_manager._stored_zone_centers[i]
		var curr_radius: float = _zone_manager._stored_zone_radii[i]
		var dist := prev_center.distance_to(curr_center)
		assert_lte(dist + curr_radius, prev_radius + 0.001,
			"Zone %d must be contained within zone %d" % [i, i - 1])


# --- Storm damage tests ---

func test_storm_damage_phase_1_is_1_dps() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var damage := _zone_manager.get_storm_damage(1)
	assert_almost_eq(damage, 1.0, 0.001, "Phase 1 storm damage should be 1 DPS")


func test_storm_damage_increases_each_phase() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var prev_damage := _zone_manager.get_storm_damage(1)
	for phase in range(2, _zone_manager.total_phases + 1):
		var damage := _zone_manager.get_storm_damage(phase)
		assert_gt(damage, prev_damage, "Phase %d damage should be greater than phase %d" % [phase, phase - 1])
		assert_gte(damage - prev_damage, 1.0, "Damage should increase by at least 1 per phase")
		prev_damage = damage


func test_storm_damage_phase_0_returns_zero() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var damage := _zone_manager.get_storm_damage(0)
	assert_almost_eq(damage, 0.0, 0.001, "Phase 0 should return 0 damage")


func test_storm_damage_negative_phase_returns_zero() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var damage := _zone_manager.get_storm_damage(-1)
	assert_almost_eq(damage, 0.0, 0.001, "Negative phase should return 0 damage")


# --- is_in_safe_zone tests ---

func test_center_is_in_safe_zone() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	assert_true(_zone_manager.is_in_safe_zone(_zone_manager.current_center),
		"Center of zone should be in safe zone")


func test_position_at_boundary_is_in_safe_zone() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var boundary_pos := _zone_manager.current_center + Vector2(_zone_manager.current_radius, 0)
	assert_true(_zone_manager.is_in_safe_zone(boundary_pos),
		"Position exactly at boundary should be in safe zone")


func test_position_outside_zone_is_not_safe() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var outside_pos := _zone_manager.current_center + Vector2(_zone_manager.current_radius + 10.0, 0)
	assert_false(_zone_manager.is_in_safe_zone(outside_pos),
		"Position outside zone should not be in safe zone")


func test_position_just_inside_zone_is_safe() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var inside_pos := _zone_manager.current_center + Vector2(_zone_manager.current_radius - 1.0, 0)
	assert_true(_zone_manager.is_in_safe_zone(inside_pos),
		"Position just inside boundary should be in safe zone")


# --- get_nearest_safe_point tests ---

func test_nearest_safe_point_inside_zone_returns_position() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var pos := _zone_manager.current_center + Vector2(10, 10)
	var result := _zone_manager.get_nearest_safe_point(pos)
	assert_almost_eq(result.x, pos.x, 0.001)
	assert_almost_eq(result.y, pos.y, 0.001)


func test_nearest_safe_point_outside_zone_returns_boundary_point() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var outside_pos := _zone_manager.current_center + Vector2(600, 0)
	var result := _zone_manager.get_nearest_safe_point(outside_pos)
	# Result should be on the boundary (distance from center == radius)
	var dist_from_center := result.distance_to(_zone_manager.current_center)
	assert_almost_eq(dist_from_center, _zone_manager.current_radius, 0.01,
		"Nearest safe point should be on the zone boundary")


func test_nearest_safe_point_direction_toward_zone() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var outside_pos := _zone_manager.current_center + Vector2(600, 0)
	var result := _zone_manager.get_nearest_safe_point(outside_pos)
	# The nearest point should be between the outside position and the center
	assert_lt(result.x, outside_pos.x, "Nearest safe point should be closer to center than outside position")


# --- Phase transition tests ---

func test_advance_phase_from_waiting_to_shrinking() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	_zone_manager.start_first_phase()
	assert_eq(_zone_manager.phase_state, Enums.PhaseState.WAITING)
	_zone_manager.advance_phase()
	assert_eq(_zone_manager.phase_state, Enums.PhaseState.SHRINKING)


func test_advance_phase_emits_shrink_started() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	_zone_manager.start_first_phase()
	watch_signals(_zone_manager)
	_zone_manager.advance_phase()
	assert_signal_emitted(_zone_manager, "zone_shrink_started")


func test_advance_phase_from_shrinking_emits_completed() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	_zone_manager.start_first_phase()
	_zone_manager.advance_phase()  # WAITING -> SHRINKING
	watch_signals(_zone_manager)
	_zone_manager.advance_phase()  # SHRINKING -> complete, next phase WAITING
	assert_signal_emitted(_zone_manager, "zone_shrink_completed")


func test_advance_phase_from_shrinking_moves_to_next_phase() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	_zone_manager.start_first_phase()
	assert_eq(_zone_manager.current_phase, 1)
	_zone_manager.advance_phase()  # WAITING -> SHRINKING
	_zone_manager.advance_phase()  # SHRINKING -> next phase WAITING
	assert_eq(_zone_manager.current_phase, 2)
	assert_eq(_zone_manager.phase_state, Enums.PhaseState.WAITING)


# --- Speed multiplier tests ---

func test_slow_speed_multiplier_increases_wait_time() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.SLOW)
	var wait_time := _zone_manager.get_phase_wait_time(1)
	# Phase 1 wait is 120s, SLOW multiplier is 1.5x = 180s
	assert_almost_eq(wait_time, 180.0, 0.001)


func test_normal_speed_multiplier_keeps_wait_time() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var wait_time := _zone_manager.get_phase_wait_time(1)
	# Phase 1 wait is 120s, NORMAL multiplier is 1.0x = 120s
	assert_almost_eq(wait_time, 120.0, 0.001)


func test_fast_speed_multiplier_decreases_wait_time() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.FAST)
	var wait_time := _zone_manager.get_phase_wait_time(1)
	# Phase 1 wait is 120s, FAST multiplier is 0.6x = 72s
	assert_almost_eq(wait_time, 72.0, 0.001)


func test_fast_speed_shrink_duration() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.FAST)
	var shrink_time := _zone_manager.get_phase_shrink_duration(1)
	# Phase 1 shrink is 60s, FAST multiplier is 0.6x = 36s
	assert_almost_eq(shrink_time, 36.0, 0.001)


# --- Zone warning tests ---

func test_zone_warning_fires_at_least_10_seconds_before_shrink() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	_zone_manager.start_first_phase()
	watch_signals(_zone_manager)
	
	# Simulate time passing until warning should fire
	# Phase 1 wait is 120s, warning should fire at or before 10s remaining
	# Simulate 110 seconds of waiting (1-second steps)
	for i in range(110):
		_zone_manager._process(1.0)
	
	# Warning should have been emitted by now (at 10s remaining)
	assert_signal_emitted(_zone_manager, "zone_warning")


# --- First zone coverage test ---

func test_first_zone_covers_no_more_than_70_percent_of_map() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	# The first phase target radius should be 70% of map radius
	# stored_zone_radii[1] is the phase 1 target
	if _zone_manager._stored_zone_radii.size() > 1:
		var first_phase_radius: float = _zone_manager._stored_zone_radii[1]
		var map_radius: float = _zone_manager._stored_zone_radii[0]
		var area_ratio := (first_phase_radius * first_phase_radius) / (map_radius * map_radius)
		assert_lte(area_ratio, 0.70 + 0.001,
			"First safe zone should cover no more than 70%% of map area")


# --- Final zone radius test ---

func test_final_zone_radius_no_larger_than_50_meters() -> void:
	_zone_manager.initialize_zones(_map_bounds, Enums.ZoneShrinkSpeed.NORMAL)
	var last_index := _zone_manager._stored_zone_radii.size() - 1
	if last_index > 0:
		var final_radius: float = _zone_manager._stored_zone_radii[last_index]
		# 5% of 500 = 25, which is <= 50
		assert_lte(final_radius, 50.0,
			"Final safe zone radius should be no larger than 50 meters")
