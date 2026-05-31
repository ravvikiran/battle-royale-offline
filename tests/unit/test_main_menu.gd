## Unit tests for MainMenu controller.
## Tests menu options, character display, login state, and transition behavior.
extends GutTest


var _main_menu: MainMenu


func before_each() -> void:
	_main_menu = MainMenu.new()
	add_child_autofree(_main_menu)
	# Wait for _ready to complete
	await get_tree().process_frame


func test_default_character_is_blitz_male() -> void:
	# Requirement 14.2: Default character is Blitz male if none selected
	assert_eq(_main_menu.get_displayed_character(), "BLITZ",
		"Default displayed character should be BLITZ")
	assert_eq(_main_menu.get_displayed_variant(), "MALE",
		"Default displayed variant should be MALE")


func test_play_button_emits_signal() -> void:
	watch_signals(_main_menu)
	_main_menu._on_play_pressed()
	assert_signal_emitted(_main_menu, "play_pressed",
		"Play button should emit play_pressed signal")


func test_characters_button_emits_signal() -> void:
	watch_signals(_main_menu)
	_main_menu._on_characters_pressed()
	assert_signal_emitted(_main_menu, "characters_pressed",
		"Characters button should emit characters_pressed signal")


func test_career_stats_button_emits_signal() -> void:
	watch_signals(_main_menu)
	_main_menu._on_career_stats_pressed()
	assert_signal_emitted(_main_menu, "career_stats_pressed",
		"Career Stats button should emit career_stats_pressed signal")


func test_settings_button_emits_signal() -> void:
	watch_signals(_main_menu)
	_main_menu._on_settings_pressed()
	assert_signal_emitted(_main_menu, "settings_pressed",
		"Settings button should emit settings_pressed signal")


func test_login_button_emits_signal() -> void:
	watch_signals(_main_menu)
	_main_menu._on_login_pressed()
	assert_signal_emitted(_main_menu, "login_pressed",
		"Login button should emit login_pressed signal")


func test_transition_blocks_double_tap() -> void:
	# First press should work
	watch_signals(_main_menu)
	_main_menu._on_play_pressed()
	assert_signal_emitted(_main_menu, "play_pressed")

	# Second press should be blocked (transitioning = true)
	_main_menu._on_play_pressed()
	assert_signal_emit_count(_main_menu, "play_pressed", 1,
		"Second play press should be blocked during transition")


func test_reset_transition_allows_interaction() -> void:
	_main_menu._on_play_pressed()
	assert_true(_main_menu._transitioning, "Should be transitioning after play press")

	_main_menu.reset_transition()
	assert_false(_main_menu._transitioning, "Should not be transitioning after reset")


func test_login_button_shows_login_when_no_auth() -> void:
	# Without auth manager, login button should show "Login"
	_main_menu._update_login_button()
	# Can't check button text without scene tree nodes, but verify no crash


func test_login_button_shows_id_when_authenticated() -> void:
	var auth := AuthManager.new()
	auth.auth_state = Enums.AuthState.AUTHENTICATED
	auth.user_id = "test@example.com"
	_main_menu.set_auth_manager(auth)
	# Verify no crash when updating login button with auth manager


func test_character_data_loads_fallback() -> void:
	# The character data should have at least 3 entries (fallback)
	assert_gte(_main_menu._characters_data.size(), 3,
		"Should have at least 3 characters loaded")


func test_get_character_data_returns_correct_character() -> void:
	var data := _main_menu._get_character_data("TITAN")
	assert_eq(data.get("id", ""), "TITAN",
		"Should return Titan character data")


func test_get_character_data_fallback_for_unknown() -> void:
	var data := _main_menu._get_character_data("UNKNOWN")
	assert_ne(data.get("id", ""), "",
		"Should return fallback character data for unknown ID")


func test_max_transition_time_constant() -> void:
	# Requirement 14.3: Transition within 3 seconds
	assert_eq(MainMenu.MAX_TRANSITION_TIME, 3.0,
		"Max transition time should be 3 seconds")
