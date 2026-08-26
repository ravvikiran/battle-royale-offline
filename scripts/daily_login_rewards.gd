## Manages daily login rewards with escalating bonuses.
## Players receive rewards for logging in each day, with a 7-day cycle
## that resets with increasingly valuable rewards.
## Missed days don't reset the cycle but don't advance it either.
class_name DailyLoginRewards
extends RefCounted


## Emitted when a daily reward is claimed
signal reward_claimed(day: int, reward: Dictionary)

## Emitted when a full cycle (7 days) is completed
signal cycle_completed(total_cycles: int)


## Current day in the reward cycle (1-7)
var current_day: int = 0

## Total days claimed all-time
var total_days_claimed: int = 0

## Whether today's reward has been claimed
var claimed_today: bool = false

## Last claim date (ISO format)
var _last_claim_date: String = ""

## Reference to progress store extensions
var _store_ext: ProgressStoreExtensions = null

## Whether initialized
var _initialized: bool = false


## Reward cycle (7 days, repeating with escalation)
const REWARD_CYCLE: Array = [
	{"day": 1, "type": "XP", "amount": 50, "name": "50 XP", "description": "Welcome back!"},
	{"day": 2, "type": "XP", "amount": 75, "name": "75 XP", "description": "Day 2 streak!"},
	{"day": 3, "type": "XP", "amount": 100, "name": "100 XP", "description": "Keeping it up!"},
	{"day": 4, "type": "XP", "amount": 150, "name": "150 XP", "description": "Halfway there!"},
	{"day": 5, "type": "XP", "amount": 200, "name": "200 XP", "description": "Almost there!"},
	{"day": 6, "type": "XP", "amount": 300, "name": "300 XP", "description": "One more day!"},
	{"day": 7, "type": "XP", "amount": 500, "name": "500 XP + Bonus", "description": "Full week! Bonus unlocked!"},
]

## Bonus multiplier per completed cycle (caps at 3x)
const CYCLE_MULTIPLIER_CAP: float = 3.0


func initialize(store_ext: ProgressStoreExtensions) -> void:
	_store_ext = store_ext
	_load_state()
	_check_new_day()
	_initialized = true


## Checks if it's a new day and resets claim status
func _check_new_day() -> void:
	var today: String = _get_today_string()
	if _last_claim_date != today:
		claimed_today = false


## Returns whether the player can claim today's reward
func can_claim() -> bool:
	return not claimed_today


## Claims today's reward. Returns the reward data or empty dict if already claimed.
func claim_reward() -> Dictionary:
	if claimed_today:
		return {}

	# Advance day in cycle
	current_day += 1
	if current_day > 7:
		current_day = 1

	claimed_today = true
	total_days_claimed += 1
	_last_claim_date = _get_today_string()

	# Get reward for current day
	var base_reward: Dictionary = REWARD_CYCLE[current_day - 1].duplicate()

	# Apply cycle multiplier (more cycles = bigger rewards)
	var cycles_completed: int = total_days_claimed / 7
	var multiplier: float = minf(1.0 + float(cycles_completed) * 0.25, CYCLE_MULTIPLIER_CAP)

	if base_reward.get("type", "") == "XP":
		base_reward["amount"] = int(float(base_reward["amount"]) * multiplier)
		base_reward["name"] = "%d XP" % base_reward["amount"]

	base_reward["multiplier"] = multiplier
	base_reward["cycles_completed"] = cycles_completed

	_save_state()
	reward_claimed.emit(current_day, base_reward)

	# Check for cycle completion
	if current_day == 7:
		cycle_completed.emit(cycles_completed + 1)

	return base_reward


## Returns the reward data for a specific day (for preview display)
func get_reward_for_day(day: int) -> Dictionary:
	if day < 1 or day > 7:
		return {}
	return REWARD_CYCLE[day - 1].duplicate()


## Returns all 7 days with claim status for UI display
func get_all_rewards_display() -> Array:
	var display: Array = []
	for i in range(7):
		var reward: Dictionary = REWARD_CYCLE[i].duplicate()
		reward["is_claimed"] = (i + 1) <= current_day if not (i + 1 == current_day and not claimed_today) else (i + 1) < current_day
		reward["is_today"] = (i + 1) == current_day or (current_day == 0 and i == 0)
		reward["is_claimable"] = reward["is_today"] and not claimed_today
		display.append(reward)
	return display


## Returns the current streak info for display
func get_streak_info() -> Dictionary:
	return {
		"current_day": current_day,
		"total_days": total_days_claimed,
		"claimed_today": claimed_today,
		"cycles_completed": total_days_claimed / 7,
		"multiplier": minf(1.0 + float(total_days_claimed / 7) * 0.25, CYCLE_MULTIPLIER_CAP)
	}


## Gets today's date as string
func _get_today_string() -> String:
	var dt: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


## Loads state from ProgressStore extensions
func _load_state() -> void:
	if _store_ext == null:
		return
	var data: Dictionary = _store_ext.get_login_rewards_data()
	_last_claim_date = data.get("last_claim_date", "")
	current_day = data.get("current_day", 0)
	total_days_claimed = data.get("total_days_claimed", 0)
	claimed_today = data.get("claimed_today", false)

	# Reset claimed_today if it's a new day
	if _last_claim_date != _get_today_string():
		claimed_today = false


## Saves state to ProgressStore extensions
func _save_state() -> void:
	if _store_ext == null:
		return
	_store_ext.save_login_rewards_data({
		"last_claim_date": _last_claim_date,
		"current_day": current_day,
		"total_days_claimed": total_days_claimed,
		"claimed_today": claimed_today
	})
