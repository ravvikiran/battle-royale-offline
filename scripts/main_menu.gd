## Main Menu UI controller.
## Displays options: Play, Characters, Career Stats, Settings, Login/Player ID.
## Shows selected character 3D model (default Blitz male if none selected).
## Transitions to Character Selector or match lobby within 3 seconds on Play.
class_name MainMenu
extends Control


## Emitted when the player presses Play.
signal play_pressed

## Emitted when the player navigates to Character Selector.
signal characters_pressed

## Emitted when the player navigates to Career Stats.
signal career_stats_pressed

## Emitted when the player navigates to Settings.
signal settings_pressed

## Emitted when the player presses Login/Player ID.
signal login_pressed


## Maximum transition time in seconds (requirement 14.3).
const MAX_TRANSITION_TIME: float = 3.0

## Default character when no selection exists.
const DEFAULT_CHARACTER: String = "BLITZ"

## Default variant when no selection exists.
const DEFAULT_VARIANT: String = "MALE"


## Character data loaded from data/characters.json.
var _characters_data: Array = []

## Currently displayed character ID.
var _displayed_character: String = DEFAULT_CHARACTER

## Currently displayed variant.
var _displayed_variant: String = DEFAULT_VARIANT

## Reference to the ProgressStore for loading career stats and character selection.
var _progress_store: ProgressStore = null

## Reference to the AuthManager for login state display.
var _auth_manager: AuthManager = null

## Whether a transition is in progress (prevents double-taps).
var _transitioning: bool = false

## Transition timer to enforce 3-second max.
var _transition_timer: Timer


## UI node references.
@onready var play_button: Button = %PlayButton
@onready var characters_button: Button = %CharactersButton
@onready var career_stats_button: Button = %CareerStatsButton
@onready var settings_button: Button = %SettingsButton
@onready var login_button: Button = %LoginButton
@onready var preview_viewport: SubViewportContainer = %PreviewViewportContainer
@onready var preview_subviewport: SubViewport = %PreviewSubViewport
@onready var preview_camera: Camera3D = %PreviewCamera
@onready var preview_model_root: Node3D = %PreviewModelRoot
@onready var title_label: Label = %TitleLabel
@onready var version_label: Label = %VersionLabel


func _ready() -> void:
	_load_characters_data()
	_setup_transition_timer()
	_setup_ui()
	_load_displayed_character()
	_update_login_button()
	_load_character_model()


## Inject the ProgressStore dependency.
func set_progress_store(store: ProgressStore) -> void:
	_progress_store = store
	_load_displayed_character()
	_load_character_model()


## Inject the AuthManager dependency.
func set_auth_manager(manager: AuthManager) -> void:
	_auth_manager = manager
	_update_login_button()


## Load character data from the JSON configuration file.
func _load_characters_data() -> void:
	var file := FileAccess.open("res://data/characters.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		if error == OK and json.data.has("characters"):
			_characters_data = json.data["characters"]
		file.close()

	# Fallback if data couldn't be loaded
	if _characters_data.is_empty():
		_characters_data = [
			{"id": "BLITZ", "name": "Blitz", "description": "Nimble scout with sporty build", "primary_color": "#FF6B35", "variants": ["MALE", "FEMALE"]},
			{"id": "TITAN", "name": "Titan", "description": "Bulky heavy with armored plating", "primary_color": "#2E86AB", "variants": ["MALE", "FEMALE"]},
			{"id": "PHANTOM", "name": "Phantom", "description": "Sleek stealth with hooded cloak", "primary_color": "#7B2D8B", "variants": ["MALE", "FEMALE"]}
		]


## Set up the transition timer to enforce 3-second max transition time.
func _setup_transition_timer() -> void:
	_transition_timer = Timer.new()
	_transition_timer.one_shot = true
	_transition_timer.wait_time = MAX_TRANSITION_TIME
	_transition_timer.timeout.connect(_on_transition_timeout)
	add_child(_transition_timer)


## Set up UI elements and connect signals.
func _setup_ui() -> void:
	play_button.pressed.connect(_on_play_pressed)
	characters_button.pressed.connect(_on_characters_pressed)
	career_stats_button.pressed.connect(_on_career_stats_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	login_button.pressed.connect(_on_login_pressed)


## Load the character to display from persisted selection.
## Defaults to Blitz male if no previous selection exists (Requirement 14.2).
func _load_displayed_character() -> void:
	if _progress_store != null:
		var selection := _progress_store.get_character_selection()
		_displayed_character = selection.get("character", DEFAULT_CHARACTER)
		_displayed_variant = selection.get("variant", DEFAULT_VARIANT)
	else:
		_displayed_character = DEFAULT_CHARACTER
		_displayed_variant = DEFAULT_VARIANT


## Update the login button text based on auth state (Requirement 14.1).
func _update_login_button() -> void:
	if _auth_manager != null and _auth_manager.auth_state == Enums.AuthState.AUTHENTICATED:
		# Show truncated user ID when authenticated
		var display_id := _auth_manager.user_id
		if display_id.length() > 16:
			display_id = display_id.substr(0, 14) + "..."
		login_button.text = display_id
	else:
		login_button.text = "Login"


## Load the character 3D model for the main menu preview.
func _load_character_model() -> void:
	if preview_model_root == null:
		return
	# Clear existing model
	for child in preview_model_root.get_children():
		child.queue_free()

	var character_data := _get_character_data(_displayed_character)
	var color_hex: String = character_data.get("primary_color", "#FF6B35")

	# Try loading real model from assets
	var model_path := "characters/%s_%s.glb" % [_displayed_character.to_lower(), _displayed_variant.to_lower()]
	var scene := AssetLoader.load_model(model_path)
	if scene:
		var model := scene.instantiate()
		preview_model_root.add_child(model)
		return

	# Fallback: procedural placeholder
	var model_color := Color(color_hex)
	var mesh_instance := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.3
	capsule_mesh.height = 1.6
	mesh_instance.mesh = capsule_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = model_color
	mesh_instance.material_override = material
	preview_model_root.add_child(mesh_instance)


## Get character data by ID.
func _get_character_data(character_id: String) -> Dictionary:
	for character in _characters_data:
		if character.get("id", "") == character_id:
			return character
	# Fallback to first character (Blitz)
	if _characters_data.size() > 0:
		return _characters_data[0]
	return {"id": "BLITZ", "name": "Blitz", "primary_color": "#FF6B35"}


## Called when Play button is pressed.
## Transitions to Character Selector or match lobby within 3 seconds (Requirement 14.3).
func _on_play_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_transition_timer.start()
	play_pressed.emit()


## Called when Characters button is pressed.
func _on_characters_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_transition_timer.start()
	characters_pressed.emit()


## Called when Career Stats button is pressed.
func _on_career_stats_pressed() -> void:
	career_stats_pressed.emit()


## Called when Settings button is pressed.
func _on_settings_pressed() -> void:
	settings_pressed.emit()


## Called when Login button is pressed.
func _on_login_pressed() -> void:
	login_pressed.emit()


## Called when the transition timer expires.
## Resets the transitioning flag to allow interaction again.
func _on_transition_timeout() -> void:
	_transitioning = false


## Reset the transition state (called after scene change completes).
func reset_transition() -> void:
	_transitioning = false
	_transition_timer.stop()


## Refresh the displayed character model (e.g., after returning from Character Selector).
func refresh_character_display() -> void:
	_load_displayed_character()
	_load_character_model()


## Get the currently displayed character ID.
func get_displayed_character() -> String:
	return _displayed_character


## Get the currently displayed variant.
func get_displayed_variant() -> String:
	return _displayed_variant
