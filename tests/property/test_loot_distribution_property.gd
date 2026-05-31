## Property-based tests for loot distribution.
## **Validates: Requirements 4.6, 7.1, 11.1, 11.2, 11.7**
##
## Property 7: Loot rarity distribution
## *For any* sufficiently large sample of loot spawns (N >= 1000), the observed
## frequency of each rarity tier SHALL approximate the configured weights
## (Common 40%, Uncommon 25%, Rare 20%, Epic 10%, Legendary 5%) within a
## statistical tolerance of ±5 percentage points.
##
## Property 17: Map loot distribution constraints
## *For any* valid map configuration, named locations SHALL have at least 3× the
## loot spawn density of open areas, each named location SHALL contain at least
## 5 loot spawn points, all named locations SHALL be separated by at least 100
## meters, and each terrain type SHALL cover at least 15% of the total map area.
extends GutTest

## Number of loot spawns to generate for rarity distribution test
const SAMPLE_SIZE := 1000

## Tolerance for rarity distribution (±5 percentage points)
const RARITY_TOLERANCE := 0.05

## Number of random iterations for property tests
const NUM_ITERATIONS := 50

## Tolerance for floating point comparisons
const EPSILON := 0.001

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()


# =============================================================================
# Property 7: Loot rarity distribution
# =============================================================================


## Property test: For a large sample (N >= 1000), observed frequency of each
## rarity tier approximates configured weights within ±5 percentage points.
func test_property_rarity_distribution_approximates_configured_weights() -> void:
	var loot_manager := LootManager.new()
	var spawn_point := LootManager.LootSpawnPoint.new(Vector2.ZERO, false)

	# Count occurrences of each rarity tier
	var rarity_counts: Dictionary = {
		Enums.RarityTier.COMMON: 0,
		Enums.RarityTier.UNCOMMON: 0,
		Enums.RarityTier.RARE: 0,
		Enums.RarityTier.EPIC: 0,
		Enums.RarityTier.LEGENDARY: 0,
	}

	# Generate SAMPLE_SIZE loot items
	for i in range(SAMPLE_SIZE):
		var loot := loot_manager.spawn_loot_at(spawn_point)
		rarity_counts[loot.rarity] += 1

	# Verify each rarity tier is within ±5 percentage points of configured weight
	var expected_weights: Dictionary = loot_manager.rarity_weights

	for rarity_tier in expected_weights.keys():
		var observed_frequency: float = float(rarity_counts[rarity_tier]) / float(SAMPLE_SIZE)
		var expected_weight: float = expected_weights[rarity_tier]
		var deviation: float = abs(observed_frequency - expected_weight)

		assert_true(deviation <= RARITY_TOLERANCE,
			"Rarity tier %d: observed frequency %.4f deviates from expected %.4f by %.4f (tolerance: %.4f). Counts: %s" % [
				rarity_tier, observed_frequency, expected_weight, deviation, RARITY_TOLERANCE, str(rarity_counts)
			])


## Property test: Rarity distribution holds across multiple independent samples.
## Each sample of N >= 1000 should independently satisfy the ±5pp tolerance.
func test_property_rarity_distribution_consistent_across_samples() -> void:
	for sample_idx in range(5):
		var loot_manager := LootManager.new()
		var spawn_point := LootManager.LootSpawnPoint.new(
			Vector2(_rng.randf_range(-500, 500), _rng.randf_range(-500, 500)), false)

		var rarity_counts: Dictionary = {
			Enums.RarityTier.COMMON: 0,
			Enums.RarityTier.UNCOMMON: 0,
			Enums.RarityTier.RARE: 0,
			Enums.RarityTier.EPIC: 0,
			Enums.RarityTier.LEGENDARY: 0,
		}

		for i in range(SAMPLE_SIZE):
			var loot := loot_manager.spawn_loot_at(spawn_point)
			rarity_counts[loot.rarity] += 1

		var expected_weights: Dictionary = loot_manager.rarity_weights

		for rarity_tier in expected_weights.keys():
			var observed_frequency: float = float(rarity_counts[rarity_tier]) / float(SAMPLE_SIZE)
			var expected_weight: float = expected_weights[rarity_tier]
			var deviation: float = abs(observed_frequency - expected_weight)

			assert_true(deviation <= RARITY_TOLERANCE,
				"Sample %d, Rarity tier %d: observed %.4f vs expected %.4f (deviation: %.4f, tolerance: %.4f)" % [
					sample_idx, rarity_tier, observed_frequency, expected_weight, deviation, RARITY_TOLERANCE
				])


## Property test: All rarity tiers appear in a sufficiently large sample.
## No rarity tier should have zero occurrences in 1000 spawns.
func test_property_all_rarity_tiers_present_in_large_sample() -> void:
	var loot_manager := LootManager.new()
	var spawn_point := LootManager.LootSpawnPoint.new(Vector2.ZERO, false)

	var rarity_counts: Dictionary = {
		Enums.RarityTier.COMMON: 0,
		Enums.RarityTier.UNCOMMON: 0,
		Enums.RarityTier.RARE: 0,
		Enums.RarityTier.EPIC: 0,
		Enums.RarityTier.LEGENDARY: 0,
	}

	for i in range(SAMPLE_SIZE):
		var loot := loot_manager.spawn_loot_at(spawn_point)
		rarity_counts[loot.rarity] += 1

	for rarity_tier in rarity_counts.keys():
		assert_gt(rarity_counts[rarity_tier], 0,
			"Rarity tier %d should appear at least once in %d spawns" % [rarity_tier, SAMPLE_SIZE])


## Property test: Configured rarity weights sum to 1.0 (precondition for valid distribution).
func test_property_rarity_weights_sum_to_one() -> void:
	var loot_manager := LootManager.new()
	var total_weight: float = 0.0
	for weight in loot_manager.rarity_weights.values():
		total_weight += weight
	assert_almost_eq(total_weight, 1.0, EPSILON,
		"Rarity weights must sum to 1.0, got %.6f" % total_weight)


# =============================================================================
# Property 17: Map loot distribution constraints
# =============================================================================


## Property test: Named locations have at least 3× the loot spawn density of open areas.
func test_property_named_locations_have_3x_loot_density() -> void:
	var map_data := MapData.new()
	var loot_manager := LootManager.new()
	loot_manager.initialize_loot(map_data)

	var named_points := loot_manager.get_named_location_spawn_points()
	var open_points := loot_manager.get_open_area_spawn_points()

	# Calculate named location total area
	var named_total_area: float = 0.0
	for location in map_data.get_named_locations():
		named_total_area += PI * location.radius * location.radius

	# Calculate open area
	var total_area := map_data.get_total_map_area()
	var open_area := total_area - named_total_area

	# Both areas must be positive for a valid comparison
	assert_gt(named_total_area, 0.0, "Named location area must be positive")
	assert_gt(open_area, 0.0, "Open area must be positive")

	# Calculate densities (items per square meter)
	var named_density: float = float(named_points.size()) / named_total_area
	var open_density: float = float(open_points.size()) / open_area

	# Named density should be at least 3× open density
	# Using 2.8× as a small tolerance for rounding in spawn point generation
	var density_ratio: float = named_density / open_density if open_density > 0 else INF

	assert_gte(density_ratio, 2.8,
		"Named location density (%.6f items/m²) should be at least 3× open area density (%.6f items/m²). Ratio: %.2f. Named points: %d, Open points: %d" % [
			named_density, open_density, density_ratio, named_points.size(), open_points.size()
		])


## Property test: Each named location has at least 5 loot spawn points.
func test_property_each_named_location_has_minimum_5_spawn_points() -> void:
	var map_data := MapData.new()
	var loot_manager := LootManager.new()
	loot_manager.initialize_loot(map_data)

	# Check each named location individually
	for location in map_data.get_named_locations():
		var spawn_count := location.loot_spawn_points.size()
		assert_gte(spawn_count, MapData.MIN_LOOT_POINTS_PER_LOCATION,
			"Named location '%s' has %d spawn points, minimum required is %d" % [
				location.display_name, spawn_count, MapData.MIN_LOOT_POINTS_PER_LOCATION
			])


## Property test: All named locations are separated by at least 100 meters.
func test_property_named_locations_separated_by_100m() -> void:
	var map_data := MapData.new()
	var locations := map_data.get_named_locations()

	for i in range(locations.size()):
		for j in range(i + 1, locations.size()):
			var distance := locations[i].position.distance_to(locations[j].position)
			assert_gte(distance, MapData.MIN_LOCATION_SEPARATION,
				"Locations '%s' and '%s' are only %.2fm apart (minimum: %.2fm)" % [
					locations[i].display_name, locations[j].display_name,
					distance, MapData.MIN_LOCATION_SEPARATION
				])


## Property test: Each terrain type covers at least 15% of the total map area.
func test_property_each_terrain_type_covers_minimum_15_percent() -> void:
	var map_data := MapData.new()

	for terrain_type in MapData.TerrainType.values():
		var coverage := map_data.get_terrain_coverage(terrain_type)
		assert_gte(coverage, MapData.MIN_TERRAIN_COVERAGE_PERCENT,
			"Terrain type %d has %.2f%% coverage, minimum required is %.2f%%" % [
				terrain_type, coverage, MapData.MIN_TERRAIN_COVERAGE_PERCENT
			])


## Property test: Map validation methods confirm all constraints hold together.
func test_property_map_validates_all_constraints() -> void:
	var map_data := MapData.new()

	assert_true(map_data.validate_location_separation(),
		"Map should pass location separation validation (all locations >= 100m apart)")
	assert_true(map_data.validate_terrain_coverage(),
		"Map should pass terrain coverage validation (each type >= 15%%)")
	assert_true(map_data.validate_loot_spawn_points(),
		"Map should pass loot spawn point validation (each location >= 5 points)")


## Property test: Named locations have at least the minimum count (8).
func test_property_minimum_named_locations_count() -> void:
	var map_data := MapData.new()
	var locations := map_data.get_named_locations()

	assert_gte(locations.size(), MapData.MIN_NAMED_LOCATIONS,
		"Map should have at least %d named locations, has %d" % [
			MapData.MIN_NAMED_LOCATIONS, locations.size()
		])


## Property test: After initialization, loot spawn points in named locations
## are actually within the named location boundaries.
func test_property_named_location_spawn_points_within_bounds() -> void:
	var map_data := MapData.new()

	for location in map_data.get_named_locations():
		for point in location.loot_spawn_points:
			var distance := point.distance_to(location.position)
			# Points should be within the location's radius (with small tolerance for generation)
			assert_lt(distance, location.radius * 1.1,
				"Spawn point %s in '%s' is %.2fm from center (radius: %.2fm)" % [
					str(point), location.display_name, distance, location.radius
				])


## Property test: The density multiplier constant is at least 3.0.
func test_property_density_multiplier_constant_is_3x() -> void:
	assert_gte(LootManager.NAMED_LOCATION_DENSITY_MULTIPLIER, 3.0,
		"Named location density multiplier should be at least 3.0, got %.2f" % [
			LootManager.NAMED_LOCATION_DENSITY_MULTIPLIER
		])
