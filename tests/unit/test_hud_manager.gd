## Unit tests for HUDManager: health bar, weapon display, minimap, kill feed,
## alive counter, compass, damage indicator, and storm indicators.
extends GutTest


var _hud: HUDManager


func before_each() -> void:
	_hud = HUDManager.new()
	add_child(_hud)


func after_each() -> void:
	_hud.queue_free()


# --- Health Bar tests ---

func test_update_health_stores_values() -> void:
	_hud.update_health(75.0, 50.0)
	assert_almost_eq(_hud.current_health, 75.0, 0.001)
	assert_almost_eq(_hud.current_shield, 50.0, 0.001)


func test_update_health_emits_signal() -> void:
	watch_signals(_hud)
	_hud.update_health(80.0, 30.0)
	assert_signal_emitted(_hud, "health_updated")


func test_health_displays_actual_value_above_100() -> void:
	_hud.update_health(150.0, 120.0)
	assert_eq(_hud.get_health_display_text(), "150")
	assert_eq(_hud.get_shield_display_text(), "120")


func test_health_bar_proportion_at_100() -> void:
	_hud.update_health(100.0, 100.0)
	assert_almost_eq(_hud.get_health_bar_proportion(), 1.0, 0.001)
	assert_almost_eq(_hud.get_shield_bar_proportion(), 1.0, 0.001)


func test_health_bar_proportion_above_100() -> void:
	_hud.update_health(150.0, 0.0)
	assert_almost_eq(_hud.get_health_bar_proportion(), 1.5, 0.001)


func test_health_bar_proportion_at_zero() -> void:
	_hud.update_health(0.0, 0.0)
	assert_almost_eq(_hud.get_health_bar_proportion(), 0.0, 0.001)
	assert_almost_eq(_hud.get_shield_bar_proportion(), 0.0, 0.001)


# --- Weapon Display tests ---

func test_update_weapon_stores_values() -> void:
	_hud.update_weapon("Volt Repeater", 25, 30, 90, 2)
	assert_eq(_hud.weapon_name, "Volt Repeater")
	assert_eq(_hud.weapon_ammo, 25)
	assert_eq(_hud.weapon_magazine_capacity, 30)
	assert_eq(_hud.weapon_reserve_ammo, 90)
	assert_eq(_hud.weapon_rarity, 2)


func test_update_weapon_emits_signal() -> void:
	watch_signals(_hud)
	_hud.update_weapon("Boomstick", 5, 5, 10, 1)
	assert_signal_emitted(_hud, "weapon_updated")


func test_ammo_display_text_normal_weapon() -> void:
	_hud.update_weapon("Buzzer", 20, 25, 50, 0)
	assert_eq(_hud.get_ammo_display_text(), "20/25 + 50")


func test_ammo_display_text_melee_weapon() -> void:
	_hud.update_weapon("Fists", 0, 0, 0, 0, true)
	assert_eq(_hud.get_ammo_display_text(), "0/0")


func test_weapon_rarity_color_common() -> void:
	_hud.update_weapon("Sideswipe", 12, 12, 24, 0)
	var color := _hud.get_weapon_rarity_color()
	assert_eq(color, HUDManager.RARITY_COLORS[0])


func test_weapon_rarity_color_legendary() -> void:
	_hud.update_weapon("Longshot", 5, 5, 15, 4)
	var color := _hud.get_weapon_rarity_color()
	assert_eq(color, HUDManager.RARITY_COLORS[4])


func test_weapon_display_name() -> void:
	_hud.update_weapon("Volt Repeater", 30, 30, 60, 3)
	assert_eq(_hud.get_weapon_display_name(), "Volt Repeater")


# --- Kill Feed tests ---

func test_add_kill_feed_entry_stores_entry() -> void:
	_hud.add_kill_feed_entry({"killer": "Player", "victim": "Bot1", "weapon": "Volt Repeater"})
	assert_eq(_hud.get_kill_feed_count(), 1)


func test_kill_feed_max_5_entries() -> void:
	for i in range(7):
		_hud.add_kill_feed_entry({"killer": "Bot%d" % i, "victim": "Bot%d" % (i + 10), "weapon": "Buzzer"})
	assert_eq(_hud.get_kill_feed_count(), 5)


func test_kill_feed_emits_signal_on_add() -> void:
	watch_signals(_hud)
	_hud.add_kill_feed_entry({"killer": "Player", "victim": "Bot1", "weapon": "Boomstick"})
	assert_signal_emitted(_hud, "kill_feed_changed")


func test_kill_feed_entry_removed_after_5_seconds() -> void:
	_hud.add_kill_feed_entry({"killer": "Player", "victim": "Bot1", "weapon": "Longshot"})
	assert_eq(_hud.get_kill_feed_count(), 1)
	# Simulate 5 seconds passing
	_hud._process(5.1)
	assert_eq(_hud.get_kill_feed_count(), 0)


func test_kill_feed_entry_persists_before_5_seconds() -> void:
	_hud.add_kill_feed_entry({"killer": "Player", "victim": "Bot1", "weapon": "Sideswipe"})
	# Simulate 4.9 seconds
	_hud._process(4.9)
	assert_eq(_hud.get_kill_feed_count(), 1)


func test_kill_feed_oldest_removed_when_over_limit() -> void:
	for i in range(6):
		_hud.add_kill_feed_entry({"killer": "Bot%d" % i, "victim": "Bot%d" % (i + 10), "weapon": "AR"})
	var entries := _hud.get_kill_feed_entries()
	# The oldest (Bot0) should have been removed, Bot1 should be first
	assert_eq(entries[0]["killer"], "Bot1")


# --- Alive Counter tests ---

func test_update_alive_count_stores_value() -> void:
	_hud.update_alive_count(42)
	assert_eq(_hud.alive_count, 42)


func test_update_alive_count_emits_signal() -> void:
	watch_signals(_hud)
	_hud.update_alive_count(50)
	assert_signal_emitted(_hud, "alive_count_changed")


func test_get_alive_count_returns_current() -> void:
	_hud.update_alive_count(25)
	assert_eq(_hud.get_alive_count(), 25)


func test_alive_count_updates_immediately() -> void:
	_hud.update_alive_count(51)
	assert_eq(_hud.alive_count, 51)
	_hud.update_alive_count(50)
	assert_eq(_hud.alive_count, 50)


# --- Compass tests ---

func test_compass_heading_north() -> void:
	_hud.update_compass(0.0)
	assert_almost_eq(_hud.compass_heading, 0.0, 0.001)
	assert_eq(_hud.get_cardinal_direction(0.0), "N")


func test_compass_heading_east() -> void:
	_hud.update_compass(90.0)
	assert_almost_eq(_hud.compass_heading, 90.0, 0.001)
	assert_eq(_hud.get_cardinal_direction(90.0), "E")


func test_compass_heading_south() -> void:
	_hud.update_compass(180.0)
	assert_almost_eq(_hud.compass_heading, 180.0, 0.001)
	assert_eq(_hud.get_cardinal_direction(180.0), "S")


func test_compass_heading_west() -> void:
	_hud.update_compass(270.0)
	assert_almost_eq(_hud.compass_heading, 270.0, 0.001)
	assert_eq(_hud.get_cardinal_direction(270.0), "W")


func test_compass_normalizes_negative_angle() -> void:
	_hud.update_compass(-90.0)
	assert_almost_eq(_hud.compass_heading, 270.0, 0.001)


func test_compass_normalizes_angle_above_360() -> void:
	_hud.update_compass(450.0)
	assert_almost_eq(_hud.compass_heading, 90.0, 0.001)


func test_compass_emits_signal() -> void:
	watch_signals(_hud)
	_hud.update_compass(45.0)
	assert_signal_emitted(_hud, "compass_updated")


func test_compass_cardinal_position_north_when_facing_north() -> void:
	_hud.update_compass(0.0)
	var pos := _hud.get_cardinal_position(0.0)
	assert_almost_eq(pos, 0.0, 0.001, "N should be at center when facing N")


func test_compass_cardinal_position_east_when_facing_north() -> void:
	_hud.update_compass(0.0)
	var pos := _hud.get_cardinal_position(90.0)
	assert_almost_eq(pos, 90.0, 0.001, "E should be 90 degrees right when facing N")


func test_compass_cardinal_position_west_when_facing_north() -> void:
	_hud.update_compass(0.0)
	var pos := _hud.get_cardinal_position(270.0)
	assert_almost_eq(pos, -90.0, 0.001, "W should be 90 degrees left when facing N")


func test_get_all_cardinal_positions_returns_4_entries() -> void:
	_hud.update_compass(0.0)
	var positions := _hud.get_all_cardinal_positions()
	assert_eq(positions.size(), 4)


func test_get_all_cardinal_positions_has_correct_labels() -> void:
	_hud.update_compass(0.0)
	var positions := _hud.get_all_cardinal_positions()
	var labels: Array = []
	for p in positions:
		labels.append(p["label"])
	assert_has(labels, "N")
	assert_has(labels, "E")
	assert_has(labels, "S")
	assert_has(labels, "W")


# --- Damage Indicator tests ---

func test_show_damage_direction_adds_indicator() -> void:
	_hud.show_damage_direction(45.0)
	assert_eq(_hud.get_damage_indicator_count(), 1)


func test_damage_indicator_persists_2_seconds() -> void:
	_hud.show_damage_direction(90.0)
	_hud._process(1.9)
	assert_eq(_hud.get_damage_indicator_count(), 1)


func test_damage_indicator_removed_after_2_seconds() -> void:
	_hud.show_damage_direction(90.0)
	_hud._process(2.1)
	assert_eq(_hud.get_damage_indicator_count(), 0)


func test_damage_indicator_resets_timer_on_same_direction() -> void:
	_hud.show_damage_direction(90.0)
	_hud._process(1.5)
	# Same direction hit again - should reset timer
	_hud.show_damage_direction(92.0)  # Within 10 degrees
	_hud._process(1.5)
	# Should still be active (timer was reset at 1.5s)
	assert_eq(_hud.get_damage_indicator_count(), 1)


func test_damage_indicator_multiple_directions() -> void:
	_hud.show_damage_direction(0.0)
	_hud.show_damage_direction(90.0)
	_hud.show_damage_direction(180.0)
	assert_eq(_hud.get_damage_indicator_count(), 3)


func test_damage_indicator_emits_signal() -> void:
	watch_signals(_hud)
	_hud.show_damage_direction(45.0)
	assert_signal_emitted(_hud, "damage_indicator_shown")


# --- Storm Indicators tests ---

func test_show_storm_indicator_sets_visible() -> void:
	_hud.show_storm_indicator(Vector2(1, 0))
	assert_true(_hud.are_storm_indicators_visible())


func test_hide_storm_indicator_sets_invisible() -> void:
	_hud.show_storm_indicator(Vector2(1, 0))
	_hud.hide_storm_indicator()
	assert_false(_hud.are_storm_indicators_visible())


func test_storm_indicators_paired_display_both_renderable() -> void:
	_hud.show_storm_indicator(Vector2(1, 0))
	assert_true(_hud.are_storm_indicators_visible())


func test_storm_indicators_hidden_when_damage_indicator_not_renderable() -> void:
	_hud.show_storm_indicator(Vector2(1, 0))
	_hud.set_storm_damage_indicator_renderable(false)
	assert_false(_hud.are_storm_indicators_visible())


func test_storm_indicators_hidden_when_directional_guide_not_renderable() -> void:
	_hud.show_storm_indicator(Vector2(1, 0))
	_hud.set_storm_directional_guide_renderable(false)
	assert_false(_hud.are_storm_indicators_visible())


func test_storm_indicators_restored_when_both_renderable_again() -> void:
	_hud.show_storm_indicator(Vector2(1, 0))
	_hud.set_storm_damage_indicator_renderable(false)
	assert_false(_hud.are_storm_indicators_visible())
	_hud.set_storm_damage_indicator_renderable(true)
	assert_true(_hud.are_storm_indicators_visible())


func test_storm_safe_direction_normalized() -> void:
	_hud.show_storm_indicator(Vector2(3, 4))
	var dir := _hud.get_storm_safe_direction()
	assert_almost_eq(dir.length(), 1.0, 0.001)


func test_storm_indicators_emit_signal() -> void:
	watch_signals(_hud)
	_hud.show_storm_indicator(Vector2(1, 0))
	assert_signal_emitted(_hud, "storm_indicators_changed")


func test_storm_indicators_not_visible_when_not_in_storm() -> void:
	assert_false(_hud.are_storm_indicators_visible())
	assert_false(_hud.is_player_in_storm())


# --- Minimap tests ---

func test_update_minimap_stores_values() -> void:
	_hud.update_minimap(Vector2(100, 200), 45.0, Vector2(500, 500), 300.0, Vector2(450, 450), 200.0)
	assert_eq(_hud.minimap_player_position, Vector2(100, 200))
	assert_almost_eq(_hud.minimap_player_direction, 45.0, 0.001)
	assert_eq(_hud.minimap_zone_center, Vector2(500, 500))
	assert_almost_eq(_hud.minimap_zone_radius, 300.0, 0.001)
	assert_eq(_hud.minimap_next_zone_center, Vector2(450, 450))
	assert_almost_eq(_hud.minimap_next_zone_radius, 200.0, 0.001)


func test_update_minimap_emits_signal() -> void:
	watch_signals(_hud)
	_hud.update_minimap(Vector2(0, 0), 0.0, Vector2(500, 500), 500.0, Vector2(400, 400), 300.0)
	assert_signal_emitted(_hud, "minimap_updated")


func test_get_minimap_state_returns_all_data() -> void:
	_hud.update_minimap(Vector2(50, 75), 90.0, Vector2(500, 500), 400.0, Vector2(480, 480), 250.0)
	var state := _hud.get_minimap_state()
	assert_eq(state["player_position"], Vector2(50, 75))
	assert_almost_eq(state["player_direction"], 90.0, 0.001)
	assert_eq(state["zone_center"], Vector2(500, 500))
	assert_almost_eq(state["zone_radius"], 400.0, 0.001)
	assert_eq(state["next_zone_center"], Vector2(480, 480))
	assert_almost_eq(state["next_zone_radius"], 250.0, 0.001)
