## Main game orchestrator that wires all systems together into the complete match loop.
## Manages the full lifecycle: lobby → character selection → match settings → drop → active → end.
## Connects MatchController, ZoneManager, BotAIManager, LootManager, HUDManager,
## AudioManager, InputController, InventorySystem, WeaponSystem, RenderManager,
## ProgressStore, CharacterSelector, and MatchSettings via signals and method calls.
## Ensures the entire match completes without network connectivity.
## Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 3.5
class_name GameOrchestrator
extends Node


## Emitted when the orchestrator transitions between major game phases.
signal phase_changed(phase: String)

## Emitted when the match ends and results are ready.
signal match_results_ready(result: Dictionary)


# --- System References ---

## Core gameplay systems
var match_controller: MatchController = null
var zone_manager: ZoneManager = null
var bot_ai_manager: BotAIManager = null
var loot_manager: LootManager = null
var weapon_system: WeaponSystem = null

## Player systems
var input_controller: InputController = null
var inventory_system: InventorySystem = null

## Presentation systems
var hud_manager: HUDManager = null
var audio_manager: AudioManager = null
var render_manager: RenderManager = null
var game_map: GameMap = null

## Persistence systems
var progress_store: ProgressStore = null
var auth_manager: AuthManager = null

## UI systems (set externally before match start)
var character_selector: CharacterSelector = null
var match_settings_ui: MatchSettings = null

## Map data reference
var map_data: MapData = null

## Player state
var player_position: Vector2 = Vector2.ZERO
var player_health: float = 100.0
var player_shield: float = 0.0
var player_facing_degrees: float = 0.0
var player_character_id: String = "BLITZ"
var player_character_variant: String = "MALE"

## Match configuration from settings
var current_match_settings: Dictionary = {}

## Whether the orchestrator has been initialized
var _initialized: bool = false

## Storm damage accumulator (applies per frame)
var _storm_damage_timer: float = 0.0

## Storm damage tick interval in seconds
const STORM_DAMAGE_TICK: float = 1.0

## Footstep audio interval in seconds
const FOOTSTEP_INTERVAL: float = 0.4

## Footstep timer
var _footstep_timer: float = 0.0

## Whether player is currently moving
var _player_moving: bool = false


func _ready() -> void:
	# Get GameMap reference from scene tree (it's defined in game.tscn)
	var map_node := get_node_or_null("GameMap")
	if map_node is GameMap:
		game_map = map_node

	_initialize_systems()
	_wire_signals()
	_initialized = true


## Initializes all subsystems that are created internally.
## Systems that are scene nodes (GameMap, HUDManager) should be added as children
## or set via dependency injection before _ready().
func _initialize_systems() -> void:
	# Create core systems if not already injected
	if match_controller == null:
		match_controller = MatchController.new()
		match_controller.name = "MatchController"
		add_child(match_controller)

	if zone_manager == null:
		zone_manager = ZoneManager.new()
		zone_manager.name = "ZoneManager"
		add_child(zone_manager)

	if bot_ai_manager == null:
		bot_ai_manager = BotAIManager.new()
		bot_ai_manager.name = "BotAIManager"
		add_child(bot_ai_manager)

	if loot_manager == null:
		loot_manager = LootManager.new()

	if weapon_system == null:
		weapon_system = WeaponSystem.new()

	if input_controller == null:
		input_controller = InputController.new()
		input_controller.name = "InputController"
		add_child(input_controller)

	if inventory_system == null:
		inventory_system = InventorySystem.new()

	if hud_manager == null:
		hud_manager = HUDManager.new()
		hud_manager.name = "HUDManager"
		add_child(hud_manager)

	if audio_manager == null:
		audio_manager = AudioManager.new()

	if render_manager == null:
		render_manager = RenderManager.new()
		render_manager.name = "RenderManager"
		add_child(render_manager)

	if map_data == null:
		map_data = MapData.new()

	if progress_store == null:
		progress_store = ProgressStore.new()

	# Wire MatchController dependencies
	match_controller.zone_manager = zone_manager
	match_controller.bot_ai_manager = bot_ai_manager
	match_controller.map_data = map_data

	# Wire BotAIManager → ZoneManager
	bot_ai_manager.zone_manager = zone_manager


## Wires all signal connections between systems.
func _wire_signals() -> void:
	# --- MatchController signals ---
	match_controller.match_state_changed.connect(_on_match_state_changed)
	match_controller.elimination_occurred.connect(_on_elimination_occurred)
	match_controller.match_ended.connect(_on_match_ended)

	# --- ZoneManager signals → HUDManager ---
	zone_manager.zone_warning.connect(_on_zone_warning)
	zone_manager.zone_shrink_started.connect(_on_zone_shrink_started)
	zone_manager.zone_shrink_completed.connect(_on_zone_shrink_completed)

	# --- InputController signals → Player actions ---
	input_controller.fire_pressed.connect(_on_player_fire)
	input_controller.fire_released.connect(_on_player_fire_released)
	input_controller.reload_pressed.connect(_on_player_reload)
	input_controller.jump_pressed.connect(_on_player_jump)
	input_controller.crouch_pressed.connect(_on_player_crouch)
	input_controller.weapon_switched.connect(_on_player_weapon_switch)

	# --- RenderManager signals ---
	render_manager.quality_reduced.connect(_on_quality_reduced)
	render_manager.critical_memory_warning.connect(_on_critical_memory_warning)


## Starts the full match flow with the given character selection and match settings.
## Called after CharacterSelector confirms and MatchSettings confirms.
func start_match_from_lobby(character_id: String, variant: String, settings: Dictionary) -> void:
	player_character_id = character_id
	player_character_variant = variant
	current_match_settings = settings

	# Merge character info into settings for MatchController
	var full_settings := settings.duplicate()
	full_settings["character"] = character_id
	full_settings["variant"] = variant

	# Initialize loot on the map
	loot_manager.initialize_loot(map_data)

	# Refresh game map loot display if available
	if game_map != null:
		game_map.loot_manager = loot_manager
		game_map.refresh_loot_display()

	# Play drop phase music
	audio_manager.play_music(AudioManager.MusicTrack.DROP_PHASE)

	# Start render manager monitoring
	render_manager.start_match_monitoring()

	# Reset player state
	player_health = 100.0
	player_shield = 0.0
	inventory_system = InventorySystem.new()
	_storm_damage_timer = 0.0

	# Update HUD with initial state
	hud_manager.update_health(player_health, player_shield)
	hud_manager.update_alive_count(settings.get("bot_count", 50) + 1)

	# Set active weapon slots on input controller
	input_controller.set_active_weapon_slots(0)

	# Start the match via MatchController
	match_controller.start_match(full_settings)

	# Begin drop phase
	match_controller.begin_drop_phase()

	# Show location labels during drop phase
	if game_map != null:
		game_map.set_drop_phase_active(true)

	phase_changed.emit("drop")


## Called when the player selects a drop location during the drop phase.
func player_select_drop_location(position: Vector2) -> void:
	player_position = position
	match_controller.player_select_drop(position)


## Main frame update — processes all per-frame game logic.
func _process(delta: float) -> void:
	if not _initialized:
		return

	if match_controller.match_state == Enums.MatchState.ACTIVE:
		_process_active_gameplay(delta)


## Processes active gameplay each frame.
func _process_active_gameplay(delta: float) -> void:
	# --- Input → Player Movement ---
	var movement := input_controller.get_movement_vector()
	if movement.length() > 0.01:
		_player_moving = true
		# Move player position (simplified 2D movement for zone/bot calculations)
		# 5 meters per second at full joystick displacement
		player_position += movement * 5.0 * delta
	else:
		_player_moving = false

	# --- Input → Player Aiming ---
	var aim_delta := input_controller.get_aim_delta()
	if aim_delta.length() > 0.01:
		player_facing_degrees += aim_delta.x * 2.0
		player_facing_degrees = fmod(player_facing_degrees, 360.0)
		if player_facing_degrees < 0.0:
			player_facing_degrees += 360.0

	# --- Bot AI Update ---
	bot_ai_manager.update_all(delta)

	# --- Storm Damage ---
	_process_storm_damage(delta)

	# --- HUD Updates ---
	_update_hud()

	# --- Audio: Footsteps ---
	_process_footstep_audio(delta)

	# --- Audio: Storm Ambient ---
	_process_storm_audio()


## Applies storm damage to the player if outside the safe zone.
func _process_storm_damage(delta: float) -> void:
	if zone_manager.current_phase <= 0:
		return

	if not zone_manager.is_in_safe_zone(player_position):
		_storm_damage_timer += delta
		if _storm_damage_timer >= STORM_DAMAGE_TICK:
			_storm_damage_timer -= STORM_DAMAGE_TICK
			var damage := zone_manager.get_storm_damage(zone_manager.current_phase)
			_apply_damage_to_player(damage)

			# Show storm indicator on HUD
			var safe_point := zone_manager.get_nearest_safe_point(player_position)
			var direction := (safe_point - player_position).normalized()
			hud_manager.show_storm_indicator(direction)
	else:
		_storm_damage_timer = 0.0
		hud_manager.hide_storm_indicator()


## Applies damage to the player (shield first, then health).
func _apply_damage_to_player(amount: float) -> void:
	var remaining := amount
	if player_shield > 0.0:
		var shield_damage := minf(remaining, player_shield)
		player_shield -= shield_damage
		remaining -= shield_damage

	if remaining > 0.0:
		player_health -= remaining

	# Update inventory system health tracking
	inventory_system.current_health = player_health
	inventory_system.current_shield = player_shield

	# Update HUD
	hud_manager.update_health(player_health, player_shield)

	# Check if player is eliminated
	if player_health <= 0.0:
		player_health = 0.0
		match_controller.register_elimination(MatchController.PLAYER_ID, -1, "storm")


## Updates HUD elements each frame.
func _update_hud() -> void:
	# Update compass
	hud_manager.update_compass(player_facing_degrees)

	# Update minimap with zone info
	hud_manager.update_minimap(
		player_position,
		player_facing_degrees,
		zone_manager.current_center,
		zone_manager.current_radius,
		zone_manager.next_center,
		zone_manager.next_radius
	)

	# Update alive count
	hud_manager.update_alive_count(match_controller.alive_count)

	# Update weapon display
	var active_weapon := inventory_system.get_active_weapon()
	if active_weapon != null:
		hud_manager.update_weapon(
			active_weapon.name,
			active_weapon.magazine_size,  # current ammo (simplified)
			active_weapon.magazine_size,
			0,  # reserve ammo
			int(active_weapon.rarity),
			false
		)
	else:
		hud_manager.update_weapon("Unarmed", 0, 0, 0, 0, true)


## Processes footstep audio based on player movement.
func _process_footstep_audio(delta: float) -> void:
	if _player_moving:
		_footstep_timer += delta
		if _footstep_timer >= FOOTSTEP_INTERVAL:
			_footstep_timer -= FOOTSTEP_INTERVAL
			audio_manager.play_own_footstep()
	else:
		_footstep_timer = 0.0


## Processes storm ambient audio.
func _process_storm_audio() -> void:
	if zone_manager.current_phase <= 0:
		return

	var in_storm := not zone_manager.is_in_safe_zone(player_position)
	if in_storm and not audio_manager.is_storm_ambient_playing():
		audio_manager.play_storm_ambient()
	elif not in_storm and audio_manager.is_storm_ambient_playing():
		audio_manager.stop_storm_ambient()


# --- Signal Handlers: MatchController ---


## Handles match state transitions.
func _on_match_state_changed(new_state: Enums.MatchState) -> void:
	match new_state:
		Enums.MatchState.DROP:
			phase_changed.emit("drop")
		Enums.MatchState.ACTIVE:
			_on_active_phase_started()
			phase_changed.emit("active")
		Enums.MatchState.ENDED:
			phase_changed.emit("ended")


## Called when the match transitions to ACTIVE state.
func _on_active_phase_started() -> void:
	# Hide drop phase labels
	if game_map != null:
		game_map.set_drop_phase_active(false)

	# Stop drop phase music (active gameplay has no background music)
	# Zone manager starts its first phase via MatchController.end_drop_phase()


## Handles elimination events — updates HUD kill feed and plays audio cue.
func _on_elimination_occurred(victim_id: int, killer_id: int, weapon: String) -> void:
	# Build kill feed entry
	var killer_name := _get_participant_name(killer_id)
	var victim_name := _get_participant_name(victim_id)

	var entry := {
		"killer": killer_name,
		"victim": victim_name,
		"weapon": weapon,
	}
	hud_manager.add_kill_feed_entry(entry)

	# Update alive count on HUD
	hud_manager.update_alive_count(match_controller.alive_count)

	# Play elimination audio cue
	audio_manager.play_audio_cue(AudioManager.AudioCue.ELIMINATION)


## Handles match end — saves results and shows victory/defeat screen.
func _on_match_ended(result: Dictionary) -> void:
	# Stop render monitoring
	render_manager.stop_match_monitoring()

	# Stop storm ambient
	audio_manager.stop_storm_ambient()

	# Determine if victory or defeat
	var is_victory := result.get("placement", 0) == 1

	# Play victory music if won
	if is_victory:
		audio_manager.play_music(AudioManager.MusicTrack.VICTORY)

	# Save match results to progress store
	_save_match_results(result)

	# Emit results for UI to display
	match_results_ready.emit(result)


# --- Signal Handlers: ZoneManager ---


## Handles zone warning — updates HUD and plays audio cue.
func _on_zone_warning(seconds_remaining: int) -> void:
	# Play zone warning audio cue
	audio_manager.play_audio_cue(AudioManager.AudioCue.ZONE_WARNING)


## Handles zone shrink start.
func _on_zone_shrink_started(_phase: int) -> void:
	pass  # Zone visuals update automatically via minimap each frame


## Handles zone shrink completion.
func _on_zone_shrink_completed(_phase: int) -> void:
	pass  # Zone visuals update automatically via minimap each frame


# --- Signal Handlers: InputController ---


## Handles player fire input.
func _on_player_fire() -> void:
	var active_weapon := inventory_system.get_active_weapon()
	if active_weapon == null:
		return

	# Play gunshot audio at player position
	var player_pos_3d := Vector3(player_position.x, 0.0, player_position.y)
	audio_manager.play_gunshot(player_pos_3d, player_pos_3d)

	# Calculate damage to nearest bot in range and facing direction
	_attempt_player_shot(active_weapon)


## Handles player fire release (hold mode).
func _on_player_fire_released() -> void:
	pass  # Continuous fire stops


## Handles player reload input.
func _on_player_reload() -> void:
	# Reload logic is handled by weapon instance state (simplified here)
	pass


## Handles player jump input.
func _on_player_jump() -> void:
	pass  # Jump mechanics (simplified — no vertical gameplay in 2D zone logic)


## Handles player crouch input.
func _on_player_crouch() -> void:
	pass  # Crouch mechanics (simplified)


## Handles player weapon switch.
func _on_player_weapon_switch(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < InventorySystem.MAX_WEAPON_SLOTS:
		inventory_system.active_weapon_index = slot_index
		_update_hud()


# --- Signal Handlers: RenderManager ---


## Handles quality reduction notification.
func _on_quality_reduced(_new_preset: RenderManager.QualityPreset) -> void:
	pass  # RenderManager handles the indicator display internally


## Handles critical memory warning.
func _on_critical_memory_warning() -> void:
	# Preserve match state
	var state := {
		"player_health": player_health,
		"player_shield": player_shield,
		"player_position": player_position,
		"alive_count": match_controller.alive_count,
		"elapsed_time": match_controller.elapsed_time,
		"kills": match_controller.match_stats.get("kills", 0),
	}
	render_manager.set_match_state_for_preservation(state)


# --- Player Combat ---


## Attempts to hit a bot with the player's shot.
func _attempt_player_shot(weapon: WeaponData) -> void:
	# Find nearest bot in the player's facing direction within weapon range
	var max_range := weapon.effective_range * 2.0
	var alive_bots := bot_ai_manager.get_alive_bots()

	var best_target: BotInstance = null
	var best_distance := INF

	for bot in alive_bots:
		var distance := player_position.distance_to(bot.position)
		if distance > max_range:
			continue

		# Check if bot is roughly in the player's facing direction (±45 degrees)
		var to_bot := (bot.position - player_position).normalized()
		var facing_rad := deg_to_rad(player_facing_degrees)
		var facing_vec := Vector2(sin(facing_rad), -cos(facing_rad))
		var dot := facing_vec.dot(to_bot)

		if dot > 0.7 and distance < best_distance:  # ~45 degree cone
			best_distance = distance
			best_target = bot

	if best_target == null:
		return

	# Calculate damage using WeaponSystem
	var damage := WeaponSystem.calculate_damage(weapon, best_distance)

	# Apply accuracy check
	var accuracy := WeaponSystem.get_accuracy(weapon, weapon.rarity)
	if randf() > accuracy:
		return  # Miss

	# Apply damage to bot
	best_target.take_damage(damage)

	# Record player damage dealt
	match_controller.record_player_damage(damage)

	# Check if bot is eliminated
	if not best_target.is_alive:
		match_controller.register_elimination(best_target.id, MatchController.PLAYER_ID, weapon.name)


# --- Loot Pickup ---


## Attempts to pick up the nearest loot item within pickup range.
## Called when the player interacts with loot (e.g., via a pickup button).
func attempt_loot_pickup() -> void:
	var pickup_radius := 3.0  # meters
	var nearest_loot := loot_manager.get_nearest_loot(player_position, pickup_radius)

	if nearest_loot == null:
		return

	var result := loot_manager.pick_up_loot(nearest_loot.id, inventory_system)

	if result.get("success", false):
		# Play item pickup audio cue
		audio_manager.play_audio_cue(AudioManager.AudioCue.ITEM_PICKUP)

		# Update weapon slot count on input controller
		input_controller.set_active_weapon_slots(inventory_system.get_weapon_count())

		# Update HUD weapon display
		_update_hud()

		# Remove loot glow from map
		if game_map != null:
			game_map.remove_loot_glow(nearest_loot.id)


# --- Consumable Usage ---


## Attempts to use a consumable item from the player's inventory.
func use_consumable(type: Enums.ConsumableType) -> Dictionary:
	var result := inventory_system.use_consumable(type)
	if result.get("success", false):
		# Healing started — in a full implementation, a timer would complete it
		# For now, immediately complete healing (simplified)
		var heal_result := inventory_system.complete_healing()
		if heal_result.get("success", false):
			player_health = inventory_system.current_health
			player_shield = inventory_system.current_shield
			hud_manager.update_health(player_health, player_shield)
	return result


# --- Progress Persistence ---


## Saves match results to the progress store.
func _save_match_results(result: Dictionary) -> void:
	if progress_store == null:
		return

	# Build the full match record
	var match_record := {
		"match_id": _generate_match_id(),
		"timestamp": _get_timestamp(),
		"placement": result.get("placement", 0),
		"total_participants": result.get("total_participants", 0),
		"kills": result.get("kills", 0),
		"damage_dealt": result.get("damage_dealt", 0.0),
		"survival_time_seconds": int(result.get("survival_time_seconds", 0.0)),
		"character_name": result.get("character", player_character_id),
		"character_variant": result.get("variant", player_character_variant),
		"bot_difficulty": _difficulty_to_string(result.get("bot_difficulty", Enums.Difficulty.MEDIUM)),
		"bot_count": result.get("bot_count", 50),
	}

	progress_store.save_match_result(match_record)


# --- CharacterSelector Integration ---


## Connects the CharacterSelector signals for lobby flow.
func connect_character_selector(selector: CharacterSelector) -> void:
	character_selector = selector
	selector.character_confirmed.connect(_on_character_confirmed)


## Handles character confirmation from the selector.
func _on_character_confirmed(character_id: String, variant: String) -> void:
	player_character_id = character_id
	player_character_variant = variant


# --- MatchSettings Integration ---


## Connects the MatchSettings signals for lobby flow.
func connect_match_settings(settings_ui: MatchSettings) -> void:
	match_settings_ui = settings_ui
	settings_ui.settings_confirmed.connect(_on_settings_confirmed)


## Handles settings confirmation — starts the match.
func _on_settings_confirmed(settings: Dictionary) -> void:
	current_match_settings = settings
	start_match_from_lobby(player_character_id, player_character_variant, settings)


# --- Utility Methods ---


## Returns a display name for a participant ID.
func _get_participant_name(participant_id: int) -> String:
	if participant_id == MatchController.PLAYER_ID:
		return "You"
	elif participant_id == -1:
		return "Storm"
	else:
		# Get bot character name
		if bot_ai_manager != null:
			for bot in bot_ai_manager.bots:
				if bot.id == participant_id:
					return "%s_%d" % [bot.character_id, bot.id]
		return "Bot_%d" % participant_id


## Generates a unique match ID (UUID v4 format).
func _generate_match_id() -> String:
	var chars := "0123456789abcdef"
	var uuid := ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			uuid += "-"
		if i == 12:
			uuid += "4"  # Version 4
		elif i == 16:
			uuid += chars[8 + (randi() % 4)]  # Variant bits
		else:
			uuid += chars[randi() % 16]
	return uuid


## Returns the current timestamp as an ISO-8601 string.
func _get_timestamp() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		datetime["year"], datetime["month"], datetime["day"],
		datetime["hour"], datetime["minute"], datetime["second"]
	]


## Converts a Difficulty enum to a string for storage.
func _difficulty_to_string(difficulty: int) -> String:
	match difficulty:
		Enums.Difficulty.EASY:
			return "EASY"
		Enums.Difficulty.MEDIUM:
			return "MEDIUM"
		Enums.Difficulty.HARD:
			return "HARD"
		_:
			return "MEDIUM"


## Returns the match result for external UI consumption.
func get_last_match_result() -> Dictionary:
	return current_match_settings
