## Unit tests for MapData class
extends GutTest


var map_data: MapData


func before_each() -> void:
	map_data = MapData.new()


func test_map_bounds_defined() -> void:
	var bounds := map_data.get_map_bounds()
	assert_gt(bounds.size.x, 0.0, "Map width should be positive")
	assert_gt(bounds.size.y, 0.0, "Map height should be positive")


func test_minimum_eight_named_locations() -> void:
	var locations := map_data.get_named_locations()
	assert_gte(locations.size(), MapData.MIN_NAMED_LOCATIONS,
		"Map must have at least %d named locations" % MapData.MIN_NAMED_LOCATIONS)


func test_named_locations_have_unique_ids() -> void:
	var locations := map_data.get_named_locations()
	var ids: Array[String] = []
	for loc in locations:
		assert_does_not_have(ids, loc.id, "Duplicate location id: %s" % loc.id)
		ids.append(loc.id)


func test_named_locations_separated_by_100m() -> void:
	var locations := map_data.get_named_locations()
	for i in range(locations.size()):
		for j in range(i + 1, locations.size()):
			var dist := locations[i].position.distance_to(locations[j].position)
			assert_gte(dist, MapData.MIN_LOCATION_SEPARATION,
				"%s and %s are only %.1fm apart (need >= %.1f)" % [
					locations[i].display_name,
					locations[j].display_name,
					dist,
					MapData.MIN_LOCATION_SEPARATION
				])


func test_each_location_has_minimum_loot_points() -> void:
	var locations := map_data.get_named_locations()
	for loc in locations:
		assert_gte(loc.loot_spawn_points.size(), MapData.MIN_LOOT_POINTS_PER_LOCATION,
			"%s has only %d loot points (need >= %d)" % [
				loc.display_name,
				loc.loot_spawn_points.size(),
				MapData.MIN_LOOT_POINTS_PER_LOCATION
			])


func test_terrain_coverage_minimum_15_percent() -> void:
	for terrain_type in MapData.TerrainType.values():
		var coverage := map_data.get_terrain_coverage(terrain_type)
		assert_gte(coverage, MapData.MIN_TERRAIN_COVERAGE_PERCENT,
			"Terrain type %d has only %.1f%% coverage (need >= %.1f%%)" % [
				terrain_type, coverage, MapData.MIN_TERRAIN_COVERAGE_PERCENT
			])


func test_all_four_terrain_types_present() -> void:
	var regions := map_data.get_terrain_regions()
	var types_found: Array[int] = []
	for region in regions:
		if not types_found.has(region.terrain_type):
			types_found.append(region.terrain_type)
	assert_eq(types_found.size(), 4, "All 4 terrain types must be present")


func test_named_locations_within_map_bounds() -> void:
	var bounds := map_data.get_map_bounds()
	var locations := map_data.get_named_locations()
	for loc in locations:
		assert_true(bounds.has_point(loc.position),
			"%s at %s is outside map bounds %s" % [loc.display_name, loc.position, bounds])


func test_loot_spawn_points_within_map_bounds() -> void:
	var bounds := map_data.get_map_bounds()
	var all_points := map_data.get_all_loot_spawn_points()
	for point in all_points:
		assert_true(bounds.has_point(point),
			"Loot point at %s is outside map bounds" % point)


func test_get_nearest_named_location() -> void:
	# Position near Neon City (-700, -600)
	var nearest := map_data.get_nearest_named_location(Vector2(-710.0, -590.0))
	assert_not_null(nearest)
	assert_eq(nearest.id, "neon_city")


func test_is_in_named_location() -> void:
	# Position at center of Neon City
	assert_true(map_data.is_in_named_location(Vector2(-700.0, -600.0)))
	# Position far from any location
	assert_false(map_data.is_in_named_location(Vector2(0.0, -900.0)))


func test_get_loot_spawn_points_for_location() -> void:
	var points := map_data.get_loot_spawn_points_for_location("neon_city")
	assert_gte(points.size(), MapData.MIN_LOOT_POINTS_PER_LOCATION)


func test_get_loot_spawn_points_for_invalid_location() -> void:
	var points := map_data.get_loot_spawn_points_for_location("nonexistent")
	assert_eq(points.size(), 0)


func test_validate_location_separation_passes() -> void:
	assert_true(map_data.validate_location_separation())


func test_validate_terrain_coverage_passes() -> void:
	assert_true(map_data.validate_terrain_coverage())


func test_validate_loot_spawn_points_passes() -> void:
	assert_true(map_data.validate_loot_spawn_points())


func test_total_map_area_positive() -> void:
	assert_gt(map_data.get_total_map_area(), 0.0)
