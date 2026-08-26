## Analytics-ready event tracking system.
## Records game events locally for future backend integration.
## All events are timestamped and queued for batch processing.
## Designed to be non-blocking and memory-efficient.
class_name AnalyticsTracker
extends RefCounted


## Event queue for batch writing
var _event_queue: Array = []

## Session ID for the current play session
var session_id: String = ""

## Session start time
var session_start_time: float = 0.0

## Total events recorded this session
var events_this_session: int = 0

## Whether the tracker is active
var _active: bool = true

## Maximum queue size before auto-flush
const MAX_QUEUE_SIZE: int = 100

## Event flush interval (seconds) — in a real implementation, flush to server
const FLUSH_INTERVAL: float = 30.0


func _init() -> void:
	session_id = _generate_session_id()
	session_start_time = Time.get_unix_time_from_system()


## Tracks a game event
func track_event(event_type: Enums.AnalyticsEvent, properties: Dictionary = {}) -> void:
	if not _active:
		return

	var event: Dictionary = {
		"event_type": event_type,
		"session_id": session_id,
		"timestamp": Time.get_unix_time_from_system(),
		"properties": properties
	}

	_event_queue.append(event)
	events_this_session += 1

	# Auto-flush if queue is large
	if _event_queue.size() >= MAX_QUEUE_SIZE:
		flush()


## Tracks match start event
func track_match_start(settings: Dictionary) -> void:
	track_event(Enums.AnalyticsEvent.MATCH_START, {
		"bot_count": settings.get("bot_count", 50),
		"difficulty": settings.get("bot_difficulty", 1),
		"zone_speed": settings.get("zone_speed", 1),
		"character": settings.get("character", "BLITZ")
	})


## Tracks match end event with comprehensive data
func track_match_end(result: Dictionary) -> void:
	track_event(Enums.AnalyticsEvent.MATCH_END, {
		"placement": result.get("placement", 0),
		"kills": result.get("kills", 0),
		"damage_dealt": result.get("damage_dealt", 0.0),
		"survival_time": result.get("survival_time_seconds", 0),
		"character": result.get("character", ""),
		"difficulty": result.get("bot_difficulty", ""),
		"match_duration": result.get("survival_time_seconds", 0),
		"is_victory": result.get("placement", 0) == 1
	})


## Tracks an elimination event
func track_elimination(killer_id: int, victim_id: int, weapon: String) -> void:
	track_event(Enums.AnalyticsEvent.ELIMINATION, {
		"killer_id": killer_id,
		"victim_id": victim_id,
		"weapon": weapon,
		"is_player_kill": killer_id == -100
	})


## Tracks achievement unlock
func track_achievement_unlock(achievement_id: String) -> void:
	track_event(Enums.AnalyticsEvent.ACHIEVEMENT_UNLOCK, {
		"achievement_id": achievement_id
	})


## Tracks level up
func track_level_up(new_level: int) -> void:
	track_event(Enums.AnalyticsEvent.LEVEL_UP, {
		"new_level": new_level
	})


## Tracks challenge completion
func track_challenge_complete(challenge_id: String, challenge_type: String) -> void:
	track_event(Enums.AnalyticsEvent.CHALLENGE_COMPLETE, {
		"challenge_id": challenge_id,
		"challenge_type": challenge_type
	})


## Tracks session start
func track_session_start() -> void:
	track_event(Enums.AnalyticsEvent.SESSION_START, {
		"session_id": session_id
	})


## Tracks session end
func track_session_end() -> void:
	var duration: float = Time.get_unix_time_from_system() - session_start_time
	track_event(Enums.AnalyticsEvent.SESSION_END, {
		"session_id": session_id,
		"duration_seconds": int(duration),
		"events_count": events_this_session
	})
	flush()


## Flushes the event queue (writes to local file or sends to backend)
func flush() -> void:
	if _event_queue.is_empty():
		return

	# In a real implementation, this would send to a backend service.
	# For offline mode, we write to a local analytics file.
	var file := FileAccess.open("user://analytics_events.jsonl", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("user://analytics_events.jsonl", FileAccess.WRITE)
	if file != null:
		file.seek_end()
		for event in _event_queue:
			file.store_line(JSON.stringify(event))
		file.close()

	_event_queue.clear()


## Returns session duration so far
func get_session_duration() -> float:
	return Time.get_unix_time_from_system() - session_start_time


## Generates a unique session ID
func _generate_session_id() -> String:
	var time_part: String = str(int(Time.get_unix_time_from_system()))
	var rand_part: String = str(randi())
	return time_part + "_" + rand_part


## Enables/disables tracking
func set_active(active: bool) -> void:
	_active = active
