## Manages all bot instances and their FSM-based decision making.
## Handles spawning, updating, and eliminating bots during a match.
class_name BotAIManager
extends Node


## Array of all bot instances managed by this system.
var bots: Array[BotInstance] = []

## Current difficulty setting for all bots.
var difficulty: Enums.Difficulty = Enums.Difficulty.MEDIUM

## Engagement range in meters based on difficulty.
var engagement_range: float = 75.0

## Reference to the zone manager for safe zone queries.
var zone_manager: ZoneManager = null


## Engagement range constants per difficulty level.
const ENGAGEMENT_RANGES: Dictionary = {
	Enums.Difficulty.EASY: 50.0,
	Enums.Difficulty.MEDIUM: 75.0,
	Enums.Difficulty.HARD: 100.0,
}

## Valid character models for bot assignment.
const CHARACTER_MODELS: Array[String] = ["BLITZ", "TITAN", "PHANTOM"]

## Valid character variants.
const CHARACTER_VARIANTS: Array[String] = ["MALE", "FEMALE"]


## Spawns the specified number of bots with the given difficulty.
## Each bot is assigned a random character model and variant.
func spawn_bots(count: int, bot_difficulty: Enums.Difficulty) -> void:
	difficulty = bot_difficulty
	engagement_range = ENGAGEMENT_RANGES[difficulty]
	bots.clear()
	
	for i in range(count):
		var bot := BotInstance.new()
		bot.initialize(i, difficulty)
		
		# Assign random character model and variant
		bot.character_id = CHARACTER_MODELS[randi() % CHARACTER_MODELS.size()]
		bot.character_variant = CHARACTER_VARIANTS[randi() % CHARACTER_VARIANTS.size()]
		
		bots.append(bot)


## Updates all alive bots each frame, running their FSM decision logic.
func update_all(delta: float) -> void:
	for bot in bots:
		if not bot.is_alive:
			continue
		
		# Build context for decision making
		var context := _build_bot_context(bot)
		
		# Only act if reaction timer allows
		if bot.is_reaction_ready(delta):
			bot.decide_action(context)
		
		# If bot is outside safe zone, always move toward it regardless of reaction
		if not context.get("is_in_safe_zone", true):
			var safe_point: Vector2 = context.get("nearest_safe_point", Vector2.ZERO)
			bot.calculate_movement_toward_zone(safe_point)

		# Move bot based on current state
		_move_bot(bot, delta)

	# Resolve bot-vs-bot combat
	_resolve_bot_combat(delta)


## Moves a bot based on its current FSM state.
func _move_bot(bot: BotInstance, delta: float) -> void:
	if bot.movement_direction.length() > 0.01:
		var speed := 8.0  # meters per second
		bot.position += bot.movement_direction * speed * delta


## Resolves combat between bots that are in ENGAGING state.
## Each engaging bot has a chance to hit its target based on accuracy.
func _resolve_bot_combat(delta: float) -> void:
	for bot in bots:
		if not bot.is_alive:
			continue
		if bot.state != Enums.BotState.ENGAGING:
			continue
		if not bot.has_weapon:
			continue

		# Find nearest alive enemy in range
		var target: BotInstance = _get_nearest_alive_enemy(bot)
		if target == null:
			continue

		# Fire rate: bots shoot approximately once per second
		# Use reaction timer as fire cooldown
		if not bot.is_reaction_ready(0.0):
			continue

		# Accuracy check
		if randf() > bot.accuracy:
			continue  # Miss

		# Deal damage (base 15-25 depending on difficulty)
		var base_damage := 15.0 + (int(bot.difficulty) * 5.0)
		target.take_damage(base_damage)

		# Check if target is eliminated
		if not target.is_alive:
			_last_elimination_killer = bot.id
			_last_elimination_victim = target.id


## Tracks the last elimination for signaling
var _last_elimination_killer: int = -1
var _last_elimination_victim: int = -1


## Returns the last elimination pair and clears it.
func pop_last_elimination() -> Dictionary:
	if _last_elimination_victim >= 0:
		var result := {"killer": _last_elimination_killer, "victim": _last_elimination_victim}
		_last_elimination_killer = -1
		_last_elimination_victim = -1
		return result
	return {}


## Returns the nearest alive enemy bot within engagement range.
func _get_nearest_alive_enemy(bot: BotInstance) -> BotInstance:
	var nearest: BotInstance = null
	var nearest_dist := INF
	for other in bots:
		if other.id == bot.id or not other.is_alive:
			continue
		var dist := bot.position.distance_to(other.position)
		if dist <= bot.engagement_range and dist < nearest_dist:
			nearest_dist = dist
			nearest = other
	return nearest


## Returns an array of all currently alive bots.
func get_alive_bots() -> Array[BotInstance]:
	var alive: Array[BotInstance] = []
	for bot in bots:
		if bot.is_alive:
			alive.append(bot)
	return alive


## Eliminates a bot by ID, marking it as dead.
func eliminate_bot(bot_id: int) -> void:
	for bot in bots:
		if bot.id == bot_id:
			bot.is_alive = false
			bot.health = 0.0
			return


## Returns the number of alive bots.
func get_alive_count() -> int:
	var count := 0
	for bot in bots:
		if bot.is_alive:
			count += 1
	return count


## Builds the context dictionary for a bot's decision making.
## Uses the zone_manager reference if available for zone queries.
func _build_bot_context(bot: BotInstance) -> Dictionary:
	var context: Dictionary = {}
	
	# Zone-related context
	if zone_manager != null:
		context["is_in_safe_zone"] = zone_manager.is_in_safe_zone(bot.position)
		context["nearest_safe_point"] = zone_manager.get_nearest_safe_point(bot.position)
	else:
		context["is_in_safe_zone"] = true
		context["nearest_safe_point"] = bot.position
	
	# Enemy detection - check distance to other alive bots and player
	context["enemy_in_range"] = _check_enemy_in_range(bot)
	context["enemy_position"] = _get_nearest_enemy_position(bot)
	
	# Under fire status
	context["is_under_fire"] = bot.is_under_fire
	
	# Nearest loot (simplified - would be provided by LootManager in full integration)
	context["nearest_loot_position"] = Vector2.ZERO
	
	return context


## Checks if any enemy is within the bot's engagement range.
func _check_enemy_in_range(bot: BotInstance) -> bool:
	for other_bot in bots:
		if other_bot.id == bot.id or not other_bot.is_alive:
			continue
		if bot.position.distance_to(other_bot.position) <= bot.engagement_range:
			return true
	return false


## Returns the position of the nearest enemy within engagement range.
func _get_nearest_enemy_position(bot: BotInstance) -> Vector2:
	var nearest_distance := INF
	var nearest_pos := Vector2.ZERO
	
	for other_bot in bots:
		if other_bot.id == bot.id or not other_bot.is_alive:
			continue
		var dist := bot.position.distance_to(other_bot.position)
		if dist <= bot.engagement_range and dist < nearest_distance:
			nearest_distance = dist
			nearest_pos = other_bot.position
	
	return nearest_pos


## Sets positions for all bots (used during drop phase distribution).
func distribute_bot_positions(positions: Array[Vector2]) -> void:
	for i in range(mini(positions.size(), bots.size())):
		bots[i].position = positions[i]
