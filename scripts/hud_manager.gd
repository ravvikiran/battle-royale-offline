## HUD Manager - Manages all heads-up display components.
## Signal-driven updates ensure HUD reflects game state within 1 frame of change.
##
## Components: HealthBar, WeaponDisplay, Minimap, KillFeed, AliveCounter,
## Compass, DamageIndicator, StormIndicators.
class_name HUDManager
extends Node


# --- Constants ---

## Maximum number of kill feed entries displayed at once.
const MAX_KILL_FEED_ENTRIES: int = 5

## Duration in seconds before a kill feed entry is removed.
const KILL_FEED_TIMEOUT: float = 5.0

## Duration in seconds for damage indicator display.
const DAMAGE_INDICATOR_DURATION: float = 2.0

## Cardinal direction definitions for compass.
const CARDINAL_DIRECTIONS: Array = [
	{"label": "N", "angle": 0.0},
	{"label": "E", "angle": 90.0},
	{"label": "S", "angle": 180.0},
	{"label": "W", "angle": 270.0},
]

## Rarity tier color mapping for weapon display border.
const RARITY_COLORS: Dictionary = {
	0: Color(0.6, 0.6, 0.6, 1.0),    # Common - Gray
	1: Color(0.0, 0.8, 0.0, 1.0),    # Uncommon - Green
	2: Color(0.0, 0.4, 1.0, 1.0),    # Rare - Blue
	3: Color(0.6, 0.0, 0.9, 1.0),    # Epic - Purple
	4: Color(1.0, 0.65, 0.0, 1.0),   # Legendary - Orange
}

## Maximum health value used for proportional bar calculation.
const MAX_HEALTH_REFERENCE: float = 100.0

## Maximum shield value used for proportional bar calculation.
const MAX_SHIELD_REFERENCE: float = 100.0


# --- Signals ---

signal health_updated(health: float, shield: float)
signal weapon_updated(weapon_name: String, ammo: int, magazine: int, reserve: int, rarity: int)
signal minimap_updated(player_pos: Vector2, player_dir: float, zone_center: Vector2, zone_radius: float, next_center: Vector2, next_radius: float)
signal kill_feed_changed(entries: Array)
signal alive_count_changed(count: int)
signal compass_updated(heading: float, cardinal: String)
signal damage_indicator_shown(direction: float)
signal storm_indicators_changed(visible: bool, direction: Vector2)


# --- Health Bar ---

## Current health value (can exceed 100).
var current_health: float = 100.0

## Current shield value (can exceed 100).
var current_shield: float = 0.0


# --- Weapon Display ---

## Currently equipped weapon name.
var weapon_name: String = ""

## Current ammo in magazine.
var weapon_ammo: int = 0

## Magazine capacity.
var weapon_magazine_capacity: int = 0

## Reserve ammo count.
var weapon_reserve_ammo: int = 0

## Weapon rarity tier index.
var weapon_rarity: int = 0

## Whether the current weapon is a melee weapon (no ammo system).
var weapon_is_melee: bool = false


# --- Kill Feed ---

## Active kill feed entries. Each entry is a Dictionary with:
## { "killer": String, "victim": String, "weapon": String, "timestamp": float }
var _kill_feed_entries: Array = []

## Internal timer tracking for kill feed entry removal.
var _kill_feed_timers: Array = []


# --- Alive Counter ---

## Number of participants still alive.
var alive_count: int = 0


# --- Compass ---

## Player's current facing direction in degrees (0-360, 0 = North, clockwise).
var compass_heading: float = 0.0


# --- Damage Indicator ---

## Active damage indicators. Each is { "direction": float, "timer": float }.
var _damage_indicators: Array = []


# --- Storm Indicators ---

## Whether the player is currently in the storm.
var _player_in_storm: bool = false

## Whether the damage indicator component is renderable.
var _storm_damage_indicator_renderable: bool = true

## Whether the directional guide component is renderable.
var _storm_directional_guide_renderable: bool = true

## Direction toward the nearest safe zone point (normalized vector).
var _storm_safe_direction: Vector2 = Vector2.ZERO

## Whether storm indicators are currently displayed (both or neither).
var storm_indicators_visible: bool = false


# --- Minimap ---

## Player position on minimap.
var minimap_player_position: Vector2 = Vector2.ZERO

## Player facing direction for minimap arrow.
var minimap_player_direction: float = 0.0

## Current zone center for minimap display.
var minimap_zone_center: Vector2 = Vector2.ZERO

## Current zone radius for minimap display.
var minimap_zone_radius: float = 0.0

## Next zone center for minimap display.
var minimap_next_zone_center: Vector2 = Vector2.ZERO

## Next zone radius for minimap display.
var minimap_next_zone_radius: float = 0.0


# --- Public Methods: Health Bar ---


## Updates health and shield display values.
## Values are stored as-is (can exceed 100) for numeric text display.
## Proportional bars use MAX_HEALTH_REFERENCE and MAX_SHIELD_REFERENCE.
func update_health(health: float, shield: float) -> void:
	current_health = health
	current_shield = shield
	health_updated.emit(health, shield)


## Returns the health bar proportion (0.0 to 1.0+).
## Values above 100 will produce proportions > 1.0 for overheal display.
func get_health_bar_proportion() -> float:
	if MAX_HEALTH_REFERENCE <= 0.0:
		return 0.0
	return current_health / MAX_HEALTH_REFERENCE


## Returns the shield bar proportion (0.0 to 1.0+).
## Values above 100 will produce proportions > 1.0 for overshield display.
func get_shield_bar_proportion() -> float:
	if MAX_SHIELD_REFERENCE <= 0.0:
		return 0.0
	return current_shield / MAX_SHIELD_REFERENCE


## Returns the health value as display text (integer, shows actual value even if > 100).
func get_health_display_text() -> String:
	return str(int(current_health))


## Returns the shield value as display text (integer, shows actual value even if > 100).
func get_shield_display_text() -> String:
	return str(int(current_shield))


# --- Public Methods: Weapon Display ---


## Updates the weapon display with current weapon info.
## For melee weapons (no ammo system), pass ammo=0, magazine=0, reserve=0, is_melee=true.
func update_weapon(name: String, ammo: int, magazine: int, reserve: int, rarity: int, is_melee: bool = false) -> void:
	weapon_name = name
	weapon_ammo = ammo
	weapon_magazine_capacity = magazine
	weapon_reserve_ammo = reserve
	weapon_rarity = rarity
	weapon_is_melee = is_melee
	weapon_updated.emit(name, ammo, magazine, reserve, rarity)


## Returns the formatted ammo display string: "current/magazine + reserve".
## For melee weapons, returns "0/0".
func get_ammo_display_text() -> String:
	if weapon_is_melee:
		return "0/0"
	return "%d/%d + %d" % [weapon_ammo, weapon_magazine_capacity, weapon_reserve_ammo]


## Returns the rarity color for the current weapon's border/background.
func get_weapon_rarity_color() -> Color:
	if RARITY_COLORS.has(weapon_rarity):
		return RARITY_COLORS[weapon_rarity]
	return RARITY_COLORS[0]


## Returns the current weapon name for display.
func get_weapon_display_name() -> String:
	return weapon_name


# --- Public Methods: Kill Feed ---


## Adds a new kill feed entry. Maintains max 5 entries.
## Each entry is removed after 5 seconds.
func add_kill_feed_entry(entry: Dictionary) -> void:
	entry["timestamp"] = _get_current_time()

	_kill_feed_entries.append(entry)
	_kill_feed_timers.append(KILL_FEED_TIMEOUT)

	# Enforce maximum entries - remove oldest if over limit
	while _kill_feed_entries.size() > MAX_KILL_FEED_ENTRIES:
		_kill_feed_entries.pop_front()
		_kill_feed_timers.pop_front()

	kill_feed_changed.emit(_kill_feed_entries.duplicate())


## Returns the current kill feed entries (read-only copy).
func get_kill_feed_entries() -> Array:
	return _kill_feed_entries.duplicate()


## Returns the number of active kill feed entries.
func get_kill_feed_count() -> int:
	return _kill_feed_entries.size()


# --- Public Methods: Alive Counter ---


## Updates the alive participant count. Emits signal immediately on change.
func update_alive_count(count: int) -> void:
	alive_count = count
	alive_count_changed.emit(count)


## Returns the current alive count for display.
func get_alive_count() -> int:
	return alive_count


# --- Public Methods: Compass ---


## Updates the compass heading based on player facing direction.
## Angle is in degrees: 0 = North, 90 = East, 180 = South, 270 = West.
func update_compass(facing_degrees: float) -> void:
	# Normalize to 0-360 range
	compass_heading = fmod(facing_degrees, 360.0)
	if compass_heading < 0.0:
		compass_heading += 360.0

	var cardinal := get_cardinal_direction(compass_heading)
	compass_updated.emit(compass_heading, cardinal)


## Returns the degree heading for the current compass state.
func get_compass_heading() -> float:
	return compass_heading


## Returns the nearest cardinal direction label for a given heading.
func get_cardinal_direction(heading: float) -> String:
	# Normalize heading
	var h := fmod(heading, 360.0)
	if h < 0.0:
		h += 360.0

	# Determine nearest cardinal direction (within 45 degrees)
	if h >= 315.0 or h < 45.0:
		return "N"
	elif h >= 45.0 and h < 135.0:
		return "E"
	elif h >= 135.0 and h < 225.0:
		return "S"
	else:
		return "W"


## Returns the relative position (offset in degrees) of a cardinal direction
## marker on the compass strip, relative to the current heading.
## Returns a value in range [-180, 180] where 0 = center of compass.
func get_cardinal_position(cardinal_angle: float) -> float:
	var diff := cardinal_angle - compass_heading
	# Normalize to [-180, 180]
	while diff > 180.0:
		diff -= 360.0
	while diff < -180.0:
		diff += 360.0
	return diff


## Returns all cardinal direction positions relative to the current heading.
## Each entry: { "label": String, "angle": float, "position": float }
## Position is the offset in degrees from center [-180, 180].
func get_all_cardinal_positions() -> Array:
	var positions: Array = []
	for cardinal in CARDINAL_DIRECTIONS:
		positions.append({
			"label": cardinal["label"],
			"angle": cardinal["angle"],
			"position": get_cardinal_position(cardinal["angle"]),
		})
	return positions


# --- Public Methods: Damage Indicator ---


## Shows a directional damage indicator pointing toward the source.
## Direction is in degrees (angle from player to damage source).
## Persists for 2 seconds after the last damage from that direction.
func show_damage_direction(source_direction: float) -> void:
	# Check if there's already an indicator for this direction (within 10 degrees)
	for indicator in _damage_indicators:
		if absf(indicator["direction"] - source_direction) < 10.0:
			# Reset timer for existing indicator
			indicator["timer"] = DAMAGE_INDICATOR_DURATION
			return

	_damage_indicators.append({
		"direction": source_direction,
		"timer": DAMAGE_INDICATOR_DURATION,
	})
	damage_indicator_shown.emit(source_direction)


## Returns the currently active damage indicators for rendering.
## Each entry: { "direction": float, "timer": float }
func get_active_damage_indicators() -> Array:
	return _damage_indicators.duplicate()


## Returns the number of active damage indicators.
func get_damage_indicator_count() -> int:
	return _damage_indicators.size()


# --- Public Methods: Storm Indicators ---


## Shows storm indicators (damage indicator + directional guide).
## Both are displayed together or neither is displayed (paired display).
func show_storm_indicator(direction_to_safe: Vector2) -> void:
	_player_in_storm = true
	_storm_safe_direction = direction_to_safe.normalized() if direction_to_safe.length() > 0.0 else Vector2.ZERO
	_update_storm_indicators_visibility()


## Hides storm indicators (player left the storm).
func hide_storm_indicator() -> void:
	_player_in_storm = false
	storm_indicators_visible = false
	storm_indicators_changed.emit(false, Vector2.ZERO)


## Sets whether the storm damage indicator component can render.
## If either component fails, both are hidden (paired display rule).
func set_storm_damage_indicator_renderable(renderable: bool) -> void:
	_storm_damage_indicator_renderable = renderable
	_update_storm_indicators_visibility()


## Sets whether the storm directional guide component can render.
## If either component fails, both are hidden (paired display rule).
func set_storm_directional_guide_renderable(renderable: bool) -> void:
	_storm_directional_guide_renderable = renderable
	_update_storm_indicators_visibility()


## Returns whether storm indicators are currently visible.
func are_storm_indicators_visible() -> bool:
	return storm_indicators_visible


## Returns the storm safe direction vector.
func get_storm_safe_direction() -> Vector2:
	return _storm_safe_direction


## Returns whether the player is currently in the storm.
func is_player_in_storm() -> bool:
	return _player_in_storm


# --- Public Methods: Minimap ---


## Updates minimap data with signal-driven notification.
func update_minimap(player_pos: Vector2, player_dir: float,
		zone_center: Vector2, zone_radius: float,
		next_center: Vector2, next_radius: float) -> void:
	minimap_player_position = player_pos
	minimap_player_direction = player_dir
	minimap_zone_center = zone_center
	minimap_zone_radius = zone_radius
	minimap_next_zone_center = next_center
	minimap_next_zone_radius = next_radius
	minimap_updated.emit(player_pos, player_dir, zone_center, zone_radius, next_center, next_radius)


## Returns the minimap state as a dictionary for rendering.
func get_minimap_state() -> Dictionary:
	return {
		"player_position": minimap_player_position,
		"player_direction": minimap_player_direction,
		"zone_center": minimap_zone_center,
		"zone_radius": minimap_zone_radius,
		"next_zone_center": minimap_next_zone_center,
		"next_zone_radius": minimap_next_zone_radius,
	}


# --- Process (timer updates) ---


## Called every frame to update time-based HUD elements.
func _process(delta: float) -> void:
	_update_kill_feed_timers(delta)
	_update_damage_indicators(delta)


# --- Private Methods ---


## Updates kill feed timers and removes expired entries.
func _update_kill_feed_timers(delta: float) -> void:
	var entries_removed := false

	# Update timers from back to front for safe removal
	var i := _kill_feed_timers.size() - 1
	while i >= 0:
		_kill_feed_timers[i] -= delta
		if _kill_feed_timers[i] <= 0.0:
			_kill_feed_entries.remove_at(i)
			_kill_feed_timers.remove_at(i)
			entries_removed = true
		i -= 1

	if entries_removed:
		kill_feed_changed.emit(_kill_feed_entries.duplicate())


## Updates damage indicator timers and removes expired ones.
func _update_damage_indicators(delta: float) -> void:
	var i := _damage_indicators.size() - 1
	while i >= 0:
		_damage_indicators[i]["timer"] -= delta
		if _damage_indicators[i]["timer"] <= 0.0:
			_damage_indicators.remove_at(i)
		i -= 1


## Updates storm indicator visibility based on paired display rule.
## Both damage indicator and directional guide must be renderable,
## otherwise neither is shown.
func _update_storm_indicators_visibility() -> void:
	if not _player_in_storm:
		storm_indicators_visible = false
		storm_indicators_changed.emit(false, Vector2.ZERO)
		return

	# Paired display: both must be renderable, or neither is shown
	var both_renderable := _storm_damage_indicator_renderable and _storm_directional_guide_renderable
	storm_indicators_visible = both_renderable

	storm_indicators_changed.emit(storm_indicators_visible, _storm_safe_direction if storm_indicators_visible else Vector2.ZERO)


## Returns the current time in seconds (for timestamping kill feed entries).
## Can be overridden in tests.
func _get_current_time() -> float:
	return Time.get_ticks_msec() / 1000.0
