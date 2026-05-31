## Character Selector UI controller.
## Displays 3 characters (Blitz, Titan, Phantom) with male/female variant toggle.
## Implements 360-degree horizontal rotation preview and persists selection.
class_name CharacterSelector
extends Control


## Emitted when the player confirms a character selection.
signal character_confirmed(character_id: String, variant: String)

## Emitted when the player cancels/goes back.
signal back_pressed

## Emitted when character loading fails and player can retry or pick alternate.
signal load_error(message: String)


## Character data loaded from data/characters.json
var _characters_data: Array = []

## Currently selected character index (0=Blitz, 1=Titan, 2=Phantom)
var _selected_index: int = 0

## Currently selected variant ("MALE" or "FEMALE")
var _selected_variant: String = "MALE"

## Whether a character has been explicitly confirmed this session
var _confirmed_this_session: bool = false

## Rotation angle for the 3D preview (degrees, 0-360)
var _preview_rotation: float = 0.0

## Whether the preview model is currently loaded
var _model_loaded: bool = false

## Whether a load operation is in progress
var _loading: bool = false

## Timer for load timeout (5 seconds max)
var _load_timer: Timer

## Reference to the ProgressStore for persistence
var _progress_store: ProgressStore = null

## Rotation speed in degrees per second for drag interaction
const ROTATION_SPEED: float = 180.0

## Maximum load time in seconds before showing error
const MAX_LOAD_TIME: float = 5.0

## Default character ID when no previous selection exists
const DEFAULT_CHARACTER: String = "BLITZ"

## Default variant when no previous selection exists
const DEFAULT_VARIANT: String = "MALE"


## UI node references
@onready var character_name_label: Label = %CharacterNameLabel
@onready var character_description_label: Label = %CharacterDescriptionLabel
@onready var variant_toggle: Button = %VariantToggle
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton
@onready var confirm_button: Button = %ConfirmButton
@onready var back_button: Button = %BackButton
@onready var preview_viewport: SubViewportContainer = %PreviewViewportContainer
@onready var preview_subviewport: SubViewport = %PreviewSubViewport
@onready var preview_camera: Camera3D = %PreviewCamera
@onready var preview_model_root: Node3D = %PreviewModelRoot
@onready var loading_label: Label = %LoadingLabel
@onready var error_container: VBoxContainer = %ErrorContainer
@onready var error_label: Label = %ErrorLabel
@onready var retry_button: Button = %RetryButton
@onready var alternate_button: Button = %AlternateButton
@onready var character_color_indicator: ColorRect = %CharacterColorIndicator


func _ready() -> void:
	_load_characters_data()
	_setup_load_timer()
	_setup_ui()
	_load_persisted_selection()
	_update_display()
	_begin_model_load()


## Inject the ProgressStore dependency for persistence.
func set_progress_store(store: ProgressStore) -> void:
	_progress_store = store


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


## Set up the load timeout timer.
func _setup_load_timer() -> void:
	_load_timer = Timer.new()
	_load_timer.one_shot = true
	_load_timer.wait_time = MAX_LOAD_TIME
	_load_timer.timeout.connect(_on_load_timeout)
	add_child(_load_timer)


## Set up UI elements and connect signals.
func _setup_ui() -> void:
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	variant_toggle.pressed.connect(_on_variant_toggle_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	alternate_button.pressed.connect(_on_alternate_pressed)

	# Hide error container initially
	error_container.visible = false
	loading_label.visible = false


## Load the previously persisted character selection from ProgressStore.
## Defaults to Blitz male if no previous selection exists.
func _load_persisted_selection() -> void:
	if _progress_store == null:
		_selected_index = 0
		_selected_variant = DEFAULT_VARIANT
		return

	var selection := _progress_store.get_character_selection()
	var character_id: String = selection.get("character", DEFAULT_CHARACTER)
	var variant: String = selection.get("variant", DEFAULT_VARIANT)

	# Find the index for the persisted character
	_selected_index = _get_character_index(character_id)
	_selected_variant = variant

	# Validate variant
	if _selected_variant != "MALE" and _selected_variant != "FEMALE":
		_selected_variant = DEFAULT_VARIANT


## Get the index of a character by its ID. Returns 0 (Blitz) if not found.
func _get_character_index(character_id: String) -> int:
	for i in range(_characters_data.size()):
		if _characters_data[i].get("id", "") == character_id:
			return i
	return 0


## Get the currently selected character data dictionary.
func _get_selected_character() -> Dictionary:
	if _selected_index >= 0 and _selected_index < _characters_data.size():
		return _characters_data[_selected_index]
	return _characters_data[0]


## Get the currently selected character ID.
func get_selected_character_id() -> String:
	return _get_selected_character().get("id", DEFAULT_CHARACTER)


## Get the currently selected variant.
func get_selected_variant() -> String:
	return _selected_variant


## Update all display elements to reflect the current selection.
func _update_display() -> void:
	var character := _get_selected_character()

	# Update name and description
	character_name_label.text = character.get("name", "Unknown")
	character_description_label.text = character.get("description", "")

	# Update variant toggle text
	variant_toggle.text = "Variant: %s" % _selected_variant.capitalize()

	# Update color indicator
	var color_hex: String = character.get("primary_color", "#FFFFFF")
	character_color_indicator.color = Color(color_hex)

	# Update navigation button states
	prev_button.disabled = false
	next_button.disabled = false


## Begin loading the character model for preview.
func _begin_model_load() -> void:
	_loading = true
	_model_loaded = false
	loading_label.visible = true
	error_container.visible = false

	# Start the load timeout timer
	_load_timer.start()

	# Simulate model loading (in a real implementation, this would load a 3D model)
	_load_character_model()


## Load the character model for the 3D preview.
## In a full implementation, this loads the actual .glb/.tscn model.
## For now, creates a placeholder representation using the character's color.
func _load_character_model() -> void:
	# Clear existing model
	for child in preview_model_root.get_children():
		child.queue_free()

	var character := _get_selected_character()
	var color_hex: String = character.get("primary_color", "#FFFFFF")
	var model_color := Color(color_hex)

	# Create a placeholder character model (blocky style)
	var mesh_instance := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.3
	capsule_mesh.height = 1.6
	mesh_instance.mesh = capsule_mesh

	# Apply character color material
	var material := StandardMaterial3D.new()
	material.albedo_color = model_color
	mesh_instance.material_override = material

	preview_model_root.add_child(mesh_instance)

	# Mark as loaded
	_on_model_loaded_success()


## Called when the model loads successfully.
func _on_model_loaded_success() -> void:
	_load_timer.stop()
	_loading = false
	_model_loaded = true
	loading_label.visible = false
	error_container.visible = false


## Called when the load timer expires (5 second timeout).
func _on_load_timeout() -> void:
	_loading = false
	_model_loaded = false
	loading_label.visible = false

	# Show error with retry/alternate options
	error_container.visible = true
	error_label.text = "Failed to load character model. Please retry or select a different character."
	load_error.emit("Character model load timed out after %d seconds." % int(MAX_LOAD_TIME))


## Handle 360-degree rotation via input.
func _input(event: InputEvent) -> void:
	if not _model_loaded:
		return

	# Handle touch drag for rotation on the preview area
	if event is InputEventScreenDrag:
		_preview_rotation += event.relative.x * 0.5
		_preview_rotation = fmod(_preview_rotation, 360.0)
		if _preview_rotation < 0.0:
			_preview_rotation += 360.0
		_apply_rotation()

	# Handle mouse drag for rotation (desktop testing)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_preview_rotation += event.relative.x * 0.5
		_preview_rotation = fmod(_preview_rotation, 360.0)
		if _preview_rotation < 0.0:
			_preview_rotation += 360.0
		_apply_rotation()


## Apply the current rotation to the preview model.
func _apply_rotation() -> void:
	if preview_model_root:
		preview_model_root.rotation_degrees.y = _preview_rotation


## Navigate to the previous character.
func _on_prev_pressed() -> void:
	_selected_index -= 1
	if _selected_index < 0:
		_selected_index = _characters_data.size() - 1
	_update_display()
	_begin_model_load()


## Navigate to the next character.
func _on_next_pressed() -> void:
	_selected_index += 1
	if _selected_index >= _characters_data.size():
		_selected_index = 0
	_update_display()
	_begin_model_load()


## Toggle between male and female variants.
func _on_variant_toggle_pressed() -> void:
	if _selected_variant == "MALE":
		_selected_variant = "FEMALE"
	else:
		_selected_variant = "MALE"
	_update_display()
	_begin_model_load()


## Confirm the current character selection.
func _on_confirm_pressed() -> void:
	var character_id := get_selected_character_id()

	# Persist the selection
	_persist_selection(character_id, _selected_variant)

	_confirmed_this_session = true
	character_confirmed.emit(character_id, _selected_variant)


## Go back without confirming (uses previously persisted selection).
func _on_back_pressed() -> void:
	back_pressed.emit()


## Retry loading the current character model.
func _on_retry_pressed() -> void:
	_begin_model_load()


## Select an alternate character when load fails.
func _on_alternate_pressed() -> void:
	# Move to next character and try loading
	_on_next_pressed()


## Persist the character selection to the ProgressStore.
func _persist_selection(character_id: String, variant: String) -> void:
	if _progress_store != null:
		_progress_store.save_character_selection(character_id, variant)


## Get the selection to use for a match (persisted or current).
## If player starts match without confirming, returns the previously persisted selection.
func get_match_selection() -> Dictionary:
	if _confirmed_this_session:
		return {"character": get_selected_character_id(), "variant": _selected_variant}

	# Use previously persisted selection
	if _progress_store != null:
		return _progress_store.get_character_selection()

	# Ultimate fallback
	return {"character": DEFAULT_CHARACTER, "variant": DEFAULT_VARIANT}


## Get the total number of available characters.
func get_character_count() -> int:
	return _characters_data.size()


## Get character data by index.
func get_character_at(index: int) -> Dictionary:
	if index >= 0 and index < _characters_data.size():
		return _characters_data[index]
	return {}


## Set selection programmatically (for testing or external control).
func set_selection(character_id: String, variant: String) -> void:
	_selected_index = _get_character_index(character_id)
	if variant == "MALE" or variant == "FEMALE":
		_selected_variant = variant
	else:
		_selected_variant = DEFAULT_VARIANT
	_update_display()
	_begin_model_load()
