## Property-based test for inventory capacity invariant.
## **Validates: Requirements 4.3, 7.2, 7.4**
##
## Property 8: Inventory capacity invariant
## *For any* sequence of item pickup operations, the inventory SHALL never contain
## more than 5 weapons, never contain more than 3 consumable stacks, and each
## consumable stack SHALL never exceed its type's maximum (5 for bandages, 3 for
## medkits, 3 for shield potions). Pickup attempts when at capacity SHALL be
## rejected without modifying inventory state.
extends GutTest

## Number of random test iterations per property test
const NUM_ITERATIONS := 200

## Maximum number of operations per sequence
const MAX_OPS_PER_SEQUENCE := 50

## Weapon capacity limit
const MAX_WEAPONS := 5

## Consumable slot limit
const MAX_CONSUMABLE_SLOTS := 3

## Stack limits per consumable type
const STACK_LIMITS := {
	Enums.ConsumableType.BANDAGE: 5,
	Enums.ConsumableType.MEDKIT: 3,
	Enums.ConsumableType.SHIELD_POTION: 3,
}

## All consumable types for generation
const CONSUMABLE_TYPES := [
	Enums.ConsumableType.BANDAGE,
	Enums.ConsumableType.MEDKIT,
	Enums.ConsumableType.SHIELD_POTION,
]

## All weapon categories for generation
const WEAPON_CATEGORIES := [
	Enums.WeaponCategory.AR,
	Enums.WeaponCategory.SHOTGUN,
	Enums.WeaponCategory.SMG,
	Enums.WeaponCategory.SNIPER,
	Enums.WeaponCategory.PISTOL,
]

## All rarity tiers for generation
const RARITY_TIERS := [
	Enums.RarityTier.COMMON,
	Enums.RarityTier.UNCOMMON,
	Enums.RarityTier.RARE,
	Enums.RarityTier.EPIC,
	Enums.RarityTier.LEGENDARY,
]

## Operation types for random sequence generation
enum OpType {
	ADD_WEAPON,
	REMOVE_WEAPON,
	ADD_CONSUMABLE,
}

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()


## Generates a random WeaponData instance.
func _generate_random_weapon() -> WeaponData:
	var weapon := WeaponData.new()
	weapon.category = WEAPON_CATEGORIES[_rng.randi_range(0, WEAPON_CATEGORIES.size() - 1)]
	weapon.name = "TestWeapon_%d" % _rng.randi_range(0, 999)
	weapon.rarity = RARITY_TIERS[_rng.randi_range(0, RARITY_TIERS.size() - 1)]
	weapon.base_damage = _rng.randf_range(10.0, 100.0)
	weapon.fire_rate = _rng.randf_range(0.5, 10.0)
	weapon.magazine_size = _rng.randi_range(5, 30)
	weapon.reload_time = _rng.randf_range(1.0, 4.0)
	weapon.effective_range = _rng.randf_range(10.0, 150.0)
	weapon.accuracy_base = _rng.randf_range(0.5, 0.95)
	return weapon


## Generates a random consumable type.
func _generate_random_consumable_type() -> Enums.ConsumableType:
	return CONSUMABLE_TYPES[_rng.randi_range(0, CONSUMABLE_TYPES.size() - 1)]


## Generates a random operation type.
func _generate_random_op() -> OpType:
	var roll := _rng.randi_range(0, 2)
	match roll:
		0:
			return OpType.ADD_WEAPON
		1:
			return OpType.REMOVE_WEAPON
		_:
			return OpType.ADD_CONSUMABLE


## Asserts that the inventory capacity invariants hold.
func _assert_capacity_invariants(inventory: InventorySystem, context: String) -> void:
	# Weapon count must never exceed MAX_WEAPONS
	var weapon_count := inventory.get_weapon_count()
	assert_true(weapon_count <= MAX_WEAPONS,
		"%s: Weapon count %d exceeds maximum %d" % [context, weapon_count, MAX_WEAPONS])

	# Each consumable stack must not exceed its type's maximum
	for type in CONSUMABLE_TYPES:
		var count := inventory.get_consumable_count(type)
		var max_stack: int = STACK_LIMITS[type]
		assert_true(count <= max_stack,
			"%s: Consumable type %d count %d exceeds max stack %d" % [context, type, count, max_stack])

	# Consumable counts must be non-negative
	for type in CONSUMABLE_TYPES:
		var count := inventory.get_consumable_count(type)
		assert_true(count >= 0,
			"%s: Consumable type %d has negative count %d" % [context, type, count])


## Property test: For any random sequence of add/remove operations,
## the weapon count SHALL never exceed 5.
func test_property_weapon_count_never_exceeds_max() -> void:
	for i in range(NUM_ITERATIONS):
		var inventory := InventorySystem.new()
		var num_ops := _rng.randi_range(1, MAX_OPS_PER_SEQUENCE)

		for op_idx in range(num_ops):
			# Randomly add or remove weapons
			if _rng.randi_range(0, 1) == 0:
				var weapon := _generate_random_weapon()
				inventory.add_weapon(weapon)
			else:
				var slot := _rng.randi_range(0, MAX_WEAPONS - 1)
				inventory.remove_weapon(slot)

			# Assert invariant after every operation
			var weapon_count := inventory.get_weapon_count()
			assert_true(weapon_count <= MAX_WEAPONS,
				"Iteration %d, op %d: Weapon count %d exceeds maximum %d" % [
					i, op_idx, weapon_count, MAX_WEAPONS])


## Property test: For any random sequence of consumable add operations,
## each consumable stack SHALL never exceed its type's maximum.
func test_property_consumable_stacks_never_exceed_max() -> void:
	for i in range(NUM_ITERATIONS):
		var inventory := InventorySystem.new()
		var num_ops := _rng.randi_range(1, MAX_OPS_PER_SEQUENCE)

		for op_idx in range(num_ops):
			var type := _generate_random_consumable_type()
			var count := _rng.randi_range(1, 6)  # May exceed stack limit
			inventory.add_consumable(type, count)

			# Assert invariant after every operation
			for check_type in CONSUMABLE_TYPES:
				var current_count := inventory.get_consumable_count(check_type)
				var max_stack: int = STACK_LIMITS[check_type]
				assert_true(current_count <= max_stack,
					"Iteration %d, op %d: Consumable type %d count %d exceeds max %d" % [
						i, op_idx, check_type, current_count, max_stack])


## Property test: Pickup attempts when weapon slots are at capacity
## SHALL be rejected without modifying inventory state.
func test_property_weapon_pickup_at_capacity_rejected_without_state_change() -> void:
	for i in range(NUM_ITERATIONS):
		var inventory := InventorySystem.new()

		# Fill all weapon slots
		for _slot in range(MAX_WEAPONS):
			var weapon := _generate_random_weapon()
			inventory.add_weapon(weapon)

		# Capture state before rejected pickup
		var weapons_before: Array = []
		for slot_idx in range(MAX_WEAPONS):
			weapons_before.append(inventory.weapon_slots[slot_idx])

		# Attempt to add another weapon (should be rejected)
		var extra_weapon := _generate_random_weapon()
		var result := inventory.add_weapon(extra_weapon)

		# Verify rejection
		assert_eq(result, FAILED,
			"Iteration %d: Adding weapon at capacity should return FAILED" % i)

		# Verify state unchanged
		assert_eq(inventory.get_weapon_count(), MAX_WEAPONS,
			"Iteration %d: Weapon count should remain %d after rejected pickup" % [i, MAX_WEAPONS])

		for slot_idx in range(MAX_WEAPONS):
			assert_eq(inventory.weapon_slots[slot_idx], weapons_before[slot_idx],
				"Iteration %d: Weapon slot %d should be unchanged after rejected pickup" % [i, slot_idx])


## Property test: Pickup attempts when consumable stacks are at capacity
## SHALL be rejected without modifying inventory state.
func test_property_consumable_pickup_at_capacity_rejected_without_state_change() -> void:
	for i in range(NUM_ITERATIONS):
		var inventory := InventorySystem.new()
		var type := _generate_random_consumable_type()
		var max_stack: int = STACK_LIMITS[type]

		# Fill the consumable stack to max
		inventory.add_consumable(type, max_stack)

		# Capture state before rejected pickup
		var count_before := inventory.get_consumable_count(type)
		var all_counts_before: Dictionary = {}
		for check_type in CONSUMABLE_TYPES:
			all_counts_before[check_type] = inventory.get_consumable_count(check_type)

		# Attempt to add more (should be rejected)
		var add_count := _rng.randi_range(1, 5)
		var result := inventory.add_consumable(type, add_count)

		# Verify rejection
		assert_eq(result, FAILED,
			"Iteration %d: Adding consumable type %d at max stack should return FAILED" % [i, type])

		# Verify state unchanged for all consumable types
		for check_type in CONSUMABLE_TYPES:
			assert_eq(inventory.get_consumable_count(check_type), all_counts_before[check_type],
				"Iteration %d: Consumable type %d count should be unchanged after rejected pickup" % [i, check_type])


## Property test: For any arbitrary sequence of mixed add/remove operations,
## ALL capacity invariants hold simultaneously after every operation.
func test_property_all_invariants_hold_under_arbitrary_operation_sequences() -> void:
	for i in range(NUM_ITERATIONS):
		var inventory := InventorySystem.new()
		var num_ops := _rng.randi_range(5, MAX_OPS_PER_SEQUENCE)

		for op_idx in range(num_ops):
			var op := _generate_random_op()

			match op:
				OpType.ADD_WEAPON:
					var weapon := _generate_random_weapon()
					inventory.add_weapon(weapon)
				OpType.REMOVE_WEAPON:
					var slot := _rng.randi_range(0, MAX_WEAPONS - 1)
					inventory.remove_weapon(slot)
				OpType.ADD_CONSUMABLE:
					var type := _generate_random_consumable_type()
					var count := _rng.randi_range(1, 6)
					inventory.add_consumable(type, count)

			# Assert ALL invariants after every operation
			_assert_capacity_invariants(inventory,
				"Iteration %d, op %d (type %d)" % [i, op_idx, op])


## Property test: Bandage stack limit is exactly 5.
## Adding bandages up to 5 succeeds, adding beyond 5 fails.
func test_property_bandage_stack_limit_is_5() -> void:
	for i in range(NUM_ITERATIONS):
		var inventory := InventorySystem.new()
		var total_to_add := _rng.randi_range(1, 10)
		var added_so_far := 0

		for _op in range(total_to_add):
			var count := _rng.randi_range(1, 3)
			var result := inventory.add_consumable(Enums.ConsumableType.BANDAGE, count)

			if added_so_far + count <= 5:
				assert_eq(result, OK,
					"Iteration %d: Adding %d bandages (total would be %d) should succeed" % [
						i, count, added_so_far + count])
				added_so_far += count
			else:
				assert_eq(result, FAILED,
					"Iteration %d: Adding %d bandages (total would be %d) should fail" % [
						i, count, added_so_far + count])

			# Invariant: never exceeds 5
			assert_true(inventory.get_consumable_count(Enums.ConsumableType.BANDAGE) <= 5,
				"Iteration %d: Bandage count should never exceed 5" % i)


## Property test: Medkit stack limit is exactly 3.
## Adding medkits up to 3 succeeds, adding beyond 3 fails.
func test_property_medkit_stack_limit_is_3() -> void:
	for i in range(NUM_ITERATIONS):
		var inventory := InventorySystem.new()
		var total_to_add := _rng.randi_range(1, 8)
		var added_so_far := 0

		for _op in range(total_to_add):
			var count := _rng.randi_range(1, 2)
			var result := inventory.add_consumable(Enums.ConsumableType.MEDKIT, count)

			if added_so_far + count <= 3:
				assert_eq(result, OK,
					"Iteration %d: Adding %d medkits (total would be %d) should succeed" % [
						i, count, added_so_far + count])
				added_so_far += count
			else:
				assert_eq(result, FAILED,
					"Iteration %d: Adding %d medkits (total would be %d) should fail" % [
						i, count, added_so_far + count])

			# Invariant: never exceeds 3
			assert_true(inventory.get_consumable_count(Enums.ConsumableType.MEDKIT) <= 3,
				"Iteration %d: Medkit count should never exceed 3" % i)


## Property test: Shield potion stack limit is exactly 3.
## Adding shield potions up to 3 succeeds, adding beyond 3 fails.
func test_property_shield_potion_stack_limit_is_3() -> void:
	for i in range(NUM_ITERATIONS):
		var inventory := InventorySystem.new()
		var total_to_add := _rng.randi_range(1, 8)
		var added_so_far := 0

		for _op in range(total_to_add):
			var count := _rng.randi_range(1, 2)
			var result := inventory.add_consumable(Enums.ConsumableType.SHIELD_POTION, count)

			if added_so_far + count <= 3:
				assert_eq(result, OK,
					"Iteration %d: Adding %d shield potions (total would be %d) should succeed" % [
						i, count, added_so_far + count])
				added_so_far += count
			else:
				assert_eq(result, FAILED,
					"Iteration %d: Adding %d shield potions (total would be %d) should fail" % [
						i, count, added_so_far + count])

			# Invariant: never exceeds 3
			assert_true(inventory.get_consumable_count(Enums.ConsumableType.SHIELD_POTION) <= 3,
				"Iteration %d: Shield potion count should never exceed 3" % i)
