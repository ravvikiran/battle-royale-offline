## Manages daily challenge generation, tracking, completion, and rewards.
## Challenges rotate daily based on date seed for consistent regeneration.
## Supports 3 daily challenges + 1 weekly challenge.
class_name DailyChallenges
extends RefCounted


## Emitted when a challenge is completed
signal challenge_completed(challenge: Dictionary)

## Emitted when all daily challenges are completed
signal all_dailies_completed()

## Emitted when the weekly challenge is completed
signal weekly_completed(challenge: Dictionary)


## Active daily challenges (3 per day)
var daily_challenges: Array = []

## Active weekly challenge (1 per week)
var weekly_challenge: Dictionary = {}

## Progress for each active challenge {challenge_id: current_progress}
var _challenge_progress: Dictionary = {}

## Last date challenges were generated (ISO format YYYY-MM-DD)
var _last_daily_date: String = ""

## Last week number challenges were generated
var _last_weekly_week: int = -1

## Reference to progress store
var _progress_store: ProgressStore = null

## Whether initialized
var _initialized: bool = false

## Daily login streak count
var login_streak: int = 0

## Last login date for streak tracking
var _last_login_date: String = ""


## Challenge templates used for generation
const CHALLENGE_TEMPLATES: Array = [
	# Easy challenges
	{"type": "KILL_COUNT", "difficulty": "EASY", "params": {"target": 3}, "xp": 50, "desc": "Get %d eliminations in a single match"},
	{"type": "KILL_COUNT", "difficulty": "EASY", "params": {"target": 5}, "xp": 75, "desc": "Get %d eliminations in a single match"},
	{"type": "TOTAL_KILLS", "difficulty": "EASY", "params": {"target": 5}, "xp": 60, "desc": "Get %d total eliminations"},
	{"type": "TOP_PLACEMENT", "difficulty": "EASY", "params": {"target": 10}, "xp": 40, "desc": "Finish in the top %d"},
	{"type": "SURVIVE_TIME", "difficulty": "EASY", "params": {"target": 180}, "xp": 45, "desc": "Survive for %d seconds"},
	{"type": "DEAL_DAMAGE", "difficulty": "EASY", "params": {"target": 200}, "xp": 50, "desc": "Deal %d damage total"},
	{"type": "LOOT_ITEMS", "difficulty": "EASY", "params": {"target": 5}, "xp": 35, "desc": "Pick up %d items"},
	{"type": "PLAY_CHARACTER", "difficulty": "EASY", "params": {"character": "BLITZ"}, "xp": 40, "desc": "Play a match as %s"},
	{"type": "PLAY_CHARACTER", "difficulty": "EASY", "params": {"character": "TITAN"}, "xp": 40, "desc": "Play a match as %s"},
	{"type": "PLAY_CHARACTER", "difficulty": "EASY", "params": {"character": "PHANTOM"}, "xp": 40, "desc": "Play a match as %s"},

	# Medium challenges
	{"type": "KILL_COUNT", "difficulty": "MEDIUM", "params": {"target": 8}, "xp": 120, "desc": "Get %d eliminations in a single match"},
	{"type": "TOTAL_KILLS", "difficulty": "MEDIUM", "params": {"target": 15}, "xp": 150, "desc": "Get %d total eliminations"},
	{"type": "WIN_MATCH", "difficulty": "MEDIUM", "params": {"target": 1}, "xp": 150, "desc": "Win a match"},
	{"type": "TOP_PLACEMENT", "difficulty": "MEDIUM", "params": {"target": 5}, "xp": 100, "desc": "Finish in the top %d"},
	{"type": "SURVIVE_TIME", "difficulty": "MEDIUM", "params": {"target": 420}, "xp": 100, "desc": "Survive for %d seconds"},
	{"type": "DEAL_DAMAGE", "difficulty": "MEDIUM", "params": {"target": 500}, "xp": 125, "desc": "Deal %d damage total"},
	{"type": "USE_WEAPON_CATEGORY", "difficulty": "MEDIUM", "params": {"category": "AR", "target": 5}, "xp": 110, "desc": "Get %d AR eliminations"},
	{"type": "USE_WEAPON_CATEGORY", "difficulty": "MEDIUM", "params": {"category": "SHOTGUN", "target": 3}, "xp": 110, "desc": "Get %d Shotgun eliminations"},
	{"type": "USE_WEAPON_CATEGORY", "difficulty": "MEDIUM", "params": {"category": "SMG", "target": 5}, "xp": 110, "desc": "Get %d SMG eliminations"},
	{"type": "USE_WEAPON_CATEGORY", "difficulty": "MEDIUM", "params": {"category": "SNIPER", "target": 3}, "xp": 130, "desc": "Get %d Sniper eliminations"},

	# Hard challenges
	{"type": "KILL_COUNT", "difficulty": "HARD", "params": {"target": 15}, "xp": 250, "desc": "Get %d eliminations in a single match"},
	{"type": "WIN_MATCH", "difficulty": "HARD", "params": {"target": 3}, "xp": 350, "desc": "Win %d matches today"},
	{"type": "TOTAL_KILLS", "difficulty": "HARD", "params": {"target": 30}, "xp": 300, "desc": "Get %d total eliminations today"},
	{"type": "DEAL_DAMAGE", "difficulty": "HARD", "params": {"target": 1500}, "xp": 275, "desc": "Deal %d damage today"},
	{"type": "STORM_SURVIVAL", "difficulty": "HARD", "params": {"target": 60}, "xp": 200, "desc": "Survive %d seconds in the storm"},
	{"type": "NO_DAMAGE_WIN", "difficulty": "HARD", "params": {"target": 1}, "xp": 500, "desc": "Win without taking damage"},
]

## Weekly challenge templates (harder, bigger rewards)
const WEEKLY_TEMPLATES: Array = [
	{"type": "TOTAL_KILLS", "difficulty": "LEGENDARY", "params": {"target": 100}, "xp": 1000, "desc": "Get %d eliminations this week"},
	{"type": "WIN_MATCH", "difficulty": "LEGENDARY", "params": {"target": 10}, "xp": 1200, "desc": "Win %d matches this week"},
	{"type": "DEAL_DAMAGE", "difficulty": "LEGENDARY", "params": {"target": 5000}, "xp": 1000, "desc": "Deal %d damage this week"},
	{"type": "SURVIVE_TIME", "difficulty": "LEGENDARY", "params": {"target": 3600}, "xp": 800, "desc": "Survive %d total seconds this week"},
]


func initialize(progress_store: ProgressStore) -> void:
	_progress_store = progress_store
	_load_state()
	_check_daily_refresh()
	_check_weekly_refresh()
	_update_login_streak()
	_initialized = true


## Checks if daily challenges need to be regenerated
func _check_daily_refresh() -> void:
	var today: String = _get_today_string()
	if _last_daily_date != today:
		_generate_daily_challenges(today)
		_last_daily_date = today
		_save_state()


## Checks if weekly challenge needs to be regenerated
func _check_weekly_refresh() -> void:
	var current_week: int = _get_week_number()
	if _last_weekly_week != current_week:
		_generate_weekly_challenge(current_week)
		_last_weekly_week = current_week
		_save_state()


## Generates 3 daily challenges based on date seed
func _generate_daily_challenges(date_str: String) -> void:
	daily_challenges.clear()

	# Use date as seed for reproducible daily challenges
	var seed_val: int = date_str.hash()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Select 1 easy, 1 medium, 1 hard
	var easy_pool: Array = CHALLENGE_TEMPLATES.filter(func(t): return t["difficulty"] == "EASY")
	var medium_pool: Array = CHALLENGE_TEMPLATES.filter(func(t): return t["difficulty"] == "MEDIUM")
	var hard_pool: Array = CHALLENGE_TEMPLATES.filter(func(t): return t["difficulty"] == "HARD")

	var picked_easy: Dictionary = easy_pool[rng.randi() % easy_pool.size()].duplicate(true)
	var picked_medium: Dictionary = medium_pool[rng.randi() % medium_pool.size()].duplicate(true)
	var picked_hard: Dictionary = hard_pool[rng.randi() % hard_pool.size()].duplicate(true)

	picked_easy["id"] = "daily_easy_" + date_str
	picked_medium["id"] = "daily_medium_" + date_str
	picked_hard["id"] = "daily_hard_" + date_str

	# Format descriptions
	picked_easy["description"] = _format_desc(picked_easy)
	picked_medium["description"] = _format_desc(picked_medium)
	picked_hard["description"] = _format_desc(picked_hard)

	daily_challenges = [picked_easy, picked_medium, picked_hard]

	# Reset progress for new challenges
	for c in daily_challenges:
		_challenge_progress[c["id"]] = 0


## Generates the weekly challenge based on week number
func _generate_weekly_challenge(week_num: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = week_num * 7919  # Prime multiplier for variety

	var template: Dictionary = WEEKLY_TEMPLATES[rng.randi() % WEEKLY_TEMPLATES.size()].duplicate(true)
	template["id"] = "weekly_%d" % week_num
	template["description"] = _format_desc(template)
	weekly_challenge = template
	_challenge_progress[template["id"]] = 0


## Formats the description with parameter values
func _format_desc(challenge: Dictionary) -> String:
	var desc: String = challenge.get("desc", "")
	var params: Dictionary = challenge.get("params", {})

	if params.has("target"):
		desc = desc % [params["target"]]
	elif params.has("character"):
		desc = desc % [params["character"]]
	elif params.has("category"):
		desc = desc % [params.get("target", 0), params["category"]]

	return desc


## Updates the daily login streak
func _update_login_streak() -> void:
	var today: String = _get_today_string()
	if _last_login_date == "":
		login_streak = 1
	elif _last_login_date == _get_yesterday_string():
		login_streak += 1
	elif _last_login_date != today:
		login_streak = 1  # Streak broken

	_last_login_date = today
	_save_state()


## Processes match results against active challenges.
## Returns array of completed challenge data.
func process_match_results(result: Dictionary) -> Array:
	var completed: Array = []

	var kills: int = result.get("kills", 0)
	var placement: int = result.get("placement", 0)
	var survival_time: int = result.get("survival_time_seconds", 0)
	var damage_dealt: float = result.get("damage_dealt", 0.0)
	var character: String = result.get("character", "")
	var damage_taken: float = result.get("damage_taken", 0.0)
	var storm_time: float = result.get("storm_survival_time", 0.0)
	var items_looted: int = result.get("items_looted", 0)
	var weapon_kills: Dictionary = result.get("weapon_category_kills", {})

	var all_challenges: Array = daily_challenges.duplicate()
	if not weekly_challenge.is_empty():
		all_challenges.append(weekly_challenge)

	for challenge in all_challenges:
		var cid: String = challenge.get("id", "")
		if _is_challenge_completed(cid):
			continue

		var progress_added: int = 0
		var ctype: String = challenge.get("type", "")
		var params: Dictionary = challenge.get("params", {})
		var target: int = params.get("target", 1)

		match ctype:
			"KILL_COUNT":
				if kills >= target:
					progress_added = 1
					_challenge_progress[cid] = 1
			"TOTAL_KILLS":
				progress_added = kills
			"WIN_MATCH":
				if placement == 1:
					progress_added = 1
			"TOP_PLACEMENT":
				if placement <= target:
					progress_added = 1
					_challenge_progress[cid] = 1
			"SURVIVE_TIME":
				progress_added = survival_time
			"DEAL_DAMAGE":
				progress_added = int(damage_dealt)
			"USE_WEAPON_CATEGORY":
				var cat: String = params.get("category", "")
				progress_added = weapon_kills.get(cat, 0)
			"NO_DAMAGE_WIN":
				if placement == 1 and damage_taken <= 0.0:
					progress_added = 1
			"STORM_SURVIVAL":
				progress_added = int(storm_time)
			"LOOT_ITEMS":
				progress_added = items_looted
			"PLAY_CHARACTER":
				if character == params.get("character", ""):
					progress_added = 1
					_challenge_progress[cid] = 1

		if progress_added > 0 and ctype not in ["KILL_COUNT", "TOP_PLACEMENT", "PLAY_CHARACTER"]:
			_challenge_progress[cid] = _challenge_progress.get(cid, 0) + progress_added

		# Check completion
		if _is_challenge_completed(cid):
			completed.append(challenge)
			if cid.begins_with("weekly_"):
				weekly_completed.emit(challenge)
			else:
				challenge_completed.emit(challenge)

	# Check if all dailies completed
	var all_done: bool = true
	for dc in daily_challenges:
		if not _is_challenge_completed(dc.get("id", "")):
			all_done = false
			break
	if all_done and daily_challenges.size() > 0:
		all_dailies_completed.emit()

	_save_state()
	return completed


## Checks if a challenge is completed based on current progress
func _is_challenge_completed(challenge_id: String) -> bool:
	var challenge: Dictionary = _find_challenge(challenge_id)
	if challenge.is_empty():
		return false
	var target: int = challenge.get("params", {}).get("target", 1)
	var progress: int = _challenge_progress.get(challenge_id, 0)
	return progress >= target


## Finds a challenge by ID across dailies and weekly
func _find_challenge(challenge_id: String) -> Dictionary:
	for c in daily_challenges:
		if c.get("id", "") == challenge_id:
			return c
	if weekly_challenge.get("id", "") == challenge_id:
		return weekly_challenge
	return {}


## Returns progress fraction for a challenge (0.0 to 1.0)
func get_challenge_progress(challenge_id: String) -> float:
	var challenge: Dictionary = _find_challenge(challenge_id)
	if challenge.is_empty():
		return 0.0
	var target: int = challenge.get("params", {}).get("target", 1)
	var progress: int = _challenge_progress.get(challenge_id, 0)
	return clampf(float(progress) / float(target), 0.0, 1.0)


## Returns the XP reward for completing all dailies (bonus)
func get_all_dailies_bonus_xp() -> int:
	return 200 + (login_streak * 25)  # Streak multiplier


## Returns login streak bonus XP
func get_streak_bonus_xp() -> int:
	# Exponential but capped: 10, 20, 40, 80, 100, 100, ...
	return mini(10 * int(pow(2, mini(login_streak - 1, 4))), 100)


## Gets today's date as string
func _get_today_string() -> String:
	var dt: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


## Gets yesterday's date as string
func _get_yesterday_string() -> String:
	var unix: int = int(Time.get_unix_time_from_system()) - 86400
	var dt: Dictionary = Time.get_date_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


## Gets current ISO week number
func _get_week_number() -> int:
	var day_of_year: int = Time.get_date_dict_from_system()["day"]
	var month: int = Time.get_date_dict_from_system()["month"]
	# Approximate week number
	var approx_day: int = (month - 1) * 30 + day_of_year
	return approx_day / 7


## Loads state from ProgressStore
func _load_state() -> void:
	if _progress_store == null:
		return
	var data: Dictionary = _progress_store.get_challenges_data()
	_last_daily_date = data.get("last_daily_date", "")
	_last_weekly_week = data.get("last_weekly_week", -1)
	daily_challenges = data.get("daily_challenges", [])
	weekly_challenge = data.get("weekly_challenge", {})
	_challenge_progress = data.get("progress", {})
	login_streak = data.get("login_streak", 0)
	_last_login_date = data.get("last_login_date", "")


## Saves state to ProgressStore
func _save_state() -> void:
	if _progress_store == null:
		return
	_progress_store.save_challenges_data({
		"last_daily_date": _last_daily_date,
		"last_weekly_week": _last_weekly_week,
		"daily_challenges": daily_challenges,
		"weekly_challenge": weekly_challenge,
		"progress": _challenge_progress,
		"login_streak": login_streak,
		"last_login_date": _last_login_date
	})
