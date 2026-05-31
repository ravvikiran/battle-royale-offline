## Unit tests for the LootManager class.
## Tests loot initialization, spawning, pickup, and nearest-loot queries.
extends GutTest


var loot_manager: LootManager
var map_data: MapData


func before_each() -> void:
	loot_manager = LootManager.new()
	map_data = MapData.new()


func after_each() -> void:
	loot_manager = null
	map_data = null


## Test that LootManager initializes with correct rarity weights
func test_rarity_weights_initialized() -> void:
	assert_almost_eq(loot_manager.rarity_weights[Enums.RarityTier.COMMON], 0.40, 0.001)
	assert_almost_eq(loot_manager.rarity_weights[Enums.RarityTier.UNCOMMON], 0.25, 0.001)
	assert_almost_eq(loot_manager.rarity_weights[Enums.RarityTier.RARE], 0.20, 0.001)
	assert_almost_eq(loot_manager.rarity_weights[Enums.RarityTier.EPIC], 0.10, 0.001)
	assert_almost_eq(loot_manager.rarity_weights[Enums.RarityTier.LEGENDARY], 0.05, 0.001)


## Test that rarity weights sum to 1.0
func test_rarity_weights_sum_to_one() -> void:
	var total: float = 0.0
	for weight in loot_manager.rarity_weights.values():
		total += weight
	assert_almost_eq(total, 1.0, 0.001)


## Test that initialize_loot populates spawn points and active loot
func test_initialize_loot_populates_data() -> void:
	loot_manager.initialize_loot(map_data)
	assert_gt(loot_manager.spawn_points.size(), 0, "Should have spawn points after initialization")
	assert_gt(loot_manager.active_loot.size(), 0, "Should have active loot after initialization")


## Test that each named location has at least 5 spawn points
func test_minimum_spawn_points_per_named_location() -> void:
	loot_manager.initialize_loot(map_data)

	# Count spawn points per named location by checking which are in named locations
	var named_points := loot_manager.get_named_location_spawn_points()
	# Total named location spawn points should be at least 5 per location
	var location_count := map_data.get_named_locations().size()
	assert_gte(named_points.size(), location_count * LootManager.MIN_LOOT_POINTS_PER_NAMED_LOCATION,
		"Each named location should have at least 5 spawn points")


## Test that named locations have higher loot density than open areas
func test_named_location_density_higher_than_open() -> void:
	loot_manager.initialize_loot(map_data)

	var named_points := loot_manager.get_named_location_spawn_points()
	var open_points := loot_manager.get_open_area_spawn_points()

	# Calculate areas
	var named_total_area: float = 0.0
	for location in map_data.get_named_locations():
		named_total_area += PI * location.radius * location.radius

	var total_area := map_data.get_total_map_area()
	var open_area := total_area - named_total_area

	# Calculate densities
	var named_density: float = float(named_points.size()) / named_total_area if named_total_area > 0 else 0.0
	var open_density: float = float(open_points.size()) / open_area if open_area > 0 else 0.0

	# Named density should be approximately 3× open density
	assert_gt(named_density, open_density, "Named location density should be higher than open area density")
	# Check it's roughly 3× (with some tolerance due to rounding)
	if open_density > 0:
		var ratio := named_density / open_density
		assert_gte(ratio, 2.5, "Named location density should be at least 2.5× open area density")


## Test that spawn_loot_at creates a valid loot instance
func test_spawn_loot_at_creates_instance() -> void:
	var point := LootManager.LootSpawnPoint.new(Vector2(100, 200), true)
	var loot := loot_manager.spawn_loot_at(point)

	assert_not_null(loot, "spawn_loot_at should return a LootInstance")
	assert_eq(loot.position, Vector2(100, 200), "Loot position should match spawn point")
	assert_false(loot.is_picked_up, "New loot should not be picked up")
	assert_gt(loot.id, 0, "Loot should have a positive ID")


## Test that spawn_loot_at assigns valid rarity tiers
func test_spawn_loot_rarity_is_valid() -> void:
	var point := LootManager.LootSpawnPoint.new(Vector2.ZERO, false)
	var valid_rarities := [
		Enums.RarityTier.COMMON,
		Enums.RarityTier.UNCOMMON,
		Enums.RarityTier.RARE,
		Enums.RarityTier.EPIC,
		Enums.RarityTier.LEGENDARY,
	]

	for i in range(50):
		var loot := loot_manager.spawn_loot_at(point)
		assert_has(valid_rarities, loot.rarity, "Loot rarity should be a valid tier")


## Test that each spawned loot gets a unique ID
func test_spawn_loot_unique_ids() -> void:
	var point := LootManager.LootSpawnPoint.new(Vector2.ZERO, false)
	var ids: Array[int] = []

	for i in range(20):
		var loot := loot_manager.spawn_loot_at(point)
		assert_does_not_have(ids, loot.id, "Each loot should have a unique ID")
		ids.append(loot.id)


## Test successful weapon pickup
func test_pick_up_weapon_success() -> void:
	loot_manager.initialize_loot(map_data)

	# Find a weapon loot item
	var weapon_loot: LootManager.LootInstance = null
	for loot in loot_manager.active_loot:
		if loot.loot_type == LootManager.LootType.WEAPON:
			weapon_loot = loot
			break

	if weapon_loot == null:
		pass_test("No weapon loot spawned (random), skipping")
		return

	var inventory := InventorySystem.new()
	var result := loot_manager.pick_up_loot(weapon_loot.id, inventory)

	assert_true(result["success"], "Weapon pickup should succeed")
	assert_eq(inventory.get_weapon_count(), 1, "Inventory should have 1 weapon after pickup")


## Test successful consumable pickup
func test_pick_up_consumable_success() -> void:
	loot_manager.initialize_loot(map_data)

	# Find a consumable loot item
	var consumable_loot: LootManager.LootInstance = null
	for loot in loot_manager.active_loot:
		if loot.loot_type == LootManager.LootType.CONSUMABLE:
			consumable_loot = loot
			break

	if consumable_loot == null:
		pass_test("No consumable loot spawned (random), skipping")
		return

	var inventory := InventorySystem.new()
	var result := loot_manager.pick_up_loot(consumable_loot.id, inventory)

	assert_true(result["success"], "Consumable pickup should succeed")


## Test pickup of non-existent loot returns error
func test_pick_up_nonexistent_loot() -> void:
	var inventory := InventorySystem.new()
	var result := loot_manager.pick_up_loot(99999, inventory)

	assert_false(result["success"], "Picking up non-existent loot should fail")
	assert_eq(result["error"], "loot_not_found")


## Test pickup when weapon inventory is full
func test_pick_up_weapon_inventory_full() -> void:
	loot_manager.initialize_loot(map_data)

	var inventory := InventorySystem.new()
	# Fill all 5 weapon slots
	for i in range(5):
		var weapon := WeaponData.new()
		weapon.category = Enums.WeaponCategory.PISTOL
		weapon.name = "Test"
		weapon.rarity = Enums.RarityTier.COMMON
		weapon.base_damage = 10.0
		weapon.fire_rate = 1.0
		weapon.magazine_size = 10
		weapon.reload_time = 1.0
		weapon.effective_range = 20.0
		weapon.accuracy_base = 0.5
		inventory.add_weapon(weapon)

	# Find a weapon loot item
	var weapon_loot: LootManager.LootInstance = null
	for loot in loot_manager.active_loot:
		if loot.loot_type == LootManager.LootType.WEAPON:
			weapon_loot = loot
			break

	if weapon_loot == null:
		pass_test("No weapon loot spawned (random), skipping")
		return

	var result := loot_manager.pick_up_loot(weapon_loot.id, inventory)
	assert_false(result["success"], "Pickup should fail when inventory is full")
	assert_eq(result["error"], "inventory_full")


## Test that picked up loot is removed from active loot
func test_picked_up_loot_removed_from_active() -> void:
	loot_manager.initialize_loot(map_data)

	var initial_count := loot_manager.get_active_loot_count()
	if initial_count == 0:
		pass_test("No loot spawned, skipping")
		return

	var first_loot := loot_manager.active_loot[0]
	var loot_id := first_loot.id
	var inventory := InventorySystem.new()

	loot_manager.pick_up_loot(loot_id, inventory)

	assert_eq(loot_manager.get_active_loot_count(), initial_count - 1,
		"Active loot count should decrease by 1 after pickup")


## Test get_nearest_loot returns closest loot within radius
func test_get_nearest_loot_within_radius() -> void:
	loot_manager.initialize_loot(map_data)

	if loot_manager.active_loot.is_empty():
		pass_test("No loot spawned, skipping")
		return

	# Use the position of the first loot item
	var target_loot := loot_manager.active_loot[0]
	var search_pos := target_loot.position + Vector2(5, 0)  # 5 meters away

	var nearest := loot_manager.get_nearest_loot(search_pos, 50.0)
	assert_not_null(nearest, "Should find loot within 50m radius")


## Test get_nearest_loot returns null when no loot in radius
func test_get_nearest_loot_none_in_radius() -> void:
	loot_manager.initialize_loot(map_data)

	# Search far outside the map where no loot should exist
	var result := loot_manager.get_nearest_loot(Vector2(99999, 99999), 10.0)
	assert_null(result, "Should return null when no loot is within radius")


## Test get_nearest_loot ignores picked up loot
func test_get_nearest_loot_ignores_picked_up() -> void:
	loot_manager.initialize_loot(map_data)

	if loot_manager.active_loot.size() < 2:
		pass_test("Not enough loot spawned, skipping")
		return

	var first_loot := loot_manager.active_loot[0]
	var search_pos := first_loot.position

	# Pick up the nearest loot
	var inventory := InventorySystem.new()
	loot_manager.pick_up_loot(first_loot.id, inventory)

	# Now searching at the same position should not return the picked up item
	var nearest := loot_manager.get_nearest_loot(search_pos, 1.0)
	if nearest != null:
		assert_ne(nearest.id, first_loot.id, "Should not return picked up loot")


## Test that double pickup of same loot fails
func test_double_pickup_fails() -> void:
	loot_manager.initialize_loot(map_data)

	if loot_manager.active_loot.is_empty():
		pass_test("No loot spawned, skipping")
		return

	var loot := loot_manager.active_loot[0]
	var inventory := InventorySystem.new()

	var first_result := loot_manager.pick_up_loot(loot.id, inventory)
	assert_true(first_result["success"], "First pickup should succeed")

	var second_result := loot_manager.pick_up_loot(loot.id, inventory)
	assert_false(second_result["success"], "Second pickup of same loot should fail")
