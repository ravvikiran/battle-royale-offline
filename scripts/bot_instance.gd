## Represents a single bot entity with FSM-based decision making.
## Each bot has health, shield, inventory, and difficulty-based parameters
## that determine reaction time and accuracy.
class_name BotInstance
extends RefCounted


## Unique identifier for this bot.
var id: int = 0

## Current FSM state.
var state: Enums.BotState = Enums.BotState.LOOTING

## Current health (0-100).
var health: float = 100.0

## Current shield (0-100).
var shield: float = 0.0

## Whether the bot is alive.
var is_alive: bool = true

## Current position in the game world (2D for zone calculations).
var position: Vector2 = Vector2.ZERO

## Current movement direction (normalized).
var movement_direction: Vector2 = Vector2.ZERO

## The bot's assigned character model ID (BLITZ, TITAN, PHANTOM).
var character_id: String = "BLITZ"

## The bot's assigned variant (MALE, FEMALE).
var character_variant: String = "MALE"

## The bot's difficulty level.
var difficulty: Enums.Difficulty = Enums.Difficulty.MEDIUM

## Reaction time in milliseconds (varies by difficulty).
var reaction_time_ms: float = 1000.0

## Hit-rate accuracy (0.0 to 1.0, varies by difficulty).
var accuracy: float = 0.35

## Engagement range in meters (varies by difficulty).
var engagement_range: float = 75.0

## Timer tracking reaction delay before responding to threats.
var reaction_timer: float = 0.0

## Whether the bot currently has a weapon equipped.
var has_weapon: bool = false

## Whether the bot has a healing item available.
var has_healing_item: bool = false

## Whether the bot is currently under fire.
var is_under_fire: bool = false


## Difficulty parameter ranges.
const REACTION_TIME_RANGES: Dictionary = {
	Enums.Difficulty.EASY: {"min": 1500.0, "max": 2000.0},
	Enums.Difficulty.MEDIUM: {"min": 800.0, "max": 1200.0},
	Enums.Difficulty.HARD: {"min": 300.0, "max": 600.0},
}

const ACCURACY_RANGES: Dictionary = {
	Enums.Difficulty.EASY: {"min": 0.15, "max": 0.25},
	Enums.Difficulty.MEDIUM: {"min": 0.30, "max": 0.45},
	Enums.Difficulty.HARD: {"min": 0.55, "max": 0.70},
}

const ENGAGEMENT_RANGES: Dictionary = {
	Enums.Difficulty.EASY: 50.0,
	Enums.Difficulty.MEDIUM: 75.0,
	Enums.Difficulty.HARD: 100.0,
}


## Initializes the bot with the given difficulty, assigning random parameters
## within the difficulty's defined ranges.
func initialize(bot_id: int, bot_difficulty: Enums.Difficulty) -> void:
	id = bot_id
	difficulty = bot_difficulty
	engagement_range = ENGAGEMENT_RANGES[difficulty]
	
	# Assign random reaction time within difficulty range
	var rt_range: Dictionary = REACTION_TIME_RANGES[difficulty]
	reaction_time_ms = randf_range(rt_range["min"], rt_range["max"])
	
	# Assign random accuracy within difficulty range
	var acc_range: Dictionary = ACCURACY_RANGES[difficulty]
	accuracy = randf_range(acc_range["min"], acc_range["max"])
	
	# Start in LOOTING state (no weapon at spawn)
	state = Enums.BotState.LOOTING
	has_weapon = false
	health = 100.0
	shield = 0.0
	is_alive = true


## Context dictionary expected keys:
## - "is_in_safe_zone": bool - whether the bot is inside the safe zone
## - "nearest_safe_point": Vector2 - nearest point on safe zone boundary
## - "enemy_in_range": bool - whether an enemy is within engagement range
## - "enemy_position": Vector2 - position of the nearest enemy (if any)
## - "nearest_loot_position": Vector2 - position of nearest loot
## - "is_under_fire": bool - whether the bot is currently being shot at
##
## Returns the new BotState after evaluating priority rules.
func decide_action(context: Dictionary) -> Enums.BotState:
	var in_safe_zone: bool = context.get("is_in_safe_zone", true)
	var enemy_in_range: bool = context.get("enemy_in_range", false)
	var under_fire: bool = context.get("is_under_fire", false)
	
	# Determine if bot is in "immediate danger"
	var in_danger: bool = under_fire or not in_safe_zone or health < 30.0
	
	# Priority 1: Unarmed and not in danger → LOOTING
	if not has_weapon and not in_danger:
		state = Enums.BotState.LOOTING
		return state
	
	# Priority 2: Outside safe zone → FLEEING (toward zone)
	if not in_safe_zone:
		state = Enums.BotState.FLEEING
		# Set movement direction toward nearest safe point
		var safe_point: Vector2 = context.get("nearest_safe_point", Vector2.ZERO)
		if safe_point != Vector2.ZERO or position != Vector2.ZERO:
			var direction := (safe_point - position)
			if direction.length() > 0.0:
				movement_direction = direction.normalized()
		return state
	
	# Priority 3: Enemy in range, health > 50%, armed → ENGAGING
	if enemy_in_range and health > 50.0 and has_weapon:
		state = Enums.BotState.ENGAGING
		return state
	
	# Priority 4: Enemy in range, health ≤ 50% or unarmed → FLEEING
	if enemy_in_range and (health <= 50.0 or not has_weapon):
		state = Enums.BotState.FLEEING
		return state
	
	# Priority 5: Health < 30% → disengage, heal if possible
	if health < 30.0:
		if has_healing_item:
			state = Enums.BotState.HEALING
		else:
			state = Enums.BotState.FLEEING
		return state
	
	# Priority 6: Armed, in zone, no enemy → ROAMING
	if has_weapon and in_safe_zone and not enemy_in_range:
		state = Enums.BotState.ROAMING
		return state
	
	# Fallback: if unarmed and in danger, flee/loot based on situation
	if not has_weapon and in_danger:
		state = Enums.BotState.FLEEING
		return state
	
	# Default fallback
	return state


## Calculates movement vector toward the safe zone.
## Returns a normalized vector with positive dot product toward the nearest safe boundary point.
func calculate_movement_toward_zone(nearest_safe_point: Vector2) -> Vector2:
	var direction := nearest_safe_point - position
	if direction.length() > 0.0:
		movement_direction = direction.normalized()
	else:
		movement_direction = Vector2.ZERO
	return movement_direction


## Applies damage to the bot, reducing shield first then health.
func take_damage(amount: float) -> void:
	if not is_alive:
		return
	
	var remaining := amount
	if shield > 0.0:
		var shield_damage := minf(remaining, shield)
		shield -= shield_damage
		remaining -= shield_damage
	
	if remaining > 0.0:
		health -= remaining
	
	if health <= 0.0:
		health = 0.0
		is_alive = false


## Heals the bot by the specified amount, capped at 100.
func heal(amount: float) -> void:
	health = minf(health + amount, 100.0)


## Returns whether the bot's reaction timer has elapsed (ready to act).
func is_reaction_ready(delta: float) -> bool:
	reaction_timer -= delta * 1000.0  # Convert to ms
	if reaction_timer <= 0.0:
		reaction_timer = reaction_time_ms
		return true
	return false
