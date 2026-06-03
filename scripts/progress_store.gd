## Manages local progress persistence using JSON files.
## Implements the ProgressStore with JSON for reliable local storage without plugins.
## All queries are scoped to the current user_id for data isolation.
class_name ProgressStore
extends RefCounted


## Signal emitted when data recovery notification should be shown to the player
signal data_recovery_notification(message: String)

## Signal emitted when a save failure notification should be shown
signal save_failed_notification(message: String)


## Current user identifier — all operations are scoped to this ID
var current_user_id: String = ""

## Unsaved match results retained in memory on save failure
var unsaved_results: Array = []

## In-memory data store
var _data: Dictionary = {}

## Data file path
var _data_path: String = ""

## Whether the store has been initialized
var _initialized: bool = false


## Default data structure
const DEFAULT_DATA := {
	"profiles": {},
	"match_history": [],
	"settings": {}
}


## Initializes the progress store for the given user.
## Opens or creates the JSON data file and validates data integrity.
## Returns a Dictionary with "success" (bool) and optionally "error" (String).
func initialize(user_id: String) -> Dictionary:
	if user_id.is_empty():
		return {"success": false, "error": "empty_user_id"}

	current_user_id = user_id
	_data_path = _get_data_path()

	# Load or create the data file
	var load_result := _load_data()

	if not load_result:
		# Data could not be loaded — validate integrity and recover
		var integrity_ok := validate_data_integrity()
		if not integrity_ok:
			_create_fresh_data()
			data_recovery_notification.emit("Previous progress data could not be recovered. Starting fresh.")
	else:
		# Data loaded — validate integrity of existing data
		if not validate_data_integrity():
			_create_fresh_data()
			data_recovery_notification.emit("Previous progress data could not be recovered. Starting fresh.")

	# Ensure player profile exists for this user
	if not _profile_exists(current_user_id):
		_create_profile(current_user_id, "guest")

	_initialized = true
	return {"success": true}


## Saves a match result to the progress store.
## On failure, retains the unsaved result in memory for later retry.
## Returns a Dictionary with "success" (bool) and optionally "error" (String).
func save_match_result(result: Dictionary) -> Dictionary:
	if not _initialized:
		return {"success": false, "error": "not_initialized"}

	if current_user_id.is_empty():
		return {"success": false, "error": "no_user_id"}

	# Validate required fields
	var required_fields := ["match_id", "timestamp", "placement", "total_participants",
		"kills", "damage_dealt", "survival_time_seconds", "character_name",
		"character_variant", "bot_difficulty", "bot_count"]

	for field in required_fields:
		if not result.has(field):
			return {"success": false, "error": "missing_field_" + field}

	# Build the match record scoped to current user
	var match_record := {
		"match_id": result["match_id"],
		"user_id": current_user_id,
		"timestamp": result["timestamp"],
		"placement": int(result["placement"]),
		"total_participants": int(result["total_participants"]),
		"kills": int(result["kills"]),
		"damage_dealt": float(result["damage_dealt"]),
		"survival_time_seconds": int(result["survival_time_seconds"]),
		"character_name": str(result["character_name"]),
		"character_variant": str(result["character_variant"]),
		"bot_difficulty": str(result["bot_difficulty"]),
		"bot_count": int(result["bot_count"])
	}

	# Add to match history
	if not _data.has("match_history"):
		_data["match_history"] = []
	_data["match_history"].append(match_record)

	# Update last_played_at
	_update_last_played(current_user_id)

	# Save to disk
	var save_ok := _save_data()

	if not save_ok:
		# Retain in unsaved_results for later retry
		unsaved_results.append(match_record)
		save_failed_notification.emit("Match results could not be saved. They will be retained until the next successful save.")
		return {"success": false, "error": "storage_write_failed"}

	# If save succeeded, also try to flush any previously unsaved results
	if unsaved_results.size() > 0:
		_flush_unsaved_results()

	return {"success": true}


## Computes and returns career statistics for the current user.
## Returns: { total_matches, wins, total_kills, avg_kills_per_match, win_rate }
func get_career_stats() -> Dictionary:
	if not _initialized or current_user_id.is_empty():
		return {
			"total_matches": 0,
			"wins": 0,
			"total_kills": 0,
			"avg_kills_per_match": 0.0,
			"win_rate": 0.0
		}

	return _compute_career_stats(current_user_id)


## Returns match history for the current user, limited to the specified count.
## Results are ordered by timestamp descending (most recent first).
func get_match_history(limit: int = 20) -> Array:
	if not _initialized or current_user_id.is_empty():
		return []

	var history: Array = _data.get("match_history", [])
	var user_history: Array = []

	for record in history:
		if record.get("user_id", "") == current_user_id:
			user_history.append(record)

	# Sort by timestamp descending
	user_history.sort_custom(func(a, b): return a.get("timestamp", "") > b.get("timestamp", ""))

	# Apply limit
	if limit > 0 and user_history.size() > limit:
		user_history.resize(limit)

	return user_history


## Migrates all progress data from a guest ID to an authenticated account ID.
## On failure, discards guest data and proceeds (login still succeeds).
## Returns a Dictionary with "success" (bool) and optionally "error" (String).
func migrate_guest_to_account(guest_id: String, account_id: String) -> Dictionary:
	if guest_id.is_empty() or account_id.is_empty():
		return {"success": false, "error": "invalid_ids"}

	if guest_id == account_id:
		return {"success": false, "error": "same_id"}

	# Migrate profile
	var profiles: Dictionary = _data.get("profiles", {})
	if profiles.has(guest_id):
		var guest_profile: Dictionary = profiles[guest_id].duplicate()
		guest_profile["auth_provider"] = "authenticated"
		profiles[account_id] = guest_profile
		profiles.erase(guest_id)
		_data["profiles"] = profiles

	# Migrate match history — update user_id on all guest matches
	var history: Array = _data.get("match_history", [])
	for i in range(history.size()):
		if history[i].get("user_id", "") == guest_id:
			history[i]["user_id"] = account_id
	_data["match_history"] = history

	# Migrate settings
	var settings: Dictionary = _data.get("settings", {})
	if settings.has(guest_id):
		settings[account_id] = settings[guest_id].duplicate()
		settings.erase(guest_id)
		_data["settings"] = settings

	# Save changes
	var save_ok := _save_data()
	if not save_ok:
		return {"success": false, "error": "migration_save_failed"}

	# Update current user to the new account
	current_user_id = account_id

	return {"success": true}


## Validates the integrity of the stored data.
## Returns true if data is valid, false if corrupted.
func validate_data_integrity() -> bool:
	if _data.is_empty():
		return false

	# Check that required top-level keys exist
	if not _data.has("profiles"):
		return false
	if not _data.has("match_history"):
		return false
	if not _data.has("settings"):
		return false

	# Check that profiles is a Dictionary
	if not (_data["profiles"] is Dictionary):
		return false

	# Check that match_history is an Array
	if not (_data["match_history"] is Array):
		return false

	# Check that settings is a Dictionary
	if not (_data["settings"] is Dictionary):
		return false

	# Validate match_history records have required fields
	var required_columns := ["match_id", "user_id", "timestamp", "placement",
		"total_participants", "kills", "damage_dealt", "survival_time_seconds",
		"character_name", "character_variant", "bot_difficulty", "bot_count"]

	for record in _data["match_history"]:
		if not (record is Dictionary):
			return false
		for col in required_columns:
			if not record.has(col):
				return false

	return true


## Saves the player's character selection to their profile.
func save_character_selection(character_id: String, variant: String) -> Dictionary:
	if not _initialized or current_user_id.is_empty():
		return {"success": false, "error": "not_initialized"}

	var profiles: Dictionary = _data.get("profiles", {})
	if not profiles.has(current_user_id):
		return {"success": false, "error": "no_profile"}

	profiles[current_user_id]["selected_character"] = character_id
	profiles[current_user_id]["selected_variant"] = variant
	_data["profiles"] = profiles

	var save_ok := _save_data()
	if not save_ok:
		return {"success": false, "error": "save_failed"}

	return {"success": true}


## Loads the player's character selection from their profile.
func get_character_selection() -> Dictionary:
	if not _initialized or current_user_id.is_empty():
		return {"character": "BLITZ", "variant": "MALE"}

	var profiles: Dictionary = _data.get("profiles", {})
	if not profiles.has(current_user_id):
		return {"character": "BLITZ", "variant": "MALE"}

	var profile: Dictionary = profiles[current_user_id]
	return {
		"character": profile.get("selected_character", "BLITZ"),
		"variant": profile.get("selected_variant", "MALE")
	}


## Saves user settings.
func save_settings(settings_data: Dictionary) -> Dictionary:
	if not _initialized or current_user_id.is_empty():
		return {"success": false, "error": "not_initialized"}

	var settings: Dictionary = _data.get("settings", {})
	settings[current_user_id] = {
		"sensitivity": settings_data.get("sensitivity", 5.0),
		"fire_mode": settings_data.get("fire_mode", "TAP"),
		"graphics_quality": settings_data.get("graphics_quality", "MEDIUM"),
		"music_volume": settings_data.get("music_volume", 70),
		"sfx_volume": settings_data.get("sfx_volume", 80),
		"voice_volume": settings_data.get("voice_volume", 80),
		"control_layout": settings_data.get("control_layout", "")
	}
	_data["settings"] = settings

	var save_ok := _save_data()
	if not save_ok:
		return {"success": false, "error": "save_failed"}

	return {"success": true}


## Loads user settings.
func get_settings() -> Dictionary:
	if not _initialized or current_user_id.is_empty():
		return _get_default_settings()

	var settings: Dictionary = _data.get("settings", {})
	if not settings.has(current_user_id):
		return _get_default_settings()

	var user_settings: Dictionary = settings[current_user_id]
	return {
		"sensitivity": user_settings.get("sensitivity", 5.0),
		"fire_mode": user_settings.get("fire_mode", "TAP"),
		"graphics_quality": user_settings.get("graphics_quality", "MEDIUM"),
		"music_volume": user_settings.get("music_volume", 70),
		"sfx_volume": user_settings.get("sfx_volume", 80),
		"voice_volume": user_settings.get("voice_volume", 80),
		"control_layout": user_settings.get("control_layout", "")
	}


# --- Private methods ---


## Returns the data file path.
func _get_data_path() -> String:
	return "user://progress_store.json"


## Loads data from the JSON file. Returns true on success.
func _load_data() -> bool:
	if not FileAccess.file_exists(_data_path):
		# No file yet — create fresh data
		_create_fresh_data()
		return true

	var file := FileAccess.open(_data_path, FileAccess.READ)
	if file == null:
		return false

	var content := file.get_as_text()
	file.close()

	if content.is_empty():
		_create_fresh_data()
		return true

	var json := JSON.new()
	var error := json.parse(content)
	if error != OK:
		return false

	var parsed = json.data
	if not (parsed is Dictionary):
		return false

	_data = parsed
	return true


## Saves data to the JSON file. Returns true on success.
func _save_data() -> bool:
	var file := FileAccess.open(_data_path, FileAccess.WRITE)
	if file == null:
		return false

	var json_string := JSON.stringify(_data, "\t")
	file.store_string(json_string)
	file.close()
	return true


## Creates a fresh empty data structure.
func _create_fresh_data() -> void:
	_data = {
		"profiles": {},
		"match_history": [],
		"settings": {}
	}
	_save_data()


## Checks if a player profile exists for the given user_id.
func _profile_exists(user_id: String) -> bool:
	var profiles: Dictionary = _data.get("profiles", {})
	return profiles.has(user_id)


## Creates a new player profile.
func _create_profile(user_id: String, auth_provider: String) -> void:
	var timestamp := _get_timestamp()
	var profiles: Dictionary = _data.get("profiles", {})
	profiles[user_id] = {
		"user_id": user_id,
		"auth_provider": auth_provider,
		"selected_character": "BLITZ",
		"selected_variant": "MALE",
		"created_at": timestamp,
		"last_played_at": timestamp
	}
	_data["profiles"] = profiles
	_save_data()


## Updates the last_played_at timestamp for a user.
func _update_last_played(user_id: String) -> void:
	var profiles: Dictionary = _data.get("profiles", {})
	if profiles.has(user_id):
		profiles[user_id]["last_played_at"] = _get_timestamp()
		_data["profiles"] = profiles


## Computes career stats for a specific user.
func _compute_career_stats(user_id: String) -> Dictionary:
	var history: Array = _data.get("match_history", [])
	var total_matches: int = 0
	var wins: int = 0
	var total_kills: int = 0

	for record in history:
		if record.get("user_id", "") == user_id:
			total_matches += 1
			total_kills += int(record.get("kills", 0))
			if int(record.get("placement", 0)) == 1:
				wins += 1

	var avg_kills_per_match: float = 0.0
	var win_rate: float = 0.0

	if total_matches > 0:
		avg_kills_per_match = float(total_kills) / float(total_matches)
		win_rate = snapped(float(wins) / float(total_matches) * 100.0, 0.1)

	return {
		"total_matches": total_matches,
		"wins": wins,
		"total_kills": total_kills,
		"avg_kills_per_match": avg_kills_per_match,
		"win_rate": win_rate
	}


## Attempts to flush previously unsaved results.
func _flush_unsaved_results() -> void:
	var still_unsaved: Array = []

	for record in unsaved_results:
		if not _data.has("match_history"):
			_data["match_history"] = []
		_data["match_history"].append(record)

	var save_ok := _save_data()
	if not save_ok:
		still_unsaved = unsaved_results.duplicate()

	unsaved_results = still_unsaved


## Returns the current timestamp as an ISO-8601 string.
func _get_timestamp() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		datetime["year"], datetime["month"], datetime["day"],
		datetime["hour"], datetime["minute"], datetime["second"]
	]


## Returns default settings.
func _get_default_settings() -> Dictionary:
	return {
		"sensitivity": 5.0,
		"fire_mode": "TAP",
		"graphics_quality": "MEDIUM",
		"music_volume": 70,
		"sfx_volume": 80,
		"voice_volume": 80,
		"control_layout": ""
	}
