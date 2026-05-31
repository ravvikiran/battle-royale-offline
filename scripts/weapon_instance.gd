## Runtime instance of a weapon tracking magazine state, reload status, and firing.
## Wraps a WeaponData resource with mutable state for gameplay use.
class_name WeaponInstance
extends RefCounted


## The static weapon data (category, damage, fire rate, magazine size, reload time, etc.)
var weapon_data: WeaponData

## Current rounds remaining in the magazine.
var current_ammo: int = 0

## Whether the weapon is currently in a reload cycle.
var is_reloading: bool = false

## Time remaining on the current reload (seconds). Zero when not reloading.
var reload_timer: float = 0.0

## Whether a reload prompt was triggered on the last fire attempt.
var reload_prompt_triggered: bool = false


## Creates a WeaponInstance from a WeaponData resource.
## Starts with a full magazine by default.
static func create(data: WeaponData, start_full: bool = true) -> WeaponInstance:
	var instance := WeaponInstance.new()
	instance.weapon_data = data
	if start_full:
		instance.current_ammo = data.magazine_size
	else:
		instance.current_ammo = 0
	instance.is_reloading = false
	instance.reload_timer = 0.0
	instance.reload_prompt_triggered = false
	return instance


## Attempts to fire the weapon. Returns the damage dealt (0.0 if firing is blocked).
## If the magazine is empty, triggers a reload prompt and returns 0.0.
## If the weapon is currently reloading, returns 0.0.
func attempt_fire(distance: float) -> float:
	reload_prompt_triggered = false

	# Cannot fire while reloading
	if is_reloading:
		return 0.0

	# Empty magazine blocks firing and triggers reload prompt
	if current_ammo <= 0:
		reload_prompt_triggered = true
		return 0.0

	# Fire: consume one round and calculate damage
	current_ammo -= 1
	return WeaponSystem.calculate_damage(weapon_data, distance)


## Starts the reload process. Sets is_reloading to true and reload_timer
## to the weapon's reload_time. Does nothing if already reloading or magazine is full.
func start_reload() -> void:
	if is_reloading:
		return
	if current_ammo >= weapon_data.magazine_size:
		return
	is_reloading = true
	reload_timer = weapon_data.reload_time


## Advances the reload timer by delta seconds. When the timer reaches zero,
## the magazine is refilled and is_reloading is set to false.
func update_reload(delta: float) -> void:
	if not is_reloading:
		return
	reload_timer -= delta
	if reload_timer <= 0.0:
		reload_timer = 0.0
		is_reloading = false
		current_ammo = weapon_data.magazine_size


## Returns true if the magazine is empty (0 rounds).
func is_magazine_empty() -> bool:
	return current_ammo <= 0


## Returns the reload time for this weapon's category.
func get_reload_duration() -> float:
	return weapon_data.reload_time
