## Manages scene transitions and navigation between game screens.
## Registered as an autoload to persist across scene changes.
## Handles: MainMenu → CharacterSelector → MatchSettings → Game → Victory/Defeat → MainMenu
extends Node


## Scene file paths
const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const SCENE_CHARACTER_SELECTOR := "res://scenes/character_selector.tscn"
const SCENE_MATCH_SETTINGS := "res://scenes/match_settings.tscn"
const SCENE_GAME := "res://scenes/game.tscn"
const SCENE_VICTORY := "res://scenes/victory_screen.tscn"
const SCENE_DEFEAT := "res://scenes/defeat_screen.tscn"
const SCENE_CAREER_STATS := "res://scenes/career_stats.tscn"
const SCENE_SETTINGS := "res://scenes/settings.tscn"


## Shared state between scenes
var selected_character: String = "BLITZ"
var selected_variant: String = "MALE"
var match_settings: Dictionary = {}
var last_match_result: Dictionary = {}

## Persistence systems (created once, persist across scenes)
var progress_store: ProgressStore = null
var auth_manager: AuthManager = null


func _ready() -> void:
	# Initialize persistence systems
	auth_manager = AuthManager.new()
	progress_store = ProgressStore.new()

	# Generate guest ID and initialize progress store
	var guest_id := auth_manager.generate_guest_id()
	auth_manager.user_id = guest_id
	auth_manager.auth_state = Enums.AuthState.GUEST
	progress_store.initialize(guest_id)

	# Load persisted character selection
	var selection := progress_store.get_character_selection()
	selected_character = selection.get("character", "BLITZ")
	selected_variant = selection.get("variant", "MALE")

	# Connect to the current scene if it's the main menu
	call_deferred("_connect_current_scene")


## Connects signals from the current scene after it's ready.
func _connect_current_scene() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	if current_scene is MainMenu:
		_connect_main_menu(current_scene)
	elif current_scene is CharacterSelector:
		_connect_character_selector(current_scene)
	elif current_scene is MatchSettings:
		_connect_match_settings(current_scene)
	elif current_scene is GameOrchestrator:
		_connect_game_orchestrator(current_scene)
	elif current_scene is VictoryScreen:
		_connect_victory_screen(current_scene)
	elif current_scene is DefeatScreen:
		_connect_defeat_screen(current_scene)
	elif current_scene is CareerStats:
		_connect_career_stats(current_scene)
	elif current_scene is SettingsMenu:
		_connect_settings_menu(current_scene)


## Navigate to a scene by path and connect its signals after loading.
func goto_scene(scene_path: String) -> void:
	# Use call_deferred to avoid issues during signal processing
	call_deferred("_deferred_goto_scene", scene_path)


func _deferred_goto_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
	# Use a one-shot timer to connect signals after the scene is loaded
	get_tree().create_timer(0.0).timeout.connect(_connect_current_scene)


# --- Main Menu ---

func _connect_main_menu(menu: MainMenu) -> void:
	menu.set_progress_store(progress_store)
	menu.set_auth_manager(auth_manager)

	if not menu.play_pressed.is_connected(_on_main_menu_play):
		menu.play_pressed.connect(_on_main_menu_play)
	if not menu.characters_pressed.is_connected(_on_main_menu_characters):
		menu.characters_pressed.connect(_on_main_menu_characters)
	if not menu.career_stats_pressed.is_connected(_on_main_menu_career_stats):
		menu.career_stats_pressed.connect(_on_main_menu_career_stats)
	if not menu.settings_pressed.is_connected(_on_main_menu_settings):
		menu.settings_pressed.connect(_on_main_menu_settings)


func _on_main_menu_play() -> void:
	goto_scene(SCENE_MATCH_SETTINGS)


func _on_main_menu_characters() -> void:
	goto_scene(SCENE_CHARACTER_SELECTOR)


func _on_main_menu_career_stats() -> void:
	goto_scene(SCENE_CAREER_STATS)


func _on_main_menu_settings() -> void:
	goto_scene(SCENE_SETTINGS)


# --- Character Selector ---

func _connect_character_selector(selector: CharacterSelector) -> void:
	if not selector.character_confirmed.is_connected(_on_character_confirmed):
		selector.character_confirmed.connect(_on_character_confirmed)
	if not selector.back_pressed.is_connected(_on_character_selector_back):
		selector.back_pressed.connect(_on_character_selector_back)


func _on_character_confirmed(character_id: String, variant: String) -> void:
	selected_character = character_id
	selected_variant = variant
	progress_store.save_character_selection(character_id, variant)
	goto_scene(SCENE_MAIN_MENU)


func _on_character_selector_back() -> void:
	goto_scene(SCENE_MAIN_MENU)


# --- Match Settings ---

func _connect_match_settings(settings_ui: MatchSettings) -> void:
	if not settings_ui.settings_confirmed.is_connected(_on_match_settings_confirmed):
		settings_ui.settings_confirmed.connect(_on_match_settings_confirmed)
	if not settings_ui.back_pressed.is_connected(_on_match_settings_back):
		settings_ui.back_pressed.connect(_on_match_settings_back)


func _on_match_settings_confirmed(settings: Dictionary) -> void:
	match_settings = settings
	match_settings["character"] = selected_character
	match_settings["variant"] = selected_variant
	goto_scene(SCENE_GAME)


func _on_match_settings_back() -> void:
	goto_scene(SCENE_MAIN_MENU)


# --- Game (Orchestrator) ---

func _connect_game_orchestrator(orchestrator: GameOrchestrator) -> void:
	orchestrator.progress_store = progress_store
	orchestrator.auth_manager = auth_manager

	if not orchestrator.match_results_ready.is_connected(_on_match_results_ready):
		orchestrator.match_results_ready.connect(_on_match_results_ready)

	# Start the match with the configured settings
	orchestrator.start_match_from_lobby(selected_character, selected_variant, match_settings)


func _on_match_results_ready(result: Dictionary) -> void:
	last_match_result = result
	var placement: int = result.get("placement", 0)
	if placement == 1:
		goto_scene(SCENE_VICTORY)
	else:
		goto_scene(SCENE_DEFEAT)


# --- Victory / Defeat / Career Stats / Settings (back navigation) ---


func _connect_victory_screen(screen: VictoryScreen) -> void:
	screen.set_match_result(last_match_result)
	if not screen.return_to_menu_pressed.is_connected(_on_return_to_menu):
		screen.return_to_menu_pressed.connect(_on_return_to_menu)
	if not screen.play_again_pressed.is_connected(_on_play_again):
		screen.play_again_pressed.connect(_on_play_again)


func _connect_defeat_screen(screen: DefeatScreen) -> void:
	screen.set_match_result(last_match_result)
	if not screen.return_to_menu_pressed.is_connected(_on_return_to_menu):
		screen.return_to_menu_pressed.connect(_on_return_to_menu)
	if not screen.play_again_pressed.is_connected(_on_play_again):
		screen.play_again_pressed.connect(_on_play_again)


func _connect_career_stats(stats_screen: CareerStats) -> void:
	stats_screen.set_progress_store(progress_store)
	if not stats_screen.back_pressed.is_connected(_on_career_stats_back):
		stats_screen.back_pressed.connect(_on_career_stats_back)


func _connect_settings_menu(settings_screen: SettingsMenu) -> void:
	settings_screen.set_progress_store(progress_store)
	settings_screen.set_auth_manager(auth_manager)
	if not settings_screen.back_pressed.is_connected(_on_settings_back):
		settings_screen.back_pressed.connect(_on_settings_back)


func _on_return_to_menu() -> void:
	goto_scene(SCENE_MAIN_MENU)


func _on_play_again() -> void:
	# Reuse the same match settings from the last game
	if match_settings.is_empty():
		match_settings = {
			"bot_count": 50,
			"bot_difficulty": Enums.Difficulty.MEDIUM,
			"zone_speed": Enums.ZoneShrinkSpeed.NORMAL,
			"character": selected_character,
			"variant": selected_variant
		}
	goto_scene(SCENE_GAME)


func _on_career_stats_back() -> void:
	goto_scene(SCENE_MAIN_MENU)


func _on_settings_back() -> void:
	goto_scene(SCENE_MAIN_MENU)


func go_to_main_menu() -> void:
	goto_scene(SCENE_MAIN_MENU)


func get_last_match_result() -> Dictionary:
	return last_match_result
