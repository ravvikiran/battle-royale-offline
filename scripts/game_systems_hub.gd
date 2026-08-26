## Central hub that initializes and wires all v0.2.0 game systems together.
## Acts as the integration layer between the new systems (XP, achievements,
## challenges, battle pass, combat feedback, adaptive difficulty, hot drops)
## and the existing GameOrchestrator + SceneManager.
##
## Registered as an autoload alongside SceneManager and AssetLoader.
## Owns the lifecycle of all new systems and provides signal routing.
class_name GameSystemsHub
extends Node


# --- System instances ---
var xp_manager: XPManager = null
var achievements_manager: AchievementsManager = null
var daily_challenges: DailyChallenges = null
var battle_pass: BattlePass = null
var combat_feedback: CombatFeedback = null
var adaptive_difficulty: AdaptiveDifficulty = null
var hot_drop_system: HotDropSystem = null
var daily_login: DailyLoginRewards = null
var notification_manager: NotificationManager = null
var store_extensions: ProgressStoreExtensions = null

## Reference to SceneManager's progress store
var _progress_store: ProgressStore = null

## Whether the hub has been initialized
var _initialized: bool = false

## Match tracking state (accumulated during match for post-match processing)
var _match_tracking: Dictionary = {
	"damage_taken": 0.0,
	"storm_time": 0.0,
	"items_looted": 0,
	"weapon_category_kills": {},
	"is_first_match_of_day": false,
	"max_kill_streak": 0,
	"final_health": 100.0,
}

## Whether this is the first match today
var _first_match_checked: bool = false
var _last_match_date: String = ""


func _ready() -> void:
	# Wait for SceneManager to be ready first
	call_deferred("_deferred_init")


## Deferred initialization — waits for SceneManager to have progress_store ready
func _deferred_init() -> void:
	# Get progress store from SceneManager (another autoload)
	var scene_mgr: Node = get_node_or_null("/root/SceneManager")
	if scene_mgr and scene_mgr.get("progress_store") != null:
		_progress_store = scene_mgr.progress_store
	else:
		# Fallback: create our own
		_progress_store = ProgressStore.new()
		_progress_store.initialize("guest_default")

	_initialize_all_systems()
	_initialized = true


## Initializes all new game systems
func _initialize_all_systems() -> void:
	# Create store extensions wrapper
	store_extensions = ProgressStoreExtensions.new(_progress_store)

	# Initialize XP Manager
	xp_manager = XPManager.new()
	xp_manager.initialize(_progress_store)
	xp_manager.level_up.connect(_on_level_up)
	xp_manager.xp_gained.connect(_on_xp_gained)

	# Initialize Achievements Manager
	achievements_manager = AchievementsManager.new()
	achievements_manager.initialize(_progress_store)
	achievements_manager.achievement_unlocked.connect(_on_achievement_unlocked)

	# Initialize Daily Challenges
	daily_challenges = DailyChallenges.new()
	daily_challenges.initialize(_progress_store)
	daily_challenges.challenge_completed.connect(_on_challenge_completed)
	daily_challenges.all_dailies_completed.connect(_on_all_dailies_completed)

	# Initialize Battle Pass
	battle_pass = BattlePass.new()
	battle_pass.initialize(_progress_store)
	battle_pass.tier_reached.connect(_on_bp_tier_reached)

	# Initialize Combat Feedback
	combat_feedback = CombatFeedback.new()
	combat_feedback.name = "CombatFeedback"
	add_child(combat_feedback)
	combat_feedback.streak_achieved.connect(_on_streak_achieved)

	# Initialize Adaptive Difficulty
	adaptive_difficulty = AdaptiveDifficulty.new()
	adaptive_difficulty.initialize(_progress_store)

	# Initialize Hot Drop System
	hot_drop_system = HotDropSystem.new()
	hot_drop_system.hot_drop_survived.connect(_on_hot_drop_survived)

	# Initialize Daily Login Rewards
	daily_login = DailyLoginRewards.new()
	daily_login.initialize(store_extensions)
	daily_login.reward_claimed.connect(_on_login_reward_claimed)

	# Initialize Notification Manager
	notification_manager = NotificationManager.new()
	notification_manager.name = "NotificationManager"
	add_child(notification_manager)

	# Check first match of day
	_check_first_match_of_day()


## Called by GameOrchestrator when a match starts
func on_match_start(settings: Dictionary) -> void:
	# Reset match tracking
	_match_tracking = {
		"damage_taken": 0.0,
		"storm_time": 0.0,
		"items_looted": 0,
		"weapon_category_kills": {},
		"is_first_match_of_day": not _first_match_checked,
		"max_kill_streak": 0,
		"final_health": 100.0,
	}

	# Reset combat feedback
	combat_feedback.reset()

	# Reset adaptive difficulty match metrics
	adaptive_difficulty.reset_match_metrics()

	# Generate hot drop zones
	var scene_mgr: Node = get_node_or_null("/root/SceneManager")
	var map_data: MapData = MapData.new()
	var bot_count: int = settings.get("bot_count", 50)
	hot_drop_system.generate_zones(map_data, bot_count)

	# Mark first match checked
	_first_match_checked = true


## Called by GameOrchestrator when the player gets a kill
func on_player_kill(victim_name: String, weapon_name: String, weapon_category: String, damage: float) -> void:
	# Combat feedback
	combat_feedback.on_player_kill(victim_name, weapon_name, damage)
	_match_tracking["max_kill_streak"] = maxi(_match_tracking["max_kill_streak"], combat_feedback.current_streak)

	# Track weapon category kills
	var cat_kills: Dictionary = _match_tracking.get("weapon_category_kills", {})
	cat_kills[weapon_category] = cat_kills.get(weapon_category, 0) + 1
	_match_tracking["weapon_category_kills"] = cat_kills


## Called by GameOrchestrator when the player hits but doesn't kill
func on_player_hit(damage: float, target_position: Vector2) -> void:
	combat_feedback.on_player_hit(damage, target_position)


## Called by GameOrchestrator when the player takes damage
func on_player_damaged(amount: float, from_direction: Vector2) -> void:
	combat_feedback.on_player_damaged(amount, from_direction)
	_match_tracking["damage_taken"] = _match_tracking.get("damage_taken", 0.0) + amount


## Called by GameOrchestrator when player health changes
func on_health_changed(health: float, shield: float) -> void:
	combat_feedback.update_health_state(health)
	_match_tracking["final_health"] = health


## Called when the player loots an item
func on_item_looted() -> void:
	_match_tracking["items_looted"] = _match_tracking.get("items_looted", 0) + 1


## Called each frame during storm damage
func on_storm_damage_tick(delta: float) -> void:
	_match_tracking["storm_time"] = _match_tracking.get("storm_time", 0.0) + delta


## Called when player selects a drop position
func on_player_drop(position: Vector2) -> void:
	hot_drop_system.on_player_drop(position)
	if hot_drop_system.player_in_hot_zone:
		var zone: Dictionary = hot_drop_system.player_drop_zone
		notification_manager.show_hot_drop(zone.get("heat_name", "Hot Zone"))


## Called each frame during active gameplay (for hot drop survival tracking)
func on_match_update(delta: float, kills: int, damage_dealt: float, 
		elapsed_time: float, alive_count: int, total_bots: int) -> void:
	# Hot drop survival tracking
	hot_drop_system.update(delta)

	# Adaptive difficulty mid-match adjustments
	adaptive_difficulty.update_mid_match(
		kills, damage_dealt, 
		_match_tracking.get("damage_taken", 0.0),
		elapsed_time, alive_count, total_bots
	)


## Called by GameOrchestrator when a match ends.
## Processes all post-match rewards: XP, achievements, challenges, battle pass.
func on_match_end(result: Dictionary) -> void:
	# Merge match tracking data into result
	var full_result: Dictionary = result.duplicate()
	full_result["damage_taken"] = _match_tracking.get("damage_taken", 0.0)
	full_result["storm_survival_time"] = _match_tracking.get("storm_time", 0.0)
	full_result["items_looted"] = _match_tracking.get("items_looted", 0)
	full_result["weapon_category_kills"] = _match_tracking.get("weapon_category_kills", {})
	full_result["is_first_match_of_day"] = _match_tracking.get("is_first_match_of_day", false)
	full_result["max_kill_streak"] = _match_tracking.get("max_kill_streak", 0)
	full_result["final_health"] = _match_tracking.get("final_health", 0.0)

	# --- XP Processing ---
	var xp_breakdown: Dictionary = xp_manager.process_match_xp(full_result)

	# --- Achievement Processing ---
	var new_achievements: Array = achievements_manager.process_match_results(full_result)
	for ach_id in new_achievements:
		var ach_data: Dictionary = achievements_manager.get_all_achievements().get(ach_id, {})
		xp_manager.award_achievement_xp(ach_data)

	# --- Challenge Processing ---
	var completed_challenges: Array = daily_challenges.process_match_results(full_result)
	for challenge in completed_challenges:
		xp_manager.award_challenge_xp(challenge)

	# --- Battle Pass XP (seasonal) ---
	var total_match_xp: int = 0
	for val in xp_breakdown.values():
		total_match_xp += val
	battle_pass.award_season_xp(total_match_xp)

	# --- Adaptive Difficulty Update ---
	adaptive_difficulty.post_match_update(full_result)

	# Store full_result for match history enrichment
	full_result["xp_breakdown"] = xp_breakdown
	full_result["achievements_unlocked"] = new_achievements
	full_result["challenges_completed"] = completed_challenges


# --- Signal Handlers (route to NotificationManager) ---

func _on_level_up(new_level: int, rewards: Array) -> void:
	notification_manager.show_level_up(new_level, rewards)


func _on_xp_gained(amount: int, _source: Enums.XPSource, _total: int) -> void:
	# Only show notification for significant XP gains
	if amount >= 50:
		notification_manager.show_xp_gain(amount, _get_xp_source_text(_source))


func _on_achievement_unlocked(_id: String, data: Dictionary) -> void:
	notification_manager.show_achievement_unlock(data)


func _on_challenge_completed(challenge: Dictionary) -> void:
	notification_manager.show_challenge_complete(challenge)


func _on_all_dailies_completed() -> void:
	var bonus_xp: int = daily_challenges.get_all_dailies_bonus_xp()
	xp_manager.award_xp(bonus_xp, Enums.XPSource.DAILY_CHALLENGE)
	notification_manager.show_toast(
		"All Dailies Complete!",
		"+%d Bonus XP (Streak: %d)" % [bonus_xp, daily_challenges.login_streak]
	)


func _on_bp_tier_reached(tier: int, rewards: Array) -> void:
	notification_manager.show_battle_pass_tier(tier, rewards)


func _on_streak_achieved(tier: Enums.KillStreak, kill_count: int) -> void:
	var text: String = combat_feedback.get_streak_announcement()
	if not text.is_empty():
		notification_manager.show_streak_announcement(text, kill_count)


func _on_hot_drop_survived(_zone: Dictionary, bonus_xp: int) -> void:
	xp_manager.award_xp(bonus_xp, Enums.XPSource.STREAK_BONUS)
	notification_manager.show_toast("Hot Drop Survived!", "+%d XP" % bonus_xp)


func _on_login_reward_claimed(_day: int, reward: Dictionary) -> void:
	notification_manager.show_toast(
		"Daily Reward: %s" % reward.get("name", "Reward"),
		reward.get("description", "")
	)


## Checks if this is the first match of the day
func _check_first_match_of_day() -> void:
	var today: String = _get_today_string()
	if _last_match_date != today:
		_first_match_checked = false
	_last_match_date = today


## Gets human-readable XP source text
func _get_xp_source_text(source: Enums.XPSource) -> String:
	match source:
		Enums.XPSource.KILL: return "Eliminations"
		Enums.XPSource.PLACEMENT: return "Placement"
		Enums.XPSource.SURVIVAL_TIME: return "Survival"
		Enums.XPSource.WIN_BONUS: return "Victory!"
		Enums.XPSource.DAILY_CHALLENGE: return "Challenge"
		Enums.XPSource.ACHIEVEMENT: return "Achievement"
		Enums.XPSource.FIRST_MATCH_OF_DAY: return "First Match Bonus"
		Enums.XPSource.STREAK_BONUS: return "Streak Bonus"
		Enums.XPSource.BATTLE_PASS_BONUS: return "Battle Pass"
		_: return "Bonus"


## Gets today's date string
func _get_today_string() -> String:
	var dt: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


## Returns the combat feedback screen shake offset (for camera integration)
func get_camera_shake_offset() -> Vector2:
	if combat_feedback != null:
		return combat_feedback.shake_offset
	return Vector2.ZERO


## Returns whether the hit marker should be visible
func is_hit_marker_visible() -> bool:
	if combat_feedback != null:
		return combat_feedback.hit_marker_visible
	return false


## Returns whether the hit marker is a kill confirmation
func is_hit_marker_kill() -> bool:
	if combat_feedback != null:
		return combat_feedback.hit_marker_is_kill
	return false
