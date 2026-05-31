## Manages loot spawning, distribution, and pickup across the game map.
## Handles weighted rarity selection, density-based distribution (3× in named locations),
## and provides nearest-loot queries for bot AI loot-seeking behavior.
class_name LootManager
extends RefCounted


## Loot item types that can spawn
enum LootType {
	WEAPON,
	CONSUMABLE
}


## Represents a point where loot can spawn on the map
class LootSpawnPoint:
	var position: Vector2
	var is_named_location: bool  ## Whether this point is inside a named location

	func _init(p_position: Vector2, p_is_named: bool) -> void:
		position = p_position
		is_named_location = p_is_named


## Represents an active loot item on the ground
class LootInstance:
	var id: int
	var position: Vector2
	var loot_type: LootType
	var rarity: Enums.RarityTier
	var weapon_data: WeaponData  ## Set if loot_type == WEAPON
	var consumable_type: Enums.ConsumableType  ## Set if loot_type == CONSUMABLE
	var is_picked_up: bool

	func _init(p_id: int, p_position: Vector2, p_type: LootType, p_rarity: Enums.RarityTier) -> void:
		id = p_id
		position = p_position
		loot_type = p_type
		rarity = p_rarity
		weapon_data = null
		consumable_type = Enums.ConsumableType.BANDAGE
		is_picked_up = false


## All spawn points on the map (populated during initialization)
var spawn_points: Array[LootSpawnPoint] = []

## All active (not yet picked up) loot instances on the map
var active_loot: Array[LootInstance] = []

## Rarity weight distribution for loot spawns
var rarity_weights: Dictionary = {
	Enums.RarityTier.COMMON: 0.40,
	Enums.RarityTier.UNCOMMON: 0.25,
	Enums.RarityTier.RARE: 0.20,
	Enums.RarityTier.EPIC: 0.10,
	Enums.RarityTier.LEGENDARY: 0.05,
}

## Density multiplier for named locations vs open areas
const NAMED_LOCATION_DENSITY_MULTIPLIER: float = 3.0

## Minimum loot spawn points per named location
const MIN_LOOT_POINTS_PER_NAMED_LOCATION: int = 5

## Base number of open-area spawn points per 10000 sq meters
const OPEN_AREA_SPAWN_DENSITY: float = 0.5

## Probability that a loot spawn is a weapon (vs consumable)
const WEAPON_SPAWN_CHANCE: float = 0.65

## Internal counter for generating unique loot IDs
var _next_loot_id: int = 1

## Weapon configuration data loaded from JSON
var _weapon_configs: Array = []

## Reference to the map data for location queries
var _map_data: MapData = null


func _init() -> void:
	_load_weapon_configs()


## Initializes loot distribution across the map based on map data.
## Named locations receive 3× the loot density compared to open areas.
## Each named location is guaranteed at least 5 loot spawn points.
func initialize_loot(map_data: MapData) -> void:
	_map_data = map_data
	spawn_points.clear()
	active_loot.clear()
	_next_loot_id = 1

	# Generate spawn points for named locations (high density)
	for location in map_data.get_named_locations():
		var location_points: Array[Vector2] = location.loot_spawn_points
		# Ensure minimum 5 spawn points per named location
		var points_to_use: Array[Vector2] = location_points
		if points_to_use.size() < MIN_LOOT_POINTS_PER_NAMED_LOCATION:
			# Generate additional points to meet minimum
			points_to_use = _ensure_minimum_points(location.position, location.radius, points_to_use)

		for point in points_to_use:
			var spawn_point := LootSpawnPoint.new(point, true)
			spawn_points.append(spawn_point)

	# Generate spawn points for open areas (lower density)
	_generate_open_area_spawn_points(map_data)

	# Spawn loot at all spawn points
	for spawn_point in spawn_points:
		var loot := spawn_loot_at(spawn_point)
		if loot != null:
			active_loot.append(loot)


## Spawns a loot item at the given spawn point using weighted random rarity selection.
## Returns the created LootInstance, or null if spawn fails.
func spawn_loot_at(point: LootSpawnPoint) -> LootInstance:
	var rarity := _select_weighted_rarity()
	var loot_type := _select_loot_type()

	var loot := LootInstance.new(_next_loot_id, point.position, loot_type, rarity)
	_next_loot_id += 1

	if loot_type == LootType.WEAPON:
		loot.weapon_data = _create_weapon_for_loot(rarity)
	else:
		loot.consumable_type = _select_random_consumable()

	return loot


## Picks up a loot item by ID, adding it to the picker's inventory.
## Returns a Dictionary with "success" (bool) and optionally "error" (String) or "item" info.
func pick_up_loot(loot_id: int, picker: InventorySystem) -> Dictionary:
	var loot := _find_loot_by_id(loot_id)
	if loot == null:
		return {"success": false, "error": "loot_not_found"}

	if loot.is_picked_up:
		return {"success": false, "error": "already_picked_up"}

	# Attempt to add to inventory based on loot type
	var result: int
	if loot.loot_type == LootType.WEAPON:
		result = picker.add_weapon(loot.weapon_data)
		if result != OK:
			return {"success": false, "error": "inventory_full"}
	else:
		result = picker.add_consumable(loot.consumable_type, 1)
		if result != OK:
			return {"success": false, "error": "stack_full"}

	# Mark as picked up and remove from active loot
	loot.is_picked_up = true
	active_loot.erase(loot)

	return {
		"success": true,
		"loot_type": loot.loot_type,
		"rarity": loot.rarity,
		"position": loot.position,
	}


## Returns the nearest active loot instance within the given radius from position.
## Returns null if no loot is found within the radius.
func get_nearest_loot(position: Vector2, radius: float) -> LootInstance:
	var nearest: LootInstance = null
	var nearest_dist: float = INF

	for loot in active_loot:
		if loot.is_picked_up:
			continue
		var dist := position.distance_to(loot.position)
		if dist <= radius and dist < nearest_dist:
			nearest_dist = dist
			nearest = loot

	return nearest


## Returns all active loot instances within the given radius from position.
func get_loot_in_radius(position: Vector2, radius: float) -> Array[LootInstance]:
	var results: Array[LootInstance] = []
	for loot in active_loot:
		if loot.is_picked_up:
			continue
		if position.distance_to(loot.position) <= radius:
			results.append(loot)
	return results


## Returns the total number of active (not picked up) loot items.
func get_active_loot_count() -> int:
	return active_loot.size()


## Returns the total number of spawn points.
func get_spawn_point_count() -> int:
	return spawn_points.size()


## Returns spawn points that are in named locations.
func get_named_location_spawn_points() -> Array[LootSpawnPoint]:
	var results: Array[LootSpawnPoint] = []
	for point in spawn_points:
		if point.is_named_location:
			results.append(point)
	return results


## Returns spawn points that are in open areas.
func get_open_area_spawn_points() -> Array[LootSpawnPoint]:
	var results: Array[LootSpawnPoint] = []
	for point in spawn_points:
		if not point.is_named_location:
			results.append(point)
	return results


# --- Private Methods ---


## Selects a rarity tier using weighted random selection.
func _select_weighted_rarity() -> Enums.RarityTier:
	var roll := randf()
	var cumulative: float = 0.0

	for rarity_tier in rarity_weights.keys():
		cumulative += rarity_weights[rarity_tier]
		if roll <= cumulative:
			return rarity_tier

	# Fallback (should not reach here due to weights summing to 1.0)
	return Enums.RarityTier.COMMON


## Selects whether the loot is a weapon or consumable.
func _select_loot_type() -> LootType:
	if randf() < WEAPON_SPAWN_CHANCE:
		return LootType.WEAPON
	return LootType.CONSUMABLE


## Creates a WeaponData instance for a loot spawn with the given rarity.
func _create_weapon_for_loot(rarity: Enums.RarityTier) -> WeaponData:
	if _weapon_configs.is_empty():
		# Fallback: create a basic pistol
		var weapon := WeaponData.new()
		weapon.category = Enums.WeaponCategory.PISTOL
		weapon.name = "Sideswipe"
		weapon.rarity = rarity
		weapon.base_damage = 24.0
		weapon.fire_rate = 3.0
		weapon.magazine_size = 12
		weapon.reload_time = 1.0
		weapon.effective_range = 35.0
		weapon.accuracy_base = 0.70
		return weapon

	# Pick a random weapon category from configs
	var config: Dictionary = _weapon_configs[randi() % _weapon_configs.size()]
	return WeaponData.from_dict(config, rarity)


## Selects a random consumable type.
func _select_random_consumable() -> Enums.ConsumableType:
	var types := [
		Enums.ConsumableType.BANDAGE,
		Enums.ConsumableType.MEDKIT,
		Enums.ConsumableType.SHIELD_POTION,
	]
	return types[randi() % types.size()]


## Finds a loot instance by its unique ID.
func _find_loot_by_id(loot_id: int) -> LootInstance:
	for loot in active_loot:
		if loot.id == loot_id:
			return loot
	return null


## Generates spawn points in open areas (outside named locations) at lower density.
func _generate_open_area_spawn_points(map_data: MapData) -> void:
	var bounds := map_data.get_map_bounds()
	var map_area := bounds.size.x * bounds.size.y

	# Calculate number of named-location spawn points for density comparison
	var named_spawn_count := 0
	var named_total_area: float = 0.0
	for location in map_data.get_named_locations():
		named_spawn_count += location.loot_spawn_points.size()
		named_total_area += PI * location.radius * location.radius

	# Open area = total map area minus named location areas
	var open_area := map_area - named_total_area
	if open_area <= 0:
		return

	# Named location density (items per sq meter)
	var named_density: float = 0.0
	if named_total_area > 0:
		named_density = float(named_spawn_count) / named_total_area

	# Open area density is 1/3 of named location density (named is 3× open)
	var open_density: float = named_density / NAMED_LOCATION_DENSITY_MULTIPLIER

	# Calculate number of open area spawn points
	var open_spawn_count := int(open_density * open_area)
	# Ensure at least some open area spawns
	open_spawn_count = max(open_spawn_count, 10)

	# Generate random positions in open areas
	for i in range(open_spawn_count):
		var position := _generate_open_area_position(map_data, bounds)
		var spawn_point := LootSpawnPoint.new(position, false)
		spawn_points.append(spawn_point)


## Generates a random position in an open area (not inside any named location).
func _generate_open_area_position(map_data: MapData, bounds: Rect2) -> Vector2:
	# Try to find a position outside named locations
	for _attempt in range(20):
		var x := randf_range(bounds.position.x, bounds.position.x + bounds.size.x)
		var y := randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		var pos := Vector2(x, y)
		if not map_data.is_in_named_location(pos):
			return pos

	# Fallback: return a random position (unlikely to be in a named location given map size)
	var x := randf_range(bounds.position.x, bounds.position.x + bounds.size.x)
	var y := randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
	return Vector2(x, y)


## Ensures a location has at least MIN_LOOT_POINTS_PER_NAMED_LOCATION spawn points.
func _ensure_minimum_points(center: Vector2, radius: float, existing: Array[Vector2]) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for p in existing:
		points.append(p)

	var needed := MIN_LOOT_POINTS_PER_NAMED_LOCATION - points.size()
	for i in range(needed):
		var angle := randf() * TAU
		var dist := randf() * radius * 0.7
		var new_point := center + Vector2(cos(angle), sin(angle)) * dist
		points.append(new_point)

	return points


## Loads weapon configuration data from the JSON file.
func _load_weapon_configs() -> void:
	_weapon_configs = []
	var file_path := "res://data/weapons.json"
	if not FileAccess.file_exists(file_path):
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		return

	var data: Dictionary = json.data
	if data.has("weapons"):
		_weapon_configs = data["weapons"]
