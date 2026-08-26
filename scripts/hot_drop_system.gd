## Hot Drop system that creates risk/reward landing zones during the drop phase.
## Zones are dynamically generated each match with varying heat levels.
## Hotter zones have better loot but more bots landing there.
## Provides visual indicators and post-drop survival bonuses.
class_name HotDropSystem
extends RefCounted


## Emitted when drop zones are generated for a new match
signal zones_generated(zones: Array)

## Emitted when the player lands in a hot zone
signal player_hot_dropped(zone: Dictionary, heat: Enums.DropZoneHeat)

## Emitted when the player survives a hot drop (alive after 30 seconds)
signal hot_drop_survived(zone: Dictionary, bonus_xp: int)


## All active drop zones for the current match
var drop_zones: Array = []

## The zone the player landed in (if any hot zone)
var player_drop_zone: Dictionary = {}

## Whether the player landed in a hot zone
var player_in_hot_zone: bool = false

## Timer for hot drop survival bonus
var _survival_timer: float = 0.0

## Whether the survival bonus has been awarded
var _survival_bonus_awarded: bool = false

## Reference to map data
var _map_data = null  # MapData reference

## Reference to bot AI manager for steering bots to zones
var _bot_ai_manager = null  # BotAIManager reference


## Zone generation parameters
const MIN_ZONES: int = 3
const MAX_ZONES: int = 6
const MIN_ZONE_RADIUS: float = 80.0
const MAX_ZONE_RADIUS: float = 150.0
const MIN_ZONE_SEPARATION: float = 200.0

## Bot attraction percentages per heat level
const BOT_ATTRACTION: Dictionary = {
	Enums.DropZoneHeat.COLD: 0.05,     # 5% of bots attracted
	Enums.DropZoneHeat.WARM: 0.15,     # 15% of bots
	Enums.DropZoneHeat.HOT: 0.25,      # 25% of bots
	Enums.DropZoneHeat.INFERNO: 0.40,  # 40% of bots
}

## Loot density multipliers per heat level
const LOOT_MULTIPLIER: Dictionary = {
	Enums.DropZoneHeat.COLD: 0.8,
	Enums.DropZoneHeat.WARM: 1.5,
	Enums.DropZoneHeat.HOT: 2.5,
	Enums.DropZoneHeat.INFERNO: 4.0,
}

## Minimum rarity tier per heat level
const MIN_RARITY: Dictionary = {
	Enums.DropZoneHeat.COLD: Enums.RarityTier.COMMON,
	Enums.DropZoneHeat.WARM: Enums.RarityTier.UNCOMMON,
	Enums.DropZoneHeat.HOT: Enums.RarityTier.RARE,
	Enums.DropZoneHeat.INFERNO: Enums.RarityTier.EPIC,
}

## XP bonus for surviving a hot drop (30 seconds alive)
const HOT_DROP_SURVIVAL_XP: Dictionary = {
	Enums.DropZoneHeat.COLD: 0,
	Enums.DropZoneHeat.WARM: 25,
	Enums.DropZoneHeat.HOT: 75,
	Enums.DropZoneHeat.INFERNO: 200,
}

## Time in seconds to survive for hot drop bonus
const SURVIVAL_THRESHOLD: float = 30.0

## Colors for zone heat visualization
const HEAT_COLORS: Dictionary = {
	Enums.DropZoneHeat.COLD: Color(0.3, 0.5, 0.8, 0.3),
	Enums.DropZoneHeat.WARM: Color(0.9, 0.7, 0.2, 0.4),
	Enums.DropZoneHeat.HOT: Color(1.0, 0.4, 0.1, 0.5),
	Enums.DropZoneHeat.INFERNO: Color(1.0, 0.1, 0.1, 0.7),
}

## Names for heat levels (displayed on HUD)
const HEAT_NAMES: Dictionary = {
	Enums.DropZoneHeat.COLD: "Cold Zone",
	Enums.DropZoneHeat.WARM: "Warm Zone",
	Enums.DropZoneHeat.HOT: "HOT ZONE",
	Enums.DropZoneHeat.INFERNO: "INFERNO ZONE",
}


## Generates drop zones for a new match.
## Uses match settings to scale zone generation.
func generate_zones(map_data, bot_count: int) -> void:
	_map_data = map_data
	drop_zones.clear()
	player_in_hot_zone = false
	player_drop_zone = {}
	_survival_bonus_awarded = false
	_survival_timer = 0.0

	var bounds: Rect2 = map_data.get_map_bounds()
	var num_zones: int = randi_range(MIN_ZONES, MAX_ZONES)

	# Always have at most 1 Inferno zone, 1-2 Hot zones, rest are Warm/Cold
	var heat_distribution: Array = _generate_heat_distribution(num_zones)

	for i in range(num_zones):
		var zone := _generate_single_zone(bounds, heat_distribution[i], bot_count)
		if zone.is_empty():
			continue

		# Check minimum separation from existing zones
		var too_close := false
		for existing in drop_zones:
			var dist: float = zone["center"].distance_to(existing["center"])
			if dist < MIN_ZONE_SEPARATION:
				too_close = true
				break

		if not too_close:
			drop_zones.append(zone)

	zones_generated.emit(drop_zones)


## Generates a heat level distribution for N zones
func _generate_heat_distribution(count: int) -> Array:
	var distribution: Array = []

	# Guarantee 1 Inferno (if enough zones)
	if count >= 4:
		distribution.append(Enums.DropZoneHeat.INFERNO)
	
	# 1-2 Hot zones
	var hot_count: int = mini(randi_range(1, 2), count - distribution.size())
	for i in range(hot_count):
		distribution.append(Enums.DropZoneHeat.HOT)

	# Fill remaining with Warm and Cold
	while distribution.size() < count:
		if randf() < 0.6:
			distribution.append(Enums.DropZoneHeat.WARM)
		else:
			distribution.append(Enums.DropZoneHeat.COLD)

	distribution.shuffle()
	return distribution


## Generates a single drop zone within map bounds
func _generate_single_zone(bounds: Rect2, heat: Enums.DropZoneHeat, bot_count: int) -> Dictionary:
	var radius: float = randf_range(MIN_ZONE_RADIUS, MAX_ZONE_RADIUS)

	# Scale radius by heat (hotter = smaller, more concentrated)
	match heat:
		Enums.DropZoneHeat.INFERNO:
			radius *= 0.6
		Enums.DropZoneHeat.HOT:
			radius *= 0.8
		Enums.DropZoneHeat.WARM:
			radius *= 1.0
		Enums.DropZoneHeat.COLD:
			radius *= 1.3

	# Random position within map bounds (with margin for radius)
	var margin: float = radius + 50.0
	var center := Vector2(
		randf_range(bounds.position.x + margin, bounds.position.x + bounds.size.x - margin),
		randf_range(bounds.position.y + margin, bounds.position.y + bounds.size.y - margin)
	)

	# Try to align with named map locations for thematic coherence
	if _map_data != null and _map_data.has_method("get_nearest_location"):
		var nearest_loc: Dictionary = _map_data.get_nearest_location(center)
		if not nearest_loc.is_empty():
			var loc_pos: Vector2 = nearest_loc.get("position", center)
			if center.distance_to(loc_pos) < radius * 2.0:
				center = loc_pos  # Snap to named location

	# Calculate bot attraction count
	var attracted_bots: int = int(float(bot_count) * BOT_ATTRACTION[heat])

	return {
		"center": center,
		"radius": radius,
		"heat": heat,
		"heat_name": HEAT_NAMES[heat],
		"color": HEAT_COLORS[heat],
		"loot_multiplier": LOOT_MULTIPLIER[heat],
		"min_rarity": MIN_RARITY[heat],
		"attracted_bots": attracted_bots,
		"survival_xp": HOT_DROP_SURVIVAL_XP[heat],
	}


## Called when the player selects a drop position.
## Determines if they're in a hot zone and triggers appropriate feedback.
func on_player_drop(position: Vector2) -> void:
	player_in_hot_zone = false
	player_drop_zone = {}

	for zone in drop_zones:
		var dist: float = position.distance_to(zone["center"])
		if dist <= zone["radius"]:
			player_in_hot_zone = true
			player_drop_zone = zone
			player_hot_dropped.emit(zone, zone["heat"])
			break


## Called each frame during active gameplay after a hot drop.
## Tracks time for survival bonus.
func update(delta: float) -> void:
	if not player_in_hot_zone:
		return
	if _survival_bonus_awarded:
		return

	_survival_timer += delta
	if _survival_timer >= SURVIVAL_THRESHOLD:
		_survival_bonus_awarded = true
		var bonus_xp: int = player_drop_zone.get("survival_xp", 0)
		hot_drop_survived.emit(player_drop_zone, bonus_xp)


## Returns the bot landing positions influenced by hot zones.
## Bots are distributed: some attracted to hot zones, rest random.
func get_bot_landing_positions(bot_count: int, map_bounds: Rect2) -> Array:
	var positions: Array = []
	var attracted_count: int = 0

	# Distribute attracted bots to hot zones
	for zone in drop_zones:
		var count: int = zone.get("attracted_bots", 0)
		for i in range(count):
			if attracted_count >= bot_count:
				break
			# Random position within zone radius
			var angle: float = randf() * TAU
			var dist: float = randf() * zone["radius"]
			var pos: Vector2 = zone["center"] + Vector2(cos(angle), sin(angle)) * dist
			positions.append(pos)
			attracted_count += 1

	# Remaining bots get random positions
	while positions.size() < bot_count:
		var pos := Vector2(
			randf_range(map_bounds.position.x, map_bounds.position.x + map_bounds.size.x),
			randf_range(map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)
		)
		positions.append(pos)

	return positions


## Returns drop zone data for minimap/HUD rendering
func get_zones_for_display() -> Array:
	var display_data: Array = []
	for zone in drop_zones:
		display_data.append({
			"center": zone["center"],
			"radius": zone["radius"],
			"color": zone["color"],
			"heat_name": zone["heat_name"],
			"heat": zone["heat"]
		})
	return display_data


## Gets the loot multiplier for a position (for LootManager integration)
func get_loot_multiplier_at(position: Vector2) -> float:
	for zone in drop_zones:
		if position.distance_to(zone["center"]) <= zone["radius"]:
			return zone["loot_multiplier"]
	return 1.0


## Gets the minimum rarity for a position (for LootManager integration)
func get_min_rarity_at(position: Vector2) -> Enums.RarityTier:
	for zone in drop_zones:
		if position.distance_to(zone["center"]) <= zone["radius"]:
			return zone["min_rarity"]
	return Enums.RarityTier.COMMON


## Resets for a new match
func reset() -> void:
	drop_zones.clear()
	player_in_hot_zone = false
	player_drop_zone = {}
	_survival_timer = 0.0
	_survival_bonus_awarded = false
