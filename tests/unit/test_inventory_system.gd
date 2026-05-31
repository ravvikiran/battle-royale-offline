## Unit tests for InventorySystem weapon management, consumable handling, and healing logic.
extends GutTest


var _inventory: InventorySystem
var _ar_weapon: WeaponData
var _shotgun_weapon: WeaponData
var _smg_weapon: WeaponData
var _sniper_weapon: WeaponData
var _pistol_weapon: WeaponData
var _extra_weapon: WeaponData


func before_each() -> void:
	_inventory = InventorySystem.new()

	_ar_weapon = WeaponData.new()
	_ar_weapon.category = Enums.WeaponCategory.AR
	_ar_weapon.name = "Volt Repeater"
	_ar_weapon.rarity = Enums.RarityTier.COMMON
	_ar_weapon.base_damage = 30.0
	_ar_weapon.fire_rate = 5.0
	_ar_weapon.magazine_size = 30
	_ar_weapon.reload_time = 2.0
	_ar_weapon.effective_range = 50.0
	_ar_weapon.accuracy_base = 0.75

	_shotgun_weapon = WeaponData.new()
	_shotgun_weapon.category = Enums.WeaponCategory.SHOTGUN
	_shotgun_weapon.name = "Boomstick"
	_shotgun_weapon.rarity = Enums.RarityTier.UNCOMMON
	_shotgun_weapon.base_damage = 90.0
	_shotgun_weapon.fire_rate = 1.0
	_shotgun_weapon.magazine_size = 5
	_shotgun_weapon.reload_time = 4.0
	_shotgun_weapon.effective_range = 10.0
	_shotgun_weapon.accuracy_base = 0.60

	_smg_weapon = WeaponData.new()
	_smg_weapon.category = Enums.WeaponCategory.SMG
	_smg_weapon.name = "Buzzer"
	_smg_weapon.rarity = Enums.RarityTier.RARE
	_smg_weapon.base_damage = 18.0
	_smg_weapon.fire_rate = 8.0
	_smg_weapon.magazine_size = 25
	_smg_weapon.reload_time = 1.5
	_smg_weapon.effective_range = 30.0
	_smg_weapon.accuracy_base = 0.65

	_sniper_weapon = WeaponData.new()
	_sniper_weapon.category = Enums.WeaponCategory.SNIPER
	_sniper_weapon.name = "Longshot"
	_sniper_weapon.rarity = Enums.RarityTier.EPIC
	_sniper_weapon.base_damage = 100.0
	_sniper_weapon.fire_rate = 0.5
	_sniper_weapon.magazine_size = 5
	_sniper_weapon.reload_time = 3.0
	_sniper_weapon.effective_range = 150.0
	_sniper_weapon.accuracy_base = 0.90

	_pistol_weapon = WeaponData.new()
	_pistol_weapon.category = Enums.WeaponCategory.PISTOL
	_pistol_weapon.name = "Sideswipe"
	_pistol_weapon.rarity = Enums.RarityTier.LEGENDARY
	_pistol_weapon.base_damage = 24.0
	_pistol_weapon.fire_rate = 3.0
	_pistol_weapon.magazine_size = 12
	_pistol_weapon.reload_time = 1.0
	_pistol_weapon.effective_range = 35.0
	_pistol_weapon.accuracy_base = 0.70

	_extra_weapon = WeaponData.new()
	_extra_weapon.category = Enums.WeaponCategory.AR
	_extra_weapon.name = "Extra Gun"
	_extra_weapon.rarity = Enums.RarityTier.COMMON
	_extra_weapon.base_damage = 25.0
	_extra_weapon.fire_rate = 4.0
	_extra_weapon.magazine_size = 20
	_extra_weapon.reload_time = 2.5
	_extra_weapon.effective_range = 45.0
	_extra_weapon.accuracy_base = 0.70


# --- Weapon slot tests ---

func test_add_weapon_to_empty_inventory() -> void:
	var result := _inventory.add_weapon(_ar_weapon)
	assert_eq(result, OK, "Adding weapon to empty inventory should succeed")
	assert_eq(_inventory.get_weapon_count(), 1)


func test_add_weapon_fills_first_available_slot() -> void:
	_inventory.add_weapon(_ar_weapon)
	assert_eq(_inventory.weapon_slots[0], _ar_weapon)


func test_add_five_weapons_fills_inventory() -> void:
	assert_eq(_inventory.add_weapon(_ar_weapon), OK)
	assert_eq(_inventory.add_weapon(_shotgun_weapon), OK)
	assert_eq(_inventory.add_weapon(_smg_weapon), OK)
	assert_eq(_inventory.add_weapon(_sniper_weapon), OK)
	assert_eq(_inventory.add_weapon(_pistol_weapon), OK)
	assert_eq(_inventory.get_weapon_count(), 5)


func test_add_weapon_at_capacity_returns_error() -> void:
	_inventory.add_weapon(_ar_weapon)
	_inventory.add_weapon(_shotgun_weapon)
	_inventory.add_weapon(_smg_weapon)
	_inventory.add_weapon(_sniper_weapon)
	_inventory.add_weapon(_pistol_weapon)
	var result := _inventory.add_weapon(_extra_weapon)
	assert_eq(result, ERR_CANT_ACQUIRE, "Adding 6th weapon should fail")
	assert_eq(_inventory.get_weapon_count(), 5, "Weapon count should remain 5")


func test_swap_weapon_returns_old_weapon() -> void:
	_inventory.add_weapon(_ar_weapon)
	var old := _inventory.swap_weapon(0, _shotgun_weapon)
	assert_eq(old, _ar_weapon, "Swap should return the old weapon")
	assert_eq(_inventory.weapon_slots[0], _shotgun_weapon, "Slot should contain new weapon")


func test_swap_weapon_empty_slot_returns_null() -> void:
	var old := _inventory.swap_weapon(0, _ar_weapon)
	assert_null(old, "Swapping into empty slot should return null")
	assert_eq(_inventory.weapon_slots[0], _ar_weapon)


func test_swap_weapon_invalid_slot_returns_null() -> void:
	var old := _inventory.swap_weapon(-1, _ar_weapon)
	assert_null(old)
	old = _inventory.swap_weapon(5, _ar_weapon)
	assert_null(old)


func test_remove_weapon_returns_weapon() -> void:
	_inventory.add_weapon(_ar_weapon)
	var removed := _inventory.remove_weapon(0)
	assert_eq(removed, _ar_weapon)
	assert_null(_inventory.weapon_slots[0])
	assert_eq(_inventory.get_weapon_count(), 0)


func test_remove_weapon_empty_slot_returns_null() -> void:
	var removed := _inventory.remove_weapon(0)
	assert_null(removed)


func test_remove_weapon_invalid_slot_returns_null() -> void:
	assert_null(_inventory.remove_weapon(-1))
	assert_null(_inventory.remove_weapon(5))


func test_get_active_weapon_default_slot_zero() -> void:
	_inventory.add_weapon(_ar_weapon)
	assert_eq(_inventory.get_active_weapon(), _ar_weapon)


func test_get_active_weapon_empty_returns_null() -> void:
	assert_null(_inventory.get_active_weapon())


func test_get_active_weapon_after_index_change() -> void:
	_inventory.add_weapon(_ar_weapon)
	_inventory.add_weapon(_shotgun_weapon)
	_inventory.active_weapon_index = 1
	assert_eq(_inventory.get_active_weapon(), _shotgun_weapon)


func test_has_weapon_space_when_empty() -> void:
	assert_true(_inventory.has_weapon_space())


func test_has_weapon_space_when_full() -> void:
	_inventory.add_weapon(_ar_weapon)
	_inventory.add_weapon(_shotgun_weapon)
	_inventory.add_weapon(_smg_weapon)
	_inventory.add_weapon(_sniper_weapon)
	_inventory.add_weapon(_pistol_weapon)
	assert_false(_inventory.has_weapon_space())


# --- Consumable slot tests ---

func test_add_consumable_bandage() -> void:
	var result := _inventory.add_consumable(Enums.ConsumableType.BANDAGE, 3)
	assert_eq(result, OK)
	assert_eq(_inventory.get_consumable_count(Enums.ConsumableType.BANDAGE), 3)


func test_add_consumable_bandage_at_max_stack() -> void:
	_inventory.add_consumable(Enums.ConsumableType.BANDAGE, 5)
	var result := _inventory.add_consumable(Enums.ConsumableType.BANDAGE, 1)
	assert_eq(result, ERR_CANT_ACQUIRE, "Adding beyond max stack should fail")
	assert_eq(_inventory.get_consumable_count(Enums.ConsumableType.BANDAGE), 5)


func test_add_consumable_medkit_max_3() -> void:
	assert_eq(_inventory.add_consumable(Enums.ConsumableType.MEDKIT, 3), OK)
	assert_eq(_inventory.add_consumable(Enums.ConsumableType.MEDKIT, 1), ERR_CANT_ACQUIRE)
	assert_eq(_inventory.get_consumable_count(Enums.ConsumableType.MEDKIT), 3)


func test_add_consumable_shield_potion_max_3() -> void:
	assert_eq(_inventory.add_consumable(Enums.ConsumableType.SHIELD_POTION, 3), OK)
	assert_eq(_inventory.add_consumable(Enums.ConsumableType.SHIELD_POTION, 1), ERR_CANT_ACQUIRE)
	assert_eq(_inventory.get_consumable_count(Enums.ConsumableType.SHIELD_POTION), 3)


func test_add_consumable_zero_count_succeeds() -> void:
	var result := _inventory.add_consumable(Enums.ConsumableType.BANDAGE, 0)
	assert_eq(result, OK)
	assert_eq(_inventory.get_consumable_count(Enums.ConsumableType.BANDAGE), 0)


func test_can_add_consumable_true_when_space() -> void:
	assert_true(_inventory.can_add_consumable(Enums.ConsumableType.BANDAGE, 5))


func test_can_add_consumable_false_when_full() -> void:
	_inventory.add_consumable(Enums.ConsumableType.BANDAGE, 5)
	assert_false(_inventory.can_add_consumable(Enums.ConsumableType.BANDAGE, 1))


# --- Healing logic tests ---

func test_use_bandage_heals_25_hp() -> void:
	_inventory.current_health = 50.0
	_inventory.add_consumable(Enums.ConsumableType.BANDAGE, 1)
	var use_result := _inventory.use_consumable(Enums.ConsumableType.BANDAGE)
	assert_true(use_result["success"])
	var heal_result := _inventory.complete_healing()
	assert_true(heal_result["success"])
	assert_almost_eq(_inventory.current_health, 75.0, 0.001)


func test_use_bandage_capped_at_75() -> void:
	_inventory.current_health = 60.0
	_inventory.add_consumable(Enums.ConsumableType.BANDAGE, 1)
	_inventory.use_consumable(Enums.ConsumableType.BANDAGE)
	_inventory.complete_healing()
	assert_almost_eq(_inventory.current_health, 75.0, 0.001, "Bandage should cap at 75 HP")


func test_use_bandage_blocked_at_75_health() -> void:
	_inventory.current_health = 75.0
	_inventory.add_consumable(Enums.ConsumableType.BANDAGE, 1)
	var result := _inventory.use_consumable(Enums.ConsumableType.BANDAGE)
	assert_false(result["success"])
	assert_eq(result["error"], "health_at_cap")
	assert_eq(_inventory.get_consumable_count(Enums.ConsumableType.BANDAGE), 1, "Item should not be consumed")


func test_use_bandage_blocked_above_75_health() -> void:
	_inventory.current_health = 90.0
	_inventory.add_consumable(Enums.ConsumableType.BANDAGE, 1)
	var result := _inventory.use_consumable(Enums.ConsumableType.BANDAGE)
	assert_false(result["success"])
	assert_eq(result["error"], "health_at_cap")


func test_use_medkit_full_heal() -> void:
	_inventory.current_health = 10.0
	_inventory.add_consumable(Enums.ConsumableType.MEDKIT, 1)
	_inventory.use_consumable(Enums.ConsumableType.MEDKIT)
	_inventory.complete_healing()
	assert_almost_eq(_inventory.current_health, 100.0, 0.001, "Medkit should fully heal to 100")


func test_use_medkit_at_full_health() -> void:
	_inventory.current_health = 100.0
	_inventory.add_consumable(Enums.ConsumableType.MEDKIT, 1)
	var result := _inventory.use_consumable(Enums.ConsumableType.MEDKIT)
	assert_true(result["success"], "Medkit should be usable even at full health")
	_inventory.complete_healing()
	assert_almost_eq(_inventory.current_health, 100.0, 0.001)


func test_use_shield_potion_adds_50_shield() -> void:
	_inventory.current_shield = 0.0
	_inventory.add_consumable(Enums.ConsumableType.SHIELD_POTION, 1)
	_inventory.use_consumable(Enums.ConsumableType.SHIELD_POTION)
	_inventory.complete_healing()
	assert_almost_eq(_inventory.current_shield, 50.0, 0.001)


func test_use_shield_potion_capped_at_100() -> void:
	_inventory.current_shield = 70.0
	_inventory.add_consumable(Enums.ConsumableType.SHIELD_POTION, 1)
	_inventory.use_consumable(Enums.ConsumableType.SHIELD_POTION)
	_inventory.complete_healing()
	assert_almost_eq(_inventory.current_shield, 100.0, 0.001, "Shield should cap at 100")


func test_use_consumable_no_item_fails() -> void:
	var result := _inventory.use_consumable(Enums.ConsumableType.BANDAGE)
	assert_false(result["success"])
	assert_eq(result["error"], "no_item")


func test_use_consumable_decrements_count() -> void:
	_inventory.current_health = 50.0
	_inventory.add_consumable(Enums.ConsumableType.BANDAGE, 3)
	_inventory.use_consumable(Enums.ConsumableType.BANDAGE)
	assert_eq(_inventory.get_consumable_count(Enums.ConsumableType.BANDAGE), 2)


# --- Healing interruption tests ---

func test_cancel_healing_consumes_item_no_heal() -> void:
	_inventory.current_health = 50.0
	_inventory.add_consumable(Enums.ConsumableType.BANDAGE, 2)
	_inventory.use_consumable(Enums.ConsumableType.BANDAGE)
	var cancelled := _inventory.cancel_healing()
	assert_true(cancelled, "Cancel should return true when healing was in progress")
	assert_almost_eq(_inventory.current_health, 50.0, 0.001, "Health should not change on cancel")
	assert_eq(_inventory.get_consumable_count(Enums.ConsumableType.BANDAGE), 1, "Item should be consumed")


func test_cancel_healing_medkit_no_heal() -> void:
	_inventory.current_health = 30.0
	_inventory.add_consumable(Enums.ConsumableType.MEDKIT, 1)
	_inventory.use_consumable(Enums.ConsumableType.MEDKIT)
	_inventory.cancel_healing()
	assert_almost_eq(_inventory.current_health, 30.0, 0.001, "Health should not change on cancel")
	assert_eq(_inventory.get_consumable_count(Enums.ConsumableType.MEDKIT), 0, "Medkit consumed")


func test_cancel_healing_shield_potion_no_heal() -> void:
	_inventory.current_shield = 20.0
	_inventory.add_consumable(Enums.ConsumableType.SHIELD_POTION, 1)
	_inventory.use_consumable(Enums.ConsumableType.SHIELD_POTION)
	_inventory.cancel_healing()
	assert_almost_eq(_inventory.current_shield, 20.0, 0.001, "Shield should not change on cancel")
	assert_eq(_inventory.get_consumable_count(Enums.ConsumableType.SHIELD_POTION), 0, "Potion consumed")


func test_cancel_healing_when_not_healing_returns_false() -> void:
	var cancelled := _inventory.cancel_healing()
	assert_false(cancelled)


func test_cannot_use_two_consumables_simultaneously() -> void:
	_inventory.current_health = 50.0
	_inventory.add_consumable(Enums.ConsumableType.BANDAGE, 2)
	_inventory.use_consumable(Enums.ConsumableType.BANDAGE)
	var result := _inventory.use_consumable(Enums.ConsumableType.BANDAGE)
	assert_false(result["success"])
	assert_eq(result["error"], "already_healing")


func test_complete_healing_when_not_healing_fails() -> void:
	var result := _inventory.complete_healing()
	assert_false(result["success"])
	assert_eq(result["error"], "not_healing")
