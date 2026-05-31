## Property-based test for adaptive quality reduction.
## **Validates: Requirements 13.5**
##
## Property 31: Adaptive quality reduction
## *For any* device memory state below 200MB during a match where the current
## graphics quality is not already at the lowest preset, the system SHALL reduce
## quality by exactly one preset level.
extends GutTest


## Number of random test iterations per property test.
const NUM_ITERATIONS := 100

## Memory threshold below which quality is reduced.
const MEMORY_THRESHOLD := 200

## Critical memory threshold at lowest preset.
const MEMORY_CRITICAL := 100


var _rng: RandomNumberGenerator
var _render_manager: RenderManager


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_render_manager = RenderManager.new()
	_render_manager.start_match_monitoring()


## Returns a random memory value below the reduction threshold (0 to 199).
func _random_memory_below_threshold() -> int:
	return _rng.randi_range(0, MEMORY_THRESHOLD - 1)


## Returns a random memory value at or above the reduction threshold (200+).
func _random_memory_at_or_above_threshold() -> int:
	return _rng.randi_range(MEMORY_THRESHOLD, 1024)


## Returns a random non-LOW preset (MEDIUM or HIGH).
func _random_non_low_preset() -> RenderManager.QualityPreset:
	if _rng.randi_range(0, 1) == 0:
		return RenderManager.QualityPreset.MEDIUM
	else:
		return RenderManager.QualityPreset.HIGH


## Returns the expected preset one level below the given preset.
func _one_level_below(preset: RenderManager.QualityPreset) -> RenderManager.QualityPreset:
	match preset:
		RenderManager.QualityPreset.HIGH:
			return RenderManager.QualityPreset.MEDIUM
		RenderManager.QualityPreset.MEDIUM:
			return RenderManager.QualityPreset.LOW
		_:
			return RenderManager.QualityPreset.LOW


# --- Property 31: Adaptive quality reduction ---

## Property test: For any memory < 200MB and preset != LOW, quality reduces by
## exactly one level.
func test_property_quality_reduces_by_one_level_below_threshold() -> void:
	gut.p("Property 31: Adaptive quality reduction - reduces by one level")
	gut.p("For any memory < 200MB and preset != LOW, quality SHALL reduce by exactly one level.")

	for i in range(NUM_ITERATIONS):
		# Reset render manager for each iteration
		_render_manager = RenderManager.new()
		_render_manager.start_match_monitoring()

		var preset := _random_non_low_preset()
		_render_manager.set_quality_preset(preset)

		var memory_mb := _random_memory_below_threshold()
		var expected_preset := _one_level_below(preset)

		var result := _render_manager.check_memory_and_adapt(memory_mb)

		assert_eq(_render_manager.current_preset, expected_preset,
			"[Iter %d] Preset was %s with memory %dMB, expected reduction to %s, got %s" % [
				i, RenderManager.QualityPreset.keys()[preset],
				memory_mb,
				RenderManager.QualityPreset.keys()[expected_preset],
				RenderManager.QualityPreset.keys()[_render_manager.current_preset]])

		assert_eq(result["action"], "quality_reduced",
			"[Iter %d] Action should be 'quality_reduced' when memory=%dMB and preset=%s" % [
				i, memory_mb, RenderManager.QualityPreset.keys()[preset]])

		assert_eq(result["details"]["old_preset"], preset,
			"[Iter %d] Old preset in result should be %s" % [
				i, RenderManager.QualityPreset.keys()[preset]])

		assert_eq(result["details"]["new_preset"], expected_preset,
			"[Iter %d] New preset in result should be %s" % [
				i, RenderManager.QualityPreset.keys()[expected_preset]])


## Property test: For any memory >= 200MB, no quality reduction occurs regardless
## of current preset.
func test_property_no_reduction_above_threshold() -> void:
	gut.p("Property 31: Adaptive quality reduction - no reduction above threshold")
	gut.p("For any memory >= 200MB, no quality reduction SHALL occur.")

	for i in range(NUM_ITERATIONS):
		# Reset render manager for each iteration
		_render_manager = RenderManager.new()
		_render_manager.start_match_monitoring()

		# Pick any preset (LOW, MEDIUM, or HIGH)
		var preset_index := _rng.randi_range(0, 2)
		var preset: RenderManager.QualityPreset = preset_index as RenderManager.QualityPreset
		_render_manager.set_quality_preset(preset)

		var memory_mb := _random_memory_at_or_above_threshold()

		var result := _render_manager.check_memory_and_adapt(memory_mb)

		assert_eq(_render_manager.current_preset, preset,
			"[Iter %d] Preset should remain %s when memory=%dMB (>= threshold)" % [
				i, RenderManager.QualityPreset.keys()[preset], memory_mb])

		assert_eq(result["action"], "none",
			"[Iter %d] Action should be 'none' when memory=%dMB (>= threshold), got '%s'" % [
				i, memory_mb, result["action"]])


## Property test: For any memory < 200MB and preset == LOW, no quality reduction
## occurs (already at lowest). Critical warning may fire if memory < 100MB.
func test_property_no_reduction_at_lowest_preset() -> void:
	gut.p("Property 31: Adaptive quality reduction - no reduction at lowest preset")
	gut.p("For any memory < 200MB and preset == LOW, no reduction SHALL occur.")

	for i in range(NUM_ITERATIONS):
		# Reset render manager for each iteration
		_render_manager = RenderManager.new()
		_render_manager.start_match_monitoring()

		_render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)

		# Generate memory below threshold but above critical (100-199)
		# to avoid triggering critical warning which changes the action
		var memory_mb := _rng.randi_range(MEMORY_CRITICAL, MEMORY_THRESHOLD - 1)

		var result := _render_manager.check_memory_and_adapt(memory_mb)

		assert_eq(_render_manager.current_preset, RenderManager.QualityPreset.LOW,
			"[Iter %d] Preset should remain LOW when already at lowest, memory=%dMB" % [
				i, memory_mb])

		assert_eq(result["action"], "none",
			"[Iter %d] Action should be 'none' when already at LOW preset with memory=%dMB, got '%s'" % [
				i, memory_mb, result["action"]])


## Property test: For memory < 100MB at LOW preset, critical warning fires
## (but quality does NOT reduce further).
func test_property_critical_warning_at_lowest_preset() -> void:
	gut.p("Property 31: Adaptive quality reduction - critical warning at lowest")
	gut.p("For memory < 100MB at LOW preset, critical warning fires but no reduction.")

	for i in range(NUM_ITERATIONS):
		# Reset render manager for each iteration
		_render_manager = RenderManager.new()
		_render_manager.start_match_monitoring()

		_render_manager.set_quality_preset(RenderManager.QualityPreset.LOW)

		# Generate memory below critical threshold (0-99)
		var memory_mb := _rng.randi_range(0, MEMORY_CRITICAL - 1)

		var result := _render_manager.check_memory_and_adapt(memory_mb)

		# Quality should still be LOW (no further reduction possible)
		assert_eq(_render_manager.current_preset, RenderManager.QualityPreset.LOW,
			"[Iter %d] Preset should remain LOW even at critical memory=%dMB" % [
				i, memory_mb])

		# Action should be critical_warning (first time)
		assert_eq(result["action"], "critical_warning",
			"[Iter %d] Action should be 'critical_warning' at memory=%dMB with LOW preset, got '%s'" % [
				i, memory_mb, result["action"]])

		# Calling again should return "none" (warning already shown)
		var second_result := _render_manager.check_memory_and_adapt(memory_mb)
		assert_eq(second_result["action"], "none",
			"[Iter %d] Second call should return 'none' (warning already shown)" % [i])
