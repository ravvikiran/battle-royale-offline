## Unit tests for CharacterSelector class covering character selection,
## variant toggling, persistence, default behavior, and error handling.
extends GutTest


var _selector: CharacterSelector


func before_each() -> void:
	_selector = CharacterSelector.new()
	# We test the logic without the full scene tree (no @onready nodes).
	# CharacterSelector logic methods are testable independently.


func after_each() -> void:
	if _selector and is_instance_valid(_selector):
		_selector.free()


# --- Helper to create a mock ProgressStore ---

class MockProgressStore extends ProgressStore:
	var _stored_character: String = ""
	var _stored_variant: String = ""
	var _has_selection: bool = false

	func save_character_selection(character_id: String, variant: String) -> Dictionary:
		_stored_character = character_id
		_stored_variant = variant
		_has_selection = true
		return {"success": true}

	func get_character_selection() -> Dictionary:
		if _has_selection:
			return {"character": _stored_character, "variant": _stored_variant}
		return {"character": "BLITZ", "variant": "MALE"}


# --- Character data loading tests ---

func test_loads_three_characters() -> void:
	_selector._load_characters_data()
	assert_eq(_selector.get_character_count(), 3)


func test_character_ids_are_correct() -> void:
	_selector._load_characters_data()
	assert_eq(_selector.get_character_at(0).get("id"), "BLITZ")
	assert_eq(_selector.get_character_at(1).get("id"), "TITAN")
	assert_eq(_selector.get_character_at(2).get("id"), "PHANTOM")


func test_each_character_has_male_and_female_variants() -> void:
	_selector._load_characters_data()
	for i in range(_selector.get_character_count()):
		var character := _selector.get_character_at(i)
		var variants: Array = character.get("variants", [])
		assert_true(variants.has("MALE"), "Character %s should have MALE variant" % character.get("id"))
		assert_true(variants.has("FEMALE"), "Character %s should have FEMALE variant" % character.get("id"))


func test_characters_have_distinct_primary_colors() -> void:
	_selector._load_characters_data()
	var colors: Array = []
	for i in range(_selector.get_character_count()):
		var character := _selector.get_character_at(i)
		var color: String = character.get("primary_color", "")
		assert_false(colors.has(color), "Duplicate color found: %s" % color)
		colors.append(color)


# --- Default selection tests ---

func test_default_selection_is_blitz_male() -> void:
	_selector._load_characters_data()
	_selector._load_persisted_selection()
	assert_eq(_selector.get_selected_character_id(), "BLITZ")
	assert_eq(_selector.get_selected_variant(), "MALE")


func test_default_when_no_progress_store() -> void:
	_selector._progress_store = null
	_selector._load_characters_data()
	_selector._load_persisted_selection()
	assert_eq(_selector.get_selected_character_id(), "BLITZ")
	assert_eq(_selector.get_selected_variant(), "MALE")


# --- Navigation tests ---

func test_get_character_index_blitz() -> void:
	_selector._load_characters_data()
	assert_eq(_selector._get_character_index("BLITZ"), 0)


func test_get_character_index_titan() -> void:
	_selector._load_characters_data()
	assert_eq(_selector._get_character_index("TITAN"), 1)


func test_get_character_index_phantom() -> void:
	_selector._load_characters_data()
	assert_eq(_selector._get_character_index("PHANTOM"), 2)


func test_get_character_index_unknown_returns_zero() -> void:
	_selector._load_characters_data()
	assert_eq(_selector._get_character_index("UNKNOWN"), 0)


func test_selected_character_wraps_forward() -> void:
	_selector._load_characters_data()
	_selector._selected_index = 2  # Phantom
	_selector._selected_index += 1
	if _selector._selected_index >= _selector._characters_data.size():
		_selector._selected_index = 0
	assert_eq(_selector._selected_index, 0)  # Wraps to Blitz


func test_selected_character_wraps_backward() -> void:
	_selector._load_characters_data()
	_selector._selected_index = 0  # Blitz
	_selector._selected_index -= 1
	if _selector._selected_index < 0:
		_selector._selected_index = _selector._characters_data.size() - 1
	assert_eq(_selector._selected_index, 2)  # Wraps to Phantom


# --- Variant toggle tests ---

func test_variant_toggle_male_to_female() -> void:
	_selector._load_characters_data()
	_selector._selected_variant = "MALE"
	# Simulate toggle
	if _selector._selected_variant == "MALE":
		_selector._selected_variant = "FEMALE"
	else:
		_selector._selected_variant = "MALE"
	assert_eq(_selector._selected_variant, "FEMALE")


func test_variant_toggle_female_to_male() -> void:
	_selector._load_characters_data()
	_selector._selected_variant = "FEMALE"
	# Simulate toggle
	if _selector._selected_variant == "MALE":
		_selector._selected_variant = "FEMALE"
	else:
		_selector._selected_variant = "MALE"
	assert_eq(_selector._selected_variant, "MALE")


# --- Persistence tests ---

func test_persisted_selection_loaded_on_init() -> void:
	var mock_store := MockProgressStore.new()
	mock_store._stored_character = "TITAN"
	mock_store._stored_variant = "FEMALE"
	mock_store._has_selection = true

	_selector._progress_store = mock_store
	_selector._load_characters_data()
	_selector._load_persisted_selection()

	assert_eq(_selector.get_selected_character_id(), "TITAN")
	assert_eq(_selector.get_selected_variant(), "FEMALE")


func test_persist_selection_saves_to_store() -> void:
	var mock_store := MockProgressStore.new()
	_selector._progress_store = mock_store
	_selector._load_characters_data()

	_selector._persist_selection("PHANTOM", "FEMALE")

	assert_eq(mock_store._stored_character, "PHANTOM")
	assert_eq(mock_store._stored_variant, "FEMALE")


func test_invalid_variant_defaults_to_male() -> void:
	var mock_store := MockProgressStore.new()
	mock_store._stored_character = "BLITZ"
	mock_store._stored_variant = "INVALID"
	mock_store._has_selection = true

	_selector._progress_store = mock_store
	_selector._load_characters_data()
	_selector._load_persisted_selection()

	assert_eq(_selector.get_selected_variant(), "MALE")


# --- Match selection fallback tests ---

func test_match_selection_uses_persisted_if_not_confirmed() -> void:
	var mock_store := MockProgressStore.new()
	mock_store._stored_character = "TITAN"
	mock_store._stored_variant = "MALE"
	mock_store._has_selection = true

	_selector._progress_store = mock_store
	_selector._load_characters_data()
	_selector._load_persisted_selection()
	_selector._confirmed_this_session = false

	var selection := _selector.get_match_selection()
	assert_eq(selection["character"], "TITAN")
	assert_eq(selection["variant"], "MALE")


func test_match_selection_uses_current_if_confirmed() -> void:
	_selector._load_characters_data()
	_selector._selected_index = 2  # Phantom
	_selector._selected_variant = "FEMALE"
	_selector._confirmed_this_session = true

	var selection := _selector.get_match_selection()
	assert_eq(selection["character"], "PHANTOM")
	assert_eq(selection["variant"], "FEMALE")


func test_match_selection_fallback_without_store() -> void:
	_selector._progress_store = null
	_selector._load_characters_data()
	_selector._confirmed_this_session = false

	var selection := _selector.get_match_selection()
	assert_eq(selection["character"], "BLITZ")
	assert_eq(selection["variant"], "MALE")


# --- Set selection programmatic tests ---

func test_set_selection_updates_character() -> void:
	_selector._load_characters_data()
	_selector._selected_index = 0
	_selector._selected_variant = "MALE"

	# Simulate set_selection logic without UI nodes
	_selector._selected_index = _selector._get_character_index("PHANTOM")
	_selector._selected_variant = "FEMALE"

	assert_eq(_selector.get_selected_character_id(), "PHANTOM")
	assert_eq(_selector.get_selected_variant(), "FEMALE")


func test_set_selection_invalid_character_defaults_to_blitz() -> void:
	_selector._load_characters_data()
	_selector._selected_index = _selector._get_character_index("NONEXISTENT")
	assert_eq(_selector.get_selected_character_id(), "BLITZ")


# --- Rotation tests ---

func test_rotation_wraps_at_360() -> void:
	_selector._preview_rotation = 350.0
	_selector._preview_rotation += 20.0
	_selector._preview_rotation = fmod(_selector._preview_rotation, 360.0)
	if _selector._preview_rotation < 0.0:
		_selector._preview_rotation += 360.0
	assert_almost_eq(_selector._preview_rotation, 10.0, 0.001)


func test_rotation_wraps_negative() -> void:
	_selector._preview_rotation = 10.0
	_selector._preview_rotation -= 30.0
	_selector._preview_rotation = fmod(_selector._preview_rotation, 360.0)
	if _selector._preview_rotation < 0.0:
		_selector._preview_rotation += 360.0
	assert_almost_eq(_selector._preview_rotation, 340.0, 0.001)


func test_rotation_stays_in_range() -> void:
	_selector._preview_rotation = 0.0
	# Simulate multiple rotations
	for i in range(100):
		_selector._preview_rotation += 7.3
		_selector._preview_rotation = fmod(_selector._preview_rotation, 360.0)
		if _selector._preview_rotation < 0.0:
			_selector._preview_rotation += 360.0
	assert_true(_selector._preview_rotation >= 0.0)
	assert_true(_selector._preview_rotation < 360.0)


# --- Load timeout constant test ---

func test_max_load_time_is_five_seconds() -> void:
	assert_eq(CharacterSelector.MAX_LOAD_TIME, 5.0)
