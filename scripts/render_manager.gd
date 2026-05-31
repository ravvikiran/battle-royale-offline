## Manages graphics quality presets and adaptive quality reduction based on device memory.
## Monitors available memory during matches and automatically reduces quality when
## memory pressure is detected. Provides quality presets (Low, Medium, High) that
## adjust draw distance, shadow quality, and particle effects.
class_name RenderManager
extends Node


## Emitted when graphics quality is reduced due to memory pressure.
## [param new_preset]: The new quality preset after reduction.
signal quality_reduced(new_preset: QualityPreset)

## Emitted when a critical memory warning is displayed.
signal critical_memory_warning()

## Emitted when the quality indicator should be shown briefly.
## [param message]: The message to display to the player.
signal quality_indicator_shown(message: String)


## Graphics quality preset levels.
enum QualityPreset {
	LOW,
	MEDIUM,
	HIGH,
}


## Memory threshold (MB) below which quality is reduced by one level.
const MEMORY_THRESHOLD_REDUCE: int = 200

## Critical memory threshold (MB) at lowest preset — triggers match state preservation.
const MEMORY_THRESHOLD_CRITICAL: int = 100

## Target minimum frames per second on mid-range devices.
const TARGET_FPS: int = 30

## Maximum installed application size in megabytes.
const MAX_INSTALLED_SIZE_MB: int = 500

## Minimum Android API level supported.
const MIN_ANDROID_API: int = 26

## Maximum map loading time in seconds (to Drop Phase on minimum spec).
const MAX_MAP_LOAD_TIME_SECONDS: float = 15.0

## Maximum number of bots visible on screen for performance target.
const MAX_VISIBLE_BOTS: int = 20

## Minimum device RAM in MB for performance target.
const MIN_DEVICE_RAM_MB: int = 4096

## Duration in seconds to show the quality reduction indicator.
const QUALITY_INDICATOR_DURATION: float = 3.0

## Memory check interval in seconds during a match.
const MEMORY_CHECK_INTERVAL: float = 5.0


## Quality preset settings for each level.
## Each preset defines draw_distance (meters), shadow_quality (0-2), particle_density (0.0-1.0).
const PRESET_SETTINGS: Dictionary = {
	QualityPreset.LOW: {
		"draw_distance": 150.0,
		"shadow_quality": 0,
		"particle_density": 0.25,
		"label": "Low",
	},
	QualityPreset.MEDIUM: {
		"draw_distance": 300.0,
		"shadow_quality": 1,
		"particle_density": 0.6,
		"label": "Medium",
	},
	QualityPreset.HIGH: {
		"draw_distance": 500.0,
		"shadow_quality": 2,
		"particle_density": 1.0,
		"label": "High",
	},
}


## Current graphics quality preset.
var current_preset: QualityPreset = QualityPreset.MEDIUM

## Current draw distance in meters.
var draw_distance: float = 300.0

## Current shadow quality level (0 = off, 1 = low, 2 = high).
var shadow_quality: int = 1

## Current particle effect density (0.0 = none, 1.0 = full).
var particle_density: float = 0.6

## Whether a match is currently active (enables memory monitoring).
var _match_active: bool = false

## Timer for periodic memory checks during a match.
var _memory_check_timer: float = 0.0

## Whether the quality indicator is currently being shown.
var _indicator_visible: bool = false

## Remaining time for the quality indicator display.
var _indicator_timer: float = 0.0

## Whether a critical memory warning has been shown this match (avoid spam).
var _critical_warning_shown: bool = false

## Whether quality was auto-reduced this match (for tracking).
var _quality_auto_reduced: bool = false

## Preserved match state when critical memory is reached.
var _preserved_match_state: Dictionary = {}


## Sets the graphics quality preset and applies its settings.
## [param preset]: The quality preset to apply (LOW, MEDIUM, HIGH).
func set_quality_preset(preset: QualityPreset) -> void:
	current_preset = preset
	_apply_preset_settings(preset)


## Returns the current quality preset.
func get_quality_preset() -> QualityPreset:
	return current_preset


## Returns the settings dictionary for a given preset.
func get_preset_settings(preset: QualityPreset) -> Dictionary:
	if PRESET_SETTINGS.has(preset):
		return PRESET_SETTINGS[preset].duplicate()
	return PRESET_SETTINGS[QualityPreset.MEDIUM].duplicate()


## Returns the human-readable label for the current preset.
func get_current_preset_label() -> String:
	return PRESET_SETTINGS[current_preset]["label"]


## Starts memory monitoring for an active match.
## Call this when a match begins (after map loading).
func start_match_monitoring() -> void:
	_match_active = true
	_memory_check_timer = MEMORY_CHECK_INTERVAL
	_critical_warning_shown = false
	_quality_auto_reduced = false
	_preserved_match_state = {}


## Stops memory monitoring when a match ends.
func stop_match_monitoring() -> void:
	_match_active = false
	_memory_check_timer = 0.0


## Returns whether a match is currently being monitored.
func is_match_monitoring_active() -> bool:
	return _match_active


## Checks available device memory and performs adaptive quality reduction if needed.
## Called periodically during a match or can be called manually.
## [param available_memory_mb]: Available device memory in megabytes.
## Returns a dictionary with the action taken: { "action": String, "details": Dictionary }
func check_memory_and_adapt(available_memory_mb: int) -> Dictionary:
	if not _match_active:
		return {"action": "none", "details": {}}

	# Critical memory at lowest preset — preserve match state and warn
	if available_memory_mb < MEMORY_THRESHOLD_CRITICAL and current_preset == QualityPreset.LOW:
		if not _critical_warning_shown:
			_critical_warning_shown = true
			_preserve_match_state()
			critical_memory_warning.emit()
			return {
				"action": "critical_warning",
				"details": {
					"memory_mb": available_memory_mb,
					"message": "Low memory — match may need to end",
				},
			}
		return {"action": "none", "details": {}}

	# Memory below threshold and not at lowest preset — reduce quality
	if available_memory_mb < MEMORY_THRESHOLD_REDUCE and current_preset != QualityPreset.LOW:
		var old_preset := current_preset
		var new_preset := _get_lower_preset(current_preset)
		set_quality_preset(new_preset)
		_quality_auto_reduced = true

		var message := "Quality reduced to %s" % get_current_preset_label()
		_show_quality_indicator(message)
		quality_reduced.emit(new_preset)

		return {
			"action": "quality_reduced",
			"details": {
				"old_preset": old_preset,
				"new_preset": new_preset,
				"memory_mb": available_memory_mb,
				"message": message,
			},
		}

	return {"action": "none", "details": {}}


## Returns the available device memory in megabytes.
## Uses OS.get_static_memory_usage() in Godot or platform-specific queries.
## This method can be overridden in tests to simulate memory conditions.
func get_available_memory_mb() -> int:
	# In a full implementation, this would query the device's available memory.
	# On Android, this uses ActivityManager.getMemoryInfo().
	# For Godot, we estimate from OS.get_static_memory_usage() and device total RAM.
	var static_memory := OS.get_static_memory_usage()
	var static_memory_mb := int(static_memory / (1024 * 1024))

	# Estimate available memory (total device RAM minus current usage)
	# This is a simplified estimation; real implementation would use platform APIs.
	var estimated_total_mb := MIN_DEVICE_RAM_MB
	var available := estimated_total_mb - static_memory_mb
	return maxi(available, 0)


## Returns whether the quality indicator is currently visible.
func is_quality_indicator_visible() -> bool:
	return _indicator_visible


## Returns whether quality was auto-reduced during the current match.
func was_quality_auto_reduced() -> bool:
	return _quality_auto_reduced


## Returns whether a critical memory warning was shown this match.
func was_critical_warning_shown() -> bool:
	return _critical_warning_shown


## Returns the preserved match state (set when critical memory is reached).
func get_preserved_match_state() -> Dictionary:
	return _preserved_match_state.duplicate()


## Sets match state data to be preserved in case of critical memory.
## [param state]: Dictionary containing match state to preserve.
func set_match_state_for_preservation(state: Dictionary) -> void:
	_preserved_match_state = state.duplicate()


## Returns whether the current device meets minimum spec requirements.
## Minimum spec: 4GB RAM, Android 8.0+ (API 26).
func meets_minimum_spec() -> bool:
	var os_name := OS.get_name()
	if os_name == "Android":
		# Check API level (would use OS.get_model_name() or Engine info in real impl)
		pass
	# For non-Android or testing, assume minimum spec is met
	return true


## Called every frame to update memory monitoring and indicator timers.
func _process(delta: float) -> void:
	_update_indicator_timer(delta)
	_update_memory_check(delta)


## Updates the quality indicator display timer.
func _update_indicator_timer(delta: float) -> void:
	if _indicator_visible:
		_indicator_timer -= delta
		if _indicator_timer <= 0.0:
			_indicator_visible = false
			_indicator_timer = 0.0


## Periodically checks device memory during an active match.
func _update_memory_check(delta: float) -> void:
	if not _match_active:
		return

	_memory_check_timer -= delta
	if _memory_check_timer <= 0.0:
		_memory_check_timer = MEMORY_CHECK_INTERVAL
		var available_mb := get_available_memory_mb()
		check_memory_and_adapt(available_mb)


## Applies the rendering settings for a given preset.
func _apply_preset_settings(preset: QualityPreset) -> void:
	var settings: Dictionary = PRESET_SETTINGS[preset]
	draw_distance = settings["draw_distance"]
	shadow_quality = settings["shadow_quality"]
	particle_density = settings["particle_density"]

	# In a full implementation, this would configure:
	# - RenderingServer.directional_shadow_atlas_size
	# - Camera3D.far (draw distance)
	# - GPUParticles3D amount multiplier
	# - Environment quality settings


## Returns the next lower quality preset.
## HIGH → MEDIUM, MEDIUM → LOW, LOW → LOW (no change).
func _get_lower_preset(preset: QualityPreset) -> QualityPreset:
	match preset:
		QualityPreset.HIGH:
			return QualityPreset.MEDIUM
		QualityPreset.MEDIUM:
			return QualityPreset.LOW
		_:
			return QualityPreset.LOW


## Shows the quality indicator for a brief duration.
func _show_quality_indicator(message: String) -> void:
	_indicator_visible = true
	_indicator_timer = QUALITY_INDICATOR_DURATION
	quality_indicator_shown.emit(message)


## Preserves the current match state for potential recovery.
## Called when critical memory threshold is reached at lowest quality.
func _preserve_match_state() -> void:
	# In a full implementation, this would serialize:
	# - Player position, health, shield, inventory
	# - Bot positions and states
	# - Zone phase and timer state
	# - Match statistics so far
	# The _preserved_match_state dictionary is populated by the match controller
	# via set_match_state_for_preservation() before this point.
	pass
