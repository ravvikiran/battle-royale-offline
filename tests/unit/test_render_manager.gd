## Unit tests for RenderManager adaptive quality system.
## Tests quality presets, memory-based adaptation, and indicator behavior.
extends GutTest


var render_manager: RenderManager


func before_each() -> void:
	render_manager = RenderManager.new()
	add_child_autofree(render_manager)


# --- Quality Preset Tests ---


func test_default_preset_is_medium() -> void:
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.MEDIUM)
	assert_eq(render_manager.draw_distance, 300.0)
	assert_eq(render_manager.shadow_quality, 1)
	assert_almost_eq(render_manager.particle_density, 0.6, 0.001)


func test_set_quality_preset_low() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.LOW)
	assert_eq(render_manager.draw_distance, 150.0)
	assert_eq(render_manager.shadow_quality, 0)
	assert_almost_eq(render_manager.particle_density, 0.25, 0.001)


func test_set_quality_preset_high() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.HIGH)
	assert_eq(render_manager.draw_distance, 500.0)
	assert_eq(render_manager.shadow_quality, 2)
	assert_almost_eq(render_manager.particle_density, 1.0, 0.001)


func test_get_preset_settings_returns_correct_values() -> void:
	var low_settings := render_manager.get_preset_settings(RenderManager.QualityPreset.LOW)
	assert_eq(low_settings["draw_distance"], 150.0)
	assert_eq(low_settings["shadow_quality"], 0)
	assert_eq(low_settings["label"], "Low")

	var high_settings := render_manager.get_preset_settings(RenderManager.QualityPreset.HIGH)
	assert_eq(high_settings["draw_distance"], 500.0)
	assert_eq(high_settings["shadow_quality"], 2)
	assert_eq(high_settings["label"], "High")


func test_get_current_preset_label() -> void:
	assert_eq(render_manager.get_current_preset_label(), "Medium")
	render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)
	assert_eq(render_manager.get_current_preset_label(), "Low")
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	assert_eq(render_manager.get_current_preset_label(), "High")


# --- Memory Monitoring Tests ---


func test_start_match_monitoring() -> void:
	render_manager.start_match_monitoring()
	assert_true(render_manager.is_match_monitoring_active())
	assert_false(render_manager.was_quality_auto_reduced())
	assert_false(render_manager.was_critical_warning_shown())


func test_stop_match_monitoring() -> void:
	render_manager.start_match_monitoring()
	render_manager.stop_match_monitoring()
	assert_false(render_manager.is_match_monitoring_active())


# --- Adaptive Quality Reduction Tests ---


func test_reduce_quality_when_memory_below_200mb_from_high() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	render_manager.start_match_monitoring()

	var result := render_manager.check_memory_and_adapt(180)
	assert_eq(result["action"], "quality_reduced")
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.MEDIUM)
	assert_true(render_manager.was_quality_auto_reduced())


func test_reduce_quality_when_memory_below_200mb_from_medium() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.MEDIUM)
	render_manager.start_match_monitoring()

	var result := render_manager.check_memory_and_adapt(150)
	assert_eq(result["action"], "quality_reduced")
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.LOW)
	assert_true(render_manager.was_quality_auto_reduced())


func test_no_reduction_when_already_at_lowest_and_above_critical() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)
	render_manager.start_match_monitoring()

	var result := render_manager.check_memory_and_adapt(150)
	assert_eq(result["action"], "none")
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.LOW)


func test_no_reduction_when_memory_above_threshold() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	render_manager.start_match_monitoring()

	var result := render_manager.check_memory_and_adapt(250)
	assert_eq(result["action"], "none")
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.HIGH)


func test_no_action_when_match_not_active() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	# Do NOT start match monitoring

	var result := render_manager.check_memory_and_adapt(50)
	assert_eq(result["action"], "none")
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.HIGH)


func test_reduces_by_exactly_one_level() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	render_manager.start_match_monitoring()

	# First reduction: HIGH → MEDIUM
	var result := render_manager.check_memory_and_adapt(180)
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.MEDIUM)

	# Second reduction: MEDIUM → LOW
	result = render_manager.check_memory_and_adapt(180)
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.LOW)


# --- Critical Memory Tests ---


func test_critical_memory_at_lowest_preset() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)
	render_manager.start_match_monitoring()

	var result := render_manager.check_memory_and_adapt(80)
	assert_eq(result["action"], "critical_warning")
	assert_true(render_manager.was_critical_warning_shown())


func test_critical_warning_only_shown_once() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)
	render_manager.start_match_monitoring()

	var result1 := render_manager.check_memory_and_adapt(80)
	assert_eq(result1["action"], "critical_warning")

	var result2 := render_manager.check_memory_and_adapt(50)
	assert_eq(result2["action"], "none")


func test_critical_memory_not_triggered_above_threshold() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)
	render_manager.start_match_monitoring()

	var result := render_manager.check_memory_and_adapt(120)
	assert_eq(result["action"], "none")
	assert_false(render_manager.was_critical_warning_shown())


func test_critical_memory_not_triggered_when_not_at_lowest() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.MEDIUM)
	render_manager.start_match_monitoring()

	# Memory below 100 but not at lowest preset — should reduce quality instead
	var result := render_manager.check_memory_and_adapt(80)
	assert_eq(result["action"], "quality_reduced")
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.LOW)
	assert_false(render_manager.was_critical_warning_shown())


# --- Match State Preservation Tests ---


func test_set_and_get_preserved_match_state() -> void:
	var state := {"player_health": 75.0, "alive_count": 12, "phase": 3}
	render_manager.set_match_state_for_preservation(state)

	var retrieved := render_manager.get_preserved_match_state()
	assert_eq(retrieved["player_health"], 75.0)
	assert_eq(retrieved["alive_count"], 12)
	assert_eq(retrieved["phase"], 3)


# --- Quality Indicator Tests ---


func test_quality_indicator_shown_on_reduction() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	render_manager.start_match_monitoring()

	render_manager.check_memory_and_adapt(150)
	assert_true(render_manager.is_quality_indicator_visible())


func test_quality_indicator_hides_after_duration() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	render_manager.start_match_monitoring()

	render_manager.check_memory_and_adapt(150)
	assert_true(render_manager.is_quality_indicator_visible())

	# Simulate time passing beyond indicator duration
	render_manager._process(RenderManager.QUALITY_INDICATOR_DURATION + 0.1)
	assert_false(render_manager.is_quality_indicator_visible())


# --- Signal Tests ---


func test_quality_reduced_signal_emitted() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	render_manager.start_match_monitoring()
	watch_signals(render_manager)

	render_manager.check_memory_and_adapt(150)
	assert_signal_emitted(render_manager, "quality_reduced")


func test_critical_memory_warning_signal_emitted() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)
	render_manager.start_match_monitoring()
	watch_signals(render_manager)

	render_manager.check_memory_and_adapt(80)
	assert_signal_emitted(render_manager, "critical_memory_warning")


func test_quality_indicator_shown_signal_emitted() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.MEDIUM)
	render_manager.start_match_monitoring()
	watch_signals(render_manager)

	render_manager.check_memory_and_adapt(150)
	assert_signal_emitted(render_manager, "quality_indicator_shown")


# --- Constants Verification Tests ---


func test_memory_thresholds_are_correct() -> void:
	assert_eq(RenderManager.MEMORY_THRESHOLD_REDUCE, 200)
	assert_eq(RenderManager.MEMORY_THRESHOLD_CRITICAL, 100)


func test_performance_targets_are_correct() -> void:
	assert_eq(RenderManager.TARGET_FPS, 30)
	assert_eq(RenderManager.MAX_INSTALLED_SIZE_MB, 500)
	assert_eq(RenderManager.MIN_ANDROID_API, 26)
	assert_eq(RenderManager.MAX_MAP_LOAD_TIME_SECONDS, 15.0)
	assert_eq(RenderManager.MAX_VISIBLE_BOTS, 20)


# --- Edge Case Tests ---


func test_memory_exactly_at_200mb_does_not_reduce() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	render_manager.start_match_monitoring()

	var result := render_manager.check_memory_and_adapt(200)
	assert_eq(result["action"], "none")
	assert_eq(render_manager.current_preset, RenderManager.QualityPreset.HIGH)


func test_memory_exactly_at_100mb_at_lowest_does_not_trigger_critical() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)
	render_manager.start_match_monitoring()

	var result := render_manager.check_memory_and_adapt(100)
	assert_eq(result["action"], "none")
	assert_false(render_manager.was_critical_warning_shown())


func test_memory_at_199mb_triggers_reduction() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	render_manager.start_match_monitoring()

	var result := render_manager.check_memory_and_adapt(199)
	assert_eq(result["action"], "quality_reduced")


func test_memory_at_99mb_at_lowest_triggers_critical() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)
	render_manager.start_match_monitoring()

	var result := render_manager.check_memory_and_adapt(99)
	assert_eq(result["action"], "critical_warning")


func test_reset_state_on_new_match() -> void:
	render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)
	render_manager.start_match_monitoring()
	render_manager.check_memory_and_adapt(80)
	assert_true(render_manager.was_critical_warning_shown())

	# Start a new match — state should reset
	render_manager.stop_match_monitoring()
	render_manager.set_quality_preset(RenderManager.QualityPreset.HIGH)
	render_manager.start_match_monitoring()
	assert_false(render_manager.was_critical_warning_shown())
	assert_false(render_manager.was_quality_auto_reduced())
