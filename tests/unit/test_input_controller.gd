## Unit tests for InputController
## Tests virtual joystick, aiming, buttons, weapon switch, latency, layout, and fire modes.
extends GutTest


var controller: InputController


func before_each() -> void:
	controller = InputController.new()
	controller.screen_size = Vector2(1920, 1080)


func after_each() -> void:
	controller.free()


# --- Joystick Tests (Requirement 9.1, 9.8) ---

func test_joystick_inactive_by_default() -> void:
	assert_false(controller.joystick_active)
	assert_eq(controller.get_movement_vector(), Vector2.ZERO)


func test_joystick_activates_on_left_side_touch() -> void:
	# Touch in left half of screen
	controller.process_joystick_touch(Vector2(200, 500), true, 0)
	assert_true(controller.joystick_active)


func test_joystick_does_not_activate_on_right_side_touch() -> void:
	# Touch in right half of screen
	controller.process_joystick_touch(Vector2(1200, 500), true, 0)
	assert_false(controller.joystick_active)


func test_joystick_appears_at_touch_position() -> void:
	controller.process_joystick_touch(Vector2(300, 400), true, 0)
	assert_true(controller.joystick_active)
	# Center should be at touch position
	assert_eq(controller._joystick_center, Vector2(300, 400))


func test_joystick_movement_proportional_to_displacement() -> void:
	controller.process_joystick_touch(Vector2(300, 400), true, 0)

	# Drag halfway to radius
	var half_radius := InputController.JOYSTICK_RADIUS * 0.5
	controller.update_joystick_drag(Vector2(300 + half_radius, 400), 0)

	var movement := controller.get_movement_vector()
	# Should be approximately 0.5 magnitude in the x direction
	assert_almost_eq(movement.x, 0.5, 0.01)
	assert_almost_eq(movement.y, 0.0, 0.01)


func test_joystick_movement_clamped_at_radius() -> void:
	controller.process_joystick_touch(Vector2(300, 400), true, 0)

	# Drag beyond radius
	controller.update_joystick_drag(Vector2(300 + InputController.JOYSTICK_RADIUS * 2, 400), 0)

	var movement := controller.get_movement_vector()
	# Should be clamped to 1.0 magnitude
	assert_almost_eq(movement.length(), 1.0, 0.01)


func test_joystick_direction_matches_displacement() -> void:
	controller.process_joystick_touch(Vector2(300, 400), true, 0)

	# Drag diagonally down-right
	var offset := Vector2(50, 50)
	controller.update_joystick_drag(Vector2(300, 400) + offset, 0)

	var movement := controller.get_movement_vector()
	# Direction should be normalized diagonal (roughly 0.707, 0.707)
	var expected_dir := offset.normalized()
	assert_almost_eq(movement.normalized().x, expected_dir.x, 0.01)
	assert_almost_eq(movement.normalized().y, expected_dir.y, 0.01)


func test_joystick_deactivates_on_release() -> void:
	controller.process_joystick_touch(Vector2(300, 400), true, 0)
	assert_true(controller.joystick_active)

	controller.process_joystick_touch(Vector2(300, 400), false, 0)
	assert_false(controller.joystick_active)
	assert_eq(controller.get_movement_vector(), Vector2.ZERO)


func test_joystick_ignores_wrong_touch_index() -> void:
	controller.process_joystick_touch(Vector2(300, 400), true, 0)
	# Drag with different touch index should be ignored
	controller.update_joystick_drag(Vector2(400, 400), 1)
	assert_eq(controller.joystick_displacement, Vector2.ZERO)


# --- Aim Tests (Requirement 9.2) ---

func test_aim_touch_activates_on_right_side() -> void:
	controller.process_aim_touch(Vector2(1200, 500), true, 1)
	assert_true(controller.is_action_pressed("aim"))


func test_aim_touch_does_not_activate_on_left_side() -> void:
	controller.process_aim_touch(Vector2(200, 500), true, 1)
	assert_false(controller.is_action_pressed("aim"))


func test_aim_delta_scales_with_sensitivity() -> void:
	controller.set_sensitivity(10.0)
	controller.process_aim_touch(Vector2(1200, 500), true, 1)
	controller.update_aim_drag(Vector2(1250, 500), 1)
	var delta_high := controller.get_aim_delta()

	# Reset
	controller.process_aim_touch(Vector2(1200, 500), false, 1)

	controller.set_sensitivity(1.0)
	controller.process_aim_touch(Vector2(1200, 500), true, 2)
	controller.update_aim_drag(Vector2(1250, 500), 2)
	var delta_low := controller.get_aim_delta()

	# Higher sensitivity should produce larger delta
	assert_gt(delta_high.length(), delta_low.length())


func test_sensitivity_clamped_to_valid_range() -> void:
	controller.set_sensitivity(0.0)
	assert_eq(controller.get_sensitivity(), 1.0)

	controller.set_sensitivity(15.0)
	assert_eq(controller.get_sensitivity(), 10.0)

	controller.set_sensitivity(5.0)
	assert_eq(controller.get_sensitivity(), 5.0)


# --- Fire Mode Tests (Requirement 9.6) ---

func test_tap_to_shoot_default_mode() -> void:
	assert_eq(controller.fire_mode, Enums.FireMode.TAP)


func test_tap_mode_emits_on_press() -> void:
	watch_signals(controller)
	controller.process_fire_input(true)
	assert_signal_emitted(controller, "fire_pressed")


func test_tap_mode_does_not_track_hold() -> void:
	controller.process_fire_input(true)
	assert_false(controller.is_fire_held())


func test_hold_mode_tracks_held_state() -> void:
	controller.set_fire_mode(Enums.FireMode.HOLD)
	controller.process_fire_input(true)
	assert_true(controller.is_fire_held())

	controller.process_fire_input(false)
	assert_false(controller.is_fire_held())


func test_hold_mode_emits_fire_released() -> void:
	controller.set_fire_mode(Enums.FireMode.HOLD)
	watch_signals(controller)
	controller.process_fire_input(true)
	controller.process_fire_input(false)
	assert_signal_emitted(controller, "fire_released")


# --- Button Tests (Requirement 9.3) ---

func test_jump_emits_signal() -> void:
	watch_signals(controller)
	controller.process_jump_input()
	assert_signal_emitted(controller, "jump_pressed")


func test_crouch_emits_signal() -> void:
	watch_signals(controller)
	controller.process_crouch_input()
	assert_signal_emitted(controller, "crouch_pressed")


func test_reload_emits_signal() -> void:
	watch_signals(controller)
	controller.process_reload_input()
	assert_signal_emitted(controller, "reload_pressed")


# --- Weapon Quick-Switch Tests (Requirement 9.4) ---

func test_weapon_switch_emits_signal() -> void:
	controller.set_active_weapon_slots(3)
	watch_signals(controller)
	controller.process_weapon_switch(1)
	assert_signal_emitted_with_parameters(controller, "weapon_switched", [1])


func test_weapon_switch_rejects_invalid_slot() -> void:
	controller.set_active_weapon_slots(3)
	watch_signals(controller)
	controller.process_weapon_switch(4)  # Out of range
	assert_signal_not_emitted(controller, "weapon_switched")


func test_weapon_switch_rejects_negative_slot() -> void:
	controller.set_active_weapon_slots(3)
	watch_signals(controller)
	controller.process_weapon_switch(-1)
	assert_signal_not_emitted(controller, "weapon_switched")


func test_weapon_slots_clamped_to_max() -> void:
	controller.set_active_weapon_slots(10)
	assert_eq(controller._active_weapon_slot_count, InputController.MAX_WEAPON_SLOTS)


func test_selected_slot_adjusts_when_slots_reduced() -> void:
	controller.set_active_weapon_slots(5)
	controller.process_weapon_switch(4)
	assert_eq(controller.get_selected_weapon_slot(), 4)

	controller.set_active_weapon_slots(3)
	assert_eq(controller.get_selected_weapon_slot(), 2)


# --- Input Latency Tests (Requirement 9.7) ---

func test_input_within_latency_accepted() -> void:
	var event_time := 1000.0
	var current_time := 1030.0  # 30ms latency
	assert_true(controller.validate_input_latency(event_time, current_time))


func test_input_at_exact_latency_limit_accepted() -> void:
	var event_time := 1000.0
	var current_time := 1050.0  # Exactly 50ms
	assert_true(controller.validate_input_latency(event_time, current_time))


func test_input_exceeding_latency_rejected() -> void:
	var event_time := 1000.0
	var current_time := 1051.0  # 51ms - exceeds limit
	assert_false(controller.validate_input_latency(event_time, current_time))


# --- Layout Tests (Requirement 9.5) ---

func test_default_layout_has_required_buttons() -> void:
	assert_true(controller.layout.elements.has("shoot"))
	assert_true(controller.layout.elements.has("jump"))
	assert_true(controller.layout.elements.has("crouch"))
	assert_true(controller.layout.elements.has("reload"))


func test_default_layout_has_weapon_slots() -> void:
	for i in range(InputController.MAX_WEAPON_SLOTS):
		assert_true(controller.layout.elements.has("weapon_slot_%d" % i))


func test_default_layout_meets_min_touch_target() -> void:
	assert_true(controller.layout.all_meet_min_touch_target())


func test_default_layout_no_overlap() -> void:
	assert_false(controller.layout.has_overlap())


func test_default_layout_within_bounds() -> void:
	assert_true(controller.layout.all_within_bounds(controller.screen_size))


func test_move_element_rejects_out_of_bounds() -> void:
	# Try to move shoot button off screen
	var result := controller.move_control_element("shoot", Vector2(1900, 1050))
	assert_false(result)


func test_move_element_rejects_overlap() -> void:
	# Move jump button to same position as shoot button
	var shoot_pos: Vector2 = controller.layout.elements["shoot"].position
	var result := controller.move_control_element("jump", shoot_pos)
	assert_false(result)


func test_move_element_accepts_valid_position() -> void:
	# Move to a valid empty area
	var result := controller.move_control_element("shoot", Vector2(100, 100))
	assert_true(result)


func test_resize_element_enforces_min_size() -> void:
	# Move shoot to a safe position first, then try to resize below minimum
	controller.move_control_element("shoot", Vector2(100, 100))
	controller.resize_control_element("shoot", Vector2(20, 20))
	var elem: InputController.ControlElement = controller.layout.elements["shoot"]
	assert_gte(elem.size.x, InputController.MIN_TOUCH_TARGET_DP)
	assert_gte(elem.size.y, InputController.MIN_TOUCH_TARGET_DP)


func test_reset_to_default_restores_layout() -> void:
	# Move an element
	controller.move_control_element("shoot", Vector2(100, 100))
	var moved_pos: Vector2 = controller.layout.elements["shoot"].position
	assert_eq(moved_pos, Vector2(100, 100))

	# Reset
	controller.reset_layout_to_default()
	var reset_pos: Vector2 = controller.layout.elements["shoot"].position
	# Should be back to default (1750, 700)
	assert_eq(reset_pos, Vector2(1750, 700))


func test_validate_layout_returns_true_for_valid_layout() -> void:
	assert_true(controller.validate_layout())
