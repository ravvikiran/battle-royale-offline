## AI-powered adaptive difficulty system that learns from player performance.
## Analyzes recent match history to recommend difficulty adjustments,
## keeping the player in a "flow state" — challenged but not frustrated.
## Uses a rolling window of recent matches for responsiveness.
class_name AdaptiveDifficulty
extends RefCounted


## Emitted when a difficulty recommendation changes
signal recommendation_changed(recommended: Enums.Difficulty, reason: String)

## Emitted when difficulty auto-adjusts mid-match
signal mid_match_adjustment(new_engagement_range: float, new_accuracy_mod: float)


## Current recommended difficulty
var recommended_difficulty: Enums.Difficulty = Enums.Difficulty.MEDIUM

## Reason for current recommendation
var recommendation_reason: String = ""

## Player skill rating (0.0 = beginner, 1.0 = expert)
var player_skill_rating: float = 0.5

## Confidence in the skill rating (increases with more matches)
var confidence: float = 0.0

## Rolling match performance window (last N matches)
var _recent_matches: Array = []

## Reference to progress store
var _progress_store: ProgressStore = null

## Whether initialized
var _initialized: bool = false

## Mid-match performance metrics
var _match_kills_so_far: int = 0
var _match_deaths: int = 0
var _match_time: float = 0.0
var _match_damage_dealt: float = 0.0
var _match_damage_taken: float = 0.0

## Current mid-match modifier (multiplier on bot accuracy/aggression)
var bot_accuracy_modifier: float = 1.0
var bot_aggression_modifier: float = 1.0


## Number of matches to consider in the rolling window
const WINDOW_SIZE: int = 10

## Skill rating weights for different metrics
const WEIGHT_WIN_RATE: float = 0.3
const WEIGHT_KD_RATIO: float = 0.25
const WEIGHT_AVG_KILLS: float = 0.2
const WEIGHT_SURVIVAL: float = 0.15
const WEIGHT_CONSISTENCY: float = 0.1

## Thresholds for difficulty recommendations
const SKILL_EASY_THRESHOLD: float = 0.3     ## Below this → suggest Easy
const SKILL_MEDIUM_THRESHOLD: float = 0.6   ## Between easy and this → Medium
const SKILL_HARD_THRESHOLD: float = 0.75    ## Above this → Hard

## Frustration detection thresholds
const FRUSTRATION_LOSS_STREAK: int = 5      ## 5 losses in a row triggers concern
const FRUSTRATION_LOW_KILLS: float = 1.0    ## Avg kills below this on current difficulty

## Boredom detection thresholds
const BOREDOM_WIN_STREAK: int = 5           ## 5 wins in a row suggests too easy
const BOREDOM_HIGH_KILLS: float = 15.0      ## Avg kills above this suggests domination

## Mid-match adjustment sensitivity
const MID_MATCH_CHECK_INTERVAL: float = 30.0  ## Check every 30 seconds


func initialize(progress_store: ProgressStore) -> void:
	_progress_store = progress_store
	_load_recent_matches()
	_calculate_skill_rating()
	_update_recommendation()
	_initialized = true


## Loads recent match history from ProgressStore
func _load_recent_matches() -> void:
	if _progress_store == null:
		return
	var history: Array = _progress_store.get_match_history(WINDOW_SIZE)
	_recent_matches = history


## Calculates the player skill rating from recent performance
func _calculate_skill_rating() -> void:
	if _recent_matches.size() == 0:
		player_skill_rating = 0.5
		confidence = 0.0
		return

	var total_matches: int = _recent_matches.size()
	confidence = clampf(float(total_matches) / float(WINDOW_SIZE), 0.0, 1.0)

	# Calculate component metrics
	var wins: int = 0
	var total_kills: int = 0
	var total_survival: int = 0
	var placements: Array = []

	for match_data in _recent_matches:
		if match_data.get("placement", 99) == 1:
			wins += 1
		total_kills += match_data.get("kills", 0)
		total_survival += match_data.get("survival_time_seconds", 0)
		placements.append(match_data.get("placement", 50))

	# Win rate component (0.0 - 1.0)
	var win_rate: float = float(wins) / float(total_matches)
	# Normalize: 10% win rate = 0.0 skill, 50%+ = 1.0
	var win_score: float = clampf((win_rate - 0.1) / 0.4, 0.0, 1.0)

	# K/D ratio component (kills per match)
	var avg_kills: float = float(total_kills) / float(total_matches)
	# Normalize: 2 kills/match = 0.0, 15+ = 1.0
	var kd_score: float = clampf((avg_kills - 2.0) / 13.0, 0.0, 1.0)

	# Average kills raw score
	var kill_score: float = clampf(avg_kills / 20.0, 0.0, 1.0)

	# Survival score (average survival time)
	var avg_survival: float = float(total_survival) / float(total_matches)
	# Normalize: 60s = 0.0, 600s+ = 1.0
	var survival_score: float = clampf((avg_survival - 60.0) / 540.0, 0.0, 1.0)

	# Consistency score (low variance in placement = consistent)
	var avg_placement: float = 0.0
	for p in placements:
		avg_placement += float(p)
	avg_placement /= float(total_matches)
	var variance: float = 0.0
	for p in placements:
		variance += pow(float(p) - avg_placement, 2)
	variance /= float(total_matches)
	# Low variance = high consistency
	var consistency_score: float = clampf(1.0 - (sqrt(variance) / 25.0), 0.0, 1.0)

	# Weighted combination
	player_skill_rating = (
		win_score * WEIGHT_WIN_RATE +
		kd_score * WEIGHT_KD_RATIO +
		kill_score * WEIGHT_AVG_KILLS +
		survival_score * WEIGHT_SURVIVAL +
		consistency_score * WEIGHT_CONSISTENCY
	)


## Updates the difficulty recommendation based on skill rating and patterns
func _update_recommendation() -> void:
	var prev_recommendation: Enums.Difficulty = recommended_difficulty

	# Check for frustration patterns first
	if _detect_frustration():
		if recommended_difficulty != Enums.Difficulty.EASY:
			recommended_difficulty = Enums.Difficulty.EASY
			recommendation_reason = "You've had a rough streak. Try Easy to rebuild confidence!"
			if recommended_difficulty != prev_recommendation:
				recommendation_changed.emit(recommended_difficulty, recommendation_reason)
			return

	# Check for boredom patterns
	if _detect_boredom():
		if recommended_difficulty != Enums.Difficulty.HARD:
			recommended_difficulty = Enums.Difficulty.HARD
			recommendation_reason = "You're dominating! Try Hard for a real challenge."
			if recommended_difficulty != prev_recommendation:
				recommendation_changed.emit(recommended_difficulty, recommendation_reason)
			return

	# Standard skill-based recommendation
	if player_skill_rating < SKILL_EASY_THRESHOLD:
		recommended_difficulty = Enums.Difficulty.EASY
		recommendation_reason = "Recommended based on your recent performance."
	elif player_skill_rating < SKILL_MEDIUM_THRESHOLD:
		recommended_difficulty = Enums.Difficulty.MEDIUM
		recommendation_reason = "Balanced challenge for your skill level."
	elif player_skill_rating >= SKILL_HARD_THRESHOLD:
		recommended_difficulty = Enums.Difficulty.HARD
		recommendation_reason = "You're skilled enough for the hardest challenge!"
	else:
		recommended_difficulty = Enums.Difficulty.MEDIUM
		recommendation_reason = "Good match for your current skill."

	if recommended_difficulty != prev_recommendation:
		recommendation_changed.emit(recommended_difficulty, recommendation_reason)


## Detects frustration patterns (many consecutive losses, low kills)
func _detect_frustration() -> bool:
	if _recent_matches.size() < 3:
		return false

	# Check for loss streak
	var consecutive_losses: int = 0
	for match_data in _recent_matches:
		if match_data.get("placement", 99) != 1:
			consecutive_losses += 1
		else:
			break

	if consecutive_losses >= FRUSTRATION_LOSS_STREAK:
		return true

	# Check for consistently low kills
	var recent_kills: Array = []
	for i in range(mini(5, _recent_matches.size())):
		recent_kills.append(_recent_matches[i].get("kills", 0))

	if recent_kills.size() >= 3:
		var avg: float = 0.0
		for k in recent_kills:
			avg += float(k)
		avg /= float(recent_kills.size())
		if avg < FRUSTRATION_LOW_KILLS:
			return true

	return false


## Detects boredom patterns (many consecutive wins, very high kills)
func _detect_boredom() -> bool:
	if _recent_matches.size() < 3:
		return false

	# Check for win streak
	var consecutive_wins: int = 0
	for match_data in _recent_matches:
		if match_data.get("placement", 99) == 1:
			consecutive_wins += 1
		else:
			break

	if consecutive_wins >= BOREDOM_WIN_STREAK:
		return true

	# Check for consistently high kills
	var recent_kills: Array = []
	for i in range(mini(5, _recent_matches.size())):
		recent_kills.append(_recent_matches[i].get("kills", 0))

	if recent_kills.size() >= 3:
		var avg: float = 0.0
		for k in recent_kills:
			avg += float(k)
		avg /= float(recent_kills.size())
		if avg >= BOREDOM_HIGH_KILLS:
			return true

	return false


## Called during an active match to update mid-match metrics.
## Can trigger real-time difficulty adjustments (rubber banding).
func update_mid_match(kills: int, damage_dealt: float, damage_taken: float, 
		elapsed_time: float, alive_count: int, total_bots: int) -> void:
	_match_kills_so_far = kills
	_match_damage_dealt = damage_dealt
	_match_damage_taken = damage_taken
	_match_time = elapsed_time

	# Only adjust every N seconds
	if fmod(elapsed_time, MID_MATCH_CHECK_INTERVAL) > 1.0:
		return

	# Calculate how the player is performing relative to expected
	var expected_kills_by_now: float = elapsed_time / 60.0 * 3.0  # ~3 kills per minute expected
	var kill_performance: float = float(kills) / maxf(expected_kills_by_now, 1.0)

	# If player is struggling (fewer kills than expected, taking lots of damage)
	if kill_performance < 0.3 and damage_taken > damage_dealt * 1.5:
		# Make bots slightly less accurate and aggressive
		bot_accuracy_modifier = lerpf(bot_accuracy_modifier, 0.75, 0.1)
		bot_aggression_modifier = lerpf(bot_aggression_modifier, 0.8, 0.1)
	elif kill_performance > 2.0 and damage_taken < damage_dealt * 0.3:
		# Player is dominating — make bots slightly harder
		bot_accuracy_modifier = lerpf(bot_accuracy_modifier, 1.2, 0.05)
		bot_aggression_modifier = lerpf(bot_aggression_modifier, 1.15, 0.05)
	else:
		# Normalize back toward 1.0
		bot_accuracy_modifier = lerpf(bot_accuracy_modifier, 1.0, 0.05)
		bot_aggression_modifier = lerpf(bot_aggression_modifier, 1.0, 0.05)

	mid_match_adjustment.emit(bot_accuracy_modifier, bot_aggression_modifier)


## Called after a match to add results to the rolling window
func post_match_update(result: Dictionary) -> void:
	_recent_matches.insert(0, result)
	if _recent_matches.size() > WINDOW_SIZE:
		_recent_matches.resize(WINDOW_SIZE)
	_calculate_skill_rating()
	_update_recommendation()


## Resets mid-match metrics for a new match
func reset_match_metrics() -> void:
	_match_kills_so_far = 0
	_match_deaths = 0
	_match_time = 0.0
	_match_damage_dealt = 0.0
	_match_damage_taken = 0.0
	bot_accuracy_modifier = 1.0
	bot_aggression_modifier = 1.0


## Returns a summary of the player's performance profile
func get_player_profile() -> Dictionary:
	return {
		"skill_rating": player_skill_rating,
		"confidence": confidence,
		"recommended_difficulty": recommended_difficulty,
		"reason": recommendation_reason,
		"matches_analyzed": _recent_matches.size(),
		"accuracy_mod": bot_accuracy_modifier,
		"aggression_mod": bot_aggression_modifier
	}
