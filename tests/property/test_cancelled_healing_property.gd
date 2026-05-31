## Property-based test: Cancelled healing consumes item (Property 19)
## **Validates: Requirements 7.7**
##
## For any healing action that is interrupted before the usage animation completes,
## the consumable item SHALL be removed from inventory AND no healing effect SHALL
## be applied to the player's health or shield.
extends GutTest


## Number of random iterations for property tests.
const ITERATIONS: int = 200

## Tolerance for floating point comparisons.
const EPSILON := 0.001

## All consumable types for random generation.
const CONSUMABLE_TYPES: Array = [
	Enums.ConsumableType.BANDAGE,
	Enums.ConsumableType.MEDKIT,
	Enums.ConsumableType.SHIELD_POTION,
]

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()


## Generates a random health value appropriate for the given consumable type.
## For bandages, health must be below 75 (otherwise use is blocked).
## For medkits, any health below 100 is valid.
## For shield potions, health doesn't matter (shield is the target).
func _generate_valid_health_for_type(type: Enums.ConsumableType) -> float:
	match type:
		Enums.ConsumableType.BANDAGE:
			# Bandage is blocked at >= 75, so generate health in [1, 74]
			return _rng.randf_range(1.0, 74.0)
		Enums.ConsumableType.MEDKIT:
			# Medkit works at any health below 100
			return _rng.randf_range(1.0, 99.0)
		Enums.ConsumableType.SHIELD_POTION:
			# Shield potion targets shield, health can be anything
			return _rng.randf_range(1.0, 100.0)
		_:
			return 50.0


## Generates a random shield value for the given consumable type.
## For shield potions, shield must be below 100 (otherwise no effect, but use is still allowed).
func _generate_random_shield(type: Enums.ConsumableType) -> float:
	match type:
		Enums.ConsumableType.SHIELD_POTION:
			# Generate shield below cap so healing would have an effect if completed
			return _rng.randf_range(0.0, 99.0)
		_:
			# For health-targeting consumables, shield can be anything
			return _rng.randf_range(0.0, 100.0)


## Generates a random initial consumable count (at least 1 so we can use one).
func _generate_initial_count(type: Enums.ConsumableType) -> int:
	var max_stack: int = InventorySystem.STACK_LIMITS[type]
	return _rng.randi_range(1, max_stack)


## Returns the consumable type name for debug messages.
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


## Property: Cancelled healing consumes exactly one item from inventory.
## For any consumable type and valid starting state, starting healing and then
## cancelling it must result in the item count being decremented by exactly 1.
func test_property_cancelled_healing_consumes_item() -> void:
	for i in range(ITERATIONS):
		var type: Enums.ConsumableType = CONSUMABLE_TYPES[_rng.randi_range(0, CONSUMABLE_TYPES.size() - 1)]
		var initial_count := _generate_initial_count(type)
		var health := _generate_valid_health_for_type(type)
		var shield := _generate_random_shield(type)

		# Set up inventory
		var inventory := InventorySystem.new()
		inventory.current_health = health
		inventory.current_shield = shield
		inventory.consumable_slots[type] = initial_count

		# Start healing
		var result := inventory.use_consumable(type)
		assert_true(result["success"],
			"Iteration %d: use_consumable should succeed for %s with count %d, health %.1f, shield %.1f" % [
				i, _type_name(type), initial_count, health, shield
			])

		# Cancel healing before completion
		var cancelled := inventory.cancel_healing()
		assert_true(cancelled,
			"Iteration %d: cancel_healing should return true when healing is in progress" % i)

		# Verify item was consumed (count decreased by 1)
		var final_count := inventory.get_consumable_count(type)
		assert_eq(final_count, initial_count - 1,
			"Iteration %d: %s count should decrease by 1 after cancelled healing. " % [i, _type_name(type)] +
			"Initial: %d, Expected: %d, Got: %d" % [initial_count, initial_count - 1, final_count])


## Property: Cancelled healing applies no health effect.
## For any health-targeting consumable (bandage, medkit), starting healing and
## cancelling it must leave health unchanged from its value at the time of cancellation.
func test_property_cancelled_healing_no_health_change() -> void:
	for i in range(ITERATIONS):
		# Only test health-targeting consumables
		var type: Enums.ConsumableType
		if _rng.randi_range(0, 1) == 0:
			type = Enums.ConsumableType.BANDAGE
		else:
			type = Enums.ConsumableType.MEDKIT

		var initial_count := _generate_initial_count(type)
		var health := _generate_valid_health_for_type(type)
		var shield := _generate_random_shield(type)

		# Set up inventory
		var inventory := InventorySystem.new()
		inventory.current_health = health
		inventory.current_shield = shield
		inventory.consumable_slots[type] = initial_count

		# Start healing
		var result := inventory.use_consumable(type)
		assert_true(result["success"],
			"Iteration %d: use_consumable should succeed for %s" % [i, _type_name(type)])

		# Cancel healing
		inventory.cancel_healing()

		# Verify health is unchanged
		assert_almost_eq(inventory.current_health, health, EPSILON,
			"Iteration %d: Health should remain unchanged after cancelled %s healing. " % [i, _type_name(type)] +
			"Expected: %.3f, Got: %.3f" % [health, inventory.current_health])


## Property: Cancelled healing applies no shield effect.
## For shield potions, starting healing and cancelling it must leave shield unchanged.
func test_property_cancelled_healing_no_shield_change() -> void:
	for i in range(ITERATIONS):
		var type := Enums.ConsumableType.SHIELD_POTION
		var initial_count := _generate_initial_count(type)
		var health := _generate_valid_health_for_type(type)
		var shield := _generate_random_shield(type)

		# Set up inventory
		var inventory := InventorySystem.new()
		inventory.current_health = health
		inventory.current_shield = shield
		inventory.consumable_slots[type] = initial_count

		# Start healing
		var result := inventory.use_consumable(type)
		assert_true(result["success"],
			"Iteration %d: use_consumable should succeed for SHIELD_POTION" % i)

		# Cancel healing
		inventory.cancel_healing()

		# Verify shield is unchanged
		assert_almost_eq(inventory.current_shield, shield, EPSILON,
			"Iteration %d: Shield should remain unchanged after cancelled SHIELD_POTION healing. " % i +
			"Expected: %.3f, Got: %.3f" % [shield, inventory.current_shield])


## Property: Cancelled healing leaves the inventory in a non-healing state.
## After cancellation, is_healing must be false and no healing timer remains.
func test_property_cancelled_healing_resets_healing_state() -> void:
	for i in range(ITERATIONS):
		var type: Enums.ConsumableType = CONSUMABLE_TYPES[_rng.randi_range(0, CONSUMABLE_TYPES.size() - 1)]
		var initial_count := _generate_initial_count(type)
		var health := _generate_valid_health_for_type(type)
		var shield := _generate_random_shield(type)

		# Set up inventory
		var inventory := InventorySystem.new()
		inventory.current_health = health
		inventory.current_shield = shield
		inventory.consumable_slots[type] = initial_count

		# Start healing
		inventory.use_consumable(type)

		# Cancel healing
		inventory.cancel_healing()

		# Verify healing state is reset
		assert_false(inventory.is_healing,
			"Iteration %d: is_healing should be false after cancellation" % i)


## Property: Both item consumption AND no healing hold simultaneously.
## This is the combined property: for any cancelled healing, the item is consumed
## AND neither health nor shield changes.
func test_property_cancelled_healing_combined_item_consumed_no_effect() -> void:
	for i in range(ITERATIONS):
		var type: Enums.ConsumableType = CONSUMABLE_TYPES[_rng.randi_range(0, CONSUMABLE_TYPES.size() - 1)]
		var initial_count := _generate_initial_count(type)
		var health := _generate_valid_health_for_type(type)
		var shield := _generate_random_shield(type)

		# Set up inventory
		var inventory := InventorySystem.new()
		inventory.current_health = health
		inventory.current_shield = shield
		inventory.consumable_slots[type] = initial_count

		# Start healing
		var result := inventory.use_consumable(type)
		assert_true(result["success"],
			"Iteration %d: use_consumable should succeed for %s" % [i, _type_name(type)])

		# Cancel healing
		inventory.cancel_healing()

		# Verify BOTH conditions hold:
		# 1. Item was consumed
		var final_count := inventory.get_consumable_count(type)
		assert_eq(final_count, initial_count - 1,
			"Iteration %d: %s count should decrease by 1. Initial: %d, Got: %d" % [
				i, _type_name(type), initial_count, final_count])

		# 2. No healing effect applied
		assert_almost_eq(inventory.current_health, health, EPSILON,
			"Iteration %d: Health should be unchanged. Expected: %.3f, Got: %.3f" % [
				i, health, inventory.current_health])
		assert_almost_eq(inventory.current_shield, shield, EPSILON,
			"Iteration %d: Shield should be unchanged. Expected: %.3f, Got: %.3f" % [
				i, shield, inventory.current_shield])
