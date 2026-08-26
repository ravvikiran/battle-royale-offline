## Battle Pass / Season system with tiered rewards and XP-based progression.
## Features free and premium tracks with 50 tiers per season.
## Tracks seasonal XP independently from player level.
## Rewards include cosmetic items, titles, banners, and currency.
class_name BattlePass
extends RefCounted


## Emitted when a new tier is reached
signal tier_reached(tier: int, rewards: Array)

## Emitted when the battle pass is completed (all 50 tiers)
signal pass_completed(is_premium: bool)

## Emitted when seasonal XP is gained
signal season_xp_gained(amount: int, new_total: int)


## Current season identifier
var current_season: Enums.Season = Enums.Season.SEASON_1

## Current tier (1-50)
var current_tier: int = 0

## XP within current tier
var current_tier_xp: int = 0

## Total seasonal XP earned
var total_season_xp: int = 0

## Whether the player has the premium pass
var is_premium: bool = false

## Claimed tier rewards (array of tier numbers already claimed)
var _claimed_free: Array = []
var _claimed_premium: Array = []

## Reference to progress store
var _progress_store: ProgressStore = null

## Whether initialized
var _initialized: bool = false


## Total number of tiers in the battle pass
const MAX_TIER: int = 50

## Base XP required per tier (scales slightly with tier)
const BASE_TIER_XP: int = 200

## XP scaling per tier (tier 1 = base, tier 50 = base * 1.5)
const TIER_XP_SCALE: float = 0.01

## Season display names
const SEASON_NAMES: Dictionary = {
	Enums.Season.SEASON_1: "Season 1: First Drop",
	Enums.Season.SEASON_2: "Season 2: Storm Rising",
	Enums.Season.SEASON_3: "Season 3: Neon Nights",
	Enums.Season.SEASON_4: "Season 4: Final Stand",
}

## Season theme colors
const SEASON_COLORS: Dictionary = {
	Enums.Season.SEASON_1: Color(0.2, 0.6, 1.0),
	Enums.Season.SEASON_2: Color(0.6, 0.2, 0.8),
	Enums.Season.SEASON_3: Color(0.0, 1.0, 0.8),
	Enums.Season.SEASON_4: Color(1.0, 0.3, 0.1),
}

## Free tier rewards (tier_number: reward_data)
const FREE_REWARDS: Dictionary = {
	1: {"type": "XP", "value": 100, "name": "100 Bonus XP"},
	3: {"type": "BANNER", "value": "season1_basic", "name": "Season 1 Banner"},
	5: {"type": "TITLE", "value": "season_warrior", "name": "Season Warrior Title"},
	7: {"type": "XP", "value": 200, "name": "200 Bonus XP"},
	10: {"type": "TRAIL_EFFECT", "value": "smoke_trail", "name": "Smoke Trail"},
	12: {"type": "XP", "value": 250, "name": "250 Bonus XP"},
	15: {"type": "BANNER", "value": "season1_silver", "name": "Silver Season Banner"},
	18: {"type": "XP", "value": 300, "name": "300 Bonus XP"},
	20: {"type": "DROP_EFFECT", "value": "spark_drop", "name": "Spark Drop Effect"},
	22: {"type": "XP", "value": 350, "name": "350 Bonus XP"},
	25: {"type": "TITLE", "value": "battle_veteran", "name": "Battle Veteran Title"},
	28: {"type": "XP", "value": 400, "name": "400 Bonus XP"},
	30: {"type": "TRAIL_EFFECT", "value": "electric_trail", "name": "Electric Trail"},
	33: {"type": "XP", "value": 450, "name": "450 Bonus XP"},
	35: {"type": "BANNER", "value": "season1_gold", "name": "Gold Season Banner"},
	38: {"type": "XP", "value": 500, "name": "500 Bonus XP"},
	40: {"type": "DROP_EFFECT", "value": "lightning_drop", "name": "Lightning Drop"},
	43: {"type": "XP", "value": 600, "name": "600 Bonus XP"},
	45: {"type": "TITLE", "value": "season_legend", "name": "Season Legend Title"},
	48: {"type": "XP", "value": 750, "name": "750 Bonus XP"},
	50: {"type": "BANNER", "value": "season1_diamond", "name": "Diamond Season Banner"},
}

## Premium tier rewards (in addition to free rewards)
const PREMIUM_REWARDS: Dictionary = {
	1: {"type": "CHARACTER_SKIN", "value": "blitz_neon", "name": "Blitz Neon Skin"},
	5: {"type": "WEAPON_SKIN", "value": "volt_chrome", "name": "Chrome Volt Repeater"},
	8: {"type": "EMOTE", "value": "victory_dance", "name": "Victory Dance Emote"},
	10: {"type": "CHARACTER_SKIN", "value": "titan_arctic", "name": "Titan Arctic Skin"},
	13: {"type": "WEAPON_SKIN", "value": "boom_gold", "name": "Gold Boomstick"},
	15: {"type": "DROP_EFFECT", "value": "meteor_premium", "name": "Meteor Drop (Premium)"},
	18: {"type": "EMOTE", "value": "flex", "name": "Flex Emote"},
	20: {"type": "CHARACTER_SKIN", "value": "phantom_shadow", "name": "Phantom Shadow Skin"},
	23: {"type": "WEAPON_SKIN", "value": "buzzer_plasma", "name": "Plasma Buzzer"},
	25: {"type": "TRAIL_EFFECT", "value": "rainbow_trail", "name": "Rainbow Trail"},
	28: {"type": "EMOTE", "value": "slow_clap", "name": "Slow Clap Emote"},
	30: {"type": "CHARACTER_SKIN", "value": "blitz_fire", "name": "Blitz Fire Skin"},
	33: {"type": "WEAPON_SKIN", "value": "longshot_void", "name": "Void Longshot"},
	35: {"type": "DROP_EFFECT", "value": "portal_drop", "name": "Portal Drop Effect"},
	38: {"type": "EMOTE", "value": "dab", "name": "Dab Emote"},
	40: {"type": "CHARACTER_SKIN", "value": "titan_magma", "name": "Titan Magma Skin"},
	43: {"type": "WEAPON_SKIN", "value": "sideswipe_neon", "name": "Neon Sideswipe"},
	45: {"type": "TRAIL_EFFECT", "value": "galaxy_trail", "name": "Galaxy Trail"},
	48: {"type": "CHARACTER_SKIN", "value": "phantom_celestial", "name": "Phantom Celestial Skin"},
	50: {"type": "TITLE", "value": "season_master", "name": "Season Master Title"},
}


func initialize(progress_store: ProgressStore) -> void:
	_progress_store = progress_store
	_load_state()
	_initialized = true


## Returns XP required for a specific tier
func get_xp_for_tier(tier: int) -> int:
	return int(BASE_TIER_XP * (1.0 + TIER_XP_SCALE * float(tier - 1)))


## Returns progress fraction within current tier (0.0 to 1.0)
func get_tier_progress() -> float:
	if current_tier >= MAX_TIER:
		return 1.0
	var needed: int = get_xp_for_tier(current_tier + 1)
	if needed <= 0:
		return 1.0
	return clampf(float(current_tier_xp) / float(needed), 0.0, 1.0)


## Awards seasonal XP. Handles tier advancement.
func award_season_xp(amount: int) -> void:
	if amount <= 0:
		return
	if current_tier >= MAX_TIER:
		return

	current_tier_xp += amount
	total_season_xp += amount
	season_xp_gained.emit(amount, total_season_xp)

	# Check for tier advancement
	while current_tier < MAX_TIER:
		var needed: int = get_xp_for_tier(current_tier + 1)
		if current_tier_xp >= needed:
			current_tier_xp -= needed
			current_tier += 1
			_on_tier_reached()
		else:
			break

	_save_state()


## Called when a new tier is reached
func _on_tier_reached() -> void:
	var rewards: Array = get_rewards_for_tier(current_tier)
	tier_reached.emit(current_tier, rewards)

	if current_tier >= MAX_TIER:
		pass_completed.emit(is_premium)


## Gets all available rewards for a tier (free + premium if applicable)
func get_rewards_for_tier(tier: int) -> Array:
	var rewards: Array = []
	if FREE_REWARDS.has(tier):
		rewards.append(FREE_REWARDS[tier])
	if is_premium and PREMIUM_REWARDS.has(tier):
		rewards.append(PREMIUM_REWARDS[tier])
	return rewards


## Claims rewards for a specific tier.
## Returns the rewards that were claimed.
func claim_tier_rewards(tier: int) -> Array:
	var rewards: Array = []

	if tier > current_tier:
		return rewards  # Can't claim future tiers

	# Claim free reward
	if FREE_REWARDS.has(tier) and tier not in _claimed_free:
		rewards.append(FREE_REWARDS[tier])
		_claimed_free.append(tier)

	# Claim premium reward
	if is_premium and PREMIUM_REWARDS.has(tier) and tier not in _claimed_premium:
		rewards.append(PREMIUM_REWARDS[tier])
		_claimed_premium.append(tier)

	if rewards.size() > 0:
		_save_state()

	return rewards


## Checks if a tier's free reward has been claimed
func is_free_claimed(tier: int) -> bool:
	return tier in _claimed_free


## Checks if a tier's premium reward has been claimed
func is_premium_claimed(tier: int) -> bool:
	return tier in _claimed_premium


## Returns all unclaimed rewards up to current tier
func get_unclaimed_rewards() -> Array:
	var unclaimed: Array = []
	for tier in range(1, current_tier + 1):
		if FREE_REWARDS.has(tier) and tier not in _claimed_free:
			var reward: Dictionary = FREE_REWARDS[tier].duplicate()
			reward["tier"] = tier
			reward["track"] = "free"
			unclaimed.append(reward)
		if is_premium and PREMIUM_REWARDS.has(tier) and tier not in _claimed_premium:
			var reward: Dictionary = PREMIUM_REWARDS[tier].duplicate()
			reward["tier"] = tier
			reward["track"] = "premium"
			unclaimed.append(reward)
	return unclaimed


## Returns the season display name
func get_season_name() -> String:
	return SEASON_NAMES.get(current_season, "Unknown Season")


## Returns the season theme color
func get_season_color() -> Color:
	return SEASON_COLORS.get(current_season, Color.WHITE)


## Resets the battle pass for a new season
func start_new_season(season: Enums.Season) -> void:
	current_season = season
	current_tier = 0
	current_tier_xp = 0
	total_season_xp = 0
	_claimed_free.clear()
	_claimed_premium.clear()
	_save_state()


## Upgrades to premium pass (unlocks premium track retroactively)
func upgrade_to_premium() -> void:
	is_premium = true
	_save_state()


## Loads battle pass state from ProgressStore
func _load_state() -> void:
	if _progress_store == null:
		return
	var data: Dictionary = _progress_store.get_battle_pass_data()
	current_season = data.get("season", Enums.Season.SEASON_1)
	current_tier = data.get("tier", 0)
	current_tier_xp = data.get("tier_xp", 0)
	total_season_xp = data.get("total_xp", 0)
	is_premium = data.get("is_premium", false)
	_claimed_free = data.get("claimed_free", [])
	_claimed_premium = data.get("claimed_premium", [])


## Saves battle pass state to ProgressStore
func _save_state() -> void:
	if _progress_store == null:
		return
	_progress_store.save_battle_pass_data({
		"season": current_season,
		"tier": current_tier,
		"tier_xp": current_tier_xp,
		"total_xp": total_season_xp,
		"is_premium": is_premium,
		"claimed_free": _claimed_free,
		"claimed_premium": _claimed_premium
	})
