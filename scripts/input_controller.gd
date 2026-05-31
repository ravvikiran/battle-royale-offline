## Input Controller for touch-based mobile controls.
## Handles virtual joystick, aiming, action buttons, weapon quick-switch,
## input latency validation, custom layout, and fire modes.
## Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8
class_name InputController
extends Node


## Emitted when the player fires (tap or hold mode)
signal fire_pressed
## Emitted when the player releases fire (hold mode)
signal fire_released
## Emitted when the player taps jump
signal jump_pressed
## Emitted when the player taps crouch
signal crouch_pressed
## Emitted when the player taps reload
signal reload_pressed
## Emitted when the player switches weapon slot
signal weapon_switched(slot_index: int)


## Minimum touch target size in density-independent pixels (Requirement 9.3)
const MIN_TOUCH_TARGET_DP: float = 44.0
## Maximum allowed input latency in milliseconds (Requirement 9.7)
const MAX_INPUT_LATENCY_MS: float = 50.0
## Maximum weapon slots in quick-switch bar (Requirement 9.4)
const MAX_WEAPON_SLOTS: int = 5
## Joystick maximum radius in pixels (used for proportional movement)
const JOYSTICK_RADIUS: float = 100.0
## Minimum sensitivity value (Requirement 9.2)
const MIN_SENSITIVITY: float = 1.0
## Maximum sensitivity value (Requirement 9.2)
const MAX_SENSITIVITY: float = 10.0


## Whether the virtual joystick is currently active (finger down in left area)
var joystick_active: bool = false
## Current joystick displacement vector from center (normalized to 0-1 magnitude)
var joystick_displacement: Vector2 = Vector2.ZERO
## Aim sensitivity from 1 (slowest) to 10 (fastest) (Requirement 9.2)
var sensitivity: float = 5.0:
	set(value):
		sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
## Firing mode: TAP (default) or HOLD (Requirement 9.6)
var fire_mode: Enums.FireMode = Enums.FireMode.TAP
## Current control layout configuration
var layout: ControlLayout = ControlLayout.new()
## Screen size in pixels (updated on viewport resize)
var screen_size: Vector2 = Vector2(1920, 1080)


## Internal state for joystick tracking
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_touch_index: int = -1
## Internal state for aim tracking
var _aim_touch_index: int = -1
var _aim_last_position: Vector2 = Vector2.ZERO
var _aim_delta: Vector2 = Vector2.ZERO
## Fire button state for hold mode
var _fire_held: bool = false
## Active weapon slot count (how many slots are occupied)
var _active_weapon_slot_count: int = 0
## Currently selected weapon slot index
var _selected_weapon_slot: int = 0


## Represents a single UI control element with position and size
class ControlElement:
	## Unique identifier for this element
	var id: String = ""
	## Position in screen coordinates (top-left corner)
	var position: Vector2 = Vector2.ZERO
	## Size in density-independent pixels
	var size: Vector2 = Vector2(44.0, 44.0)
	## Whether this element is interactive (used for overlap checks)
	var interactive: bool = true

	func _init(p_id: String = "", p_position: Vector2 = Vector2.ZERO, p_size: Vector2 = Vector2(44.0, 44.0), p_interactive: bool = true) -> void:
		id = p_id
		position = p_position
		size = p_size
		interactive = p_interactive

	## Returns the bounding rectangle of this element
	func get_rect() -> Rect2:
		return Rect2(position, size)

	## Check if this element meets minimum touch target size
	func meets_min_touch_target() -> bool:
		return size.x >= 44.0 and size.y >= 44.0


## Represents the full control layout with all interactive elements
class ControlLayout:
	## All control elements in the layout
	var elements: Dictionary = {}
	## Default layout positions (used for reset)
	var _default_elements: Dictionary = {}

	func _init() -> void:
		_setup_default_layout()

	## Set up the default control layout positions
	func _setup_default_layout() -> void:
		# Default positions assume a 1920x1080 screen
		# Left side: joystick activation area (no explicit button, area-based)
		# Right side: action buttons
		var shoot_btn := ControlElement.new("shoot", Vector2(1750, 700), Vector2(80, 80))
		var jump_btn := ControlElement.new("jump", Vector2(1650, 600), Vector2(60, 60))
		var crouch_btn := ControlElement.new("crouch", Vector2(1650, 800), Vector2(60, 60))
		var reload_btn := ControlElement.new("reload", Vector2(1550, 700), Vector2(60, 60))

		# Weapon quick-switch bar (centered at bottom)
		for i in range(5):  # MAX_WEAPON_SLOTS = 5
			var slot := ControlElement.new(
				"weapon_slot_%d" % i,
				Vector2(710 + i * 100, 1000),
				Vector2(80, 60)
			)
			elements["weapon_slot_%d" % i] = slot

		elements["shoot"] = shoot_btn
		elements["jump"] = jump_btn
		elements["crouch"] = crouch_btn
		elements["reload"] = reload_btn

		# Store defaults for reset
		_save_as_default()

	## Save current layout as the default
	func _save_as_default() -> void:
		_default_elements.clear()
		for key in elements:
			var elem: ControlElement = elements[key]
			var copy := ControlElement.new(elem.id, elem.position, elem.size, elem.interactive)
			_default_elements[key] = copy

	## Reset layout to default positions (Requirement 9.5)
	func reset_to_default() -> void:
		elements.clear()
		for key in _default_elements:
			var elem: ControlElement = _default_elements[key]
			var copy := ControlElement.new(elem.id, elem.position, elem.size, elem.interactive)
			elements[key] = copy

	## Check if all elements are within screen bounds (Requirement 9.5)
	func all_within_bounds(p_screen_size: Vector2) -> bool:
		var screen_rect := Rect2(Vector2.ZERO, p_screen_size)
		for key in elements:
			var elem: ControlElement = elements[key]
			var elem_rect := elem.get_rect()
			if not screen_rect.encloses(elem_rect):
				return false
		return true

	## Check if any two interactive elements overlap (Requirement 9.5)
	func has_overlap() -> bool:
		var interactive_elements: Array[ControlElement] = []
		for key in elements:
			var elem: ControlElement = elements[key]
			if elem.interactive:
				interactive_elements.append(elem)

		for i in range(interactive_elements.size()):
			for j in range(i + 1, interactive_elements.size()):
				var rect_a := interactive_elements[i].get_rect()
				var rect_b := interactive_elements[j].get_rect()
				if rect_a.intersects(rect_b):
					return true
		return false

	## Check if all interactive elements meet minimum touch target size (Requirement 9.3)
	func all_meet_min_touch_target() -> bool:
		for key in elements:
			var elem: ControlElement = elements[key]
			if elem.interactive and not elem.meets_min_touch_target():
				return false
		return true

	## Move an element to a new position, constrained within screen bounds (Requirement 9.5)
	func move_element(element_id: String, new_position: Vector2, p_screen_size: Vector2) -> bool:
		if not elements.has(element_id):
			return false

		var elem: ControlElement = elements[element_id]
		var proposed_rect := Rect2(new_position, elem.size)
		var screen_rect := Rect2(Vector2.ZERO, p_screen_size)

		# Constrain within screen bounds
		if not screen_rect.encloses(proposed_rect):
			return false

		# Check for overlap with other interactive elements
		for key in elements:
			if key == element_id:
				continue
			var other: ControlElement = elements[key]
			if other.interactive:
				var other_rect := other.get_rect()
				if proposed_rect.intersects(other_rect):
					return false

		elem.position = new_position
		return true

	## Resize an element, enforcing minimum touch target (Requirement 9.3, 9.5)
	func resize_element(element_id: String, new_size: Vector2, p_screen_size: Vector2) -> bool:
		if not elements.has(element_id):
			return false

		# Enforce minimum touch target size (44dp)
		var clamped_size := Vector2(
			maxf(new_size.x, 44.0),
			maxf(new_size.y, 44.0)
		)

		var elem: ControlElement = elements[element_id]
		var proposed_rect := Rect2(elem.position, clamped_size)
		var screen_rect := Rect2(Vector2.ZERO, p_screen_size)

		# Constrain within screen bounds
		if not screen_rect.encloses(proposed_rect):
			return false

		# Check for overlap with other interactive elements
		for key in elements:
			if key == element_id:
				continue
			var other: ControlElement = elements[key]
			if other.interactive:
				var other_rect := other.get_rect()
				if proposed_rect.intersects(other_rect):
					return false

		elem.size = clamped_size
		return true


## Validate and process a touch input event.
## Returns true if the input was accepted (within latency threshold).
## Returns false if the input is rejected due to exceeding MAX_INPUT_LATENCY_MS.
## (Requirement 9.7)
func validate_input_latency(event_timestamp_ms: float, current_time_ms: float) -> bool:
	var latency := current_time_ms - event_timestamp_ms
	return latency <= MAX_INPUT_LATENCY_MS


## Process a touch event for the virtual joystick (Requirement 9.1, 9.8).
## The joystick appears at the first touch position in the left-side activation area.
## Movement is proportional to displacement magnitude, direction matches displacement.
func process_joystick_touch(touch_position: Vector2, is_pressed: bool, touch_index: int) -> void:
	var left_boundary := screen_size.x * 0.5

	if is_pressed:
		# Only activate if touch is in left-side area and no joystick is active
		if touch_position.x <= left_boundary and not joystick_active:
			joystick_active = true
			_joystick_center = touch_position
			_joystick_touch_index = touch_index
			joystick_displacement = Vector2.ZERO
	else:
		# Release joystick
		if touch_index == _joystick_touch_index:
			joystick_active = false
			_joystick_touch_index = -1
			joystick_displacement = Vector2.ZERO


## Update joystick displacement based on current finger position (Requirement 9.8).
## Movement speed is proportional to displacement distance up to joystick radius.
## Direction matches the displacement direction.
func update_joystick_drag(touch_position: Vector2, touch_index: int) -> void:
	if not joystick_active or touch_index != _joystick_touch_index:
		return

	var displacement := touch_position - _joystick_center
	var distance := displacement.length()

	if distance > 0.0:
		# Clamp magnitude to joystick radius, then normalize to 0-1 range
		var clamped_distance := minf(distance, JOYSTICK_RADIUS)
		var direction := displacement.normalized()
		# Proportional magnitude: 0 at center, 1 at radius edge
		joystick_displacement = direction * (clamped_distance / JOYSTICK_RADIUS)
	else:
		joystick_displacement = Vector2.ZERO


## Get the current movement vector from the joystick (Requirement 9.8).
## Returns Vector2 with magnitude 0-1 proportional to displacement, direction matching displacement.
func get_movement_vector() -> Vector2:
	if not joystick_active:
		return Vector2.ZERO
	return joystick_displacement


## Process touch-and-drag aiming on the right side of the screen (Requirement 9.2).
## Sensitivity scales the aim delta from 1 (slowest) to 10 (fastest).
func process_aim_touch(touch_position: Vector2, is_pressed: bool, touch_index: int) -> void:
	var right_boundary := screen_size.x * 0.5

	if is_pressed:
		# Only activate if touch is in right-side area and no aim touch is active
		if touch_position.x > right_boundary and _aim_touch_index == -1:
			_aim_touch_index = touch_index
			_aim_last_position = touch_position
			_aim_delta = Vector2.ZERO
	else:
		if touch_index == _aim_touch_index:
			_aim_touch_index = -1
			_aim_delta = Vector2.ZERO


## Update aim delta based on drag movement (Requirement 9.2).
func update_aim_drag(touch_position: Vector2, touch_index: int) -> void:
	if touch_index != _aim_touch_index:
		return

	var raw_delta := touch_position - _aim_last_position
	# Apply sensitivity scaling: sensitivity 1 = 0.1x, sensitivity 10 = 1.0x
	var sensitivity_factor := sensitivity / MAX_SENSITIVITY
	_aim_delta = raw_delta * sensitivity_factor
	_aim_last_position = touch_position


## Get the current aim delta vector, scaled by sensitivity (Requirement 9.2).
func get_aim_delta() -> Vector2:
	var delta := _aim_delta
	# Reset delta after reading (consumed per frame)
	_aim_delta = Vector2.ZERO
	return delta


## Process a shoot button press/release (Requirement 9.6).
## In TAP mode: emits fire_pressed on each tap.
## In HOLD mode: emits fire_pressed when held, fire_released when released.
func process_fire_input(is_pressed: bool) -> void:
	if fire_mode == Enums.FireMode.TAP:
		if is_pressed:
			fire_pressed.emit()
	else:  # HOLD mode
		if is_pressed:
			_fire_held = true
			fire_pressed.emit()
		else:
			_fire_held = false
			fire_released.emit()


## Check if fire is currently active (for hold mode continuous fire)
func is_fire_held() -> bool:
	return _fire_held and fire_mode == Enums.FireMode.HOLD


## Process jump button press (Requirement 9.3)
func process_jump_input() -> void:
	jump_pressed.emit()


## Process crouch button press (Requirement 9.3)
func process_crouch_input() -> void:
	crouch_pressed.emit()


## Process reload button press (Requirement 9.3)
func process_reload_input() -> void:
	reload_pressed.emit()


## Process weapon quick-switch tap (Requirement 9.4).
## slot_index must be 0 to (active_weapon_slot_count - 1).
func process_weapon_switch(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _active_weapon_slot_count:
		return
	if slot_index >= MAX_WEAPON_SLOTS:
		return
	_selected_weapon_slot = slot_index
	weapon_switched.emit(slot_index)


## Set the number of active weapon slots (occupied slots in inventory)
func set_active_weapon_slots(count: int) -> void:
	_active_weapon_slot_count = clampi(count, 0, MAX_WEAPON_SLOTS)
	# Adjust selected slot if it's now out of range
	if _selected_weapon_slot >= _active_weapon_slot_count and _active_weapon_slot_count > 0:
		_selected_weapon_slot = _active_weapon_slot_count - 1


## Get the currently selected weapon slot index
func get_selected_weapon_slot() -> int:
	return _selected_weapon_slot


## Check if a specific action is currently pressed/active
func is_action_pressed(action: String) -> bool:
	match action:
		"fire":
			return _fire_held
		"move":
			return joystick_active
		"aim":
			return _aim_touch_index != -1
		_:
			return false


## Set the fire mode (TAP or HOLD) (Requirement 9.6)
func set_fire_mode(mode: Enums.FireMode) -> void:
	fire_mode = mode
	# Reset fire state when switching modes
	_fire_held = false


## Set aim sensitivity, clamped to valid range 1-10 (Requirement 9.2)
func set_sensitivity(value: float) -> void:
	sensitivity = value  # Setter handles clamping


## Get current sensitivity value
func get_sensitivity() -> float:
	return sensitivity


## Reset the control layout to default positions (Requirement 9.5)
func reset_layout_to_default() -> void:
	layout.reset_to_default()


## Move a control element to a new position with constraint validation (Requirement 9.5).
## Returns true if the move was successful (within bounds, no overlap).
func move_control_element(element_id: String, new_position: Vector2) -> bool:
	return layout.move_element(element_id, new_position, screen_size)


## Resize a control element with constraint validation (Requirement 9.3, 9.5).
## Returns true if the resize was successful (meets min size, within bounds, no overlap).
func resize_control_element(element_id: String, new_size: Vector2) -> bool:
	return layout.resize_element(element_id, new_size, screen_size)


## Validate the entire layout meets all constraints (Requirements 9.3, 9.5).
## Returns true if all elements are within bounds, no overlaps, and meet min touch target.
func validate_layout() -> bool:
	return (
		layout.all_within_bounds(screen_size)
		and not layout.has_overlap()
		and layout.all_meet_min_touch_target()
	)


## Update screen size (call when viewport changes)
func update_screen_size(new_size: Vector2) -> void:
	screen_size = new_size
