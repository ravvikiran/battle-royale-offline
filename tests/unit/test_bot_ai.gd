## Unit tests for BotInstance FSM decision logic, BotAIManager spawning,
## difficulty parameters, and movement toward safe zone.
extends GutTest


var _manager: BotAIManager
var _bot: BotInstance


func before_each() -> void:
	_manager = BotAIManager.new()
	add_child(_manager)
	_bot = BotInstance.new()
	_bot.initialize(0, Enums.Difficulty.MEDIUM)


func after_each() -> void:
	_manager.queue_free()


# --- BotInstance initialization tests ---

func test_bot_initialize_sets_id() -> void:
	assert_eq(_bot.id, 0)


func test_bot_initialize_starts_in_looting_state() -> void:
	assert_eq(_bot.state, Enums.BotState.LOOTING)


func test_bot_initialize_starts_unarmed() -> void:
	assert_false(_bot.has_weapon)


func test_bot_initialize_full_health() -> void:
	assert_almost_eq(_bot.health, 100.0, 0.001)


func test_bot_initialize_alive() -> void:
	assert_true(_bot.is_alive)


# --- Difficulty parameter range tests ---

func test_easy_reaction_time_in_range() -> void:
	var bot := BotInstance.new()
	bot.initialize(1, Enums.Difficulty.EASY)
	assert_gte(bot.reaction_time_ms, 1500.0, "Easy reaction time should be >= 1500ms")
	assert_lte(bot.reaction_time_ms, 2000.0, "Easy reaction time should be <= 2000ms")


func test_medium_reaction_time_in_range() -> void:
	var bot := BotInstance.new()
	bot.initialize(1, Enums.Difficulty.MEDIUM)
	assert_gte(bot.reaction_time_ms, 800.0, "Medium reaction time should be >= 800ms")
	assert_lte(bot.reaction_time_ms, 1200.0, "Medium reaction time should be <= 1200ms")


func test_hard_reaction_time_in_range() -> void:
	var bot := BotInstance.new()
	bot.initialize(1, Enums.Difficulty.HARD)
	assert_gte(bot.reaction_time_ms, 300.0, "Hard reaction time should be >= 300ms")
	assert_lte(bot.reaction_time_ms, 600.0, "Hard reaction time should be <= 600ms")


func test_easy_accuracy_in_range() -> void:
	var bot := BotInstance.new()
	bot.initialize(1, Enums.Difficulty.EASY)
	assert_gte(bot.accuracy, 0.15, "Easy accuracy should be >= 15%")
	assert_lte(bot.accuracy, 0.25, "Easy accuracy should be <= 25%")


func test_medium_accuracy_in_range() -> void:
	var bot := BotInstance.new()
	bot.initialize(1, Enums.Difficulty.MEDIUM)
	assert_gte(bot.accuracy, 0.30, "Medium accuracy should be >= 30%")
	assert_lte(bot.accuracy, 0.45, "Medium accuracy should be <= 45%")


func test_hard_accuracy_in_range() -> void:
	var bot := BotInstance.new()
	bot.initialize(1, Enums.Difficulty.HARD)
	assert_gte(bot.accuracy, 0.55, "Hard accuracy should be >= 55%")
	assert_lte(bot.accuracy, 0.70, "Hard accuracy should be <= 70%")


func test_easy_engagement_range() -> void:
	var bot := BotInstance.new()
	bot.initialize(1, Enums.Difficulty.EASY)
	assert_almost_eq(bot.engagement_range, 50.0, 0.001)


func test_medium_engagement_range() -> void:
	var bot := BotInstance.new()
	bot.initialize(1, Enums.Difficulty.MEDIUM)
	assert_almost_eq(bot.engagement_range, 75.0, 0.001)


func test_hard_engagement_range() -> void:
	var bot := BotInstance.new()
	bot.initialize(1, Enums.Difficulty.HARD)
	assert_almost_eq(bot.engagement_range, 100.0, 0.001)


# --- FSM decide_action priority tests ---

func test_priority_1_unarmed_not_in_danger_loots() -> void:
	_bot.has_weapon = false
	_bot.health = 100.0
	var context := {
		"is_in_safe_zone": true,
		"enemy_in_range": false,
		"is_under_fire": false,
		"nearest_safe_point": Vector2.ZERO,
	}
	var result := _bot.decide_action(context)
	assert_eq(result, Enums.BotState.LOOTING)


func test_priority_2_outside_safe_zone_flees() -> void:
	_bot.has_weapon = true
	_bot.health = 100.0
	_bot.position = Vector2(600, 0)
	var context := {
		"is_in_safe_zone": false,
		"enemy_in_range": false,
		"is_under_fire": false,
		"nearest_safe_point": Vector2(500, 0),
	}
	var result := _bot.decide_action(context)
	assert_eq(result, Enums.BotState.FLEEING)


func test_priority_2_unarmed_outside_zone_flees() -> void:
	_bot.has_weapon = false
	_bot.health = 100.0
	_bot.position = Vector2(600, 0)
	var context := {
		"is_in_safe_zone": false,
		"enemy_in_range": false,
		"is_under_fire": false,
		"nearest_safe_point": Vector2(500, 0),
	}
	var result := _bot.decide_action(context)
	assert_eq(result, Enums.BotState.FLEEING)


func test_priority_3_enemy_in_range_healthy_armed_engages() -> void:
	_bot.has_weapon = true
	_bot.health = 80.0
	var context := {
		"is_in_safe_zone": true,
		"enemy_in_range": true,
		"enemy_position": Vector2(50, 0),
		"is_under_fire": false,
		"nearest_safe_point": Vector2.ZERO,
	}
	var result := _bot.decide_action(context)
	assert_eq(result, Enums.BotState.ENGAGING)


func test_priority_3_health_exactly_51_engages() -> void:
	_bot.has_weapon = true
	_bot.health = 51.0
	var context := {
		"is_in_safe_zone": true,
		"enemy_in_range": true,
		"enemy_position": Vector2(50, 0),
		"is_under_fire": false,
		"nearest_safe_point": Vector2.ZERO,
	}
	var result := _bot.decide_action(context)
	assert_eq(result, Enums.BotState.ENGAGING)


func test_priority_4_enemy_in_range_low_health_flees() -> void:
	_bot.has_weapon = true
	_bot.health = 50.0
	var context := {
		"is_in_safe_zone": true,
		"enemy_in_range": true,
		"enemy_position": Vector2(50, 0),
		"is_under_fire": false,
		"nearest_safe_point": Vector2.ZERO,
	}
	var result := _bot.decide_action(context)
	assert_eq(result, Enums.BotState.FLEEING)


func test_priority_4_enemy_in_range_unarmed_flees() -> void:
	_bot.has_weapon = false
	_bot.health = 80.0
	# Unarmed + enemy in range + under fire (in danger) → not priority 1
	var context := {
		"is_in_safe_zone": true,
		"enemy_in_range": true,
		"enemy_position": Vector2(50, 0),
		"is_under_fire": true,
		"nearest_safe_point": Vector2.ZERO,
	}
	var result := _bot.decide_action(context)
	assert_eq(result, Enums.BotState.FLEEING)


func test_priority_5_health_below_30_with_healing_heals() -> void:
	_bot.has_weapon = true
	_bot.health = 25.0
	_bot.has_healing_item = true
	var context := {
		"is_in_safe_zone": true,
		"enemy_in_range": false,
		"is_under_fire": false,
		"nearest_safe_point": Vector2.ZERO,
	}
	var result := _bot.decide_action(context)
	assert_eq(result, Enums.BotState.HEALING)


func test_priority_5_health_below_30_no_healing_flees() -> void:
	_bot.has_weapon = true
	_bot.health = 25.0
	_bot.has_healing_item = false
	var context := {
		"is_in_safe_zone": true,
		"enemy_in_range": false,
		"is_under_fire": false,
		"nearest_safe_point": Vector2.ZERO,
	}
	var result := _bot.decide_action(context)
	assert_eq(result, Enums.BotState.FLEEING)


func test_priority_6_armed_in_zone_no_enemy_roams() -> void:
	_bot.has_weapon = true
	_bot.health = 80.0
	var context := {
		"is_in_safe_zone": true,
		"enemy_in_range": false,
		"is_under_fire": false,
		"nearest_safe_point": Vector2.ZERO,
	}
	var result := _bot.decide_action(context)
	assert_eq(result, Enums.BotState.ROAMING)


# --- Movement toward safe zone tests ---

func test_movement_toward_zone_positive_dot_product() -> void:
	_bot.position = Vector2(600, 0)
	var safe_point := Vector2(500, 0)
	var movement := _bot.calculate_movement_toward_zone(safe_point)
	
	# Dot product of movement with direction toward safe point should be positive
	var toward_safe := (safe_point - _bot.position).normalized()
	var dot := movement.dot(toward_safe)
	assert_gt(dot, 0.0, "Movement should have positive dot product toward safe zone")


func test_movement_toward_zone_is_normalized() -> void:
	_bot.position = Vector2(700, 300)
	var safe_point := Vector2(500, 500)
	var movement := _bot.calculate_movement_toward_zone(safe_point)
	assert_almost_eq(movement.length(), 1.0, 0.001, "Movement vector should be normalized")


func test_movement_toward_zone_zero_when_at_safe_point() -> void:
	_bot.position = Vector2(500, 500)
	var safe_point := Vector2(500, 500)
	var movement := _bot.calculate_movement_toward_zone(safe_point)
	assert_almost_eq(movement.length(), 0.0, 0.001, "Movement should be zero when at safe point")


# --- BotAIManager spawn tests ---

func test_spawn_bots_creates_correct_count() -> void:
	_manager.spawn_bots(50, Enums.Difficulty.MEDIUM)
	assert_eq(_manager.bots.size(), 50)


func test_spawn_bots_all_alive() -> void:
	_manager.spawn_bots(20, Enums.Difficulty.EASY)
	for bot in _manager.bots:
		assert_true(bot.is_alive)


func test_spawn_bots_assigns_valid_characters() -> void:
	_manager.spawn_bots(30, Enums.Difficulty.HARD)
	var valid_characters := ["BLITZ", "TITAN", "PHANTOM"]
	var valid_variants := ["MALE", "FEMALE"]
	for bot in _manager.bots:
		assert_has(valid_characters, bot.character_id,
			"Bot should have a valid character model")
		assert_has(valid_variants, bot.character_variant,
			"Bot should have a valid variant")


func test_spawn_bots_sets_difficulty() -> void:
	_manager.spawn_bots(10, Enums.Difficulty.HARD)
	assert_eq(_manager.difficulty, Enums.Difficulty.HARD)
	assert_almost_eq(_manager.engagement_range, 100.0, 0.001)


func test_spawn_bots_unique_ids() -> void:
	_manager.spawn_bots(50, Enums.Difficulty.MEDIUM)
	var ids: Array[int] = []
	for bot in _manager.bots:
		assert_does_not_have(ids, bot.id, "Bot IDs should be unique")
		ids.append(bot.id)


# --- BotAIManager elimination tests ---

func test_eliminate_bot_marks_dead() -> void:
	_manager.spawn_bots(10, Enums.Difficulty.MEDIUM)
	_manager.eliminate_bot(0)
	assert_false(_manager.bots[0].is_alive)
	assert_almost_eq(_manager.bots[0].health, 0.0, 0.001)


func test_get_alive_bots_excludes_eliminated() -> void:
	_manager.spawn_bots(10, Enums.Difficulty.MEDIUM)
	_manager.eliminate_bot(0)
	_manager.eliminate_bot(1)
	var alive := _manager.get_alive_bots()
	assert_eq(alive.size(), 8)


func test_get_alive_count() -> void:
	_manager.spawn_bots(10, Enums.Difficulty.MEDIUM)
	assert_eq(_manager.get_alive_count(), 10)
	_manager.eliminate_bot(5)
	assert_eq(_manager.get_alive_count(), 9)


# --- Bot damage tests ---

func test_take_damage_reduces_health() -> void:
	_bot.take_damage(30.0)
	assert_almost_eq(_bot.health, 70.0, 0.001)


func test_take_damage_shield_absorbs_first() -> void:
	_bot.shield = 50.0
	_bot.take_damage(30.0)
	assert_almost_eq(_bot.shield, 20.0, 0.001)
	assert_almost_eq(_bot.health, 100.0, 0.001)


func test_take_damage_overflow_to_health() -> void:
	_bot.shield = 20.0
	_bot.take_damage(50.0)
	assert_almost_eq(_bot.shield, 0.0, 0.001)
	assert_almost_eq(_bot.health, 70.0, 0.001)


func test_take_damage_kills_bot() -> void:
	_bot.take_damage(150.0)
	assert_almost_eq(_bot.health, 0.0, 0.001)
	assert_false(_bot.is_alive)


func test_heal_caps_at_100() -> void:
	_bot.health = 80.0
	_bot.heal(50.0)
	assert_almost_eq(_bot.health, 100.0, 0.001)


# --- Manager engagement range tests ---

func test_manager_easy_engagement_range() -> void:
	_manager.spawn_bots(5, Enums.Difficulty.EASY)
	assert_almost_eq(_manager.engagement_range, 50.0, 0.001)


func test_manager_medium_engagement_range() -> void:
	_manager.spawn_bots(5, Enums.Difficulty.MEDIUM)
	assert_almost_eq(_manager.engagement_range, 75.0, 0.001)


func test_manager_hard_engagement_range() -> void:
	_manager.spawn_bots(5, Enums.Difficulty.HARD)
	assert_almost_eq(_manager.engagement_range, 100.0, 0.001)
