## Property-based test: Empty magazine blocks firing (Property 9)
## **Validates: Requirements 4.8**
##
## For any weapon with 0 rounds in its magazine, attempting to fire SHALL produce
## no damage output and SHALL trigger a reload prompt, and the weapon SHALL not
## fire until a reload of the correct duration for its category has completed.
extends GutTest


## Number of random iterations for property tests.
const ITERATIONS: int = 100

## Weapon category configurations: [category, magazine_size, reload_time, base_damage, fire_rate, effective_range, accuracy]
const WEAPON_CONFIGS: Array = [
	[Enums.WeaponCategory.AR, 30, 2.0, 30.0, 5.0, 50.0, 0.75],
	[Enums.WeaponCategory.SHOTGUN, 5, 4.0, 90.0, 1.0, 10.0, 0.60],
	[Enums.WeaponCategory.SMG, 25, 1.5, 18.0, 8.0, 30.0, 0.65],
	[Enums.WeaponCategory.SNIPER, 5, 3.0, 100.0, 0.5, 150.0, 0.90],
	[Enums.WeaponCategory.PISTOL, 12, 1.0, 24.0, 3.0, 35.0, 0.70],
]

## All rarity tiers for random selection.
const RARITY_TIERS: Array = [
	Enums.RarityTier.COMMON,
	Enums.RarityTier.UNCOMMON,
	Enums.RarityTier.RARE,
	Enums.RarityTier.EPIC,
	Enums.RarityTier.LEGENDARY,
]


## Generates a random WeaponData with a random category and rarity.
func _generate_random_weapon() -> WeaponData:
	var config: Array = WEAPON_CONFIGS[randi() % WEAPON_CONFIGS.size()]
	var rarity: Enums.RarityTier = RARITY_TIERS[randi() % RARITY_TIERS.size()]

	var weapon := WeaponData.new()
	weapon.category = config[0]
	weapon.name = "TestWeapon"
	weapon.rarity = rarity
	weapon.base_damage = config[3]
	weapon.fire_rate = config[4]
	weapon.magazine_size = config[1]
	weapon.reload_time = config[2]
	weapon.effective_range = config[5]
	weapon.accuracy_base = config[6]
	return weapon


## Generates a random positive distance for firing tests.
func _generate_random_distance() -> float:
	# Random distance between 0 and 200 meters
	return randf() * 200.0


## Property: Firing with an empty magazine produces zero damage.
## For any weapon configuration with 0 rounds, attempt_fire must return 0.0.
func test_property_empty_magazine_produces_no_damage() -> void:
	seed(12345)
	for i in range(ITERATIONS):
		var weapon_data := _generate_random_weapon()
		var instance := WeaponInstance.create(weapon_data, false)  # Start with empty magazine
		var distance := _generate_random_distance()

		var damage := instance.attempt_fire(distance)

		assert_eq(damage, 0.0,
			"Iteration %d: Firing with empty magazine should produce 0 damage. " % i +
			"Category: %s, Rarity: %s, Distance: %.1f" % [
				_category_name(weapon_data.category),
				_rarity_name(weapon_data.rarity),
				distance
			])


## Property: Firing with an empty magazine triggers a reload prompt.
## For any weapon configuration with 0 rounds, attempt_fire must set reload_prompt_triggered.
func test_property_empty_magazine_triggers_reload_prompt() -> void:
	seed(23456)
	for i in range(ITERATIONS):
		var weapon_data := _generate_random_weapon()
		var instance := WeaponInstance.create(weapon_data, false)  # Start with empty magazine
		var distance := _generate_random_distance()

		instance.attempt_fire(distance)

		assert_true(instance.reload_prompt_triggered,
			"Iteration %d: Firing with empty magazine should trigger reload prompt. " % i +
			"Category: %s, Rarity: %s" % [
				_category_name(weapon_data.category),
				_rarity_name(weapon_data.rarity)
			])


## Property: Weapon cannot fire during reload (before reload completes).
## For any weapon that starts reloading, attempt_fire must return 0 damage
## until the full reload duration has elapsed.
func test_property_weapon_blocked_during_reload() -> void:
	seed(34567)
	for i in range(ITERATIONS):
		var weapon_data := _generate_random_weapon()
		var instance := WeaponInstance.create(weapon_data, false)  # Start with empty magazine
		var distance := _generate_random_distance()

		# Start reload
		instance.start_reload()
		assert_true(instance.is_reloading,
			"Iteration %d: Weapon should be in reloading state after start_reload." % i)

		# Advance reload partially (random fraction less than full duration)
		var partial_time := weapon_data.reload_time * randf() * 0.9  # 0-90% of reload time
		instance.update_reload(partial_time)

		# Attempt to fire during reload - should produce no damage
		var damage := instance.attempt_fire(distance)
		assert_eq(damage, 0.0,
			"Iteration %d: Firing during reload should produce 0 damage. " % i +
			"Category: %s, Reload time: %.1fs, Elapsed: %.1fs" % [
				_category_name(weapon_data.category),
				weapon_data.reload_time,
				partial_time
			])


## Property: After reload completes with correct duration, weapon can fire again.
## For any weapon category, after waiting the full reload_time, the weapon
## must have a full magazine and be able to deal damage.
func test_property_weapon_fires_after_full_reload() -> void:
	seed(45678)
	for i in range(ITERATIONS):
		var weapon_data := _generate_random_weapon()
		var instance := WeaponInstance.create(weapon_data, false)  # Start with empty magazine
		# Use a distance within effective range to guarantee non-zero damage
		var distance := randf() * weapon_data.effective_range

		# Start reload
		instance.start_reload()

		# Complete the full reload duration
		instance.update_reload(weapon_data.reload_time)

		# Verify reload completed
		assert_false(instance.is_reloading,
			"Iteration %d: Weapon should not be reloading after full duration. " % i +
			"Category: %s, Reload time: %.1fs" % [
				_category_name(weapon_data.category),
				weapon_data.reload_time
			])

		# Verify magazine is full
		assert_eq(instance.current_ammo, weapon_data.magazine_size,
			"Iteration %d: Magazine should be full after reload. " % i +
			"Expected: %d, Got: %d" % [weapon_data.magazine_size, instance.current_ammo])

		# Verify weapon can now fire and deal damage
		var damage := instance.attempt_fire(distance)
		assert_gt(damage, 0.0,
			"Iteration %d: Weapon should deal damage after reload completes. " % i +
			"Category: %s, Distance: %.1f (effective range: %.1f)" % [
				_category_name(weapon_data.category),
				distance,
				weapon_data.effective_range
			])


## Property: Reload duration matches the weapon category's configured reload_time.
## For any weapon, the reload_timer when reload starts must equal the weapon's reload_time,
## and the reload must not complete before that duration has fully elapsed.
func test_property_reload_duration_matches_category() -> void:
	seed(56789)
	for i in range(ITERATIONS):
		var weapon_data := _generate_random_weapon()
		var instance := WeaponInstance.create(weapon_data, false)  # Start with empty magazine

		# Start reload and verify timer is set to correct duration
		instance.start_reload()
		assert_almost_eq(instance.reload_timer, weapon_data.reload_time, 0.001,
			"Iteration %d: Reload timer should equal weapon reload_time. " % i +
			"Category: %s, Expected: %.1fs, Got: %.1fs" % [
				_category_name(weapon_data.category),
				weapon_data.reload_time,
				instance.reload_timer
			])

		# Advance by slightly less than full duration - should still be reloading
		var almost_done := weapon_data.reload_time - 0.01
		if almost_done > 0.0:
			instance.update_reload(almost_done)
			assert_true(instance.is_reloading,
				"Iteration %d: Weapon should still be reloading before full duration. " % i +
				"Category: %s, Reload time: %.1fs, Elapsed: %.3fs" % [
					_category_name(weapon_data.category),
					weapon_data.reload_time,
					almost_done
				])


## Property: Multiple fire attempts on empty magazine all produce zero damage.
## For any weapon with 0 rounds, repeated fire attempts must all return 0.
func test_property_repeated_fire_attempts_on_empty_all_blocked() -> void:
	seed(67890)
	for i in range(ITERATIONS):
		var weapon_data := _generate_random_weapon()
		var instance := WeaponInstance.create(weapon_data, false)  # Start with empty magazine

		# Attempt to fire multiple times (random 2-10 attempts)
		var attempts := (randi() % 9) + 2
		for j in range(attempts):
			var distance := _generate_random_distance()
			var damage := instance.attempt_fire(distance)
			assert_eq(damage, 0.0,
				"Iteration %d, attempt %d: Repeated fire on empty magazine should produce 0 damage. " % [i, j] +
				"Category: %s" % _category_name(weapon_data.category))
			assert_true(instance.reload_prompt_triggered,
				"Iteration %d, attempt %d: Each fire attempt on empty should trigger reload prompt." % [i, j])


# --- Helper functions ---

func _category_name(category: Enums.WeaponCategory) -> String:
	match category:
		Enums.WeaponCategory.AR:
			return "AR"
		Enums.WeaponCategory.SHOTGUN:
			return "SHOTGUN"
		Enums.WeaponCategory.SMG:
			return "SMG"
		Enums.WeaponCategory.SNIPER:
			return "SNIPER"
		Enums.WeaponCategory.PISTOL:
			return "PISTOL"
		_:
			return "UNKNOWN"


func _rarity_name(rarity: Enums.RarityTier) -> String:
	match rarity:
		Enums.RarityTier.COMMON:
			return "COMMON"
		Enums.RarityTier.UNCOMMON:
			return "UNCOMMON"
		Enums.RarityTier.RARE:
			return "RARE"
		Enums.RarityTier.EPIC:
			return "EPIC"
		Enums.RarityTier.LEGENDARY:
			return "LEGENDARY"
		_:
			return "UNKNOWN"
