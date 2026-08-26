## Manages achievement definitions, unlock tracking, progress, and notifications.
## Achievements persist via ProgressStore and reward XP on unlock.
## Tracks cumulative stats across matches for progressive achievements.
class_name AchievementsManager
extends RefCounted


## Emitted when an achievement is unlocked
signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)

## Emitted when achievement progress updates
signal achievement_progress_updated(achievement_id: String, current: int, target: int)


## All achievement definitions indexed by ID
var _achievements: Dictionary = {}

## Unlocked achievement IDs for current user
var _unlocked: Array = []

## Progress tracking for progressive achievements {achievement_id: current_count}
var _progress: Dictionary = {}

## Reference to progress store for persistence
var _progress_store: ProgressStore = null

## Whether the manager has been initialized
var _initialized: bool = false


## Achievement definition structure
## {
##   "id": String,
##   "name": String,
##   "description": String,
##   "category": Enums.AchievementCategory,
##   "rarity": Enums.AchievementRarity,
##   "target": int,        # Target count to unlock (1 for one-shot achievements)
##   "xp_reward": int,     # XP granted on unlock
##   "icon": String,       # Icon identifier
##   "hidden": bool        # Whether to show before unlocking
## }


func initialize(progress_store: ProgressStore) -> void:
	_progress_store = progress_store
	_define_achievements()
	_load_progress()
	_initialized = true


## Defines all achievements in the game
func _define_achievements() -> void:
	# --- COMBAT ACHIEVEMENTS ---
	_add("first_blood", "First Blood", "Get your first elimination", 
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.BRONZE, 1, 50)
	_add("sharpshooter", "Sharpshooter", "Get 10 eliminations total",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.BRONZE, 10, 100)
	_add("serial_eliminator", "Serial Eliminator", "Get 50 eliminations total",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.SILVER, 50, 250)
	_add("apex_predator", "Apex Predator", "Get 200 eliminations total",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.GOLD, 200, 500)
	_add("terminator", "Terminator", "Get 500 eliminations total",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.PLATINUM, 500, 1000)
	_add("legend_of_legends", "Legend of Legends", "Get 1000 eliminations total",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.DIAMOND, 1000, 2500)
	_add("double_trouble", "Double Trouble", "Get a Double Kill",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.BRONZE, 1, 75)
	_add("triple_threat", "Triple Threat", "Get a Triple Kill",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.SILVER, 1, 150)
	_add("rampage_master", "Rampage Master", "Achieve a Rampage (5 rapid kills)",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.GOLD, 1, 300)
	_add("unstoppable_force", "Unstoppable Force", "Achieve Unstoppable (7 rapid kills)",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.PLATINUM, 1, 750)
	_add("godlike", "GODLIKE", "Achieve Godlike status (10 rapid kills)",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.DIAMOND, 1, 1500)
	_add("overkill", "Overkill", "Get 10+ kills in a single match",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.GOLD, 1, 400)
	_add("massacre", "Massacre", "Get 20+ kills in a single match",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.PLATINUM, 1, 800)
	_add("one_shot_one_kill", "One Shot, One Kill", "Eliminate a bot with a sniper from max range",
		Enums.AchievementCategory.COMBAT, Enums.AchievementRarity.SILVER, 1, 200)

	# --- VICTORY ACHIEVEMENTS ---
	_add("first_win", "Winner Winner", "Win your first match",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.BRONZE, 1, 100)
	_add("champion_5", "Rising Champion", "Win 5 matches",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.SILVER, 5, 300)
	_add("champion_25", "Battle Hardened", "Win 25 matches",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.GOLD, 25, 750)
	_add("champion_100", "Centurion", "Win 100 matches",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.PLATINUM, 100, 2000)
	_add("flawless", "Flawless Victory", "Win without taking any damage",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.DIAMOND, 1, 1000)
	_add("underdog", "Underdog", "Win on Hard difficulty",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.SILVER, 1, 200)
	_add("impossible", "Mission Impossible", "Win on Hard with 99 bots",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.DIAMOND, 1, 2000)
	_add("speedrun", "Speed Demon", "Win a match in under 3 minutes",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.GOLD, 1, 500)
	_add("pacifist", "Pacifist", "Win with 0 kills (bots eliminate each other)",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.PLATINUM, 1, 1000)
	_add("win_streak_3", "Hot Streak", "Win 3 matches in a row",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.GOLD, 3, 500)
	_add("win_streak_5", "On Fire", "Win 5 matches in a row",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.PLATINUM, 5, 1000)
	_add("win_streak_10", "Invincible", "Win 10 matches in a row",
		Enums.AchievementCategory.VICTORY, Enums.AchievementRarity.DIAMOND, 10, 3000)

	# --- SURVIVAL ACHIEVEMENTS ---
	_add("survivor", "Survivor", "Survive for 5 minutes in a single match",
		Enums.AchievementCategory.SURVIVAL, Enums.AchievementRarity.BRONZE, 1, 50)
	_add("endurance", "Endurance", "Survive for 10 minutes in a single match",
		Enums.AchievementCategory.SURVIVAL, Enums.AchievementRarity.SILVER, 1, 150)
	_add("marathon", "Marathon Runner", "Survive for 15 minutes total across matches",
		Enums.AchievementCategory.SURVIVAL, Enums.AchievementRarity.SILVER, 900, 200)
	_add("storm_dancer", "Storm Dancer", "Survive 30 seconds in the storm",
		Enums.AchievementCategory.SURVIVAL, Enums.AchievementRarity.BRONZE, 1, 75)
	_add("storm_surfer", "Storm Surfer", "Survive 60 seconds in the storm",
		Enums.AchievementCategory.SURVIVAL, Enums.AchievementRarity.SILVER, 1, 150)
	_add("phoenix", "Phoenix", "Recover from below 10 HP to full health",
		Enums.AchievementCategory.SURVIVAL, Enums.AchievementRarity.GOLD, 1, 300)
	_add("last_stand", "Last Stand", "Win with less than 10 HP remaining",
		Enums.AchievementCategory.SURVIVAL, Enums.AchievementRarity.GOLD, 1, 400)

	# --- MASTERY ACHIEVEMENTS ---
	_add("ar_master", "AR Master", "Get 50 kills with Assault Rifles",
		Enums.AchievementCategory.MASTERY, Enums.AchievementRarity.SILVER, 50, 300)
	_add("shotgun_master", "Shotgun Master", "Get 50 kills with Shotguns",
		Enums.AchievementCategory.MASTERY, Enums.AchievementRarity.SILVER, 50, 300)
	_add("smg_master", "SMG Master", "Get 50 kills with SMGs",
		Enums.AchievementCategory.MASTERY, Enums.AchievementRarity.SILVER, 50, 300)
	_add("sniper_master", "Sniper Master", "Get 50 kills with Snipers",
		Enums.AchievementCategory.MASTERY, Enums.AchievementRarity.SILVER, 50, 300)
	_add("pistol_master", "Pistol Master", "Get 50 kills with Pistols",
		Enums.AchievementCategory.MASTERY, Enums.AchievementRarity.SILVER, 50, 300)
	_add("all_rounder", "All-Rounder", "Get a kill with every weapon category",
		Enums.AchievementCategory.MASTERY, Enums.AchievementRarity.GOLD, 5, 500)
	_add("blitz_main", "Blitz Main", "Win 10 matches as Blitz",
		Enums.AchievementCategory.MASTERY, Enums.AchievementRarity.SILVER, 10, 250)
	_add("titan_main", "Titan Main", "Win 10 matches as Titan",
		Enums.AchievementCategory.MASTERY, Enums.AchievementRarity.SILVER, 10, 250)
	_add("phantom_main", "Phantom Main", "Win 10 matches as Phantom",
		Enums.AchievementCategory.MASTERY, Enums.AchievementRarity.SILVER, 10, 250)
	_add("legendary_hunter", "Legendary Hunter", "Pick up 10 Legendary weapons",
		Enums.AchievementCategory.MASTERY, Enums.AchievementRarity.GOLD, 10, 400)

	# --- EXPLORATION ACHIEVEMENTS ---
	_add("first_drop", "Feet on the Ground", "Complete your first drop",
		Enums.AchievementCategory.EXPLORATION, Enums.AchievementRarity.BRONZE, 1, 25)
	_add("hot_dropper", "Hot Dropper", "Land in a Hot zone 10 times",
		Enums.AchievementCategory.EXPLORATION, Enums.AchievementRarity.SILVER, 10, 200)
	_add("inferno_dropper", "Inferno Dropper", "Land in an Inferno zone and survive",
		Enums.AchievementCategory.EXPLORATION, Enums.AchievementRarity.GOLD, 1, 300)
	_add("loot_goblin", "Loot Goblin", "Pick up 100 items total",
		Enums.AchievementCategory.EXPLORATION, Enums.AchievementRarity.SILVER, 100, 200)
	_add("hoarder", "Hoarder", "Have a full inventory (5 weapons + max consumables)",
		Enums.AchievementCategory.EXPLORATION, Enums.AchievementRarity.BRONZE, 1, 75)
	_add("match_veteran", "Veteran", "Play 100 matches",
		Enums.AchievementCategory.EXPLORATION, Enums.AchievementRarity.GOLD, 100, 500)
	_add("match_legend", "Living Legend", "Play 500 matches",
		Enums.AchievementCategory.EXPLORATION, Enums.AchievementRarity.DIAMOND, 500, 2000)


## Helper to add an achievement definition
func _add(id: String, aname: String, desc: String, category: Enums.AchievementCategory, 
		rarity: Enums.AchievementRarity, target: int, xp: int, hidden: bool = false) -> void:
	_achievements[id] = {
		"id": id,
		"name": aname,
		"description": desc,
		"category": category,
		"rarity": rarity,
		"target": target,
		"xp_reward": xp,
		"hidden": hidden
	}


## Loads unlocked achievements and progress from ProgressStore
func _load_progress() -> void:
	if _progress_store == null:
		return
	var data: Dictionary = _progress_store.get_achievements_data()
	_unlocked = data.get("unlocked", [])
	_progress = data.get("progress", {})


## Saves current achievement state to ProgressStore
func _save_progress() -> void:
	if _progress_store == null:
		return
	_progress_store.save_achievements_data({
		"unlocked": _unlocked,
		"progress": _progress
	})


## Checks if an achievement is already unlocked
func is_unlocked(achievement_id: String) -> bool:
	return achievement_id in _unlocked


## Gets current progress for a progressive achievement
func get_progress(achievement_id: String) -> int:
	return _progress.get(achievement_id, 0)


## Gets the target count for an achievement
func get_target(achievement_id: String) -> int:
	var ach: Dictionary = _achievements.get(achievement_id, {})
	return ach.get("target", 1)


## Increments progress on an achievement and checks for unlock.
## Returns true if the achievement was just unlocked.
func increment_progress(achievement_id: String, amount: int = 1) -> bool:
	if is_unlocked(achievement_id):
		return false
	if not _achievements.has(achievement_id):
		return false

	var current: int = _progress.get(achievement_id, 0)
	current += amount
	_progress[achievement_id] = current

	var target: int = _achievements[achievement_id]["target"]
	achievement_progress_updated.emit(achievement_id, current, target)

	if current >= target:
		return _unlock(achievement_id)

	_save_progress()
	return false


## Directly unlocks an achievement (for one-shot achievements)
func unlock_achievement(achievement_id: String) -> bool:
	if is_unlocked(achievement_id):
		return false
	if not _achievements.has(achievement_id):
		return false
	return _unlock(achievement_id)


## Internal unlock logic
func _unlock(achievement_id: String) -> bool:
	_unlocked.append(achievement_id)
	_progress[achievement_id] = _achievements[achievement_id]["target"]
	_save_progress()
	achievement_unlocked.emit(achievement_id, _achievements[achievement_id])
	return true


## Processes match results to check for achievement unlocks.
## Called after each match by the GameOrchestrator.
func process_match_results(result: Dictionary) -> Array:
	var newly_unlocked: Array = []

	var kills: int = result.get("kills", 0)
	var placement: int = result.get("placement", 0)
	var survival_time: int = result.get("survival_time_seconds", 0)
	var damage_dealt: float = result.get("damage_dealt", 0.0)
	var character: String = result.get("character", "")
	var difficulty_str: String = result.get("bot_difficulty", "MEDIUM")
	var bot_count: int = result.get("bot_count", 50)
	var damage_taken: float = result.get("damage_taken", 0.0)
	var final_health: float = result.get("final_health", 0.0)
	var max_streak: int = result.get("max_kill_streak", 0)

	# --- Kill achievements (cumulative) ---
	if increment_progress("first_blood"):
		newly_unlocked.append("first_blood")
	# Add kills to cumulative trackers
	for i in range(kills - 1):  # -1 because first_blood already counted one
		increment_progress("sharpshooter")
		increment_progress("serial_eliminator")
		increment_progress("apex_predator")
		increment_progress("terminator")
		increment_progress("legend_of_legends")
	# Also count the one from first_blood for the cumulative ones
	if kills >= 1:
		increment_progress("sharpshooter")
		increment_progress("serial_eliminator")
		increment_progress("apex_predator")
		increment_progress("terminator")
		increment_progress("legend_of_legends")

	# --- Single match kill thresholds ---
	if kills >= 10:
		if unlock_achievement("overkill"):
			newly_unlocked.append("overkill")
	if kills >= 20:
		if unlock_achievement("massacre"):
			newly_unlocked.append("massacre")

	# --- Kill streak achievements ---
	if max_streak >= 2:
		if unlock_achievement("double_trouble"):
			newly_unlocked.append("double_trouble")
	if max_streak >= 3:
		if unlock_achievement("triple_threat"):
			newly_unlocked.append("triple_threat")
	if max_streak >= 5:
		if unlock_achievement("rampage_master"):
			newly_unlocked.append("rampage_master")
	if max_streak >= 7:
		if unlock_achievement("unstoppable_force"):
			newly_unlocked.append("unstoppable_force")
	if max_streak >= 10:
		if unlock_achievement("godlike"):
			newly_unlocked.append("godlike")

	# --- Victory achievements ---
	if placement == 1:
		if increment_progress("first_win"):
			newly_unlocked.append("first_win")
		if increment_progress("champion_5"):
			newly_unlocked.append("champion_5")
		if increment_progress("champion_25"):
			newly_unlocked.append("champion_25")
		if increment_progress("champion_100"):
			newly_unlocked.append("champion_100")

		# Flawless victory (no damage taken)
		if damage_taken <= 0.0:
			if unlock_achievement("flawless"):
				newly_unlocked.append("flawless")

		# Pacifist
		if kills == 0:
			if unlock_achievement("pacifist"):
				newly_unlocked.append("pacifist")

		# Underdog (hard difficulty)
		if difficulty_str == "HARD":
			if unlock_achievement("underdog"):
				newly_unlocked.append("underdog")

		# Mission Impossible (hard + 99 bots)
		if difficulty_str == "HARD" and bot_count >= 99:
			if unlock_achievement("impossible"):
				newly_unlocked.append("impossible")

		# Speed Demon (under 3 minutes)
		if survival_time < 180:
			if unlock_achievement("speedrun"):
				newly_unlocked.append("speedrun")

		# Last Stand (win with < 10 HP)
		if final_health > 0.0 and final_health < 10.0:
			if unlock_achievement("last_stand"):
				newly_unlocked.append("last_stand")

		# Character-specific wins
		match character:
			"BLITZ":
				if increment_progress("blitz_main"):
					newly_unlocked.append("blitz_main")
			"TITAN":
				if increment_progress("titan_main"):
					newly_unlocked.append("titan_main")
			"PHANTOM":
				if increment_progress("phantom_main"):
					newly_unlocked.append("phantom_main")

	# --- Survival achievements ---
	if survival_time >= 300:
		if unlock_achievement("survivor"):
			newly_unlocked.append("survivor")
	if survival_time >= 600:
		if unlock_achievement("endurance"):
			newly_unlocked.append("endurance")

	# --- Exploration ---
	if unlock_achievement("first_drop"):
		newly_unlocked.append("first_drop")
	if increment_progress("match_veteran"):
		newly_unlocked.append("match_veteran")
	if increment_progress("match_legend"):
		newly_unlocked.append("match_legend")

	return newly_unlocked


## Returns all achievement definitions
func get_all_achievements() -> Dictionary:
	return _achievements


## Returns achievements filtered by category
func get_achievements_by_category(category: Enums.AchievementCategory) -> Array:
	var result: Array = []
	for ach in _achievements.values():
		if ach["category"] == category:
			result.append(ach)
	return result


## Returns count of unlocked achievements
func get_unlocked_count() -> int:
	return _unlocked.size()


## Returns total achievement count
func get_total_count() -> int:
	return _achievements.size()


## Returns completion percentage (0.0 - 1.0)
func get_completion_percentage() -> float:
	if _achievements.size() == 0:
		return 0.0
	return float(_unlocked.size()) / float(_achievements.size())
