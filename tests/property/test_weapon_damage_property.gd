## Property-based test for weapon damage calculation.
## **Validates: Requirements 4.4, 4.5**
##
## Property 6: Weapon damage calculation
## *For any* weapon category, rarity tier, and target distance, the calculated
## damage SHALL equal: base_damage × (1 + 0.10 × rarity_index) when distance ≤
## effective_range; linearly interpolated from full damage to 50% damage between
## effective_range and 2× effective_range; and exactly zero beyond 2× effective_range.
extends GutTest

## Number of random test iterations per property test
const NUM_ITERATIONS := 200

## Tolerance for floating point comparisons
const EPSILON := 0.001

## All weapon categories with their base stats for generation
const WEAPON_CONFIGS := [
	{"category": "AR", "name": "Volt Repeater", "base_damage": 30.0, "fire_rate": 5.0, "magazine_size": 30, "reload_time": 2.0, "effective_range": 50.0, "accuracy_base": 0.75},
	{"category": "SHOTGUN", "name": "Boomstick", "base_damage": 90.0, "fire_rate": 1.0, "magazine_size": 5, "reload_time": 4.0, "effective_range": 10.0, "accuracy_base": 0.60},
	{"category": "SMG", "name": "Buzzer", "base_damage": 18.0, "fire_rate": 8.0, "magazine_size": 25, "reload_time": 1.5, "effective_range": 30.0, "accuracy_base": 0.65},
	{"category": "SNIPER", "name": "Longshot", "base_damage": 100.0, "fire_rate": 0.5, "magazine_size": 5, "reload_time": 3.0, "effective_range": 150.0, "accuracy_base": 0.90},
	{"category": "PISTOL", "name": "Sideswipe", "base_damage": 24.0, "fire_rate": 3.0, "magazine_size": 12, "reload_time": 1.0, "effective_range": 35.0, "accuracy_base": 0.70},
]

## All rarity tiers for generation
const RARITY_TIERS := [
	Enums.RarityTier.COMMON,
	Enums.RarityTier.UNCOMMON,
	Enums.RarityTier.RARE,
	Enums.RarityTier.EPIC,
	Enums.RarityTier.LEGENDARY,
]

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()


## Generates a random WeaponData with a random category and rarity tier.
func _generate_random_weapon() -> WeaponData:
	var config: Dictionary = WEAPON_CONFIGS[_rng.randi_range(0, WEAPON_CONFIGS.size() - 1)]
	var rarity: Enums.RarityTier = RARITY_TIERS[_rng.randi_range(0, RARITY_TIERS.size() - 1)]

	var weapon := WeaponData.new()
	weapon.category = _parse_category(config["category"])
	weapon.name = config["name"]
	weapon.rarity = rarity
	weapon.base_damage = config["base_damage"]
	weapon.fire_rate = config["fire_rate"]
	weapon.magazine_size = config["magazine_size"]
	weapon.reload_time = config["reload_time"]
	weapon.effective_range = config["effective_range"]
	weapon.accuracy_base = config["accuracy_base"]
	return weapon


## Generates a random distance value covering all three damage zones:
## - Within effective range (0 to effective_range)
## - Falloff zone (effective_range to 2× effective_range)
## - Beyond max range (2× effective_range to 3× effective_range)
func _generate_random_distance(effective_range: float) -> float:
	var max_test_distance := effective_range * 3.0
	return _rng.randf_range(0.0, max_test_distance)


## Helper to parse category string to enum
func _parse_category(category_str: String) -> Enums.WeaponCategory:
	match category_str:
		"AR":
			return Enums.WeaponCategory.AR
		"SHOTGUN":
			return Enums.WeaponCategory.SHOTGUN
		"SMG":
			return Enums.WeaponCategory.SMG
		"SNIPER":
			return Enums.WeaponCategory.SNIPER
		"PISTOL":
			return Enums.WeaponCategory.PISTOL
		_:
			return Enums.WeaponCategory.AR


## Computes the expected damage based on the property specification.
func _compute_expected_damage(weapon: WeaponData, distance: float) -> float:
	var rarity_index := int(weapon.rarity)
	var modified_damage := weapon.base_damage * (1.0 + 0.10 * rarity_index)
	var effective_range := weapon.effective_range
	var max_range := effective_range * 2.0

	# Beyond 2× effective range: zero damage
	if distance > max_range:
		return 0.0

	# Within effective range: full modified damage
	if distance <= effective_range:
		return modified_damage

	# Between effective_range and 2× effective_range: linear interpolation
	# from full damage (100%) to 50% damage
	var falloff_progress := (distance - effective_range) / (max_range - effective_range)
	var damage_multiplier := 1.0 - (falloff_progress * 0.5)
	return modified_damage * damage_multiplier


## Property test: For any weapon and distance within effective range,
## damage equals base_damage × (1 + 0.10 × rarity_index).
func test_property_full_damage_within_effective_range() -> void:
	for i in range(NUM_ITERATIONS):
		var weapon := _generate_random_weapon()
		var distance := _rng.randf_range(0.0, weapon.effective_range)

		var actual_damage := WeaponSystem.calculate_damage(weapon, distance)
		var rarity_index := int(weapon.rarity)
		var expected_damage := weapon.base_damage * (1.0 + 0.10 * rarity_index)

		assert_almost_eq(actual_damage, expected_damage, EPSILON,
			"Iteration %d: %s (rarity %d) at distance %.2f within effective range %.2f should deal full modified damage %.3f but got %.3f" % [
				i, weapon.name, rarity_index, distance, weapon.effective_range, expected_damage, actual_damage
			])


## Property test: For any weapon and distance between effective_range and
## 2× effective_range, damage is linearly interpolated from full to 50%.
func test_property_linear_falloff_between_effective_and_max_range() -> void:
	for i in range(NUM_ITERATIONS):
		var weapon := _generate_random_weapon()
		var effective_range := weapon.effective_range
		var max_range := effective_range * 2.0
		# Generate distance strictly between effective_range and max_range
		var distance := _rng.randf_range(effective_range + 0.01, max_range)

		var actual_damage := WeaponSystem.calculate_damage(weapon, distance)
		var expected_damage := _compute_expected_damage(weapon, distance)

		assert_almost_eq(actual_damage, expected_damage, EPSILON,
			"Iteration %d: %s (rarity %d) at distance %.2f in falloff zone [%.2f, %.2f] should deal %.3f but got %.3f" % [
				i, weapon.name, int(weapon.rarity), distance, effective_range, max_range, expected_damage, actual_damage
			])


## Property test: For any weapon and distance beyond 2× effective_range,
## damage is exactly zero.
func test_property_zero_damage_beyond_max_range() -> void:
	for i in range(NUM_ITERATIONS):
		var weapon := _generate_random_weapon()
		var max_range := weapon.effective_range * 2.0
		# Generate distance beyond 2× effective range
		var distance := _rng.randf_range(max_range + 0.01, max_range * 2.0)

		var actual_damage := WeaponSystem.calculate_damage(weapon, distance)

		assert_almost_eq(actual_damage, 0.0, EPSILON,
			"Iteration %d: %s (rarity %d) at distance %.2f beyond max range %.2f should deal zero damage but got %.3f" % [
				i, weapon.name, int(weapon.rarity), distance, max_range, actual_damage
			])


## Property test: At exactly the effective range boundary, damage equals
## full modified damage (boundary condition).
func test_property_boundary_at_effective_range() -> void:
	for i in range(NUM_ITERATIONS):
		var weapon := _generate_random_weapon()
		var distance := weapon.effective_range  # Exactly at boundary

		var actual_damage := WeaponSystem.calculate_damage(weapon, distance)
		var rarity_index := int(weapon.rarity)
		var expected_damage := weapon.base_damage * (1.0 + 0.10 * rarity_index)

		assert_almost_eq(actual_damage, expected_damage, EPSILON,
			"Iteration %d: %s (rarity %d) at exactly effective range %.2f should deal full modified damage %.3f but got %.3f" % [
				i, weapon.name, rarity_index, weapon.effective_range, expected_damage, actual_damage
			])


## Property test: At exactly 2× effective range, damage equals 50% of
## modified damage (boundary condition).
func test_property_boundary_at_2x_effective_range() -> void:
	for i in range(NUM_ITERATIONS):
		var weapon := _generate_random_weapon()
		var distance := weapon.effective_range * 2.0  # Exactly at max range

		var actual_damage := WeaponSystem.calculate_damage(weapon, distance)
		var rarity_index := int(weapon.rarity)
		var expected_damage := weapon.base_damage * (1.0 + 0.10 * rarity_index) * 0.5

		assert_almost_eq(actual_damage, expected_damage, EPSILON,
			"Iteration %d: %s (rarity %d) at exactly 2x effective range %.2f should deal 50%% modified damage %.3f but got %.3f" % [
				i, weapon.name, rarity_index, distance, expected_damage, actual_damage
			])


## Property test: Damage is monotonically non-increasing with distance.
## For any weapon, if d1 < d2, then damage(d1) >= damage(d2).
func test_property_damage_monotonically_decreases_with_distance() -> void:
	for i in range(NUM_ITERATIONS):
		var weapon := _generate_random_weapon()
		var max_test_distance := weapon.effective_range * 3.0
		var d1 := _rng.randf_range(0.0, max_test_distance)
		var d2 := _rng.randf_range(d1, max_test_distance)

		var damage_at_d1 := WeaponSystem.calculate_damage(weapon, d1)
		var damage_at_d2 := WeaponSystem.calculate_damage(weapon, d2)

		assert_true(damage_at_d1 >= damage_at_d2 - EPSILON,
			"Iteration %d: %s damage at %.2f (%.3f) should be >= damage at %.2f (%.3f)" % [
				i, weapon.name, d1, damage_at_d1, d2, damage_at_d2
			])


## Property test: Damage is always non-negative for any valid input.
func test_property_damage_never_negative() -> void:
	for i in range(NUM_ITERATIONS):
		var weapon := _generate_random_weapon()
		var distance := _generate_random_distance(weapon.effective_range)

		var actual_damage := WeaponSystem.calculate_damage(weapon, distance)

		assert_true(actual_damage >= 0.0,
			"Iteration %d: %s at distance %.2f should never produce negative damage, got %.3f" % [
				i, weapon.name, distance, actual_damage
			])


## Property test: Higher rarity always produces equal or greater damage
## at the same distance for the same weapon category.
func test_property_higher_rarity_produces_more_damage() -> void:
	for i in range(NUM_ITERATIONS):
		var config: Dictionary = WEAPON_CONFIGS[_rng.randi_range(0, WEAPON_CONFIGS.size() - 1)]
		var rarity_idx_1 := _rng.randi_range(0, 3)
		var rarity_idx_2 := _rng.randi_range(rarity_idx_1 + 1, 4)

		var weapon_lower := WeaponData.new()
		weapon_lower.category = _parse_category(config["category"])
		weapon_lower.name = config["name"]
		weapon_lower.rarity = RARITY_TIERS[rarity_idx_1]
		weapon_lower.base_damage = config["base_damage"]
		weapon_lower.effective_range = config["effective_range"]

		var weapon_higher := WeaponData.new()
		weapon_higher.category = _parse_category(config["category"])
		weapon_higher.name = config["name"]
		weapon_higher.rarity = RARITY_TIERS[rarity_idx_2]
		weapon_higher.base_damage = config["base_damage"]
		weapon_higher.effective_range = config["effective_range"]

		var distance := _rng.randf_range(0.0, weapon_lower.effective_range * 2.0)

		var damage_lower := WeaponSystem.calculate_damage(weapon_lower, distance)
		var damage_higher := WeaponSystem.calculate_damage(weapon_higher, distance)

		assert_true(damage_higher >= damage_lower - EPSILON,
			"Iteration %d: %s at distance %.2f - higher rarity (%d) damage %.3f should be >= lower rarity (%d) damage %.3f" % [
				i, weapon_lower.name, distance, rarity_idx_2, damage_higher, rarity_idx_1, damage_lower
			])
