## Central orchestrator managing match state and phase transitions.
## Controls the match lifecycle from lobby through drop, active gameplay, to match end.
## Coordinates with ZoneManager, BotAIManager, and LootManager.
class_name MatchController
extends Node


## Emitted when the match state changes (LOBBY, DROP, ACTIVE, ENDED).
signal match_state_changed(new_state: Enums.MatchState)

## Emitted when an elimination occurs.
signal elimination_occurred(victim_id: int, killer_id: int, weapon: String)

## Emitted when the match ends with final results.
signal match_ended(result: Dictionary)


## Current match lifecycle state.
var match_state: Enums.MatchState = Enums.MatchState.LOBBY

## Number of participants still alive (player + bots).
var alive_count: int = 0

## Elapsed time in seconds since match became ACTIVE.
var elapsed_time: float = 0.0

## Match configuration settings.
var match_settings: Dictionary = {}

## Running match statistics for the player.
var match_stats: Dictionary = {
	"kills": 0,
	"damage_dealt": 0.0,
	"survival_time_seconds": 0.0,
}

## The player's unique participant ID (always 0).
const PLAYER_ID: int = 0

## Total number of participants (player + bots).
var total_participants: int = 0

## Whether the player is still alive.
var player_alive: bool = true

## Player's landing position (set during drop phase).
var player_position: Vector2 = Vector2.ZERO

## Whether the player has selected a landing position.
var player_has_dropped: bool = false

## Drop phase timer (60 seconds).
var drop_timer: float = 0.0

## Whether the drop phase timer is active.
var drop_timer_active: bool = false

## Bot distribution timer (10 seconds after drop phase begins).
var bot_distribute_timer: float = 0.0

## Whether bot distribution is pending.
var bot_distribute_pending: bool = false

## Reference to the BotAIManager.
var bot_ai_manager: BotAIManager = null

## Reference to the ZoneManager.
var zone_manager: ZoneManager = null

## Reference to the MapData.
var map_data: MapData = null

## Drop phase duration in seconds.
const DROP_PHASE_DURATION: float = 60.0

## Bot distribution time limit in seconds.
const BOT_DISTRIBUTE_TIME: float = 10.0


## Starts a new match with the given settings.
## Settings dictionary expected keys:
## - "bot_count": int (10-99)
## - "bot_difficulty": Enums.Difficulty
## - "zone_speed": Enums.ZoneShrinkSpeed
## - "character": String (player's character ID)
## - "variant": String (player's character variant)
func start_match(settings: Dictionary) -> void:
	match_settings = settings

	var bot_count: int = clampi(settings.get("bot_count", 50), 10, 99)
	total_participants = bot_count + 1  # bots + player
	alive_count = total_participants
	player_alive = true
	player_has_dropped = false
	elapsed_time = 0.0

	# Reset match stats
	match_stats = {
		"kills": 0,
		"damage_dealt": 0.0,
		"survival_time_seconds": 0.0,
	}

	# Initialize map data if not already set
	if map_data == null:
		map_data = MapData.new()

	# Initialize zone manager if available
	if zone_manager != null:
		var speed: Enums.ZoneShrinkSpeed = settings.get("zone_speed", Enums.ZoneShrinkSpeed.NORMAL)
		zone_manager.initialize_zones(map_data.get_map_bounds(), speed)

	# Spawn bots via BotAIManager
	if bot_ai_manager == null:
		bot_ai_manager = BotAIManager.new()
	var difficulty: Enums.Difficulty = settings.get("bot_difficulty", Enums.Difficulty.MEDIUM)
	bot_ai_manager.spawn_bots(bot_count, difficulty)

	# Connect zone manager to bot AI if both exist
	if zone_manager != null and bot_ai_manager != null:
		bot_ai_manager.zone_manager = zone_manager

	# Transition to DROP state
	_set_match_state(Enums.MatchState.DROP)


## Begins the drop phase with a 60-second timer.
## If the player does not select a landing location before the timer expires,
## they are auto-dropped at a random position within the safe zone.
func begin_drop_phase() -> void:
	drop_timer = DROP_PHASE_DURATION
	drop_timer_active = true
	player_has_dropped = false

	# Start bot distribution timer (bots land within 10 seconds)
	bot_distribute_timer = BOT_DISTRIBUTE_TIME
	bot_distribute_pending = true


## Called when the player selects a landing position during the drop phase.
func player_select_drop(position: Vector2) -> void:
	if match_state != Enums.MatchState.DROP:
		return
	if player_has_dropped:
		return

	player_position = position
	player_has_dropped = true


## Ends the drop phase, distributing all bots to random map positions.
## Bots are distributed within 10 seconds of the drop phase starting.
func end_drop_phase() -> void:
	drop_timer_active = false

	# Auto-drop player if they haven't selected a position
	if not player_has_dropped:
		player_position = _get_random_safe_zone_position()
		player_has_dropped = true

	# Distribute bots to random map positions
	_distribute_bots()

	# Transition to ACTIVE state
	_set_match_state(Enums.MatchState.ACTIVE)

	# Start zone phases if zone manager is available
	if zone_manager != null:
		zone_manager.start_first_phase()


## Registers an elimination event, decrementing alive_count.
## victim_id: The ID of the eliminated participant (0 = player).
## killer_id: The ID of the participant who made the kill.
## weapon: Optional weapon name used for the kill.
func register_elimination(victim_id: int, killer_id: int, weapon: String = "") -> void:
	if match_state != Enums.MatchState.ACTIVE:
		return

	alive_count -= 1

	# Track if the player was eliminated
	if victim_id == PLAYER_ID:
		player_alive = false

	# Track player kills
	if killer_id == PLAYER_ID and victim_id != PLAYER_ID:
		match_stats["kills"] += 1

	# Eliminate bot in BotAIManager
	if victim_id != PLAYER_ID and bot_ai_manager != null:
		bot_ai_manager.eliminate_bot(victim_id)

	# Emit elimination signal
	elimination_occurred.emit(victim_id, killer_id, weapon)

	# Check victory condition
	check_victory_condition()


## Checks if the victory condition has been met.
## Victory occurs when only the player remains alive,
## or when the player is eliminated simultaneously with the final opponent.
func check_victory_condition() -> bool:
	if match_state != Enums.MatchState.ACTIVE:
		return false

	# Victory: player is the last one standing
	if alive_count <= 1 and player_alive:
		var result := _build_match_result(1)  # 1st place
		end_match(result)
		return true

	# Simultaneous final elimination: player dies at same time as last opponent
	# This counts as a victory per requirement 1.5
	if alive_count == 0 and not player_alive:
		var result := _build_match_result(1)  # Victory via simultaneous elimination
		end_match(result)
		return true

	# Player eliminated but others remain
	if not player_alive and alive_count > 0:
		var placement: int = alive_count + 1  # Player's placement
		var result := _build_match_result(placement)
		end_match(result)
		return true

	return false


## Ends the match with the given result data.
## result dictionary keys: kills, placement, survival_time_seconds,
## damage_dealt, character, variant, bot_difficulty, bot_count, total_participants
func end_match(result: Dictionary) -> void:
	if match_state == Enums.MatchState.ENDED:
		return

	_set_match_state(Enums.MatchState.ENDED)
	match_ended.emit(result)


## Called every frame to update match timers and state.
func _process(delta: float) -> void:
	match match_state:
		Enums.MatchState.DROP:
			_process_drop_phase(delta)
		Enums.MatchState.ACTIVE:
			_process_active_phase(delta)


## Processes the drop phase timer and bot distribution.
func _process_drop_phase(delta: float) -> void:
	# Handle bot distribution timer
	if bot_distribute_pending:
		bot_distribute_timer -= delta
		if bot_distribute_timer <= 0.0:
			_distribute_bots()
			bot_distribute_pending = false

	# Handle drop phase timer
	if drop_timer_active:
		drop_timer -= delta
		if drop_timer <= 0.0:
			end_drop_phase()


## Processes the active match phase (elapsed time tracking).
func _process_active_phase(delta: float) -> void:
	elapsed_time += delta
	match_stats["survival_time_seconds"] = elapsed_time


## Distributes all bots to random positions across the map.
func _distribute_bots() -> void:
	if bot_ai_manager == null or map_data == null:
		return

	var bot_count: int = bot_ai_manager.bots.size()
	var positions: Array[Vector2] = []
	var bounds: Rect2 = map_data.get_map_bounds()

	for i in range(bot_count):
		var pos := Vector2(
			randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		)
		positions.append(pos)

	bot_ai_manager.distribute_bot_positions(positions)


## Returns a random position within the current safe zone.
## Falls back to map center if no zone manager is available.
func _get_random_safe_zone_position() -> Vector2:
	if zone_manager != null and zone_manager.current_radius > 0.0:
		# Generate a random point within the safe zone circle
		var angle := randf() * TAU
		var distance := randf() * zone_manager.current_radius
		return zone_manager.current_center + Vector2(cos(angle), sin(angle)) * distance
	elif map_data != null:
		# Fallback: use map center area
		var center := map_data.get_map_bounds().get_center()
		var offset := Vector2(randf_range(-100.0, 100.0), randf_range(-100.0, 100.0))
		return center + offset
	else:
		return Vector2.ZERO


## Builds the match result dictionary.
func _build_match_result(placement: int) -> Dictionary:
	return {
		"kills": match_stats.get("kills", 0),
		"placement": placement,
		"survival_time_seconds": match_stats.get("survival_time_seconds", 0.0),
		"damage_dealt": match_stats.get("damage_dealt", 0.0),
		"character": match_settings.get("character", "BLITZ"),
		"variant": match_settings.get("variant", "MALE"),
		"bot_difficulty": match_settings.get("bot_difficulty", Enums.Difficulty.MEDIUM),
		"bot_count": match_settings.get("bot_count", 50),
		"total_participants": total_participants,
	}


## Sets the match state and emits the state changed signal.
func _set_match_state(new_state: Enums.MatchState) -> void:
	match_state = new_state
	match_state_changed.emit(new_state)


## Adds damage dealt by the player to match stats.
func record_player_damage(amount: float) -> void:
	match_stats["damage_dealt"] += amount


## Returns the current match state.
func get_match_state() -> Enums.MatchState:
	return match_state


## Returns the number of alive participants.
func get_alive_count() -> int:
	return alive_count


## Returns the elapsed match time in seconds.
func get_elapsed_time() -> float:
	return elapsed_time


## Returns whether the player is still alive.
func is_player_alive() -> bool:
	return player_alive
