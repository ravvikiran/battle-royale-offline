## Settings screen UI controller.
## Provides sub-sections: Controls, Graphics, Audio, Account.
## Implements back button navigation on all sub-screens.
## Applies consistent blocky cartoon art style, color palette, and font.
class_name SettingsMenu
extends Control


## Emitted when the player presses the back button.
signal back_pressed

## Emitted when settings are saved.
signal settings_saved(settings: Dictionary)


## Sub-section identifiers.
enum Section {
	MAIN,
	CONTROLS,
	GRAPHICS,
	AUDIO,
	ACCOUNT
}

## Current active section.
var _current_section: Section = Section.MAIN

## Reference to the ProgressStore for loading/saving settings.
var _progress_store: ProgressStore = null

## Reference to the AuthManager for account section.
var _auth_manager: AuthManager = null

## Current settings state.
var _sensitivity: float = 5.0
var _fire_mode: String = "TAP"
var _graphics_quality: String = "MEDIUM"
var _music_volume: int = 70
var _sfx_volume: int = 80
var _voice_volume: int = 80


## UI node references — Main section.
@onready var back_button: Button = %BackButton
@onready var title_label: Label = %TitleLabel
@onready var controls_button: Button = %ControlsButton
@onready var graphics_button: Button = %GraphicsButton
@onready var audio_button: Button = %AudioButton
@onready var account_button: Button = %AccountButton

## UI node references — Section containers.
@onready var main_section: VBoxContainer = %MainSection
@onready var controls_section: VBoxContainer = %ControlsSection
@onready var graphics_section: VBoxContainer = %GraphicsSection
@onready var audio_section: VBoxContainer = %AudioSection
@onready var account_section: VBoxContainer = %AccountSection

## UI node references — Controls sub-section.
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_label: Label = %SensitivityLabel
@onready var fire_mode_option: OptionButton = %FireModeOption
@onready var controls_back_button: Button = %ControlsBackButton

## UI node references — Graphics sub-section.
@onready var quality_option: OptionButton = %QualityOption
@onready var graphics_back_button: Button = %GraphicsBackButton

## UI node references — Audio sub-section.
@onready var music_slider: HSlider = %MusicSlider
@onready var music_label: Label = %MusicLabel
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_label: Label = %SfxLabel
@onready var voice_slider: HSlider = %VoiceSlider
@onready var voice_label: Label = %VoiceLabel
@onready var audio_back_button: Button = %AudioBackButton

## UI node references — Account sub-section.
@onready var account_status_label: Label = %AccountStatusLabel
@onready var account_id_label: Label = %AccountIdLabel
@onready var account_back_button: Button = %AccountBackButton


func _ready() -> void:
	_setup_ui()
	_load_settings()
	_show_section(Section.MAIN)


## Inject the ProgressStore dependency.
func set_progress_store(store: ProgressStore) -> void:
	_progress_store = store
	_load_settings()


## Inject the AuthManager dependency.
func set_auth_manager(manager: AuthManager) -> void:
	_auth_manager = manager
	_update_account_display()


## Set up UI elements and connect signals.
func _setup_ui() -> void:
	# Main section buttons
	back_button.pressed.connect(_on_back_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	graphics_button.pressed.connect(_on_graphics_pressed)
	audio_button.pressed.connect(_on_audio_pressed)
	account_button.pressed.connect(_on_account_pressed)

	# Controls sub-section
	sensitivity_slider.min_value = 1.0
	sensitivity_slider.max_value = 10.0
	sensitivity_slider.step = 0.5
	sensitivity_slider.value = _sensitivity
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	fire_mode_option.clear()
	fire_mode_option.add_item("Tap to Shoot", 0)
	fire_mode_option.add_item("Hold to Shoot", 1)
	fire_mode_option.item_selected.connect(_on_fire_mode_changed)
	controls_back_button.pressed.connect(_on_sub_back_pressed)

	# Graphics sub-section
	quality_option.clear()
	quality_option.add_item("Low", 0)
	quality_option.add_item("Medium", 1)
	quality_option.add_item("High", 2)
	quality_option.item_selected.connect(_on_quality_changed)
	graphics_back_button.pressed.connect(_on_sub_back_pressed)

	# Audio sub-section
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.step = 1
	music_slider.value = _music_volume
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.step = 1
	sfx_slider.value = _sfx_volume
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	voice_slider.min_value = 0
	voice_slider.max_value = 100
	voice_slider.step = 1
	voice_slider.value = _voice_volume
	voice_slider.value_changed.connect(_on_voice_volume_changed)
	audio_back_button.pressed.connect(_on_sub_back_pressed)

	# Account sub-section
	account_back_button.pressed.connect(_on_sub_back_pressed)


## Load settings from the ProgressStore.
func _load_settings() -> void:
	if _progress_store == null:
		return

	var settings := _progress_store.get_settings()
	_sensitivity = clampf(float(settings.get("sensitivity", 5.0)), 1.0, 10.0)
	_fire_mode = settings.get("fire_mode", "TAP")
	_graphics_quality = settings.get("graphics_quality", "MEDIUM")
	_music_volume = clampi(int(settings.get("music_volume", 70)), 0, 100)
	_sfx_volume = clampi(int(settings.get("sfx_volume", 80)), 0, 100)
	_voice_volume = clampi(int(settings.get("voice_volume", 80)), 0, 100)

	_apply_settings_to_ui()


## Apply current settings values to UI elements.
func _apply_settings_to_ui() -> void:
	sensitivity_slider.value = _sensitivity
	sensitivity_label.text = "Sensitivity: %.1f" % _sensitivity

	if _fire_mode == "HOLD":
		fire_mode_option.selected = 1
	else:
		fire_mode_option.selected = 0

	match _graphics_quality:
		"LOW":
			quality_option.selected = 0
		"MEDIUM":
			quality_option.selected = 1
		"HIGH":
			quality_option.selected = 2
		_:
			quality_option.selected = 1

	music_slider.value = _music_volume
	music_label.text = "Music: %d" % _music_volume
	sfx_slider.value = _sfx_volume
	sfx_label.text = "SFX: %d" % _sfx_volume
	voice_slider.value = _voice_volume
	voice_label.text = "Voice: %d" % _voice_volume


## Update the account section display.
func _update_account_display() -> void:
	if _auth_manager == null:
		account_status_label.text = "Status: Guest"
		account_id_label.text = "ID: Not available"
		return

	if _auth_manager.auth_state == Enums.AuthState.AUTHENTICATED:
		account_status_label.text = "Status: Authenticated"
		account_id_label.text = "ID: %s" % _auth_manager.user_id
	else:
		account_status_label.text = "Status: Guest"
		var display_id := _auth_manager.user_id
		if display_id.length() > 20:
			display_id = display_id.substr(0, 18) + "..."
		account_id_label.text = "ID: %s" % display_id


## Show the specified section and hide all others.
func _show_section(section: Section) -> void:
	_current_section = section
	main_section.visible = section == Section.MAIN
	controls_section.visible = section == Section.CONTROLS
	graphics_section.visible = section == Section.GRAPHICS
	audio_section.visible = section == Section.AUDIO
	account_section.visible = section == Section.ACCOUNT

	match section:
		Section.MAIN:
			title_label.text = "SETTINGS"
		Section.CONTROLS:
			title_label.text = "CONTROLS"
		Section.GRAPHICS:
			title_label.text = "GRAPHICS"
		Section.AUDIO:
			title_label.text = "AUDIO"
		Section.ACCOUNT:
			title_label.text = "ACCOUNT"


## Save current settings to the ProgressStore.
func _save_settings() -> void:
	if _progress_store == null:
		return

	var settings := {
		"sensitivity": _sensitivity,
		"fire_mode": _fire_mode,
		"graphics_quality": _graphics_quality,
		"music_volume": _music_volume,
		"sfx_volume": _sfx_volume,
		"voice_volume": _voice_volume,
		"control_layout": ""
	}

	_progress_store.save_settings(settings)
	settings_saved.emit(settings)


## Called when the main back button is pressed.
func _on_back_pressed() -> void:
	if _current_section == Section.MAIN:
		back_pressed.emit()
	else:
		_show_section(Section.MAIN)


## Called when a sub-section back button is pressed.
func _on_sub_back_pressed() -> void:
	_save_settings()
	_show_section(Section.MAIN)


## Navigate to Controls sub-section.
func _on_controls_pressed() -> void:
	_show_section(Section.CONTROLS)


## Navigate to Graphics sub-section.
func _on_graphics_pressed() -> void:
	_show_section(Section.GRAPHICS)


## Navigate to Audio sub-section.
func _on_audio_pressed() -> void:
	_show_section(Section.AUDIO)


## Navigate to Account sub-section.
func _on_account_pressed() -> void:
	_update_account_display()
	_show_section(Section.ACCOUNT)


## Called when sensitivity slider changes.
func _on_sensitivity_changed(value: float) -> void:
	_sensitivity = clampf(value, 1.0, 10.0)
	sensitivity_label.text = "Sensitivity: %.1f" % _sensitivity


## Called when fire mode option changes.
func _on_fire_mode_changed(index: int) -> void:
	if index == 1:
		_fire_mode = "HOLD"
	else:
		_fire_mode = "TAP"


## Called when graphics quality option changes.
func _on_quality_changed(index: int) -> void:
	match index:
		0:
			_graphics_quality = "LOW"
		1:
			_graphics_quality = "MEDIUM"
		2:
			_graphics_quality = "HIGH"


## Called when music volume slider changes.
func _on_music_volume_changed(value: float) -> void:
	_music_volume = clampi(int(value), 0, 100)
	music_label.text = "Music: %d" % _music_volume


## Called when SFX volume slider changes.
func _on_sfx_volume_changed(value: float) -> void:
	_sfx_volume = clampi(int(value), 0, 100)
	sfx_label.text = "SFX: %d" % _sfx_volume


## Called when voice volume slider changes.
func _on_voice_volume_changed(value: float) -> void:
	_voice_volume = clampi(int(value), 0, 100)
	voice_label.text = "Voice: %d" % _voice_volume


## Get current settings as a dictionary.
func get_settings() -> Dictionary:
	return {
		"sensitivity": _sensitivity,
		"fire_mode": _fire_mode,
		"graphics_quality": _graphics_quality,
		"music_volume": _music_volume,
		"sfx_volume": _sfx_volume,
		"voice_volume": _voice_volume
	}


## Get the current section.
func get_current_section() -> Section:
	return _current_section
