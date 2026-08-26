## Extensions to ProgressStore for new game systems (v0.2.0).
## This file provides additional methods via composition pattern.
## The ProgressStore class itself is extended with these methods added directly.
##
## NOTE: These methods should be copied/merged into progress_store.gd
## or accessed via this helper class that wraps a ProgressStore reference.
class_name ProgressStoreExtensions
extends RefCounted


## Reference to the actual ProgressStore
var _store: ProgressStore = null


func _init(store: ProgressStore) -> void:
	_store = store


## Gets XP/leveling data from the store
func get_xp_data() -> Dictionary:
	return _get_extension_data("xp", {
		"level": 1,
		"current_xp": 0,
		"total_xp": 0,
		"title": Enums.PlayerTitle.ROOKIE
	})


## Saves XP/leveling data
func save_xp_data(data: Dictionary) -> void:
	_set_extension_data("xp", data)


## Gets achievements data from the store
func get_achievements_data() -> Dictionary:
	return _get_extension_data("achievements", {
		"unlocked": [],
		"progress": {}
	})


## Saves achievements data
func save_achievements_data(data: Dictionary) -> void:
	_set_extension_data("achievements", data)


## Gets daily challenges data
func get_challenges_data() -> Dictionary:
	return _get_extension_data("challenges", {
		"last_daily_date": "",
		"last_weekly_week": -1,
		"daily_challenges": [],
		"weekly_challenge": {},
		"progress": {},
		"login_streak": 0,
		"last_login_date": ""
	})


## Saves daily challenges data
func save_challenges_data(data: Dictionary) -> void:
	_set_extension_data("challenges", data)


## Gets battle pass data
func get_battle_pass_data() -> Dictionary:
	return _get_extension_data("battle_pass", {
		"season": Enums.Season.SEASON_1,
		"tier": 0,
		"tier_xp": 0,
		"total_xp": 0,
		"is_premium": false,
		"claimed_free": [],
		"claimed_premium": []
	})


## Saves battle pass data
func save_battle_pass_data(data: Dictionary) -> void:
	_set_extension_data("battle_pass", data)


## Gets daily login reward data
func get_login_rewards_data() -> Dictionary:
	return _get_extension_data("login_rewards", {
		"last_claim_date": "",
		"current_day": 0,
		"total_days_claimed": 0,
		"claimed_today": false
	})


## Saves daily login reward data
func save_login_rewards_data(data: Dictionary) -> void:
	_set_extension_data("login_rewards", data)


## Gets unlockable cosmetics data
func get_cosmetics_data() -> Dictionary:
	return _get_extension_data("cosmetics", {
		"unlocked_skins": [],
		"unlocked_trails": [],
		"unlocked_banners": [],
		"unlocked_emotes": [],
		"unlocked_titles": [],
		"equipped_skin": "",
		"equipped_trail": "",
		"equipped_banner": "",
		"equipped_title": ""
	})


## Saves cosmetics data
func save_cosmetics_data(data: Dictionary) -> void:
	_set_extension_data("cosmetics", data)


## Helper: Gets extension data from the _data dictionary under "extensions" key
func _get_extension_data(key: String, default: Dictionary) -> Dictionary:
	if _store == null or _store._data == null:
		return default
	var extensions: Dictionary = _store._data.get("extensions", {})
	var user_ext: Dictionary = extensions.get(_store.current_user_id, {})
	return user_ext.get(key, default)


## Helper: Sets extension data in the _data dictionary under "extensions" key
func _set_extension_data(key: String, data: Dictionary) -> void:
	if _store == null or _store._data == null:
		return
	if not _store._data.has("extensions"):
		_store._data["extensions"] = {}
	var extensions: Dictionary = _store._data["extensions"]
	if not extensions.has(_store.current_user_id):
		extensions[_store.current_user_id] = {}
	extensions[_store.current_user_id][key] = data
	_store._data["extensions"] = extensions
	_store._save_data()
