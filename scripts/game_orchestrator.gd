## Main game orchestrator that wires all systems together into the complete match loop.
## Manages the full lifecycle: lobby → character selection → match settings → drop → active → end.
## Connects MatchController, ZoneManager, BotAIManager, LootManager, HUDManager,
## AudioManager, InputController, InventorySystem, WeaponSystem, RenderManager,
## ProgressStore, CharacterSelector, and MatchSettings via signals and method calls.
## Ensures the entire match completes without network connectivity.
## Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 3.5
class_name GameOrchestrator
extends Node3D


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

## HUD label references (from game.tscn)
var _hud_health_label: Label = null
var _hud_shield_label: Label = null
var _hud_alive_label: Label = null
var _hud_time_label: Label = null
var _hud_kills_label: Label = null
var _hud_phase_label: Label = null
var _hud_center_message: Label = null

## Visual representations of bots on the map
var _bot_visuals: Dictionary = {}  # bot.id -> Node3D

## Player visual representation (MeshInstance3D for placeholder, or loaded model Node3D)
var _player_visual: Node3D = null

## Camera following the player
var _game_camera: Camera3D = null

## Player movement speed in meters per second
const PLAYER_SPEED: float = 15.0

## Camera height above player
const CAMERA_HEIGHT: float = 40.0

## Camera angle (look-down angle)
const CAMERA_ANGLE: float = -60.0


func _ready() -> void:
	# Get GameMap reference from scene tree (it's defined in game.tscn)
	var map_node := get_node_or_null("GameMap")
	if map_node is GameMap:
		game_map = map_node

	# Get HUD label references
	_hud_health_label = get_node_or_null("HUD/TopBar/HealthLabel")
	_hud_shield_label = get_node_or_null("HUD/TopBar/ShieldLabel")
	_hud_alive_label = get_node_or_null("HUD/TopBar/AliveLabel")
	_hud_time_label = get_node_or_null("HUD/TopBar/TimeLabel")
	_hud_kills_label = get_node_or_null("HUD/TopBar/KillsLabel")
	_hud_phase_label = get_node_or_null("HUD/TopBar/PhaseLabel")
	_hud_center_message = get_node_or_null("HUD/CenterMessage")

	_initialize_systems()
	_wire_signals()
	_initialized = true
	_game_camera = get_node_or_null("GameCamera")


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

	# Wire BotAIManager → ZoneManager and MapData
	bot_ai_manager.zone_manager = zone_manager
	bot_ai_manager.map_data = map_data


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

	# v0.2.0: Notify GameSystemsHub of match start
	var game_sys: Node = get_node_or_null("/root/GameSystems")
	if game_sys is GameSystemsHub:
		(game_sys as GameSystemsHub).on_match_start(settings)

	# Set up player visual with correct character
	_setup_player_visual()

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

	# For PC testing, auto-select a drop position near map center
	# In the full mobile version, the player selects via tap on minimap
	var drop_pos := map_data.get_map_bounds().get_center()
	drop_pos += Vector2(randf_range(-50.0, 50.0), randf_range(-50.0, 50.0))
	player_position = drop_pos
	match_controller.player_select_drop(drop_pos)

	# Show location labels during drop phase
	if game_map != null:
		game_map.set_drop_phase_active(true)

	phase_changed.emit("drop")

	# Auto-end drop phase after a short delay for PC testing (3 seconds)
	get_tree().create_timer(3.0).timeout.connect(_auto_end_drop_phase)


## Called when the player selects a drop location during the drop phase.
func player_select_drop_location(position: Vector2) -> void:
	player_position = position
	match_controller.player_select_drop(position)


## Auto-ends the drop phase after the short PC testing delay.
func _auto_end_drop_phase() -> void:
	if match_controller.match_state == Enums.MatchState.DROP:
		match_controller.end_drop_phase()


## Main frame update — processes all per-frame game logic.
func _process(delta: float) -> void:
	if not _initialized:
		return

	if match_controller.match_state == Enums.MatchState.ACTIVE:
		_process_active_gameplay(delta)


## Processes active gameplay each frame.
func _process_active_gameplay(delta: float) -> void:
	# --- PC Keyboard/Mouse Input ---
	_handle_pc_input(delta)

	# --- Input → Player Movement (touch) ---
	var movement := input_controller.get_movement_vector()
	if movement.length() > 0.01:
		_player_moving = true
		player_position += movement * PLAYER_SPEED * delta
	elif not _player_moving:
		pass  # _player_moving already set by _handle_pc_input

	# Clamp player position within map bounds
	if map_data != null:
		var bounds := map_data.get_map_bounds()
		player_position.x = clampf(player_position.x, bounds.position.x, bounds.position.x + bounds.size.x)
		player_position.y = clampf(player_position.y, bounds.position.y, bounds.position.y + bounds.size.y)
	
	# --- Input → Player Aiming (touch) ---
	var aim_delta := input_controller.get_aim_delta()
	if aim_delta.length() > 0.01:
		player_facing_degrees += aim_delta.x * 2.0
		player_facing_degrees = fmod(player_facing_degrees, 360.0)
		if player_facing_degrees < 0.0:
			player_facing_degrees += 360.0

	# --- Bot AI Update ---
	bot_ai_manager.update_all(delta)

	# --- Check for bot eliminations ---
	var elim := bot_ai_manager.pop_last_elimination()
	while not elim.is_empty():
		match_controller.register_elimination(elim["victim"], elim["killer"], "weapon")
		elim = bot_ai_manager.pop_last_elimination()

	# --- Update bot visuals ---
	_update_bot_visuals()

	# --- Storm Damage ---
	_process_storm_damage(delta)

	# --- HUD Updates ---
	_update_hud()

	# --- v0.2.0: GameSystemsHub per-frame update ---
	var game_sys: Node = get_node_or_null("/root/GameSystems")
	if game_sys is GameSystemsHub:
		(game_sys as GameSystemsHub).on_match_update(
			delta,
			match_controller.match_stats.get("kills", 0),
			match_controller.match_stats.get("damage_dealt", 0.0),
			match_controller.elapsed_time,
			match_controller.alive_count,
			match_controller.total_participants - 1
		)

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
			var diff := safe_point - player_position
			var direction := diff.normalized() if diff.length() > 0.01 else Vector2.UP
			hud_manager.show_storm_indicator(direction)

		# v0.2.0: Track storm time for challenges/achievements
		var game_sys: Node = get_node_or_null("/root/GameSystems")
		if game_sys is GameSystemsHub:
			(game_sys as GameSystemsHub).on_storm_damage_tick(delta)
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

	# v0.2.0: Notify combat feedback for screen effects
	var game_sys: Node = get_node_or_null("/root/GameSystems")
	if game_sys is GameSystemsHub:
		var hub: GameSystemsHub = game_sys as GameSystemsHub
		hub.on_player_damaged(amount, Vector2.ZERO)
		hub.on_health_changed(player_health, player_shield)

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

	# Update on-screen HUD labels
	_update_hud_labels()


## Creates the player's visual representation on the map.
func _setup_player_visual() -> void:
	# Try loading real player model
	var model_path := "characters/%s_%s.glb" % [player_character_id.to_lower(), player_character_variant.to_lower()]
	var scene := AssetLoader.load_model(model_path)
	if scene:
		_player_visual = scene.instantiate()
		_player_visual.position = Vector3(player_position.x, 0.0, player_position.y)
		add_child(_player_visual)
		return

	# Fallback: blue capsule placeholder
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 1.5
	capsule.height = 4.0
	mesh_inst.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.5, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.3, 0.8)
	mat.emission_energy_multiplier = 0.5
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(player_position.x, 3.0, player_position.y)
	_player_visual = mesh_inst
	add_child(_player_visual)


## Creates or updates visual representations for all alive bots.
func _update_bot_visuals() -> void:
	# Remove visuals for dead bots
	var to_remove: Array = []
	for bot_id in _bot_visuals:
		var found := false
		for bot in bot_ai_manager.bots:
			if bot.id == bot_id and bot.is_alive:
				found = true
				break
		if not found:
			var visual: Node3D = _bot_visuals[bot_id]
			visual.queue_free()
			to_remove.append(bot_id)
	for bot_id in to_remove:
		_bot_visuals.erase(bot_id)

	# Create or update visuals for alive bots
	for bot in bot_ai_manager.bots:
		if not bot.is_alive:
			continue
		if not _bot_visuals.has(bot.id):
			# Try loading real model
			var model_path := "characters/%s_%s.glb" % [bot.character_id.to_lower(), bot.character_variant.to_lower()]
			var scene := AssetLoader.load_model(model_path)
			var new_visual: Node3D
			if scene:
				new_visual = scene.instantiate()
			else:
				# Fallback: red capsule
				var mesh_inst := MeshInstance3D.new()
				var bot_capsule := CapsuleMesh.new()
				bot_capsule.radius = 1.2
				bot_capsule.height = 3.5
				mesh_inst.mesh = bot_capsule
				var bot_mat := StandardMaterial3D.new()
				bot_mat.albedo_color = Color(0.9, 0.2, 0.2)
				mesh_inst.material_override = bot_mat
				new_visual = mesh_inst
			add_child(new_visual)
			_bot_visuals[bot.id] = new_visual
		# Update position
		var existing_visual: Node3D = _bot_visuals[bot.id]
		existing_visual.position = Vector3(bot.position.x, 3.0, bot.position.y)


## Handles keyboard/mouse input for PC testing.
func _handle_pc_input(delta: float) -> void:
	var move_dir := Vector2.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_dir.x += 1.0

	if move_dir.length() > 0.0:
		move_dir = move_dir.normalized()
		player_position += move_dir * PLAYER_SPEED * delta
		_player_moving = true
	else:
		# Only set to false if touch joystick isn't active either
		if input_controller.get_movement_vector().length() <= 0.01:
			_player_moving = false

	# Update player visual position
	if _player_visual != null:
		_player_visual.position = Vector3(player_position.x, 3.0, player_position.y)

	# Update camera to follow player
	if _game_camera != null:
		_game_camera.position = Vector3(player_position.x, CAMERA_HEIGHT, player_position.y + 25.0)
		_game_camera.rotation_degrees = Vector3(CAMERA_ANGLE, 0, 0)
		# v0.2.0: Apply screen shake from combat feedback
		var game_sys: Node = get_node_or_null("/root/GameSystems")
		if game_sys is GameSystemsHub:
			var shake: Vector2 = (game_sys as GameSystemsHub).get_camera_shake_offset()
			_game_camera.position.x += shake.x
			_game_camera.position.z += shake.y

	# Shoot with spacebar (left mouse handled in _unhandled_input to avoid conflicts)
	if Input.is_action_just_pressed("ui_accept"):
		_on_player_fire()


## Updates the on-screen HUD labels with current game state.
func _update_hud_labels() -> void:
	if _hud_health_label != null:
		_hud_health_label.text = "HP: %d" % int(player_health)
	if _hud_shield_label != null:
		_hud_shield_label.text = "Shield: %d" % int(player_shield)
	if _hud_alive_label != null:
		_hud_alive_label.text = "Alive: %d" % match_controller.alive_count
	if _hud_time_label != null:
		var mins: int = int(match_controller.elapsed_time) / 60
		var secs: int = int(match_controller.elapsed_time) % 60
		_hud_time_label.text = "Time: %d:%02d" % [mins, secs]
	if _hud_kills_label != null:
		_hud_kills_label.text = "Kills: %d" % match_controller.match_stats.get("kills", 0)
	if _hud_phase_label != null:
		match match_controller.match_state:
			Enums.MatchState.DROP:
				_hud_phase_label.text = "Phase: Drop"
			Enums.MatchState.ACTIVE:
				_hud_phase_label.text = "Zone: %d" % zone_manager.current_phase
			Enums.MatchState.ENDED:
				_hud_phase_label.text = "Match Over"
			_:
				_hud_phase_label.text = ""
	if _hud_center_message != null:
		if match_controller.match_state == Enums.MatchState.DROP:
			_hud_center_message.text = "Drop Phase - Landing..."
			_hud_center_message.visible = true
		elif match_controller.match_state == Enums.MatchState.ACTIVE and match_controller.elapsed_time < 3.0:
			_hud_center_message.text = "Fight!"
			_hud_center_message.visible = true
		else:
			# v0.2.0: Show kill streak announcement if active
			var game_sys: Node = get_node_or_null("/root/GameSystems")
			if game_sys is GameSystemsHub:
				var hub: GameSystemsHub = game_sys as GameSystemsHub
				if hub.is_hit_marker_visible() and hub.is_hit_marker_kill():
					var streak_text: String = hub.combat_feedback.get_streak_announcement()
					if not streak_text.is_empty():
						_hud_center_message.text = streak_text
						_hud_center_message.visible = true
					else:
						_hud_center_message.visible = false
				else:
					_hud_center_message.visible = false
			else:
				_hud_center_message.visible = false


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
	var is_victory: bool = (result.get("placement", 0) == 1)

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

	# v0.2.0: Notify GameSystemsHub of hit
	var game_sys: Node = get_node_or_null("/root/GameSystems")
	if game_sys is GameSystemsHub:
		var hub: GameSystemsHub = game_sys as GameSystemsHub
		hub.on_player_hit(damage, best_target.position)

	# Check if bot is eliminated
	if not best_target.is_alive:
		match_controller.register_elimination(best_target.id, MatchController.PLAYER_ID, weapon.name)
		# v0.2.0: Notify kill
		if game_sys is GameSystemsHub:
			var hub2: GameSystemsHub = game_sys as GameSystemsHub
			hub2.on_player_kill("Bot_%d" % best_target.id, weapon.name, weapon.category, damage)


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

		# v0.2.0: Track loot pickup for challenges
		var game_sys: Node = get_node_or_null("/root/GameSystems")
		if game_sys is GameSystemsHub:
			(game_sys as GameSystemsHub).on_item_looted()


# --- Consumable Usage ---


## Attempts to use a consumable item from the player's inventory.
func use_consumable(type: Enums.ConsumableType) -> Dictionary:
	var result := inventory_system.use_consumable(type)
	if result.get("success", false):
		# Healing started — use a timer to delay completion by use_time
		var use_time: float = result.get("use_time", 3.0)
		get_tree().create_timer(use_time).timeout.connect(_on_healing_complete)
	return result


## Called when the healing timer finishes, applying the heal effect.
func _on_healing_complete() -> void:
	# Guard: don't heal if match ended or player is dead
	if match_controller.match_state != Enums.MatchState.ACTIVE:
		inventory_system.cancel_healing()
		return
	if player_health <= 0.0:
		inventory_system.cancel_healing()
		return
	var heal_result := inventory_system.complete_healing()
	if heal_result.get("success", false):
		player_health = inventory_system.current_health
		player_shield = inventory_system.current_shield
		hud_manager.update_health(player_health, player_shield)


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
	for i in range(36):
		if i == 8 or i == 13 or i == 18 or i == 23:
			uuid += "-"
		elif i == 14:
			uuid += "4"  # Version 4
		elif i == 19:
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
