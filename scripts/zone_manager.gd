## Manages the shrinking zone phases and storm damage for a Battle Royale match.
## Controls zone boundaries, phase transitions, and provides spatial queries
## for determining if positions are within the safe zone.
class_name ZoneManager
extends Node


## Emitted when a zone warning fires (at least 10 seconds before shrinking begins).
signal zone_warning(seconds_remaining: int)

## Emitted when zone shrinking starts for a phase.
signal zone_shrink_started(phase: int)

## Emitted when zone shrinking completes for a phase.
signal zone_shrink_completed(phase: int)


## Current zone phase index (1-based).
var current_phase: int = 0

## Total number of zone phases (minimum 5).
var total_phases: int = 5

## Center of the current safe zone circle.
var current_center: Vector2 = Vector2.ZERO

## Radius of the current safe zone circle.
var current_radius: float = 0.0

## Center of the next safe zone circle.
var next_center: Vector2 = Vector2.ZERO

## Radius of the next safe zone circle.
var next_radius: float = 0.0

## Current phase state (WAITING or SHRINKING).
var phase_state: Enums.PhaseState = Enums.PhaseState.WAITING

## Zone shrink speed preset.
var shrink_speed: Enums.ZoneShrinkSpeed = Enums.ZoneShrinkSpeed.NORMAL

## Internal phase configuration data.
var _phase_configs: Array = []

## Map bounds used for zone generation.
var _map_bounds: Rect2 = Rect2()

## Speed multiplier value derived from shrink_speed enum.
var _speed_multiplier: float = 1.0

## Timer tracking wait time remaining in current phase.
var _wait_timer: float = 0.0

## Timer tracking shrink time remaining in current phase.
var _shrink_timer: float = 0.0

## Total shrink duration for the current phase (after speed multiplier).
var _shrink_duration: float = 0.0

## Total wait duration for the current phase (after speed multiplier).
var _wait_duration: float = 0.0

## Whether the zone warning has been emitted for the current phase.
var _warning_emitted: bool = false

## Center position at the start of shrinking (used for interpolation).
var _shrink_start_center: Vector2 = Vector2.ZERO

## Radius at the start of shrinking (used for interpolation).
var _shrink_start_radius: float = 0.0

## Whether zones have been initialized.
var _initialized: bool = false


## Speed multiplier constants matching zone_phases.json.
const SPEED_MULTIPLIERS: Dictionary = {
	Enums.ZoneShrinkSpeed.SLOW: 1.5,
	Enums.ZoneShrinkSpeed.NORMAL: 1.0,
	Enums.ZoneShrinkSpeed.FAST: 0.6,
}

## Minimum warning time before shrinking (seconds).
const MIN_WARNING_TIME: float = 10.0


## Initializes zone phases based on map bounds and speed setting.
## Generates at least 5 phases with configurable speed multipliers.
## Each next zone is guaranteed to be fully contained within the current zone.
func initialize_zones(map_bounds: Rect2, speed: Enums.ZoneShrinkSpeed) -> void:
	_map_bounds = map_bounds
	shrink_speed = speed
	_speed_multiplier = SPEED_MULTIPLIERS[speed]
	
	# Load phase configuration from zone_phases.json
	_load_phase_configs()
	
	# Ensure minimum 5 phases
	assert(_phase_configs.size() >= 5, "Zone phases must have at least 5 phases")
	total_phases = _phase_configs.size()
	
	# Generate zone circles for all phases
	_generate_zone_circles()
	
	# Set initial state
	current_phase = 0
	phase_state = Enums.PhaseState.WAITING
	_initialized = true


## Advances to the next zone phase, transitioning through WAITING → SHRINKING states.
## When in WAITING state, transitions to SHRINKING.
## When in SHRINKING state (shrink complete), moves to next phase WAITING.
func advance_phase() -> void:
	if not _initialized:
		return
	
	if phase_state == Enums.PhaseState.WAITING:
		# Transition from WAITING to SHRINKING
		phase_state = Enums.PhaseState.SHRINKING
		_shrink_start_center = current_center
		_shrink_start_radius = current_radius
		
		var config := _get_current_phase_config()
		_shrink_duration = config.get("shrink_seconds", 60.0) * _speed_multiplier
		_shrink_timer = _shrink_duration
		
		zone_shrink_started.emit(current_phase)
	elif phase_state == Enums.PhaseState.SHRINKING:
		# Shrinking complete - finalize position and move to next phase
		current_center = next_center
		current_radius = next_radius
		
		zone_shrink_completed.emit(current_phase)
		
		# Move to next phase if available
		if current_phase < total_phases:
			current_phase += 1
			phase_state = Enums.PhaseState.WAITING
			_warning_emitted = false
			
			if current_phase <= total_phases:
				var config := _get_current_phase_config()
				_wait_duration = config.get("wait_seconds", 60.0) * _speed_multiplier
				_wait_timer = _wait_duration
				
				# Calculate next zone for the new phase
				if current_phase < total_phases:
					_calculate_next_zone_for_phase(current_phase)


## Returns the storm damage per second for the given phase (1-based).
## Starts at 1 DPS in phase 1, increasing by at least 1 per phase.
func get_storm_damage(phase: int) -> float:
	if phase <= 0:
		return 0.0
	
	# Use configured DPS from phase data if available
	var phase_index := phase - 1
	if phase_index < _phase_configs.size():
		return float(_phase_configs[phase_index].get("storm_dps", phase))
	
	# Fallback: at least 1 DPS increasing by at least 1 per phase
	return float(phase)


## Checks if a position is within the current safe zone circle.
func is_in_safe_zone(position: Vector2) -> bool:
	var distance := position.distance_to(current_center)
	return distance <= current_radius


## Returns the nearest point on the safe zone boundary for directional guidance.
## If the position is already inside the safe zone, returns the position itself.
func get_nearest_safe_point(position: Vector2) -> Vector2:
	if is_in_safe_zone(position):
		return position
	
	# Direction from center toward the outside position
	var direction := (position - current_center).normalized()
	
	# Nearest point on the circle boundary (closest to the outside position)
	return current_center + direction * current_radius


## Called every frame to update zone timers and state.
func _process(delta: float) -> void:
	if not _initialized or current_phase == 0:
		return
	
	if phase_state == Enums.PhaseState.WAITING:
		_update_waiting(delta)
	elif phase_state == Enums.PhaseState.SHRINKING:
		_update_shrinking(delta)


## Updates the waiting state timer and emits warnings.
func _update_waiting(delta: float) -> void:
	_wait_timer -= delta
	
	# Emit zone warning at least 10 seconds before shrinking begins
	if not _warning_emitted and _wait_timer <= MIN_WARNING_TIME:
		_warning_emitted = true
		zone_warning.emit(ceili(_wait_timer))
	
	# Transition to shrinking when wait time expires
	if _wait_timer <= 0.0:
		advance_phase()


## Updates the shrinking state, interpolating zone position and radius.
func _update_shrinking(delta: float) -> void:
	_shrink_timer -= delta
	
	if _shrink_timer <= 0.0:
		# Shrinking complete
		_shrink_timer = 0.0
		current_center = next_center
		current_radius = next_radius
		advance_phase()
	else:
		# Interpolate between start and target
		var progress := 1.0 - (_shrink_timer / _shrink_duration)
		current_center = _shrink_start_center.lerp(next_center, progress)
		current_radius = lerpf(_shrink_start_radius, next_radius, progress)


## Starts the first zone phase. Call after initialize_zones().
func start_first_phase() -> void:
	if not _initialized or total_phases == 0:
		return
	
	current_phase = 1
	phase_state = Enums.PhaseState.WAITING
	_warning_emitted = false
	
	var config := _get_current_phase_config()
	_wait_duration = config.get("wait_seconds", 60.0) * _speed_multiplier
	_wait_timer = _wait_duration
	
	# Set current zone to the initial (full map) zone
	# next zone is already calculated during initialization
	_calculate_next_zone_for_phase(1)


## Loads phase configuration from zone_phases.json data file.
func _load_phase_configs() -> void:
	var file := FileAccess.open("res://data/zone_phases.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK:
			var data: Dictionary = json.data
			_phase_configs = data.get("phases", [])
		else:
			_generate_default_phases()
	else:
		_generate_default_phases()


## Generates default phase configs if the JSON file cannot be loaded.
func _generate_default_phases() -> void:
	_phase_configs = [
		{"phase": 1, "safe_radius_percent": 70, "wait_seconds": 120, "shrink_seconds": 60, "storm_dps": 1},
		{"phase": 2, "safe_radius_percent": 50, "wait_seconds": 90, "shrink_seconds": 50, "storm_dps": 2},
		{"phase": 3, "safe_radius_percent": 30, "wait_seconds": 60, "shrink_seconds": 40, "storm_dps": 3},
		{"phase": 4, "safe_radius_percent": 15, "wait_seconds": 45, "shrink_seconds": 30, "storm_dps": 5},
		{"phase": 5, "safe_radius_percent": 5, "wait_seconds": 30, "shrink_seconds": 20, "storm_dps": 8},
	]


## Generates all zone circles ensuring each next zone is fully contained within the current.
func _generate_zone_circles() -> void:
	# Calculate the initial map radius (half the smaller dimension of map bounds)
	var map_center := _map_bounds.get_center()
	var map_radius := minf(_map_bounds.size.x, _map_bounds.size.y) / 2.0
	
	# Set initial zone to cover the full map
	current_center = map_center
	current_radius = map_radius
	
	# Pre-calculate all zone centers and radii
	var prev_center := map_center
	var prev_radius := map_radius
	
	# Store generated zones for each phase
	var _zone_centers: Array[Vector2] = []
	var _zone_radii: Array[float] = []
	
	_zone_centers.append(prev_center)
	_zone_radii.append(prev_radius)
	
	for i in range(_phase_configs.size()):
		var config: Dictionary = _phase_configs[i]
		var radius_percent: float = config.get("safe_radius_percent", 50) / 100.0
		var new_radius: float = map_radius * radius_percent
		
		# Generate a random center that ensures containment:
		# distance(prev_center, new_center) + new_radius <= prev_radius
		var max_offset: float = prev_radius - new_radius
		var new_center: Vector2
		
		if max_offset <= 0.0:
			new_center = prev_center
		else:
			# Random offset within allowed range
			var angle := randf() * TAU
			var offset_distance := randf() * max_offset
			new_center = prev_center + Vector2(cos(angle), sin(angle)) * offset_distance
		
		_zone_centers.append(new_center)
		_zone_radii.append(new_radius)
		
		prev_center = new_center
		prev_radius = new_radius
	
	# Store the generated zones for phase transitions
	_stored_zone_centers = _zone_centers
	_stored_zone_radii = _zone_radii
	
	# Set initial next zone
	if _stored_zone_centers.size() > 1:
		next_center = _stored_zone_centers[1]
		next_radius = _stored_zone_radii[1]


## Stored zone centers for all phases (index 0 = initial, index 1 = phase 1 target, etc.)
var _stored_zone_centers: Array[Vector2] = []

## Stored zone radii for all phases.
var _stored_zone_radii: Array[float] = []


## Calculates the next zone target for a given phase.
func _calculate_next_zone_for_phase(phase: int) -> void:
	# phase is 1-based, stored zones index: 0=initial, 1=phase1 target, 2=phase2 target...
	var target_index := phase
	if target_index < _stored_zone_centers.size():
		next_center = _stored_zone_centers[target_index]
		next_radius = _stored_zone_radii[target_index]


## Returns the config dictionary for the current phase.
func _get_current_phase_config() -> Dictionary:
	var phase_index := current_phase - 1
	if phase_index >= 0 and phase_index < _phase_configs.size():
		return _phase_configs[phase_index]
	return {}


## Returns the wait time for a given phase (1-based) after applying speed multiplier.
func get_phase_wait_time(phase: int) -> float:
	var phase_index := phase - 1
	if phase_index >= 0 and phase_index < _phase_configs.size():
		return float(_phase_configs[phase_index].get("wait_seconds", 60)) * _speed_multiplier
	return 0.0


## Returns the shrink duration for a given phase (1-based) after applying speed multiplier.
func get_phase_shrink_duration(phase: int) -> float:
	var phase_index := phase - 1
	if phase_index >= 0 and phase_index < _phase_configs.size():
		return float(_phase_configs[phase_index].get("shrink_seconds", 60)) * _speed_multiplier
	return 0.0


## Returns the current wait timer remaining.
func get_wait_timer_remaining() -> float:
	return _wait_timer


## Returns the current shrink timer remaining.
func get_shrink_timer_remaining() -> float:
	return _shrink_timer
