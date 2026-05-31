## MapData defines the game map: bounds, named locations, terrain types, and loot spawn points.
## This class provides all static map configuration used by LootManager, ZoneManager, and BotAI.
class_name MapData
extends RefCounted


## Terrain type classifications for map regions
enum TerrainType {
	URBAN,
	OPEN_FIELD,
	FORESTED,
	ELEVATED
}


## Represents a named point-of-interest on the map
class NamedLocation:
	var id: String
	var display_name: String
	var position: Vector2  ## Center position in world units (meters)
	var radius: float  ## Approximate area radius in meters
	var terrain_type: TerrainType
	var loot_spawn_points: Array[Vector2]  ## Positions where loot can spawn

	func _init(p_id: String, p_name: String, p_position: Vector2, p_radius: float, p_terrain: TerrainType, p_loot_points: Array[Vector2]) -> void:
		id = p_id
		display_name = p_name
		position = p_position
		radius = p_radius
		terrain_type = p_terrain
		loot_spawn_points = p_loot_points


## Represents a terrain region on the map
class TerrainRegion:
	var terrain_type: TerrainType
	var bounds: Rect2  ## Rectangular region in world coordinates
	var area_percent: float  ## Percentage of total map area this region covers

	func _init(p_type: TerrainType, p_bounds: Rect2, p_percent: float) -> void:
		terrain_type = p_type
		bounds = p_bounds
		area_percent = p_percent


## Map boundary rectangle in world units (meters)
var map_bounds: Rect2

## All named locations on the map (minimum 8)
var named_locations: Array[NamedLocation]

## Terrain regions covering the map
var terrain_regions: Array[TerrainRegion]

## Minimum separation between named locations in meters
const MIN_LOCATION_SEPARATION: float = 100.0

## Minimum loot spawn points per named location
const MIN_LOOT_POINTS_PER_LOCATION: int = 5

## Minimum terrain coverage percentage per type
const MIN_TERRAIN_COVERAGE_PERCENT: float = 15.0

## Minimum number of named locations
const MIN_NAMED_LOCATIONS: int = 8


func _init() -> void:
	_setup_map_bounds()
	_setup_terrain_regions()
	_setup_named_locations()


## Returns the map bounds rectangle
func get_map_bounds() -> Rect2:
	return map_bounds


## Returns all named locations
func get_named_locations() -> Array[NamedLocation]:
	return named_locations


## Returns all terrain regions
func get_terrain_regions() -> Array[TerrainRegion]:
	return terrain_regions


## Returns the terrain type at a given world position
func get_terrain_at(position: Vector2) -> TerrainType:
	for region in terrain_regions:
		if region.bounds.has_point(position):
			return region.terrain_type
	# Default to open field if position is outside defined regions
	return TerrainType.OPEN_FIELD


## Returns all loot spawn points across the entire map
func get_all_loot_spawn_points() -> Array[Vector2]:
	var all_points: Array[Vector2] = []
	for location in named_locations:
		for point in location.loot_spawn_points:
			all_points.append(point)
	return all_points


## Returns loot spawn points for a specific named location
func get_loot_spawn_points_for_location(location_id: String) -> Array[Vector2]:
	for location in named_locations:
		if location.id == location_id:
			return location.loot_spawn_points
	return [] as Array[Vector2]


## Returns the named location closest to a given position, or null if none exist
func get_nearest_named_location(position: Vector2) -> NamedLocation:
	var nearest: NamedLocation = null
	var nearest_dist: float = INF
	for location in named_locations:
		var dist := position.distance_to(location.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = location
	return nearest


## Returns whether a position is within any named location's radius
func is_in_named_location(position: Vector2) -> bool:
	for location in named_locations:
		if position.distance_to(location.position) <= location.radius:
			return true
	return false


## Returns the total map area in square meters
func get_total_map_area() -> float:
	return map_bounds.size.x * map_bounds.size.y


## Returns the coverage percentage for a given terrain type
func get_terrain_coverage(terrain_type: TerrainType) -> float:
	var total_coverage: float = 0.0
	for region in terrain_regions:
		if region.terrain_type == terrain_type:
			total_coverage += region.area_percent
	return total_coverage


## Validates that all named locations meet the minimum separation requirement
func validate_location_separation() -> bool:
	for i in range(named_locations.size()):
		for j in range(i + 1, named_locations.size()):
			var dist := named_locations[i].position.distance_to(named_locations[j].position)
			if dist < MIN_LOCATION_SEPARATION:
				return false
	return true


## Validates terrain coverage meets minimum requirements
func validate_terrain_coverage() -> bool:
	for terrain_type in TerrainType.values():
		if get_terrain_coverage(terrain_type) < MIN_TERRAIN_COVERAGE_PERCENT:
			return false
	return true


## Validates each named location has minimum loot spawn points
func validate_loot_spawn_points() -> bool:
	for location in named_locations:
		if location.loot_spawn_points.size() < MIN_LOOT_POINTS_PER_LOCATION:
			return false
	return true


# --- Private setup methods ---


func _setup_map_bounds() -> void:
	# Map is 2000m x 2000m centered at origin
	map_bounds = Rect2(-1000.0, -1000.0, 2000.0, 2000.0)


func _setup_terrain_regions() -> void:
	terrain_regions = [] as Array[TerrainRegion]
	# Total map area: 2000 x 2000 = 4,000,000 sq meters
	# Each terrain type must cover at least 15% = 600,000 sq meters
	# We distribute: Urban 20%, Open Field 25%, Forested 30%, Elevated 25%

	# Urban: Northwest quadrant area (20% of map)
	# 800m x 1000m = 800,000 sq m = 20%
	terrain_regions.append(TerrainRegion.new(
		TerrainType.URBAN,
		Rect2(-1000.0, -1000.0, 800.0, 1000.0),
		20.0
	))

	# Open Field: Central and eastern strip (25% of map)
	# 1000m x 1000m = 1,000,000 sq m = 25%
	terrain_regions.append(TerrainRegion.new(
		TerrainType.OPEN_FIELD,
		Rect2(-200.0, -1000.0, 1000.0, 1000.0),
		25.0
	))

	# Forested: Southern band (30% of map)
	# 2000m x 600m = 1,200,000 sq m = 30%
	terrain_regions.append(TerrainRegion.new(
		TerrainType.FORESTED,
		Rect2(-1000.0, 0.0, 2000.0, 600.0),
		30.0
	))

	# Elevated: Southeast and northeast corners (25% of map)
	# 1200m x 833m ~ 1,000,000 sq m = 25%
	terrain_regions.append(TerrainRegion.new(
		TerrainType.ELEVATED,
		Rect2(200.0, 600.0, 800.0, 400.0),
		15.0
	))
	terrain_regions.append(TerrainRegion.new(
		TerrainType.ELEVATED,
		Rect2(-1000.0, 600.0, 600.0, 400.0),
		10.0
	))


func _setup_named_locations() -> void:
	named_locations = [] as Array[NamedLocation]

	# Location 1: Neon City (Urban) - Northwest
	named_locations.append(NamedLocation.new(
		"neon_city",
		"Neon City",
		Vector2(-700.0, -600.0),
		80.0,
		TerrainType.URBAN,
		_generate_loot_points(Vector2(-700.0, -600.0), 60.0, 7)
	))

	# Location 2: Brick Borough (Urban) - West
	named_locations.append(NamedLocation.new(
		"brick_borough",
		"Brick Borough",
		Vector2(-800.0, -200.0),
		70.0,
		TerrainType.URBAN,
		_generate_loot_points(Vector2(-800.0, -200.0), 55.0, 6)
	))

	# Location 3: Dusty Flats (Open Field) - Center-East
	named_locations.append(NamedLocation.new(
		"dusty_flats",
		"Dusty Flats",
		Vector2(300.0, -500.0),
		90.0,
		TerrainType.OPEN_FIELD,
		_generate_loot_points(Vector2(300.0, -500.0), 70.0, 6)
	))

	# Location 4: Windy Meadows (Open Field) - East
	named_locations.append(NamedLocation.new(
		"windy_meadows",
		"Windy Meadows",
		Vector2(600.0, -200.0),
		75.0,
		TerrainType.OPEN_FIELD,
		_generate_loot_points(Vector2(600.0, -200.0), 60.0, 5)
	))

	# Location 5: Timber Hollow (Forested) - South-Center
	named_locations.append(NamedLocation.new(
		"timber_hollow",
		"Timber Hollow",
		Vector2(-100.0, 200.0),
		85.0,
		TerrainType.FORESTED,
		_generate_loot_points(Vector2(-100.0, 200.0), 65.0, 7)
	))

	# Location 6: Mossy Thicket (Forested) - South-West
	named_locations.append(NamedLocation.new(
		"mossy_thicket",
		"Mossy Thicket",
		Vector2(-500.0, 350.0),
		70.0,
		TerrainType.FORESTED,
		_generate_loot_points(Vector2(-500.0, 350.0), 55.0, 6)
	))

	# Location 7: Summit Peak (Elevated) - Southeast high ground
	named_locations.append(NamedLocation.new(
		"summit_peak",
		"Summit Peak",
		Vector2(500.0, 750.0),
		65.0,
		TerrainType.ELEVATED,
		_generate_loot_points(Vector2(500.0, 750.0), 50.0, 5)
	))

	# Location 8: Cliffside Outpost (Elevated) - Far south
	named_locations.append(NamedLocation.new(
		"cliffside_outpost",
		"Cliffside Outpost",
		Vector2(-600.0, 800.0),
		60.0,
		TerrainType.ELEVATED,
		_generate_loot_points(Vector2(-600.0, 800.0), 45.0, 6)
	))

	# Location 9: Block Plaza (Urban) - Northwest inner
	named_locations.append(NamedLocation.new(
		"block_plaza",
		"Block Plaza",
		Vector2(-400.0, -800.0),
		65.0,
		TerrainType.URBAN,
		_generate_loot_points(Vector2(-400.0, -800.0), 50.0, 5)
	))

	# Location 10: Crater Ridge (Elevated) - Northeast
	named_locations.append(NamedLocation.new(
		"crater_ridge",
		"Crater Ridge",
		Vector2(700.0, 400.0),
		70.0,
		TerrainType.ELEVATED,
		_generate_loot_points(Vector2(700.0, 400.0), 55.0, 6)
	))


## Generates loot spawn points in a circular pattern around a center position
func _generate_loot_points(center: Vector2, spread: float, count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in range(count):
		var angle := (TAU / count) * i
		var offset := Vector2(cos(angle), sin(angle)) * spread * 0.7
		points.append(center + offset)
	return points
