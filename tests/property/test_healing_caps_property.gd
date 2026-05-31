## Property-based test for healing calculation with caps.
## **Validates: Requirements 7.3**
##
## Property 18: Healing calculation with caps
## *For any* player health/shield state and consumable type used, the resulting
## value SHALL equal min(current + heal_amount, cap) where caps are: bandage heals
## 25 HP capped at 75, medkit heals to full (100), shield potion heals 50 shield
## capped at 100. Additionally, bandage use SHALL be blocked when current health ≥ 75.
extends GutTest

## Number of random test iterations per property test
const NUM_ITERATIONS := 200

## Tolerance for floating point comparisons
const EPSILON := 0.001

var _rng: RandomNumberGenerator
var _inventory: InventorySystem


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_inventory = InventorySystem.new()


## Generates a random health value between 0 and 100 (inclusive).
func _generate_random_health() -> float:
	return _rng.randf_range(0.0, 100.0)


## Generates a random shield value between 0 and 100 (inclusive).
func _generate_random_shield() -> float:
	return _rng.randf_range(0.0, 100.0)


## Generates a random health value strictly below 75 (valid for bandage use).
func _generate_health_below_bandage_cap() -> float:
	return _rng.randf_range(0.0, 74.99)


## Generates a random health value at or above 75 (bandage should be blocked).
func _generate_health_at_or_above_bandage_cap() -> float:
	return _rng.randf_range(75.0, 100.0)


## Sets up the inventory with a consumable and specific health/shield state.
func _setup_inventory(health: float, shield: float, type: Enums.ConsumableType) -> void:
	_inventory.current_health = health
	_inventory.current_shield = shield
	_inventory.add_consumable(type, 1)


## Property test: For any health state below 75, bandage heals to
## min(current_health + 25, 75).
func test_property_bandage_heals_capped_at_75() -> void:
	for i in range(NUM_ITERATIONS):
		_inventory = InventorySystem.new()
		var initial_health := _generate_health_below_bandage_cap()
		var initial_shield := _generate_random_shield()
		_setup_inventory(initial_health, initial_shield, Enums.ConsumableType.BANDAGE)

		var use_result := _inventory.use_consumable(Enums.ConsumableType.BANDAGE)
		assert_true(use_result["success"],
			"Iteration %d: Bandage use should succeed when health (%.2f) < 75" % [i, initial_health])

		var heal_result := _inventory.complete_healing()
		assert_true(heal_result["success"],
			"Iteration %d: complete_healing should succeed" % [i])

		var expected_health := min(initial_health + 25.0, 75.0)
		assert_almost_eq(_inventory.current_health, expected_health, EPSILON,
			"Iteration %d: Health should be min(%.2f + 25, 75) = %.2f but got %.2f" % [
				i, initial_health, expected_health, _inventory.current_health])


## Property test: For any health state at or above 75, bandage use SHALL be blocked.
func test_property_bandage_blocked_when_health_at_or_above_75() -> void:
	for i in range(NUM_ITERATIONS):
		_inventory = InventorySystem.new()
		var initial_health := _generate_health_at_or_above_bandage_cap()
		var initial_shield := _generate_random_shield()
		_setup_inventory(initial_health, initial_shield, Enums.ConsumableType.BANDAGE)

		var use_result := _inventory.use_consumable(Enums.ConsumableType.BANDAGE)
		assert_false(use_result["success"],
			"Iteration %d: Bandage use should be blocked when health (%.2f) >= 75" % [i, initial_health])
		assert_eq(use_result["error"], "health_at_cap",
			"Iteration %d: Error should be 'health_at_cap' when health >= 75" % [i])

		# Health should remain unchanged
		assert_almost_eq(_inventory.current_health, initial_health, EPSILON,
			"Iteration %d: Health should remain %.2f when bandage is blocked, got %.2f" % [
				i, initial_health, _inventory.current_health])

		# Consumable should not be consumed
		assert_eq(_inventory.get_consumable_count(Enums.ConsumableType.BANDAGE), 1,
			"Iteration %d: Bandage should not be consumed when blocked" % [i])


## Property test: For any health state, medkit heals to full (100).
func test_property_medkit_heals_to_full() -> void:
	for i in range(NUM_ITERATIONS):
		_inventory = InventorySystem.new()
		var initial_health := _generate_random_health()
		var initial_shield := _generate_random_shield()
		_setup_inventory(initial_health, initial_shield, Enums.ConsumableType.MEDKIT)

		var use_result := _inventory.use_consumable(Enums.ConsumableType.MEDKIT)
		assert_true(use_result["success"],
			"Iteration %d: Medkit use should succeed at any health (%.2f)" % [i, initial_health])

		var heal_result := _inventory.complete_healing()
		assert_true(heal_result["success"],
			"Iteration %d: complete_healing should succeed" % [i])

		assert_almost_eq(_inventory.current_health, 100.0, EPSILON,
			"Iteration %d: Health should be 100.0 after medkit (was %.2f), got %.2f" % [
				i, initial_health, _inventory.current_health])


## Property test: For any shield state, shield potion heals
## min(current_shield + 50, 100).
func test_property_shield_potion_heals_capped_at_100() -> void:
	for i in range(NUM_ITERATIONS):
		_inventory = InventorySystem.new()
		var initial_health := _generate_random_health()
		var initial_shield := _generate_random_shield()
		_setup_inventory(initial_health, initial_shield, Enums.ConsumableType.SHIELD_POTION)

		var use_result := _inventory.use_consumable(Enums.ConsumableType.SHIELD_POTION)
		assert_true(use_result["success"],
			"Iteration %d: Shield potion use should succeed at any shield (%.2f)" % [i, initial_shield])

		var heal_result := _inventory.complete_healing()
		assert_true(heal_result["success"],
			"Iteration %d: complete_healing should succeed" % [i])

		var expected_shield := min(initial_shield + 50.0, 100.0)
		assert_almost_eq(_inventory.current_shield, expected_shield, EPSILON,
			"Iteration %d: Shield should be min(%.2f + 50, 100) = %.2f but got %.2f" % [
				i, initial_shield, expected_shield, _inventory.current_shield])


## Property test: Healing a consumable does not affect the other stat.
## Bandage/medkit should not change shield; shield potion should not change health.
func test_property_healing_does_not_affect_other_stat() -> void:
	for i in range(NUM_ITERATIONS):
		_inventory = InventorySystem.new()
		var initial_health := _generate_health_below_bandage_cap()
		var initial_shield := _generate_random_shield()

		# Pick a random consumable type
		var types := [Enums.ConsumableType.BANDAGE, Enums.ConsumableType.MEDKIT, Enums.ConsumableType.SHIELD_POTION]
		var type: Enums.ConsumableType = types[_rng.randi_range(0, 2)]

		_setup_inventory(initial_health, initial_shield, type)

		var use_result := _inventory.use_consumable(type)
		if not use_result["success"]:
			continue

		_inventory.complete_healing()

		match type:
			Enums.ConsumableType.BANDAGE, Enums.ConsumableType.MEDKIT:
				# Health consumables should not change shield
				assert_almost_eq(_inventory.current_shield, initial_shield, EPSILON,
					"Iteration %d: Shield should remain %.2f after using %s, got %.2f" % [
						i, initial_shield, _type_name(type), _inventory.current_shield])
			Enums.ConsumableType.SHIELD_POTION:
				# Shield consumable should not change health
				assert_almost_eq(_inventory.current_health, initial_health, EPSILON,
					"Iteration %d: Health should remain %.2f after using shield potion, got %.2f" % [
						i, initial_health, _inventory.current_health])


## Property test: Healing result value is always non-negative and within valid bounds.
func test_property_healing_result_within_valid_bounds() -> void:
	for i in range(NUM_ITERATIONS):
		_inventory = InventorySystem.new()
		var initial_health := _generate_health_below_bandage_cap()
		var initial_shield := _generate_random_shield()

		var types := [Enums.ConsumableType.BANDAGE, Enums.ConsumableType.MEDKIT, Enums.ConsumableType.SHIELD_POTION]
		var type: Enums.ConsumableType = types[_rng.randi_range(0, 2)]

		_setup_inventory(initial_health, initial_shield, type)

		var use_result := _inventory.use_consumable(type)
		if not use_result["success"]:
			continue

		_inventory.complete_healing()

		# Health should always be between 0 and 100
		assert_true(_inventory.current_health >= 0.0 and _inventory.current_health <= 100.0,
			"Iteration %d: Health (%.2f) should be in [0, 100] after using %s" % [
				i, _inventory.current_health, _type_name(type)])

		# Shield should always be between 0 and 100
		assert_true(_inventory.current_shield >= 0.0 and _inventory.current_shield <= 100.0,
			"Iteration %d: Shield (%.2f) should be in [0, 100] after using %s" % [
				i, _inventory.current_shield, _type_name(type)])


## Property test: Bandage healing amount is always exactly min(25, 75 - current_health)
## when health < 75.
func test_property_bandage_healed_amount_correct() -> void:
	for i in range(NUM_ITERATIONS):
		_inventory = InventorySystem.new()
		var initial_health := _generate_health_below_bandage_cap()
		var initial_shield := _generate_random_shield()
		_setup_inventory(initial_health, initial_shield, Enums.ConsumableType.BANDAGE)

		_inventory.use_consumable(Enums.ConsumableType.BANDAGE)
		var heal_result := _inventory.complete_healing()

		var expected_healed := min(25.0, 75.0 - initial_health)
		var actual_healed: float = heal_result.get("healed", 0.0)

		assert_almost_eq(actual_healed, expected_healed, EPSILON,
			"Iteration %d: Bandage should heal %.2f (min(25, 75 - %.2f)) but healed %.2f" % [
				i, expected_healed, initial_health, actual_healed])


## Helper to get a readable name for a consumable type.
func _type_name(type: Enums.ConsumableType) -> String:
	match type:
		Enums.ConsumableType.BANDAGE:
			return "BANDAGE"
		Enums.ConsumableType.MEDKIT:
			return "MEDKIT"
		Enums.ConsumableType.SHIELD_POTION:
			return "SHIELD_POTION"
		_:
			return "UNKNOWN"
