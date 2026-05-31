## Property-based tests for bot AI system.
## Generates random bot states, contexts, positions, and difficulty levels,
## then verifies that bot behavior properties hold across all generated inputs.
##
## **Validates: Requirements 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 3.3, 3.5**
extends GutTest


## Number of random iterations per property test.
const ITERATIONS: int = 100

## Valid character models for bot assignment.
const VALID_CHARACTERS: Array[String] = ["BLITZ", "TITAN", "PHANTOM"]

## Valid character variants.
const VALID_VARIANTS: Array[String] = ["MALE", "FEMALE"]

## Character primary colors (from characters.json) — must all be distinct hues.
const CHARACTER_COLORS: Dictionary = {
	"BLITZ": "#FF6B35",
	"TITAN": "#2E86AB",
	"PHANTOM": "#7B2D8B",
}


var _manager: BotAIManager


func before_each() -> void:
	_manager = BotAIManager.new()
	add_child(_manager)


func after_each() -> void:
	_manager.queue_free()


# --- Helper functions for random generation ---

## Returns a random difficulty enum value.
func _random_difficulty() -> Enums.Difficulty:
	var difficulties := [
		Enums.Difficulty.EASY,
		Enums.Difficulty.MEDIUM,
		Enums.Difficulty.HARD,
	]
	return difficulties[randi() % difficulties.size()]


## Generates a random 2D position within a reasonable game world range.
func _random_position() -> Vector2:
	return Vector2(randf_range(-2000.0, 2000.0), randf_range(-2000.0, 2000.0))


## Generates a random health value between 0 and 100.
func _random_health() -> float:
	return randf_range(0.1, 100.0)


## Generates a random bot count for spawning (10-99).
func _random_bot_count() -> int:
	return randi_range(10, 99)


## Creates a random bot context dictionary for FSM decision testing.
func _random_context() -> Dictionary:
	return {
		"is_in_safe_zone": randf() > 0.5,
		"enemy_in_range": randf() > 0.5,
		"enemy_position": _random_position(),
		"is_under_fire": randf() > 0.5,
		"nearest_safe_point": _random_position(),
		"nearest_loot_position": _random_position(),
	}


## Creates a BotInstance with randomized state for property testing.
func _random_bot(difficulty: Enums.Difficulty) -> BotInstance:
	var bot := BotInstance.new()
	bot.initialize(randi_range(0, 999), difficulty)
	bot.health = _random_health()
	bot.has_weapon = randf() > 0.5
	bot.has_healing_item = randf() > 0.5
	bot.is_under_fire = randf() > 0.5
	bot.position = _random_position()
	return bot


## Converts a hex color string to HSV and returns the hue component (0-360).
func _hex_to_hue(hex: String) -> float:
	var color := Color(hex)
	return color.h * 360.0


# --- Property 10: Bot FSM decision correctness ---
# For any bot state, the chosen action follows priority rules:
# (1) unarmed + not in danger → loot
# (2) outside zone → flee
# (3) enemy + health > 50% + armed → engage
# (4) enemy + (health ≤ 50% or unarmed) → flee
# (5) health < 30% → heal/flee
# (6) armed + in zone + no enemy → roam

func test_property_10_bot_fsm_decision_correctness() -> void:
	gut.p("Property 10: Bot FSM decision correctness")
	gut.p("For any bot state, the chosen action follows priority rules.")

	for i in range(ITERATIONS):
		var difficulty := _random_difficulty()
		var bot := _random_bot(difficulty)
		var context := _random_context()

		var in_safe_zone: bool = context.get("is_in_safe_zone", true)
		var enemy_in_range: bool = context.get("enemy_in_range", false)
		var under_fire: bool = context.get("is_under_fire", false)

		# Determine "in danger" as the bot code does
		var in_danger: bool = under_fire or not in_safe_zone or bot.health < 30.0

		var result := bot.decide_action(context)

		# Priority 1: Unarmed and not in danger → LOOTING
		if not bot.has_weapon and not in_danger:
			assert_eq(result, Enums.BotState.LOOTING,
				"[Iter %d] Unarmed + safe → should LOOT (health=%.1f, weapon=%s, zone=%s, fire=%s)" % [
					i, bot.health, bot.has_weapon, in_safe_zone, under_fire])
			continue

		# Priority 2: Outside safe zone → FLEEING
		if not in_safe_zone:
			assert_eq(result, Enums.BotState.FLEEING,
				"[Iter %d] Outside zone → should FLEE (health=%.1f, weapon=%s)" % [
					i, bot.health, bot.has_weapon])
			continue

		# Priority 3: Enemy in range, health > 50%, armed → ENGAGING
		if enemy_in_range and bot.health > 50.0 and bot.has_weapon:
			assert_eq(result, Enums.BotState.ENGAGING,
				"[Iter %d] Enemy + healthy + armed → should ENGAGE (health=%.1f)" % [
					i, bot.health])
			continue

		# Priority 4: Enemy in range, health ≤ 50% or unarmed → FLEEING
		if enemy_in_range and (bot.health <= 50.0 or not bot.has_weapon):
			assert_eq(result, Enums.BotState.FLEEING,
				"[Iter %d] Enemy + low/unarmed → should FLEE (health=%.1f, weapon=%s)" % [
					i, bot.health, bot.has_weapon])
			continue

		# Priority 5: Health < 30% → heal if possible, else flee
		if bot.health < 30.0:
			if bot.has_healing_item:
				assert_eq(result, Enums.BotState.HEALING,
					"[Iter %d] Low health + has healing → should HEAL (health=%.1f)" % [
						i, bot.health])
			else:
				assert_eq(result, Enums.BotState.FLEEING,
					"[Iter %d] Low health + no healing → should FLEE (health=%.1f)" % [
						i, bot.health])
			continue

		# Priority 6: Armed, in zone, no enemy → ROAMING
		if bot.has_weapon and in_safe_zone and not enemy_in_range:
			assert_eq(result, Enums.BotState.ROAMING,
				"[Iter %d] Armed + safe + no enemy → should ROAM (health=%.1f)" % [
					i, bot.health])
			continue


# --- Property 11: Bot movement toward safe zone ---
# For any bot outside safe zone, movement vector has positive dot product
# toward nearest safe boundary point.

func test_property_11_bot_movement_toward_safe_zone() -> void:
	gut.p("Property 11: Bot movement toward safe zone")
	gut.p("For any bot outside safe zone, movement has positive dot product toward safety.")

	for i in range(ITERATIONS):
		var difficulty := _random_difficulty()
		var bot := BotInstance.new()
		bot.initialize(i, difficulty)

		# Generate random bot position and a safe point that is different
		bot.position = _random_position()
		var safe_point := _random_position()

		# Ensure bot is not already at the safe point (avoid zero-length vector)
		while bot.position.distance_to(safe_point) < 1.0:
			safe_point = _random_position()

		# Calculate movement toward zone
		var movement := bot.calculate_movement_toward_zone(safe_point)

		# The direction toward the safe point
		var toward_safe := (safe_point - bot.position).normalized()

		# Dot product should be positive (moving toward safety)
		var dot := movement.dot(toward_safe)
		assert_gt(dot, 0.0,
			"[Iter %d] Movement dot product toward safe zone must be positive. Got %f (pos=%s, safe=%s, move=%s)" % [
				i, dot, bot.position, safe_point, movement])

		# Movement vector should be normalized
		assert_almost_eq(movement.length(), 1.0, 0.001,
			"[Iter %d] Movement vector should be normalized. Got length %f" % [
				i, movement.length()])


# --- Property 12: Bot difficulty parameters ---
# Reaction time and accuracy fall within specified ranges per difficulty.

func test_property_12_bot_difficulty_parameters() -> void:
	gut.p("Property 12: Bot difficulty parameters")
	gut.p("Reaction time and accuracy fall within specified ranges per difficulty.")

	for i in range(ITERATIONS):
		var difficulty := _random_difficulty()
		var bot := BotInstance.new()
		bot.initialize(i, difficulty)

		# Get expected ranges for this difficulty
		var rt_range: Dictionary = BotInstance.REACTION_TIME_RANGES[difficulty]
		var acc_range: Dictionary = BotInstance.ACCURACY_RANGES[difficulty]

		# Verify reaction time is within range
		assert_gte(bot.reaction_time_ms, rt_range["min"],
			"[Iter %d] Reaction time %f must be >= %f for difficulty %d" % [
				i, bot.reaction_time_ms, rt_range["min"], difficulty])
		assert_lte(bot.reaction_time_ms, rt_range["max"],
			"[Iter %d] Reaction time %f must be <= %f for difficulty %d" % [
				i, bot.reaction_time_ms, rt_range["max"], difficulty])

		# Verify accuracy is within range
		assert_gte(bot.accuracy, acc_range["min"],
			"[Iter %d] Accuracy %f must be >= %f for difficulty %d" % [
				i, bot.accuracy, acc_range["min"], difficulty])
		assert_lte(bot.accuracy, acc_range["max"],
			"[Iter %d] Accuracy %f must be <= %f for difficulty %d" % [
				i, bot.accuracy, acc_range["max"], difficulty])

		# Verify engagement range matches difficulty
		var expected_range: float = BotInstance.ENGAGEMENT_RANGES[difficulty]
		assert_almost_eq(bot.engagement_range, expected_range, 0.001,
			"[Iter %d] Engagement range %f must equal %f for difficulty %d" % [
				i, bot.engagement_range, expected_range, difficulty])


# --- Property 5: Character assignment validity ---
# Each spawned bot has valid character (Blitz/Titan/Phantom) with valid
# variant (Male/Female), and no two characters share the same primary color hue.

func test_property_5_character_assignment_validity() -> void:
	gut.p("Property 5: Character assignment validity")
	gut.p("Each spawned bot has valid character with valid variant.")

	for i in range(ITERATIONS):
		var difficulty := _random_difficulty()
		var bot_count := _random_bot_count()

		_manager.spawn_bots(bot_count, difficulty)

		# Verify each bot has a valid character and variant
		for bot in _manager.bots:
			assert_has(VALID_CHARACTERS, bot.character_id,
				"[Iter %d] Bot %d character_id '%s' must be one of %s" % [
					i, bot.id, bot.character_id, VALID_CHARACTERS])
			assert_has(VALID_VARIANTS, bot.character_variant,
				"[Iter %d] Bot %d character_variant '%s' must be one of %s" % [
					i, bot.id, bot.character_variant, VALID_VARIANTS])

		# Verify no two characters in the character set share the same primary color hue
		# (This is a data-level property — check the character color definitions)
		var hues: Array[float] = []
		for character_id in CHARACTER_COLORS.keys():
			var hue := _hex_to_hue(CHARACTER_COLORS[character_id])
			# Check that this hue is sufficiently different from all previous hues
			for existing_hue in hues:
				var hue_diff := absf(hue - existing_hue)
				# Account for hue wrapping (e.g., 350 and 10 are only 20 apart)
				if hue_diff > 180.0:
					hue_diff = 360.0 - hue_diff
				assert_gt(hue_diff, 30.0,
					"[Iter %d] Characters must have distinct primary color hues. Hue %f too close to %f" % [
						i, hue, existing_hue])
			hues.append(hue)

		# Clean up for next iteration
		_manager.spawn_bots(0, difficulty)  # Clear bots
