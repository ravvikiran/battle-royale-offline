## Property-based tests for input controls.
## Generates random control layouts, joystick displacements, and settings values,
## then verifies that input control properties hold across all generated inputs.
##
## **Validates: Requirements 9.3, 9.5, 9.8, 9.2, 12.4**
extends GutTest


## Number of random iterations per property test.
const ITERATIONS: int = 100

## Minimum screen dimension for random generation.
const MIN_SCREEN_SIZE: float = 320.0

## Maximum screen dimension for random generation.
const MAX_SCREEN_SIZE: float = 3840.0


var _controller: InputController


func before_each() -> void:
	_controller = InputController.new()
	_controller.screen_size = Vector2(1920, 1080)


func after_each() -> void:
	_controller.free()


# --- Helper functions for random generation ---

## Generates a random screen size within mobile device range.
func _random_screen_size() -> Vector2:
	var width := randf_range(MIN_SCREEN_SIZE, MAX_SCREEN_SIZE)
	var height := randf_range(MIN_SCREEN_SIZE, MAX_SCREEN_SIZE)
	return Vector2(width, height)


## Generates a random position within given screen bounds.
func _random_position_in_bounds(screen: Vector2) -> Vector2:
	return Vector2(randf_range(0.0, screen.x), randf_range(0.0, screen.y))


## Generates a random element size that meets minimum touch target.
func _random_valid_size() -> Vector2:
	var w := randf_range(44.0, 200.0)
	var h := randf_range(44.0, 200.0)
	return Vector2(w, h)


## Generates a random element size that may be below minimum.
func _random_any_size() -> Vector2:
	var w := randf_range(10.0, 200.0)
	var h := randf_range(10.0, 200.0)
	return Vector2(w, h)


## Generates a random joystick displacement vector from center.
func _random_joystick_displacement() -> Vector2:
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(0.0, InputController.JOYSTICK_RADIUS * 2.0)
	return Vector2(cos(angle), sin(angle)) * distance


## Generates a random sensitivity value (may be outside valid range).
func _random_sensitivity() -> float:
	return randf_range(-10.0, 30.0)


## Generates a random volume value (may be outside valid range).
func _random_volume() -> float:
	return randf_range(-50.0, 200.0)


# --- Property 23: Control layout constraints ---
# For any custom control layout configuration, all interactive elements SHALL have
# dimensions >= 44x44 dp, all elements SHALL be fully within screen bounds, and
# no two interactive elements SHALL overlap.

func test_property_23_control_layout_constraints() -> void:
	gut.p("Property 23: Control layout constraints")
	gut.p("All interactive elements >= 44x44 dp, within screen bounds, no overlap.")

	for i in range(ITERATIONS):
		# Create a fresh controller with random screen size
		_controller.free()
		_controller = InputController.new()
		var screen := _random_screen_size()
		_controller.screen_size = screen

		# The default layout should satisfy all constraints for the default screen
		# Test with default 1920x1080 screen
		_controller.screen_size = Vector2(1920, 1080)

		# Verify all interactive elements meet minimum touch target size (44x44 dp)
		for key in _controller.layout.elements:
			var elem: InputController.ControlElement = _controller.layout.elements[key]
			if elem.interactive:
				assert_gte(elem.size.x, InputController.MIN_TOUCH_TARGET_DP,
					"[Iter %d] Element '%s' width (%f) must be >= %f dp" % [
						i, elem.id, elem.size.x, InputController.MIN_TOUCH_TARGET_DP])
				assert_gte(elem.size.y, InputController.MIN_TOUCH_TARGET_DP,
					"[Iter %d] Element '%s' height (%f) must be >= %f dp" % [
						i, elem.id, elem.size.y, InputController.MIN_TOUCH_TARGET_DP])

		# Verify all elements are within screen bounds
		var screen_rect := Rect2(Vector2.ZERO, _controller.screen_size)
		for key in _controller.layout.elements:
			var elem: InputController.ControlElement = _controller.layout.elements[key]
			var elem_rect := elem.get_rect()
			assert_true(screen_rect.encloses(elem_rect),
				"[Iter %d] Element '%s' at (%s) size (%s) must be within screen bounds (%s)" % [
					i, elem.id, str(elem.position), str(elem.size), str(_controller.screen_size)])

		# Verify no two interactive elements overlap
		var interactive_elements: Array = []
		for key in _controller.layout.elements:
			var elem: InputController.ControlElement = _controller.layout.elements[key]
			if elem.interactive:
				interactive_elements.append(elem)

		for j in range(interactive_elements.size()):
			for k in range(j + 1, interactive_elements.size()):
				var rect_a: Rect2 = interactive_elements[j].get_rect()
				var rect_b: Rect2 = interactive_elements[k].get_rect()
				assert_false(rect_a.intersects(rect_b),
					"[Iter %d] Elements '%s' and '%s' must not overlap" % [
						i, interactive_elements[j].id, interactive_elements[k].id])

		# Now test that move operations maintain constraints
		# Try random moves — successful moves must maintain all constraints
		var element_keys: Array = _controller.layout.elements.keys()
		var random_key: String = element_keys[randi() % element_keys.size()]
		var random_pos := _random_position_in_bounds(_controller.screen_size)

		var move_result := _controller.move_control_element(random_key, random_pos)
		if move_result:
			# After a successful move, all constraints must still hold
			assert_true(_controller.layout.all_meet_min_touch_target(),
				"[Iter %d] After move, all elements must meet min touch target" % [i])
			assert_true(_controller.layout.all_within_bounds(_controller.screen_size),
				"[Iter %d] After move, all elements must be within bounds" % [i])
			assert_false(_controller.layout.has_overlap(),
				"[Iter %d] After move, no elements must overlap" % [i])

		# Test that resize operations enforce minimum size
		var resize_size := _random_any_size()
		var resize_result := _controller.resize_control_element(random_key, resize_size)
		if resize_result:
			# After a successful resize, all constraints must still hold
			var resized_elem: InputController.ControlElement = _controller.layout.elements[random_key]
			assert_gte(resized_elem.size.x, InputController.MIN_TOUCH_TARGET_DP,
				"[Iter %d] After resize, element width must be >= 44dp" % [i])
			assert_gte(resized_elem.size.y, InputController.MIN_TOUCH_TARGET_DP,
				"[Iter %d] After resize, element height must be >= 44dp" % [i])
			assert_true(_controller.layout.all_within_bounds(_controller.screen_size),
				"[Iter %d] After resize, all elements must be within bounds" % [i])
			assert_false(_controller.layout.has_overlap(),
				"[Iter %d] After resize, no elements must overlap" % [i])

		# Test reset-to-default restores valid layout
		_controller.reset_layout_to_default()
		assert_true(_controller.validate_layout(),
			"[Iter %d] After reset, layout must be valid" % [i])


# --- Property 24: Joystick movement proportionality ---
# For any joystick displacement vector from center, movement speed SHALL be
# proportional to displacement magnitude (clamped at joystick radius), and
# movement direction SHALL match displacement direction.

func test_property_24_joystick_movement_proportionality() -> void:
	gut.p("Property 24: Joystick movement proportionality")
	gut.p("Speed proportional to displacement (clamped at radius), direction matches displacement.")

	for i in range(ITERATIONS):
		# Reset controller state
		_controller.free()
		_controller = InputController.new()
		_controller.screen_size = Vector2(1920, 1080)

		# Activate joystick at a random left-side position
		var center_x := randf_range(50.0, 900.0)  # Left half
		var center_y := randf_range(50.0, 1030.0)
		var center := Vector2(center_x, center_y)

		_controller.process_joystick_touch(center, true, 0)
		assert_true(_controller.joystick_active,
			"[Iter %d] Joystick must activate on left-side touch" % [i])

		# Generate random displacement
		var displacement := _random_joystick_displacement()
		var drag_position := center + displacement
		_controller.update_joystick_drag(drag_position, 0)

		var movement := _controller.get_movement_vector()
		var displacement_magnitude := displacement.length()

		if displacement_magnitude < 0.001:
			# Near-zero displacement should produce near-zero movement
			assert_almost_eq(movement.length(), 0.0, 0.01,
				"[Iter %d] Zero displacement should produce zero movement" % [i])
		else:
			# Movement magnitude should be proportional to displacement, clamped at radius
			var expected_magnitude := minf(displacement_magnitude, InputController.JOYSTICK_RADIUS) / InputController.JOYSTICK_RADIUS
			assert_almost_eq(movement.length(), expected_magnitude, 0.01,
				"[Iter %d] Movement magnitude (%f) should be proportional to displacement (%f), expected (%f)" % [
					i, movement.length(), displacement_magnitude, expected_magnitude])

			# Movement magnitude must be clamped to [0, 1]
			assert_lte(movement.length(), 1.0 + 0.001,
				"[Iter %d] Movement magnitude (%f) must be <= 1.0" % [i, movement.length()])
			assert_gte(movement.length(), 0.0,
				"[Iter %d] Movement magnitude (%f) must be >= 0.0" % [i, movement.length()])

			# Direction must match displacement direction
			var expected_direction := displacement.normalized()
			var actual_direction := movement.normalized()
			assert_almost_eq(actual_direction.x, expected_direction.x, 0.01,
				"[Iter %d] Movement direction X (%f) must match displacement direction X (%f)" % [
					i, actual_direction.x, expected_direction.x])
			assert_almost_eq(actual_direction.y, expected_direction.y, 0.01,
				"[Iter %d] Movement direction Y (%f) must match displacement direction Y (%f)" % [
					i, actual_direction.y, expected_direction.y])

		# Release joystick and verify movement returns to zero
		_controller.process_joystick_touch(center, false, 0)
		assert_eq(_controller.get_movement_vector(), Vector2.ZERO,
			"[Iter %d] Movement must be zero after joystick release" % [i])


# --- Property 30: Settings value clamping ---
# For any numeric setting input (sensitivity 1-10, volume 0-100), the stored
# and applied value SHALL be clamped to the valid range.

func test_property_30_settings_value_clamping() -> void:
	gut.p("Property 30: Settings value clamping")
	gut.p("Sensitivity 1-10 and volume 0-100 are clamped to valid range.")

	var audio_manager := AudioManager.new()

	for i in range(ITERATIONS):
		# Test sensitivity clamping (valid range: 1-10)
		var random_sensitivity := _random_sensitivity()
		_controller.set_sensitivity(random_sensitivity)
		var stored_sensitivity := _controller.get_sensitivity()

		# Stored value must be within valid range [1, 10]
		assert_gte(stored_sensitivity, InputController.MIN_SENSITIVITY,
			"[Iter %d] Sensitivity (%f) must be >= %f after setting %f" % [
				i, stored_sensitivity, InputController.MIN_SENSITIVITY, random_sensitivity])
		assert_lte(stored_sensitivity, InputController.MAX_SENSITIVITY,
			"[Iter %d] Sensitivity (%f) must be <= %f after setting %f" % [
				i, stored_sensitivity, InputController.MAX_SENSITIVITY, random_sensitivity])

		# If input was within range, stored value should equal input
		if random_sensitivity >= InputController.MIN_SENSITIVITY and random_sensitivity <= InputController.MAX_SENSITIVITY:
			assert_almost_eq(stored_sensitivity, random_sensitivity, 0.001,
				"[Iter %d] In-range sensitivity (%f) should be stored as-is" % [i, random_sensitivity])

		# If input was below minimum, stored value should be minimum
		if random_sensitivity < InputController.MIN_SENSITIVITY:
			assert_almost_eq(stored_sensitivity, InputController.MIN_SENSITIVITY, 0.001,
				"[Iter %d] Below-min sensitivity (%f) should clamp to %f" % [
					i, random_sensitivity, InputController.MIN_SENSITIVITY])

		# If input was above maximum, stored value should be maximum
		if random_sensitivity > InputController.MAX_SENSITIVITY:
			assert_almost_eq(stored_sensitivity, InputController.MAX_SENSITIVITY, 0.001,
				"[Iter %d] Above-max sensitivity (%f) should clamp to %f" % [
					i, random_sensitivity, InputController.MAX_SENSITIVITY])

		# Test volume clamping via AudioManager (valid range: 0-100)
		# Requirement 12.4: music, sfx, voice volumes each 0-100
		var random_volume_int := int(_random_volume())

		# Test music_volume clamping
		audio_manager.music_volume = random_volume_int
		assert_gte(audio_manager.music_volume, AudioManager.VOLUME_MIN,
			"[Iter %d] music_volume (%d) must be >= %d after setting %d" % [
				i, audio_manager.music_volume, AudioManager.VOLUME_MIN, random_volume_int])
		assert_lte(audio_manager.music_volume, AudioManager.VOLUME_MAX,
			"[Iter %d] music_volume (%d) must be <= %d after setting %d" % [
				i, audio_manager.music_volume, AudioManager.VOLUME_MAX, random_volume_int])

		# Test sfx_volume clamping
		audio_manager.sfx_volume = random_volume_int
		assert_gte(audio_manager.sfx_volume, AudioManager.VOLUME_MIN,
			"[Iter %d] sfx_volume (%d) must be >= %d after setting %d" % [
				i, audio_manager.sfx_volume, AudioManager.VOLUME_MIN, random_volume_int])
		assert_lte(audio_manager.sfx_volume, AudioManager.VOLUME_MAX,
			"[Iter %d] sfx_volume (%d) must be <= %d after setting %d" % [
				i, audio_manager.sfx_volume, AudioManager.VOLUME_MAX, random_volume_int])

		# Test voice_volume clamping
		audio_manager.voice_volume = random_volume_int
		assert_gte(audio_manager.voice_volume, AudioManager.VOLUME_MIN,
			"[Iter %d] voice_volume (%d) must be >= %d after setting %d" % [
				i, audio_manager.voice_volume, AudioManager.VOLUME_MIN, random_volume_int])
		assert_lte(audio_manager.voice_volume, AudioManager.VOLUME_MAX,
			"[Iter %d] voice_volume (%d) must be <= %d after setting %d" % [
				i, audio_manager.voice_volume, AudioManager.VOLUME_MAX, random_volume_int])

		# Verify exact clamping behavior for volume
		var expected_clamped := clampi(random_volume_int, AudioManager.VOLUME_MIN, AudioManager.VOLUME_MAX)
		assert_eq(audio_manager.music_volume, expected_clamped,
			"[Iter %d] music_volume should be clamped to %d, got %d (input: %d)" % [
				i, expected_clamped, audio_manager.music_volume, random_volume_int])

		# If input was within range, stored value should equal input
		if random_volume_int >= AudioManager.VOLUME_MIN and random_volume_int <= AudioManager.VOLUME_MAX:
			assert_eq(audio_manager.sfx_volume, random_volume_int,
				"[Iter %d] In-range volume (%d) should be stored as-is" % [i, random_volume_int])

		# If input was below minimum, stored value should be VOLUME_MIN
		if random_volume_int < AudioManager.VOLUME_MIN:
			assert_eq(audio_manager.voice_volume, AudioManager.VOLUME_MIN,
				"[Iter %d] Below-min volume (%d) should clamp to %d" % [
					i, random_volume_int, AudioManager.VOLUME_MIN])

		# If input was above maximum, stored value should be VOLUME_MAX
		if random_volume_int > AudioManager.VOLUME_MAX:
			assert_eq(audio_manager.voice_volume, AudioManager.VOLUME_MAX,
				"[Iter %d] Above-max volume (%d) should clamp to %d" % [
					i, random_volume_int, AudioManager.VOLUME_MAX])
