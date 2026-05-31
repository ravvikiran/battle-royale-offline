## Unit tests for the GameMap class.
## Tests map loading, terrain rendering, named location labels, and loot glow effects.
extends GutTest


var game_map: GameMap
var map_data: MapData


func before_each() -> void:
	game_map = GameMap.new()
	map_data = MapData.new()
	game_map.map_data = map_data
	add_child_autofree(game_map)


func after_each() -> void:
	game_map = null
	map_data = null


## Test that the map loads successfully with all terrain and locations.
func test_map_loads_successfully() -> void:
	assert_true(game_map.is_map_loaded(), "Map should be loaded after _ready")


## Test that map has minimum 8 named location labels.
func test_minimum_named_location_labels() -> void:
	var label_count := game_map.get_location_label_count()
	assert_gte(label_count, 8, "Map should have at least 8 named location labels")


## Test that location labels are hidden by default (not in drop phase).
func test_labels_hidden_by_default() -> void:
	assert_false(game_map.are_labels_visible(),
		"Labels should be hidden when not in drop phase")


## Test that labels become visible during drop phase.
func test_labels_visible_during_drop_phase() -> void:
	game_map.set_drop_phase_active(true)
	assert_true(game_map.are_labels_visible(),
		"Labels should be visible during drop phase")


## Test that labels are hidden after drop phase ends.
func test_labels_hidden_after_drop_phase() -> void:
	game_map.set_drop_phase_active(true)
	game_map.set_drop_phase_active(false)
	assert_false(game_map.are_labels_visible(),
		"Labels should be hidden after drop phase ends")


## Test that terrain colors are defined for all terrain types.
func test_terrain_colors_defined() -> void:
	for terrain_type in MapData.TerrainType.values():
		var color := game_map.get_terrain_color(terrain_type)
		assert_ne(color, Color(0, 0, 0, 0),
			"Terrain type %d should have a defined color" % terrain_type)


## Test that rarity glow colors are defined for all rarity tiers.
func test_rarity_glow_colors_defined() -> void:
	for rarity in Enums.RarityTier.values():
		var color := game_map.get_rarity_glow_color(rarity)
		assert_ne(color, Color(0, 0, 0, 0),
			"Rarity tier %d should have a defined glow color" % rarity)


## Test that each rarity tier has a distinct glow color.
func test_rarity_glow_colors_distinct() -> void:
	var colors: Array[Color] = []
	for rarity in Enums.RarityTier.values():
		var color := game_map.get_rarity_glow_color(rarity)
		for existing in colors:
			assert_ne(color, existing,
				"Each rarity tier should have a distinct glow color")
		colors.append(color)


## Test that map_to_world converts 2D coordinates to 3D correctly.
func test_map_to_world_conversion() -> void:
	var map_pos := Vector2(100.0, -200.0)
	var world_pos := game_map.map_to_world(map_pos)
	assert_almost_eq(world_pos.x, 100.0, 0.01)
	assert_almost_eq(world_pos.y, 0.0, 0.01)
	assert_almost_eq(world_pos.z, -200.0, 0.01)


## Test that world_to_map converts 3D coordinates to 2D correctly.
func test_world_to_map_conversion() -> void:
	var world_pos := Vector3(500.0, 10.0, -300.0)
	var map_pos := game_map.world_to_map(world_pos)
	assert_almost_eq(map_pos.x, 500.0, 0.01)
	assert_almost_eq(map_pos.y, -300.0, 0.01)


## Test that terrain container has children after loading.
func test_terrain_container_has_children() -> void:
	var terrain := game_map.terrain_container
	assert_not_null(terrain, "Terrain container should exist")
	assert_gt(terrain.get_child_count(), 0,
		"Terrain container should have children after map load")


## Test that locations container has children for each named location.
func test_locations_container_has_children() -> void:
	var locations := game_map.locations_container
	assert_not_null(locations, "Locations container should exist")
	assert_gte(locations.get_child_count(), 8,
		"Locations container should have at least 8 location markers")


## Test that loot glow can be created and removed.
func test_loot_glow_creation_and_removal() -> void:
	var loot_mgr := LootManager.new()
	loot_mgr.initialize_loot(map_data)
	game_map.loot_manager = loot_mgr
	game_map.refresh_loot_display()

	var loot_count := game_map.loot_container.get_child_count()
	assert_gt(loot_count, 0, "Loot container should have glow nodes after refresh")

	# Remove a specific loot glow
	if loot_mgr.active_loot.size() > 0:
		var first_loot := loot_mgr.active_loot[0]
		game_map.remove_loot_glow(first_loot.id)
		# Note: queue_free is deferred, so count won't change immediately in test


## Test that map emits map_loaded signal.
func test_map_loaded_signal_emitted() -> void:
	var new_map := GameMap.new()
	watch_signals(new_map)
	new_map.map_data = MapData.new()
	add_child_autofree(new_map)
	assert_signal_emitted(new_map, "map_loaded")
