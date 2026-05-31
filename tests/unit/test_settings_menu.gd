## Unit tests for SettingsMenu controller.
## Tests sub-section navigation, settings values, and back button behavior.
extends GutTest


var _settings_menu: SettingsMenu


func before_each() -> void:
	_settings_menu = SettingsMenu.new()
	add_child_autofree(_settings_menu)
	await get_tree().process_frame


func test_initial_section_is_main() -> void:
	assert_eq(_settings_menu.get_current_section(), SettingsMenu.Section.MAIN,
		"Initial section should be MAIN")


func test_back_from_main_emits_signal() -> void:
	watch_signals(_settings_menu)
	_settings_menu._current_section = SettingsMenu.Section.MAIN
	_settings_menu._on_back_pressed()
	assert_signal_emitted(_settings_menu, "back_pressed",
		"Back from main section should emit back_pressed signal")


func test_back_from_sub_section_returns_to_main() -> void:
	_settings_menu._show_section(SettingsMenu.Section.CONTROLS)
	assert_eq(_settings_menu.get_current_section(), SettingsMenu.Section.CONTROLS)

	_settings_menu._on_sub_back_pressed()
	assert_eq(_settings_menu.get_current_section(), SettingsMenu.Section.MAIN,
		"Back from sub-section should return to MAIN")


func test_navigate_to_controls() -> void:
	_settings_menu._on_controls_pressed()
	assert_eq(_settings_menu.get_current_section(), SettingsMenu.Section.CONTROLS,
		"Should navigate to CONTROLS section")


func test_navigate_to_graphics() -> void:
	_settings_menu._on_graphics_pressed()
	assert_eq(_settings_menu.get_current_section(), SettingsMenu.Section.GRAPHICS,
		"Should navigate to GRAPHICS section")


func test_navigate_to_audio() -> void:
	_settings_menu._on_audio_pressed()
	assert_eq(_settings_menu.get_current_section(), SettingsMenu.Section.AUDIO,
		"Should navigate to AUDIO section")


func test_navigate_to_account() -> void:
	_settings_menu._on_account_pressed()
	assert_eq(_settings_menu.get_current_section(), SettingsMenu.Section.ACCOUNT,
		"Should navigate to ACCOUNT section")


func test_sensitivity_clamped_to_valid_range() -> void:
	_settings_menu._on_sensitivity_changed(0.5)
	assert_eq(_settings_menu._sensitivity, 1.0,
		"Sensitivity below 1 should be clamped to 1.0")

	_settings_menu._on_sensitivity_changed(15.0)
	assert_eq(_settings_menu._sensitivity, 10.0,
		"Sensitivity above 10 should be clamped to 10.0")

	_settings_menu._on_sensitivity_changed(5.0)
	assert_eq(_settings_menu._sensitivity, 5.0,
		"Sensitivity within range should be accepted")


func test_fire_mode_tap_and_hold() -> void:
	_settings_menu._on_fire_mode_changed(0)
	assert_eq(_settings_menu._fire_mode, "TAP",
		"Index 0 should set fire mode to TAP")

	_settings_menu._on_fire_mode_changed(1)
	assert_eq(_settings_menu._fire_mode, "HOLD",
		"Index 1 should set fire mode to HOLD")


func test_graphics_quality_options() -> void:
	_settings_menu._on_quality_changed(0)
	assert_eq(_settings_menu._graphics_quality, "LOW",
		"Index 0 should set quality to LOW")

	_settings_menu._on_quality_changed(1)
	assert_eq(_settings_menu._graphics_quality, "MEDIUM",
		"Index 1 should set quality to MEDIUM")

	_settings_menu._on_quality_changed(2)
	assert_eq(_settings_menu._graphics_quality, "HIGH",
		"Index 2 should set quality to HIGH")


func test_music_volume_clamped() -> void:
	_settings_menu._on_music_volume_changed(-10.0)
	assert_eq(_settings_menu._music_volume, 0,
		"Music volume below 0 should be clamped to 0")

	_settings_menu._on_music_volume_changed(150.0)
	assert_eq(_settings_menu._music_volume, 100,
		"Music volume above 100 should be clamped to 100")

	_settings_menu._on_music_volume_changed(50.0)
	assert_eq(_settings_menu._music_volume, 50,
		"Music volume within range should be accepted")


func test_sfx_volume_clamped() -> void:
	_settings_menu._on_sfx_volume_changed(-5.0)
	assert_eq(_settings_menu._sfx_volume, 0,
		"SFX volume below 0 should be clamped to 0")

	_settings_menu._on_sfx_volume_changed(200.0)
	assert_eq(_settings_menu._sfx_volume, 100,
		"SFX volume above 100 should be clamped to 100")


func test_voice_volume_clamped() -> void:
	_settings_menu._on_voice_volume_changed(-1.0)
	assert_eq(_settings_menu._voice_volume, 0,
		"Voice volume below 0 should be clamped to 0")

	_settings_menu._on_voice_volume_changed(101.0)
	assert_eq(_settings_menu._voice_volume, 100,
		"Voice volume above 100 should be clamped to 100")


func test_get_settings_returns_current_values() -> void:
	_settings_menu._sensitivity = 7.5
	_settings_menu._fire_mode = "HOLD"
	_settings_menu._graphics_quality = "HIGH"
	_settings_menu._music_volume = 60
	_settings_menu._sfx_volume = 90
	_settings_menu._voice_volume = 40

	var settings := _settings_menu.get_settings()
	assert_eq(settings["sensitivity"], 7.5)
	assert_eq(settings["fire_mode"], "HOLD")
	assert_eq(settings["graphics_quality"], "HIGH")
	assert_eq(settings["music_volume"], 60)
	assert_eq(settings["sfx_volume"], 90)
	assert_eq(settings["voice_volume"], 40)


func test_default_settings_values() -> void:
	# Default values per design
	var settings := _settings_menu.get_settings()
	assert_eq(settings["sensitivity"], 5.0,
		"Default sensitivity should be 5.0")
	assert_eq(settings["fire_mode"], "TAP",
		"Default fire mode should be TAP")
	assert_eq(settings["graphics_quality"], "MEDIUM",
		"Default graphics quality should be MEDIUM")
	assert_eq(settings["music_volume"], 70,
		"Default music volume should be 70")
	assert_eq(settings["sfx_volume"], 80,
		"Default SFX volume should be 80")
	assert_eq(settings["voice_volume"], 80,
		"Default voice volume should be 80")
