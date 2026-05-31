## Weapon system providing weapon data resources and damage/accuracy calculations.
## Handles rarity modifiers, distance falloff, and accuracy bonuses.
class_name WeaponSystem
extends RefCounted


## Rarity damage multiplier: 10% increase per tier above Common.
const RARITY_DAMAGE_MULTIPLIER: float = 0.10

## Rarity accuracy bonus: 5% increase per tier above Common.
const RARITY_ACCURACY_BONUS: float = 0.05

## Damage falls to zero at 2× effective range.
const DAMAGE_FALLOFF_ZERO_MULTIPLIER: float = 2.0


## Calculates final damage for a weapon at a given distance.
## Applies rarity modifier to base damage, then applies distance falloff:
## - Full damage at distance <= effective_range
## - Linear falloff from 100% to 50% between effective_range and 2× effective_range
## - Zero damage beyond 2× effective_range
static func calculate_damage(weapon: WeaponData, distance: float) -> float:
	var effective_range := weapon.effective_range
	var max_range := effective_range * DAMAGE_FALLOFF_ZERO_MULTIPLIER

	# Apply rarity modifier to base damage
	var modified_damage := apply_rarity_modifier(weapon.base_damage, weapon.rarity)

	# No damage beyond 2× effective range
	if distance > max_range:
		return 0.0

	# Full damage within effective range
	if distance <= effective_range:
		return modified_damage

	# Linear falloff from 100% to 50% between effective_range and 2× effective_range
	var falloff_progress := (distance - effective_range) / (max_range - effective_range)
	var damage_multiplier := 1.0 - (falloff_progress * 0.5)
	return modified_damage * damage_multiplier


## Applies rarity modifier to a base value.
## Returns base * (1 + 0.10 * rarity_index)
## Rarity indices: COMMON=0, UNCOMMON=1, RARE=2, EPIC=3, LEGENDARY=4
static func apply_rarity_modifier(base: float, rarity: Enums.RarityTier) -> float:
	var rarity_index := int(rarity)
	return base * (1.0 + RARITY_DAMAGE_MULTIPLIER * rarity_index)


## Returns the accuracy for a weapon at a given rarity tier.
## Adds 5% bonus per tier above Common to the weapon's base accuracy.
static func get_accuracy(weapon: WeaponData, rarity: Enums.RarityTier) -> float:
	var rarity_index := int(rarity)
	return weapon.accuracy_base + (RARITY_ACCURACY_BONUS * rarity_index)
