## Manages the player's inventory including weapon slots and consumable items.
## Handles weapon pickup/swap/removal and consumable usage with healing logic.
class_name InventorySystem
extends RefCounted


## Maximum number of weapon slots available.
const MAX_WEAPON_SLOTS: int = 5

## Maximum number of consumable stack types.
const MAX_CONSUMABLE_SLOTS: int = 3

## Stack limits per consumable type.
const STACK_LIMITS: Dictionary = {
	Enums.ConsumableType.BANDAGE: 5,
	Enums.ConsumableType.MEDKIT: 3,
	Enums.ConsumableType.SHIELD_POTION: 3,
}

## Healing amounts per consumable type.
const HEAL_AMOUNTS: Dictionary = {
	Enums.ConsumableType.BANDAGE: 25,
	Enums.ConsumableType.MEDKIT: 100,
	Enums.ConsumableType.SHIELD_POTION: 50,
}

## Healing caps per consumable type.
const HEAL_CAPS: Dictionary = {
	Enums.ConsumableType.BANDAGE: 75,
	Enums.ConsumableType.MEDKIT: 100,
	Enums.ConsumableType.SHIELD_POTION: 100,
}

## Use time in seconds per consumable type.
const USE_TIMES: Dictionary = {
	Enums.ConsumableType.BANDAGE: 3.0,
	Enums.ConsumableType.MEDKIT: 8.0,
	Enums.ConsumableType.SHIELD_POTION: 4.0,
}


## Array of weapon slots (nullable entries). Null means empty slot.
var weapon_slots: Array = []

## Dictionary mapping ConsumableType to current stack count.
var consumable_slots: Dictionary = {}

## Index of the currently active weapon (0-based).
var active_weapon_index: int = 0

## Current player health (used for healing logic).
var current_health: float = 100.0

## Current player shield (used for healing logic).
var current_shield: float = 0.0

## Whether a healing action is currently in progress.
var is_healing: bool = false

## The consumable type currently being used (if healing).
var _healing_type: Enums.ConsumableType = Enums.ConsumableType.BANDAGE

## Remaining time for the current healing action.
var _healing_time_remaining: float = 0.0


func _init() -> void:
	weapon_slots.resize(MAX_WEAPON_SLOTS)
	for i in range(MAX_WEAPON_SLOTS):
		weapon_slots[i] = null
	consumable_slots = {
		Enums.ConsumableType.BANDAGE: 0,
		Enums.ConsumableType.MEDKIT: 0,
		Enums.ConsumableType.SHIELD_POTION: 0,
	}


## Adds a weapon to the first available slot.
## Returns OK on success, FAILED if inventory is full.
func add_weapon(weapon: WeaponData) -> int:
	for i in range(MAX_WEAPON_SLOTS):
		if weapon_slots[i] == null:
			weapon_slots[i] = weapon
			return OK
	return FAILED


## Swaps the weapon at the given slot with a new weapon.
## Returns the old weapon that was in the slot, or null if slot was empty.
func swap_weapon(slot: int, new_weapon: WeaponData) -> WeaponData:
	if slot < 0 or slot >= MAX_WEAPON_SLOTS:
		return null
	var old_weapon: WeaponData = weapon_slots[slot]
	weapon_slots[slot] = new_weapon
	return old_weapon


## Removes and returns the weapon at the given slot.
## Returns null if the slot is empty or index is invalid.
func remove_weapon(slot: int) -> WeaponData:
	if slot < 0 or slot >= MAX_WEAPON_SLOTS:
		return null
	var weapon: WeaponData = weapon_slots[slot]
	weapon_slots[slot] = null
	return weapon


## Returns the currently active weapon, or null if the active slot is empty.
func get_active_weapon() -> WeaponData:
	if active_weapon_index < 0 or active_weapon_index >= MAX_WEAPON_SLOTS:
		return null
	return weapon_slots[active_weapon_index]


## Returns the number of weapons currently held.
func get_weapon_count() -> int:
	var count: int = 0
	for weapon in weapon_slots:
		if weapon != null:
			count += 1
	return count


## Adds consumable items of the given type.
## Returns OK on success, FAILED if adding would exceed stack limit.
func add_consumable(type: Enums.ConsumableType, count: int) -> int:
	if count <= 0:
		return OK
	var max_stack: int = STACK_LIMITS[type]
	var current_count: int = consumable_slots.get(type, 0)
	if current_count + count > max_stack:
		return FAILED
	consumable_slots[type] = current_count + count
	return OK


## Returns the current count of a consumable type.
func get_consumable_count(type: Enums.ConsumableType) -> int:
	return consumable_slots.get(type, 0)


## Attempts to use a consumable item. Starts the healing process.
## Returns a Dictionary with "success" (bool) and optionally "error" (String).
## The actual healing is applied when complete_healing() is called after the use time.
func use_consumable(type: Enums.ConsumableType) -> Dictionary:
	# Check if we have the consumable
	var count: int = consumable_slots.get(type, 0)
	if count <= 0:
		return {"success": false, "error": "no_item"}

	# Check bandage cap restriction
	if type == Enums.ConsumableType.BANDAGE and current_health >= 75.0:
		return {"success": false, "error": "health_at_cap"}

	# Already healing
	if is_healing:
		return {"success": false, "error": "already_healing"}

	# Consume the item immediately
	consumable_slots[type] = count - 1

	# Start healing process
	is_healing = true
	_healing_type = type
	_healing_time_remaining = USE_TIMES[type]

	return {"success": true, "type": type, "use_time": USE_TIMES[type]}


## Completes the healing action, applying the heal effect.
## Should be called when the healing timer finishes without interruption.
## Returns a Dictionary with the healing result.
func complete_healing() -> Dictionary:
	if not is_healing:
		return {"success": false, "error": "not_healing"}

	is_healing = false
	var type: Enums.ConsumableType = _healing_type
	var heal_amount: int = HEAL_AMOUNTS[type]
	var heal_cap: float = float(HEAL_CAPS[type])

	var result: Dictionary = {"success": true, "type": type}

	match type:
		Enums.ConsumableType.BANDAGE:
			var old_health := current_health
			current_health = min(current_health + heal_amount, heal_cap)
			result["healed"] = current_health - old_health
			result["target"] = "health"
		Enums.ConsumableType.MEDKIT:
			var old_health := current_health
			current_health = heal_cap  # Full heal to 100
			result["healed"] = current_health - old_health
			result["target"] = "health"
		Enums.ConsumableType.SHIELD_POTION:
			var old_shield := current_shield
			current_shield = min(current_shield + heal_amount, heal_cap)
			result["healed"] = current_shield - old_shield
			result["target"] = "shield"

	return result


## Cancels the current healing action.
## The consumable is already consumed (on use_consumable call) but no healing is applied.
## Returns true if a healing was cancelled, false if no healing was in progress.
func cancel_healing() -> bool:
	if not is_healing:
		return false
	is_healing = false
	_healing_time_remaining = 0.0
	# Item was already consumed in use_consumable(), no healing applied
	return true


## Returns whether the inventory has any empty weapon slots.
func has_weapon_space() -> bool:
	for weapon in weapon_slots:
		if weapon == null:
			return true
	return false


## Returns whether a consumable type can accept more items.
func can_add_consumable(type: Enums.ConsumableType, count: int = 1) -> bool:
	var max_stack: int = STACK_LIMITS[type]
	var current_count: int = consumable_slots.get(type, 0)
	return current_count + count <= max_stack
