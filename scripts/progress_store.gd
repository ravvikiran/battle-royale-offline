## Manages local progress persistence using SQLite database.
## Implements the ProgressStore interface with SQLite for reliable local storage.
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

## SQLite database instance
var _db: SQLite = null

## Database file path
var _db_path: String = ""

## Whether the store has been initialized
var _initialized: bool = false


## SQL schema for the player_profile table
const SCHEMA_PLAYER_PROFILE := """
CREATE TABLE IF NOT EXISTS player_profile (
	user_id TEXT PRIMARY KEY,
	auth_provider TEXT,
	selected_character TEXT DEFAULT 'BLITZ',
	selected_variant TEXT DEFAULT 'MALE',
	created_at TEXT,
	last_played_at TEXT
);
"""

## SQL schema for the match_history table
const SCHEMA_MATCH_HISTORY := """
CREATE TABLE IF NOT EXISTS match_history (
	match_id TEXT PRIMARY KEY,
	user_id TEXT NOT NULL,
	timestamp TEXT NOT NULL,
	placement INTEGER NOT NULL,
	total_participants INTEGER NOT NULL,
	kills INTEGER NOT NULL,
	damage_dealt REAL NOT NULL,
	survival_time_seconds INTEGER NOT NULL,
	character_name TEXT NOT NULL,
	character_variant TEXT NOT NULL,
	bot_difficulty TEXT NOT NULL,
	bot_count INTEGER NOT NULL,
	FOREIGN KEY (user_id) REFERENCES player_profile(user_id)
);
"""

## SQL schema for the settings table
const SCHEMA_SETTINGS := """
CREATE TABLE IF NOT EXISTS settings (
	user_id TEXT PRIMARY KEY,
	sensitivity REAL DEFAULT 5.0,
	fire_mode TEXT DEFAULT 'TAP',
	graphics_quality TEXT DEFAULT 'MEDIUM',
	music_volume INTEGER DEFAULT 70,
	sfx_volume INTEGER DEFAULT 80,
	voice_volume INTEGER DEFAULT 80,
	control_layout TEXT,
	FOREIGN KEY (user_id) REFERENCES player_profile(user_id)
);
"""


## Initializes the progress store for the given user.
## Opens or creates the SQLite database and validates data integrity.
## Returns a Dictionary with "success" (bool) and optionally "error" (String).
func initialize(user_id: String) -> Dictionary:
	if user_id.is_empty():
		return {"success": false, "error": "empty_user_id"}

	current_user_id = user_id
	_db_path = _get_db_path()

	# Open or create the database
	var open_result := _open_database()

	if not open_result:
		# Database could not be opened — validate integrity and recover
		var integrity_ok := validate_data_integrity()
		if not integrity_ok:
			_create_fresh_database()
			data_recovery_notification.emit("Previous progress data could not be recovered. Starting fresh.")
			# Try opening again after fresh creation
			open_result = _open_database()
			if not open_result:
				return {"success": false, "error": "database_open_failed"}
	else:
		# Database opened — validate integrity of existing data
		if not validate_data_integrity():
			_close_database()
			_create_fresh_database()
			data_recovery_notification.emit("Previous progress data could not be recovered. Starting fresh.")
			open_result = _open_database()
			if not open_result:
				return {"success": false, "error": "database_open_failed"}

	# Create tables if they don't exist
	_create_tables()

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

	# Attempt to insert into database
	var insert_ok := _insert_match_record(match_record)

	if not insert_ok:
		# Retain in unsaved_results for later retry
		unsaved_results.append(match_record)
		save_failed_notification.emit("Match results could not be saved. They will be retained until the next successful save.")
		return {"success": false, "error": "storage_write_failed"}

	# Update last_played_at
	_update_last_played(current_user_id)

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

	var query_result := _query_career_stats(current_user_id)
	return query_result


## Returns match history for the current user, limited to the specified count.
## Results are ordered by timestamp descending (most recent first).
func get_match_history(limit: int = 20) -> Array:
	if not _initialized or current_user_id.is_empty():
		return []

	return _query_match_history(current_user_id, limit)


## Migrates all progress data from a guest ID to an authenticated account ID.
## On failure, discards guest data and proceeds (login still succeeds).
## Returns a Dictionary with "success" (bool) and optionally "error" (String).
func migrate_guest_to_account(guest_id: String, account_id: String) -> Dictionary:
	if guest_id.is_empty() or account_id.is_empty():
		return {"success": false, "error": "invalid_ids"}

	if guest_id == account_id:
		return {"success": false, "error": "same_id"}

	# Perform migration within a transaction for atomicity
	var migration_ok := _perform_migration(guest_id, account_id)

	if not migration_ok:
		# On failure, discard guest progress
		return {"success": false, "error": "migration_save_failed"}

	# Update current user to the new account
	current_user_id = account_id

	return {"success": true}


## Validates the integrity of the stored data.
## Returns true if data is valid, false if corrupted.
## On failure, creates a new file and triggers recovery notification.
func validate_data_integrity() -> bool:
	if _db == null:
		# Try to open the database for validation
		var temp_db := SQLite.new()
		temp_db.path = _db_path
		if not temp_db.open_db():
			return false

		# Check that required tables exist
		var tables_valid := _validate_tables(temp_db)
		temp_db.close_db()
		return tables_valid

	# Validate with the existing connection
	return _validate_tables(_db)


## Saves the player's character selection to their profile.
func save_character_selection(character_id: String, variant: String) -> Dictionary:
	if not _initialized or current_user_id.is_empty():
		return {"success": false, "error": "not_initialized"}

	if not _profile_exists(current_user_id):
		return {"success": false, "error": "no_profile"}

	var query := "UPDATE player_profile SET selected_character = ?, selected_variant = ? WHERE user_id = ?;"
	var params := [character_id, variant, current_user_id]
	var success := _db.query_with_bindings(query, params)

	if not success:
		return {"success": false, "error": "save_failed"}

	return {"success": true}


## Loads the player's character selection from their profile.
func get_character_selection() -> Dictionary:
	if not _initialized or current_user_id.is_empty():
		return {"character": "BLITZ", "variant": "MALE"}

	var query := "SELECT selected_character, selected_variant FROM player_profile WHERE user_id = ?;"
	var success := _db.query_with_bindings(query, [current_user_id])

	if not success or _db.query_result.is_empty():
		return {"character": "BLITZ", "variant": "MALE"}

	var row: Dictionary = _db.query_result[0]
	return {
		"character": row.get("selected_character", "BLITZ"),
		"variant": row.get("selected_variant", "MALE")
	}


## Saves user settings.
func save_settings(settings_data: Dictionary) -> Dictionary:
	if not _initialized or current_user_id.is_empty():
		return {"success": false, "error": "not_initialized"}

	# Upsert settings for the current user
	var query := """INSERT OR REPLACE INTO settings
		(user_id, sensitivity, fire_mode, graphics_quality, music_volume, sfx_volume, voice_volume, control_layout)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?);"""

	var params := [
		current_user_id,
		settings_data.get("sensitivity", 5.0),
		settings_data.get("fire_mode", "TAP"),
		settings_data.get("graphics_quality", "MEDIUM"),
		settings_data.get("music_volume", 70),
		settings_data.get("sfx_volume", 80),
		settings_data.get("voice_volume", 80),
		settings_data.get("control_layout", "")
	]

	var success := _db.query_with_bindings(query, params)

	if not success:
		return {"success": false, "error": "save_failed"}

	return {"success": true}


## Loads user settings.
func get_settings() -> Dictionary:
	if not _initialized or current_user_id.is_empty():
		return _get_default_settings()

	var query := "SELECT * FROM settings WHERE user_id = ?;"
	var success := _db.query_with_bindings(query, [current_user_id])

	if not success or _db.query_result.is_empty():
		return _get_default_settings()

	var row: Dictionary = _db.query_result[0]
	return {
		"sensitivity": row.get("sensitivity", 5.0),
		"fire_mode": row.get("fire_mode", "TAP"),
		"graphics_quality": row.get("graphics_quality", "MEDIUM"),
		"music_volume": row.get("music_volume", 70),
		"sfx_volume": row.get("sfx_volume", 80),
		"voice_volume": row.get("voice_volume", 80),
		"control_layout": row.get("control_layout", "")
	}


# --- Private methods ---


## Returns the database file path.
func _get_db_path() -> String:
	return "user://progress_store.db"


## Opens the SQLite database. Returns true on success.
func _open_database() -> bool:
	_db = SQLite.new()
	_db.path = _db_path

	if not _db.open_db():
		_db = null
		return false

	# Enable WAL mode for better concurrent access and crash recovery
	_db.query("PRAGMA journal_mode=WAL;")
	# Enable foreign keys
	_db.query("PRAGMA foreign_keys=ON;")

	return true


## Closes the database connection.
func _close_database() -> void:
	if _db != null:
		_db.close_db()
		_db = null


## Creates all required tables if they don't exist.
func _create_tables() -> void:
	_db.query(SCHEMA_PLAYER_PROFILE)
	_db.query(SCHEMA_MATCH_HISTORY)
	_db.query(SCHEMA_SETTINGS)


## Checks if a player profile exists for the given user_id.
func _profile_exists(user_id: String) -> bool:
	var query := "SELECT COUNT(*) as count FROM player_profile WHERE user_id = ?;"
	var success := _db.query_with_bindings(query, [user_id])

	if not success or _db.query_result.is_empty():
		return false

	return int(_db.query_result[0].get("count", 0)) > 0


## Creates a new player profile.
func _create_profile(user_id: String, auth_provider: String) -> void:
	var timestamp := _get_timestamp()
	var query := """INSERT INTO player_profile
		(user_id, auth_provider, selected_character, selected_variant, created_at, last_played_at)
		VALUES (?, ?, 'BLITZ', 'MALE', ?, ?);"""

	_db.query_with_bindings(query, [user_id, auth_provider, timestamp, timestamp])


## Updates the last_played_at timestamp for a user.
func _update_last_played(user_id: String) -> void:
	var timestamp := _get_timestamp()
	var query := "UPDATE player_profile SET last_played_at = ? WHERE user_id = ?;"
	_db.query_with_bindings(query, [timestamp, user_id])


## Inserts a match record into the database. Returns true on success.
func _insert_match_record(record: Dictionary) -> bool:
	var query := """INSERT INTO match_history
		(match_id, user_id, timestamp, placement, total_participants, kills,
		 damage_dealt, survival_time_seconds, character_name, character_variant,
		 bot_difficulty, bot_count)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"""

	var params := [
		record["match_id"],
		record["user_id"],
		record["timestamp"],
		record["placement"],
		record["total_participants"],
		record["kills"],
		record["damage_dealt"],
		record["survival_time_seconds"],
		record["character_name"],
		record["character_variant"],
		record["bot_difficulty"],
		record["bot_count"]
	]

	return _db.query_with_bindings(query, params)


## Queries career stats for a specific user. All data is scoped to user_id.
func _query_career_stats(user_id: String) -> Dictionary:
	var query := """SELECT
		COUNT(*) as total_matches,
		COALESCE(SUM(CASE WHEN placement = 1 THEN 1 ELSE 0 END), 0) as wins,
		COALESCE(SUM(kills), 0) as total_kills
		FROM match_history WHERE user_id = ?;"""

	var success := _db.query_with_bindings(query, [user_id])

	if not success or _db.query_result.is_empty():
		return {
			"total_matches": 0,
			"wins": 0,
			"total_kills": 0,
			"avg_kills_per_match": 0.0,
			"win_rate": 0.0
		}

	var row: Dictionary = _db.query_result[0]
	var total_matches: int = int(row.get("total_matches", 0))
	var wins: int = int(row.get("wins", 0))
	var total_kills: int = int(row.get("total_kills", 0))

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


## Queries match history for a specific user, ordered by timestamp descending.
func _query_match_history(user_id: String, limit: int) -> Array:
	var query := "SELECT * FROM match_history WHERE user_id = ? ORDER BY timestamp DESC"

	if limit > 0:
		query += " LIMIT " + str(limit)

	query += ";"

	var success := _db.query_with_bindings(query, [user_id])

	if not success:
		return []

	return _db.query_result.duplicate()


## Performs the guest-to-account migration atomically.
## Moves all data from guest_id to account_id. On failure, discards guest data.
func _perform_migration(guest_id: String, account_id: String) -> bool:
	# Begin transaction
	_db.query("BEGIN TRANSACTION;")

	# Migrate player profile
	var profile_query := "SELECT * FROM player_profile WHERE user_id = ?;"
	_db.query_with_bindings(profile_query, [guest_id])

	if not _db.query_result.is_empty():
		var profile: Dictionary = _db.query_result[0]
		# Create or update account profile with guest's data
		var insert_query := """INSERT OR REPLACE INTO player_profile
			(user_id, auth_provider, selected_character, selected_variant, created_at, last_played_at)
			VALUES (?, 'authenticated', ?, ?, ?, ?);"""

		var params := [
			account_id,
			profile.get("selected_character", "BLITZ"),
			profile.get("selected_variant", "MALE"),
			profile.get("created_at", _get_timestamp()),
			profile.get("last_played_at", _get_timestamp())
		]

		if not _db.query_with_bindings(insert_query, params):
			_db.query("ROLLBACK;")
			return false

		# Delete guest profile
		if not _db.query_with_bindings("DELETE FROM player_profile WHERE user_id = ?;", [guest_id]):
			_db.query("ROLLBACK;")
			return false

	# Migrate match history — update user_id on all guest matches
	var update_query := "UPDATE match_history SET user_id = ? WHERE user_id = ?;"
	if not _db.query_with_bindings(update_query, [account_id, guest_id]):
		_db.query("ROLLBACK;")
		return false

	# Migrate settings
	var settings_query := "SELECT * FROM settings WHERE user_id = ?;"
	_db.query_with_bindings(settings_query, [guest_id])

	if not _db.query_result.is_empty():
		var settings: Dictionary = _db.query_result[0]
		var settings_insert := """INSERT OR REPLACE INTO settings
			(user_id, sensitivity, fire_mode, graphics_quality, music_volume, sfx_volume, voice_volume, control_layout)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?);"""

		var settings_params := [
			account_id,
			settings.get("sensitivity", 5.0),
			settings.get("fire_mode", "TAP"),
			settings.get("graphics_quality", "MEDIUM"),
			settings.get("music_volume", 70),
			settings.get("sfx_volume", 80),
			settings.get("voice_volume", 80),
			settings.get("control_layout", "")
		]

		if not _db.query_with_bindings(settings_insert, settings_params):
			_db.query("ROLLBACK;")
			return false

		# Delete guest settings
		if not _db.query_with_bindings("DELETE FROM settings WHERE user_id = ?;", [guest_id]):
			_db.query("ROLLBACK;")
			return false

	# Commit transaction
	if not _db.query("COMMIT;"):
		_db.query("ROLLBACK;")
		return false

	return true


## Validates that the required tables exist and have correct structure.
func _validate_tables(db: SQLite) -> bool:
	# Check player_profile table exists
	var success := db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='player_profile';")
	if not success or db.query_result.is_empty():
		return false

	# Check match_history table exists
	success = db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='match_history';")
	if not success or db.query_result.is_empty():
		return false

	# Check settings table exists
	success = db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='settings';")
	if not success or db.query_result.is_empty():
		return false

	# Validate match_history has required columns by querying table info
	success = db.query("PRAGMA table_info(match_history);")
	if not success or db.query_result.is_empty():
		return false

	var required_columns := ["match_id", "user_id", "timestamp", "placement",
		"total_participants", "kills", "damage_dealt", "survival_time_seconds",
		"character_name", "character_variant", "bot_difficulty", "bot_count"]

	var found_columns: Array = []
	for col_info in db.query_result:
		found_columns.append(col_info.get("name", ""))

	for required_col in required_columns:
		if required_col not in found_columns:
			return false

	# Validate player_profile has required columns
	success = db.query("PRAGMA table_info(player_profile);")
	if not success or db.query_result.is_empty():
		return false

	var required_profile_columns := ["user_id", "auth_provider", "selected_character",
		"selected_variant", "created_at", "last_played_at"]

	found_columns = []
	for col_info in db.query_result:
		found_columns.append(col_info.get("name", ""))

	for required_col in required_profile_columns:
		if required_col not in found_columns:
			return false

	return true


## Creates a fresh database by deleting the existing file.
func _create_fresh_database() -> void:
	_close_database()

	# Delete the existing database file
	if FileAccess.file_exists(_db_path):
		DirAccess.remove_absolute(_db_path)

	# Also remove WAL and SHM files if they exist
	var wal_path := _db_path + "-wal"
	var shm_path := _db_path + "-shm"
	if FileAccess.file_exists(wal_path):
		DirAccess.remove_absolute(wal_path)
	if FileAccess.file_exists(shm_path):
		DirAccess.remove_absolute(shm_path)


## Attempts to flush previously unsaved results to the database.
func _flush_unsaved_results() -> void:
	var still_unsaved: Array = []

	for record in unsaved_results:
		if not _insert_match_record(record):
			still_unsaved.append(record)

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
