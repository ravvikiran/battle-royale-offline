## Manages combat juice: screen shake, hit markers, kill streaks,
## damage numbers, elimination banners, and visual/audio feedback.
## Creates the visceral, impactful feel that keeps players engaged.
class_name CombatFeedback
extends Node


## Emitted when a kill streak tier is achieved
signal streak_achieved(streak_tier: Enums.KillStreak, kill_count: int)

## Emitted when a streak ends
signal streak_ended(final_count: int)

## Emitted when a screen effect should play
signal screen_effect_requested(effect: Enums.ScreenEffect, intensity: float)

## Emitted when a hit marker should display
signal hit_marker_requested(is_kill: bool, damage: float, position: Vector2)

## Emitted when a damage number should float up
signal damage_number_requested(amount: int, position: Vector2, is_critical: bool)

## Emitted when an elimination banner should show
signal elimination_banner_requested(victim_name: String, weapon: String, streak: int)


## Current kill streak count
var current_streak: int = 0

## Maximum streak achieved this match
var max_streak: int = 0

## Time since last kill (for rapid kill detection)
var _time_since_last_kill: float = 0.0

## Whether the streak timer is active
var _streak_active: bool = false

## Current screen shake intensity (decays over time)
var _shake_intensity: float = 0.0

## Current screen shake decay rate
var _shake_decay: float = 8.0

## Screen shake offset (applied to camera)
var shake_offset: Vector2 = Vector2.ZERO

## Low HP pulse timer
var _low_hp_pulse_timer: float = 0.0

## Whether low HP vignette is active
var _low_hp_active: bool = false

## Speed lines intensity (for fast movement)
var _speed_lines_intensity: float = 0.0

## Hit marker display timer
var _hit_marker_timer: float = 0.0

## Whether hit marker is visible
var hit_marker_visible: bool = false

## Whether it was a kill hit marker
var hit_marker_is_kill: bool = false


## Time window for rapid kills to count as streak (seconds)
const STREAK_WINDOW: float = 8.0

## Screen shake intensities per event type
const SHAKE_INTENSITIES: Dictionary = {
	"hit_received_light": 3.0,
	"hit_received_heavy": 8.0,
	"near_death": 12.0,
	"explosion": 15.0,
	"kill_confirm": 2.0,
	"headshot": 5.0,
	"streak_announce": 4.0,
}

## Kill streak tier thresholds
const STREAK_TIERS: Dictionary = {
	1: Enums.KillStreak.FIRST_BLOOD,
	2: Enums.KillStreak.DOUBLE_KILL,
	3: Enums.KillStreak.TRIPLE_KILL,
	4: Enums.KillStreak.QUAD_KILL,
	5: Enums.KillStreak.RAMPAGE,
	7: Enums.KillStreak.UNSTOPPABLE,
	10: Enums.KillStreak.GODLIKE,
	15: Enums.KillStreak.LEGENDARY,
}

## Streak announcement text
const STREAK_ANNOUNCEMENTS: Dictionary = {
	Enums.KillStreak.FIRST_BLOOD: "FIRST BLOOD",
	Enums.KillStreak.DOUBLE_KILL: "DOUBLE KILL",
	Enums.KillStreak.TRIPLE_KILL: "TRIPLE KILL",
	Enums.KillStreak.QUAD_KILL: "QUAD KILL",
	Enums.KillStreak.RAMPAGE: "RAMPAGE!",
	Enums.KillStreak.UNSTOPPABLE: "UNSTOPPABLE!",
	Enums.KillStreak.GODLIKE: "G O D L I K E",
	Enums.KillStreak.LEGENDARY: "L E G E N D A R Y",
}

## Hit marker display duration
const HIT_MARKER_DURATION: float = 0.15

## Kill confirm marker duration (longer)
const KILL_MARKER_DURATION: float = 0.4

## Low HP threshold for vignette effect
const LOW_HP_THRESHOLD: float = 25.0

## Low HP pulse frequency (Hz)
const LOW_HP_PULSE_FREQ: float = 1.5


func _process(delta: float) -> void:
	_process_screen_shake(delta)
	_process_streak_timer(delta)
	_process_hit_marker(delta)
	_process_low_hp(delta)


## Processes screen shake decay
func _process_screen_shake(delta: float) -> void:
	if _shake_intensity > 0.01:
		_shake_intensity = lerpf(_shake_intensity, 0.0, _shake_decay * delta)
		# Generate random offset based on intensity
		shake_offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		_shake_intensity = 0.0
		shake_offset = Vector2.ZERO


## Processes the kill streak timer
func _process_streak_timer(delta: float) -> void:
	if _streak_active:
		_time_since_last_kill += delta
		if _time_since_last_kill > STREAK_WINDOW:
			_end_streak()


## Processes hit marker visibility timer
func _process_hit_marker(delta: float) -> void:
	if hit_marker_visible:
		_hit_marker_timer -= delta
		if _hit_marker_timer <= 0.0:
			hit_marker_visible = false


## Processes low HP pulsing effect
func _process_low_hp(delta: float) -> void:
	if _low_hp_active:
		_low_hp_pulse_timer += delta
		var pulse: float = (sin(_low_hp_pulse_timer * TAU * LOW_HP_PULSE_FREQ) + 1.0) * 0.5
		screen_effect_requested.emit(Enums.ScreenEffect.LOW_HP_VIGNETTE, pulse * 0.4)


## Called when the player gets a kill
func on_player_kill(victim_name: String, weapon: String, damage: float) -> void:
	current_streak += 1
	max_streak = maxi(max_streak, current_streak)
	_time_since_last_kill = 0.0
	_streak_active = true

	# Show kill confirm hit marker
	hit_marker_visible = true
	hit_marker_is_kill = true
	_hit_marker_timer = KILL_MARKER_DURATION
	hit_marker_requested.emit(true, damage, Vector2.ZERO)

	# Screen shake for kill confirm
	apply_shake("kill_confirm")

	# Flash effect
	screen_effect_requested.emit(Enums.ScreenEffect.FLASH_KILL, 0.3)

	# Check streak tier
	var tier: Enums.KillStreak = _get_streak_tier(current_streak)
	if tier != Enums.KillStreak.NONE:
		streak_achieved.emit(tier, current_streak)
		# Extra shake for streak milestones
		apply_shake("streak_announce")

	# Show elimination banner
	elimination_banner_requested.emit(victim_name, weapon, current_streak)


## Called when the player hits an enemy (but doesn't kill)
func on_player_hit(damage: float, target_position: Vector2) -> void:
	hit_marker_visible = true
	hit_marker_is_kill = false
	_hit_marker_timer = HIT_MARKER_DURATION
	hit_marker_requested.emit(false, damage, target_position)

	# Show damage number
	damage_number_requested.emit(int(damage), target_position, damage >= 50.0)


## Called when the player receives damage
func on_player_damaged(amount: float, from_direction: Vector2) -> void:
	if amount >= 40.0:
		apply_shake("hit_received_heavy")
	else:
		apply_shake("hit_received_light")

	# Red vignette pulse
	var intensity: float = clampf(amount / 100.0, 0.2, 0.8)
	screen_effect_requested.emit(Enums.ScreenEffect.PULSE_DAMAGE, intensity)


## Called when the player is near death (health < 10)
func on_near_death() -> void:
	apply_shake("near_death")
	screen_effect_requested.emit(Enums.ScreenEffect.PULSE_DAMAGE, 0.9)


## Called when the player heals
func on_player_healed(amount: float) -> void:
	var intensity: float = clampf(amount / 100.0, 0.2, 0.6)
	screen_effect_requested.emit(Enums.ScreenEffect.PULSE_HEAL, intensity)


## Called when the player gains shield
func on_shield_gained(amount: float) -> void:
	var intensity: float = clampf(amount / 50.0, 0.3, 0.7)
	screen_effect_requested.emit(Enums.ScreenEffect.PULSE_SHIELD, intensity)


## Called to update health state for low-HP effects
func update_health_state(health: float) -> void:
	var should_be_low: bool = health <= LOW_HP_THRESHOLD and health > 0.0
	if should_be_low and not _low_hp_active:
		_low_hp_active = true
		_low_hp_pulse_timer = 0.0
	elif not should_be_low and _low_hp_active:
		_low_hp_active = false
		screen_effect_requested.emit(Enums.ScreenEffect.LOW_HP_VIGNETTE, 0.0)


## Called when the player moves fast (e.g., sliding or sprinting)
func update_speed_effect(speed: float, max_speed: float) -> void:
	_speed_lines_intensity = clampf((speed / max_speed) - 0.7, 0.0, 1.0) * 3.0
	if _speed_lines_intensity > 0.1:
		screen_effect_requested.emit(Enums.ScreenEffect.SPEED_LINES, _speed_lines_intensity)


## Applies a named screen shake
func apply_shake(shake_name: String) -> void:
	var intensity: float = SHAKE_INTENSITIES.get(shake_name, 3.0)
	# Use max to prevent weaker shakes from overriding stronger ones
	_shake_intensity = maxf(_shake_intensity, intensity)


## Gets the current streak announcement text (empty if no announcement needed)
func get_streak_announcement() -> String:
	var tier: Enums.KillStreak = _get_streak_tier(current_streak)
	return STREAK_ANNOUNCEMENTS.get(tier, "")


## Gets the streak tier for a given kill count
func _get_streak_tier(kills: int) -> Enums.KillStreak:
	var best_tier: Enums.KillStreak = Enums.KillStreak.NONE
	for threshold in STREAK_TIERS.keys():
		if kills >= threshold:
			best_tier = STREAK_TIERS[threshold]
	return best_tier


## Ends the current streak
func _end_streak() -> void:
	if current_streak > 0:
		streak_ended.emit(current_streak)
	_streak_active = false
	current_streak = 0
	_time_since_last_kill = 0.0


## Resets all combat feedback state for a new match
func reset() -> void:
	current_streak = 0
	max_streak = 0
	_streak_active = false
	_time_since_last_kill = 0.0
	_shake_intensity = 0.0
	shake_offset = Vector2.ZERO
	_low_hp_active = false
	_speed_lines_intensity = 0.0
	hit_marker_visible = false
	hit_marker_is_kill = false
