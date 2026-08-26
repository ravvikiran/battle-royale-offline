## Manages XP accumulation, level progression, and level-up rewards.
## Uses a curve-based leveling system where each level requires more XP.
## Integrates with all XP-granting systems (matches, challenges, achievements).
class_name XPManager
extends RefCounted


## Emitted when the player gains XP
signal xp_gained(amount: int, source: Enums.XPSource, total_xp: int)

## Emitted when the player levels up
signal level_up(new_level: int, rewards: Array)

## Emitted when the player reaches a milestone level (every 10 levels)
signal milestone_reached(level: int, title: Enums.PlayerTitle)


## Current player level (starts at 1)
var current_level: int = 1

## Current XP within the current level
var current_xp: int = 0

## Total XP earned all-time
var total_xp: int = 0

## Current player title based on level
var player_title: Enums.PlayerTitle = Enums.PlayerTitle.ROOKIE

## Reference to progress store
var _progress_store: ProgressStore = null

## Whether initialized
var _initialized: bool = false

## XP history for the current session (for display purposes)
var session_xp_log: Array = []


## Base XP required for level 2
const BASE_XP: int = 100

## XP growth factor per level (each level needs this much more than the previous)
const GROWTH_FACTOR: float = 1.15

## Maximum player level
const MAX_LEVEL: int = 200

## XP awarded per kill
const XP_PER_KILL: int = 25

## XP awarded for winning (1st place)
const XP_WIN_BONUS: int = 150

## XP awarded per placement tier
const XP_PLACEMENT: Dictionary = {
	1: 150,   # Win
	2: 100,   # 2nd
	3: 80,    # 3rd
	5: 60,    # Top 5
	10: 40,   # Top 10
	25: 20,   # Top 25
}

## XP per second survived (accumulated)
const XP_PER_SURVIVAL_MINUTE: int = 10

## First match of the day bonus
const FIRST_MATCH_BONUS: int = 100

## Title thresholds {level: title}
const TITLE_THRESHOLDS: Dictionary = {
	1: Enums.PlayerTitle.ROOKIE,
	10: Enums.PlayerTitle.SURVIVOR,
	25: Enums.PlayerTitle.WARRIOR,
	50: Enums.PlayerTitle.VETERAN,
	75: Enums.PlayerTitle.CHAMPION,
	100: Enums.PlayerTitle.LEGEND,
	150: Enums.PlayerTitle.APEX_PREDATOR,
}

## Rewards per milestone level (every 10 levels)
const MILESTONE_REWARDS: Dictionary = {
	10: [{"type": "TITLE", "value": "SURVIVOR"}],
	20: [{"type": "BANNER", "value": "golden_frame"}],
	25: [{"type": "TITLE", "value": "WARRIOR"}],
	30: [{"type": "TRAIL_EFFECT", "value": "flame_trail"}],
	40: [{"type": "BANNER", "value": "diamond_frame"}],
	50: [{"type": "TITLE", "value": "VETERAN"}, {"type": "DROP_EFFECT", "value": "meteor_drop"}],
	75: [{"type": "TITLE", "value": "CHAMPION"}, {"type": "TRAIL_EFFECT", "value": "lightning_trail"}],
	100: [{"type": "TITLE", "value": "LEGEND"}, {"type": "DROP_EFFECT", "value": "legendary_drop"}, {"type": "BANNER", "value": "legendary_frame"}],
	150: [{"type": "TITLE", "value": "APEX_PREDATOR"}],
}


func initialize(progress_store: ProgressStore) -> void:
	_progress_store = progress_store
	_load_state()
	_initialized = true


## Calculates XP needed to reach a specific level from level 1
func get_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	# Sum of all XP requirements from level 2 to target level
	var total: int = 0
	for i in range(2, level + 1):
		total += _xp_required_for_level(i)
	return total


## Returns XP required to go from (level-1) to level
func _xp_required_for_level(level: int) -> int:
	return int(BASE_XP * pow(GROWTH_FACTOR, level - 2))


## Returns XP needed to reach the next level from current progress
func get_xp_to_next_level() -> int:
	if current_level >= MAX_LEVEL:
		return 0
	return _xp_required_for_level(current_level + 1) - current_xp


## Returns progress fraction toward next level (0.0 to 1.0)
func get_level_progress() -> float:
	if current_level >= MAX_LEVEL:
		return 1.0
	var needed: int = _xp_required_for_level(current_level + 1)
	if needed <= 0:
		return 1.0
	return clampf(float(current_xp) / float(needed), 0.0, 1.0)


## Awards XP from a specific source. Handles level-up checks.
## Returns the actual XP awarded (may differ due to bonuses).
func award_xp(amount: int, source: Enums.XPSource) -> int:
	if amount <= 0:
		return 0

	current_xp += amount
	total_xp += amount

	# Log for session display
	session_xp_log.append({
		"amount": amount,
		"source": source,
		"timestamp": Time.get_unix_time_from_system()
	})

	xp_gained.emit(amount, source, total_xp)

	# Check for level ups (could be multiple)
	while current_level < MAX_LEVEL:
		var needed: int = _xp_required_for_level(current_level + 1)
		if current_xp >= needed:
			current_xp -= needed
			current_level += 1
			_on_level_up()
		else:
			break

	_save_state()
	return amount


## Calculates and awards XP from match results.
## Returns a breakdown dictionary of XP earned.
func process_match_xp(result: Dictionary) -> Dictionary:
	var breakdown: Dictionary = {}
	var kills: int = result.get("kills", 0)
	var placement: int = result.get("placement", 0)
	var survival_time: int = result.get("survival_time_seconds", 0)
	var is_first_today: bool = result.get("is_first_match_of_day", false)

	# Kill XP
	var kill_xp: int = kills * XP_PER_KILL
	if kill_xp > 0:
		award_xp(kill_xp, Enums.XPSource.KILL)
		breakdown["kills"] = kill_xp

	# Placement XP (find best matching tier)
	var placement_xp: int = 0
	for threshold in XP_PLACEMENT.keys():
		if placement <= threshold:
			placement_xp = XP_PLACEMENT[threshold]
			break
	if placement_xp > 0:
		award_xp(placement_xp, Enums.XPSource.PLACEMENT)
		breakdown["placement"] = placement_xp

	# Win bonus (on top of placement XP)
	if placement == 1:
		award_xp(XP_WIN_BONUS, Enums.XPSource.WIN_BONUS)
		breakdown["win_bonus"] = XP_WIN_BONUS

	# Survival time XP (per minute)
	var survival_xp: int = int(survival_time / 60.0) * XP_PER_SURVIVAL_MINUTE
	if survival_xp > 0:
		award_xp(survival_xp, Enums.XPSource.SURVIVAL_TIME)
		breakdown["survival"] = survival_xp

	# First match of the day bonus
	if is_first_today:
		award_xp(FIRST_MATCH_BONUS, Enums.XPSource.FIRST_MATCH_OF_DAY)
		breakdown["first_match_bonus"] = FIRST_MATCH_BONUS

	return breakdown


## Awards XP from completing a daily/weekly challenge
func award_challenge_xp(challenge: Dictionary) -> void:
	var xp: int = challenge.get("xp", 0)
	if xp > 0:
		award_xp(xp, Enums.XPSource.DAILY_CHALLENGE)


## Awards XP from unlocking an achievement
func award_achievement_xp(achievement: Dictionary) -> void:
	var xp: int = achievement.get("xp_reward", 0)
	if xp > 0:
		award_xp(xp, Enums.XPSource.ACHIEVEMENT)


## Called when a level up occurs
func _on_level_up() -> void:
	# Determine rewards for this level
	var rewards: Array = []

	# Check for milestone rewards
	if MILESTONE_REWARDS.has(current_level):
		rewards = MILESTONE_REWARDS[current_level]

	# Update title if threshold reached
	var new_title: Enums.PlayerTitle = player_title
	for threshold in TITLE_THRESHOLDS.keys():
		if current_level >= threshold:
			new_title = TITLE_THRESHOLDS[threshold]
	
	if new_title != player_title:
		player_title = new_title
		milestone_reached.emit(current_level, player_title)

	level_up.emit(current_level, rewards)


## Returns title string for the current player title
func get_title_string() -> String:
	match player_title:
		Enums.PlayerTitle.ROOKIE: return "Rookie"
		Enums.PlayerTitle.SURVIVOR: return "Survivor"
		Enums.PlayerTitle.WARRIOR: return "Warrior"
		Enums.PlayerTitle.VETERAN: return "Veteran"
		Enums.PlayerTitle.CHAMPION: return "Champion"
		Enums.PlayerTitle.LEGEND: return "Legend"
		Enums.PlayerTitle.APEX_PREDATOR: return "Apex Predator"
		_: return "Rookie"


## Loads XP state from ProgressStore
func _load_state() -> void:
	if _progress_store == null:
		return
	var data: Dictionary = _progress_store.get_xp_data()
	current_level = data.get("level", 1)
	current_xp = data.get("current_xp", 0)
	total_xp = data.get("total_xp", 0)
	player_title = data.get("title", Enums.PlayerTitle.ROOKIE)


## Saves XP state to ProgressStore
func _save_state() -> void:
	if _progress_store == null:
		return
	_progress_store.save_xp_data({
		"level": current_level,
		"current_xp": current_xp,
		"total_xp": total_xp,
		"title": player_title
	})
