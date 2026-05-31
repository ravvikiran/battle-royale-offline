## Unit tests for WeaponSystem damage calculation, rarity modifiers, and accuracy.
extends GutTest


var _ar_weapon: WeaponData
var _shotgun_weapon: WeaponData
var _sniper_weapon: WeaponData


func before_each() -> void:
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
	_shotgun_weapon.rarity = Enums.RarityTier.COMMON
	_shotgun_weapon.base_damage = 90.0
	_shotgun_weapon.fire_rate = 1.0
	_shotgun_weapon.magazine_size = 5
	_shotgun_weapon.reload_time = 4.0
	_shotgun_weapon.effective_range = 10.0
	_shotgun_weapon.accuracy_base = 0.60

	_sniper_weapon = WeaponData.new()
	_sniper_weapon.category = Enums.WeaponCategory.SNIPER
	_sniper_weapon.name = "Longshot"
	_sniper_weapon.rarity = Enums.RarityTier.COMMON
	_sniper_weapon.base_damage = 100.0
	_sniper_weapon.fire_rate = 0.5
	_sniper_weapon.magazine_size = 5
	_sniper_weapon.reload_time = 3.0
	_sniper_weapon.effective_range = 150.0
	_sniper_weapon.accuracy_base = 0.90


# --- apply_rarity_modifier tests ---

func test_rarity_modifier_common_returns_base() -> void:
	var result := WeaponSystem.apply_rarity_modifier(30.0, Enums.RarityTier.COMMON)
	assert_almost_eq(result, 30.0, 0.001, "Common rarity should return base damage unchanged")


func test_rarity_modifier_uncommon_adds_10_percent() -> void:
	var result := WeaponSystem.apply_rarity_modifier(30.0, Enums.RarityTier.UNCOMMON)
	assert_almost_eq(result, 33.0, 0.001, "Uncommon should add 10% to base")


func test_rarity_modifier_rare_adds_20_percent() -> void:
	var result := WeaponSystem.apply_rarity_modifier(30.0, Enums.RarityTier.RARE)
	assert_almost_eq(result, 36.0, 0.001, "Rare should add 20% to base")


func test_rarity_modifier_epic_adds_30_percent() -> void:
	var result := WeaponSystem.apply_rarity_modifier(30.0, Enums.RarityTier.EPIC)
	assert_almost_eq(result, 39.0, 0.001, "Epic should add 30% to base")


func test_rarity_modifier_legendary_adds_40_percent() -> void:
	var result := WeaponSystem.apply_rarity_modifier(30.0, Enums.RarityTier.LEGENDARY)
	assert_almost_eq(result, 42.0, 0.001, "Legendary should add 40% to base")


# --- calculate_damage tests ---

func test_damage_within_effective_range_full_damage() -> void:
	var result := WeaponSystem.calculate_damage(_ar_weapon, 25.0)
	# Common AR: 30 * (1 + 0.10 * 0) = 30.0
	assert_almost_eq(result, 30.0, 0.001, "Damage within effective range should be full modified damage")


func test_damage_at_effective_range_boundary_full_damage() -> void:
	var result := WeaponSystem.calculate_damage(_ar_weapon, 50.0)
	assert_almost_eq(result, 30.0, 0.001, "Damage at exactly effective range should be full")


func test_damage_at_1_5x_effective_range_is_75_percent() -> void:
	# At 1.5× effective range (75m for AR with 50m range), falloff_progress = 0.5
	# damage_multiplier = 1.0 - (0.5 * 0.5) = 0.75
	var result := WeaponSystem.calculate_damage(_ar_weapon, 75.0)
	assert_almost_eq(result, 22.5, 0.001, "Damage at 1.5x effective range should be 75% of modified damage")


func test_damage_at_2x_effective_range_is_50_percent() -> void:
	# At 2× effective range (100m for AR with 50m range), falloff_progress = 1.0
	# damage_multiplier = 1.0 - (1.0 * 0.5) = 0.5
	var result := WeaponSystem.calculate_damage(_ar_weapon, 100.0)
	assert_almost_eq(result, 15.0, 0.001, "Damage at 2x effective range should be 50% of modified damage")


func test_damage_beyond_2x_effective_range_is_zero() -> void:
	var result := WeaponSystem.calculate_damage(_ar_weapon, 101.0)
	assert_almost_eq(result, 0.0, 0.001, "Damage beyond 2x effective range should be zero")


func test_damage_at_zero_distance() -> void:
	var result := WeaponSystem.calculate_damage(_shotgun_weapon, 0.0)
	assert_almost_eq(result, 90.0, 0.001, "Damage at zero distance should be full modified damage")


func test_damage_with_legendary_rarity_within_range() -> void:
	_ar_weapon.rarity = Enums.RarityTier.LEGENDARY
	var result := WeaponSystem.calculate_damage(_ar_weapon, 25.0)
	# Legendary AR: 30 * (1 + 0.10 * 4) = 30 * 1.4 = 42.0
	assert_almost_eq(result, 42.0, 0.001, "Legendary weapon should deal 40% more base damage")


func test_damage_with_epic_rarity_at_falloff() -> void:
	_sniper_weapon.rarity = Enums.RarityTier.EPIC
	# Epic sniper: 100 * (1 + 0.10 * 3) = 130.0
	# At 225m (1.5× of 150m range): falloff_progress = 0.5, multiplier = 0.75
	var result := WeaponSystem.calculate_damage(_sniper_weapon, 225.0)
	assert_almost_eq(result, 97.5, 0.001, "Epic sniper at 1.5x range should deal 75% of modified damage")


# --- get_accuracy tests ---

func test_accuracy_common_returns_base() -> void:
	var result := WeaponSystem.get_accuracy(_ar_weapon, Enums.RarityTier.COMMON)
	assert_almost_eq(result, 0.75, 0.001, "Common accuracy should equal base accuracy")


func test_accuracy_uncommon_adds_5_percent() -> void:
	var result := WeaponSystem.get_accuracy(_ar_weapon, Enums.RarityTier.UNCOMMON)
	assert_almost_eq(result, 0.80, 0.001, "Uncommon should add 5% to base accuracy")


func test_accuracy_rare_adds_10_percent() -> void:
	var result := WeaponSystem.get_accuracy(_ar_weapon, Enums.RarityTier.RARE)
	assert_almost_eq(result, 0.85, 0.001, "Rare should add 10% to base accuracy")


func test_accuracy_epic_adds_15_percent() -> void:
	var result := WeaponSystem.get_accuracy(_ar_weapon, Enums.RarityTier.EPIC)
	assert_almost_eq(result, 0.90, 0.001, "Epic should add 15% to base accuracy")


func test_accuracy_legendary_adds_20_percent() -> void:
	var result := WeaponSystem.get_accuracy(_ar_weapon, Enums.RarityTier.LEGENDARY)
	assert_almost_eq(result, 0.95, 0.001, "Legendary should add 20% to base accuracy")


func test_accuracy_shotgun_legendary() -> void:
	var result := WeaponSystem.get_accuracy(_shotgun_weapon, Enums.RarityTier.LEGENDARY)
	# 0.60 + (0.05 * 4) = 0.80
	assert_almost_eq(result, 0.80, 0.001, "Legendary shotgun accuracy should be base + 20%")


# --- WeaponData.from_dict tests ---

func test_weapon_data_from_dict() -> void:
	var data := {
		"category": "AR",
		"name": "Volt Repeater",
		"base_damage": 30,
		"fire_rate_rps": 5,
		"magazine_size": 30,
		"reload_time_seconds": 2.0,
		"effective_range_meters": 50,
		"base_accuracy": 0.75
	}
	var weapon := WeaponData.from_dict(data, Enums.RarityTier.RARE)
	assert_eq(weapon.category, Enums.WeaponCategory.AR)
	assert_eq(weapon.name, "Volt Repeater")
	assert_eq(weapon.rarity, Enums.RarityTier.RARE)
	assert_almost_eq(weapon.base_damage, 30.0, 0.001)
	assert_almost_eq(weapon.fire_rate, 5.0, 0.001)
	assert_eq(weapon.magazine_size, 30)
	assert_almost_eq(weapon.reload_time, 2.0, 0.001)
	assert_almost_eq(weapon.effective_range, 50.0, 0.001)
	assert_almost_eq(weapon.accuracy_base, 0.75, 0.001)


func test_weapon_data_from_dict_unknown_category_defaults_to_ar() -> void:
	var data := {
		"category": "UNKNOWN",
		"name": "Mystery Gun",
		"base_damage": 50,
		"fire_rate_rps": 2,
		"magazine_size": 10,
		"reload_time_seconds": 1.5,
		"effective_range_meters": 40,
		"base_accuracy": 0.70
	}
	var weapon := WeaponData.from_dict(data)
	assert_eq(weapon.category, Enums.WeaponCategory.AR, "Unknown category should default to AR")
	assert_eq(weapon.rarity, Enums.RarityTier.COMMON, "Default rarity should be COMMON")
