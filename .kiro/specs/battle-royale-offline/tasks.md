# Implementation Plan: Battle Royale Offline

## Overview

This plan implements an offline Battle Royale mobile game for Android using Godot 4.x with GDScript. The implementation follows an incremental approach: core data models and systems first, then gameplay mechanics, then UI/HUD, then persistence and polish. Each task builds on previous work, ensuring no orphaned code.

## Tasks

- [x] 1. Set up project structure and core data models
  - [x] 1.1 Create Godot project structure and core resource definitions
    - Create the Godot 4.x project with directory structure: `scripts/`, `scenes/`, `resources/`, `tests/property/`, `tests/unit/`, `tests/integration/`, `data/`
    - Define enums: `MatchState`, `WeaponCategory`, `RarityTier`, `BotState`, `Difficulty`, `PhaseState`, `ZoneShrinkSpeed`, `AuthState`, `AuthProvider`, `ConsumableType`, `FireMode`
    - Create weapon configuration data resource (`data/weapons.json`) with all 5 weapons (Volt Repeater, Boomstick, Buzzer, Longshot, Sideswipe) and their stats
    - Create zone phase configuration resource (`data/zone_phases.json`) with 5 phases and speed multipliers
    - Create consumable item data resource (`data/consumables.json`) with bandage, medkit, shield potion definitions
    - Create character data resource (`data/characters.json`) with Blitz, Titan, Phantom definitions and variants
    - _Requirements: 3.2, 4.1, 4.2, 4.7, 6.2, 6.5, 7.2, 7.3_

  - [x] 1.2 Implement WeaponData and WeaponSystem classes
    - Create `scripts/weapon_system.gd` with `WeaponData` resource class (category, name, rarity, base_damage, fire_rate, magazine_size, reload_time, effective_range, accuracy_base)
    - Implement `calculate_damage(weapon, distance)` with rarity modifier (10% per tier) and distance falloff (linear to 50% at 2× effective range, zero beyond)
    - Implement `apply_rarity_modifier(base, rarity)` returning `base * (1 + 0.10 * rarity_index)`
    - Implement `get_accuracy(weapon, rarity)` with 5% bonus per tier above Common
    - _Requirements: 4.4, 4.5, 4.7_

  - [x] 1.3 Write property test for weapon damage calculation
    - **Property 6: Weapon damage calculation**
    - **Validates: Requirements 4.4, 4.5**

  - [x] 1.4 Write property test for empty magazine blocks firing
    - **Property 9: Empty magazine blocks firing**
    - **Validates: Requirements 4.8**

- [x] 2. Implement inventory and consumable systems
  - [x] 2.1 Implement InventorySystem class
    - Create `scripts/inventory_system.gd` with weapon_slots (max 5), consumable_slots (max 3), active_weapon_index
    - Implement `add_weapon(weapon)` returning error when at capacity (5 slots)
    - Implement `swap_weapon(slot, new_weapon)` returning the old weapon
    - Implement `remove_weapon(slot)` and `get_active_weapon()`
    - Implement `add_consumable(type, count)` with stack limits (5 bandages, 3 medkits, 3 shield potions)
    - Implement `use_consumable(type)` with healing logic: bandage +25 HP capped at 75 (blocked if health ≥ 75), medkit full heal, shield potion +50 capped at 100
    - Implement healing interruption: if cancelled, consume item but apply no healing
    - _Requirements: 4.3, 7.2, 7.3, 7.4, 7.5, 7.7_

  - [x] 2.2 Write property test for inventory capacity invariant
    - **Property 8: Inventory capacity invariant**
    - **Validates: Requirements 4.3, 7.2, 7.4**

  - [x] 2.3 Write property test for healing calculation with caps
    - **Property 18: Healing calculation with caps**
    - **Validates: Requirements 7.3**

  - [x] 2.4 Write property test for cancelled healing consumes item
    - **Property 19: Cancelled healing consumes item**
    - **Validates: Requirements 7.7**

- [x] 3. Implement zone mechanics
  - [x] 3.1 Implement ZoneManager class
    - Create `scripts/zone_manager.gd` with current_phase, total_phases (min 5), current_center, current_radius, next_center, next_radius, phase_state, shrink_speed
    - Implement `initialize_zones(map_bounds, speed)` generating at least 5 phases with configurable speed multipliers (SLOW: 1.5×, NORMAL: 1.0×, FAST: 0.6×)
    - Implement `advance_phase()` transitioning through WAITING → SHRINKING states
    - Implement `get_storm_damage(phase)` starting at 1 DPS in phase 1, increasing by at least 1 per phase
    - Implement `is_in_safe_zone(position)` checking if position is within current zone circle
    - Implement `get_nearest_safe_point(position)` for directional guidance
    - Ensure next zone is fully contained within current zone: `distance(current_center, next_center) + next_radius <= current_radius`
    - Emit signals: `zone_warning`, `zone_shrink_started`, `zone_shrink_completed`
    - Implement zone warning firing at least 10 seconds before shrinking begins
    - _Requirements: 6.1, 6.2, 6.3, 6.5, 6.6, 6.7_

  - [x] 3.2 Write property tests for zone mechanics
    - **Property 3: Storm damage calculation**
    - **Property 13: Zone configuration validity**
    - **Property 14: Zone warning timing**
    - **Property 16: Next zone containment**
    - **Validates: Requirements 1.4, 6.2, 6.3, 6.5, 6.6, 6.7**

- [x] 4. Implement bot AI system
  - [x] 4.1 Implement BotAIManager and BotInstance with FSM
    - Create `scripts/bot_ai_manager.gd` with bot array, difficulty setting, engagement ranges (Easy: 50m, Medium: 75m, Hard: 100m)
    - Create `scripts/bot_instance.gd` with FSM states: LOOTING, ROAMING, ENGAGING, FLEEING, HEALING
    - Implement `decide_action(context)` following priority rules:
      1. Unarmed and not in danger → LOOTING
      2. Outside safe zone → FLEEING (toward zone)
      3. Enemy in range, health > 50%, armed → ENGAGING
      4. Enemy in range, health ≤ 50% or unarmed → FLEEING
      5. Health < 30% → disengage, heal if possible
      6. Armed, in zone, no enemy → ROAMING
    - Implement difficulty parameters: reaction time (Easy: 1500-2000ms, Medium: 800-1200ms, Hard: 300-600ms), accuracy (Easy: 15-25%, Medium: 30-45%, Hard: 55-70%)
    - Implement `spawn_bots(count, difficulty)` assigning random character models (Blitz/Titan/Phantom) with random variants
    - Implement bot movement toward safe zone with positive dot product toward nearest safe boundary point
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8_

  - [x] 4.2 Write property tests for bot AI
    - **Property 10: Bot FSM decision correctness**
    - **Property 11: Bot movement toward safe zone**
    - **Property 12: Bot difficulty parameters**
    - **Property 5: Character assignment validity**
    - **Validates: Requirements 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 3.3, 3.5**

- [x] 5. Checkpoint - Core systems verification
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement loot system and map data
  - [x] 6.1 Implement LootManager class
    - Create `scripts/loot_manager.gd` with spawn_points, active_loot, rarity_weights (Common: 0.40, Uncommon: 0.25, Rare: 0.20, Epic: 0.10, Legendary: 0.05)
    - Implement `initialize_loot(map_data)` distributing loot with 3× density in named locations vs open areas
    - Implement `spawn_loot_at(point)` using weighted random rarity selection
    - Implement `pick_up_loot(loot_id, picker)` with inventory integration
    - Implement `get_nearest_loot(position, radius)` for bot AI loot-seeking
    - Ensure minimum 5 loot spawn points per named location
    - _Requirements: 4.6, 7.1, 11.3, 11.7_

  - [x] 6.2 Implement MapData class with named locations
    - Create `scripts/map_data.gd` defining map bounds, named locations (minimum 8), terrain types
    - Define terrain distribution: urban, open fields, forested, elevated — each covering at least 15% of map area
    - Ensure named locations are separated by at least 100 in-game meters
    - Define loot spawn point positions for each named location
    - _Requirements: 11.1, 11.2, 11.5_

  - [x] 6.3 Write property tests for loot distribution
    - **Property 7: Loot rarity distribution**
    - **Property 17: Map loot distribution constraints**
    - **Validates: Requirements 4.6, 7.1, 11.1, 11.2, 11.7**

- [x] 7. Implement match controller and lifecycle
  - [x] 7.1 Implement MatchController class
    - Create `scripts/match_controller.gd` with match_state (LOBBY, DROP, ACTIVE, ENDED), alive_count, elapsed_time, match_settings, match_stats
    - Implement `start_match(settings)` spawning player + bots (bot_count + 1 total participants)
    - Implement `begin_drop_phase()` with 60-second timer; auto-drop player at random safe zone position if timer expires
    - Implement `end_drop_phase()` distributing all bots to random map positions within 10 seconds
    - Implement `register_elimination(victim_id, killer_id)` decrementing alive_count
    - Implement `check_victory_condition()` — victory when only player remains (or simultaneous final elimination)
    - Implement `end_match(result)` with MatchResult data (kills, placement, survival time, damage dealt, character, variant, difficulty, bot_count)
    - Emit signals: `match_state_changed`, `elimination_occurred`, `match_ended`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

  - [x] 7.2 Write property tests for match controller
    - **Property 1: Match spawn correctness**
    - **Property 2: Auto-drop position validity**
    - **Property 21: Alive count tracking**
    - **Validates: Requirements 1.1, 1.2, 1.8, 8.5**

- [x] 8. Implement input controller and touch controls
  - [x] 8.1 Implement InputController class
    - Create `scripts/input_controller.gd` with joystick handling, sensitivity (1-10), fire_mode (TAP/HOLD), control layout
    - Implement virtual joystick: appears at first touch position in left-side area, movement proportional to displacement magnitude, direction matches displacement
    - Implement touch-and-drag aiming on right side with configurable sensitivity
    - Implement dedicated buttons: shoot, jump, crouch, reload — all minimum 44×44 dp touch targets
    - Implement weapon quick-switch bar for up to 5 weapon slots
    - Implement input latency check: reject inputs exceeding 50ms
    - Implement custom layout: constrain elements within screen bounds, prevent overlap between interactive elements, provide reset-to-default
    - Support tap-to-shoot (default) and hold-to-shoot modes
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8_

  - [x] 8.2 Write property tests for input controls
    - **Property 23: Control layout constraints**
    - **Property 24: Joystick movement proportionality**
    - **Property 30: Settings value clamping**
    - **Validates: Requirements 9.3, 9.5, 9.8, 9.2, 12.4**

- [x] 9. Implement HUD system
  - [x] 9.1 Implement HUDManager class
    - Create `scripts/hud_manager.gd` with signal-driven updates (within 1 frame of state change)
    - Implement HealthBar: health + shield as numeric text and proportional bars, display actual value even if > 100
    - Implement WeaponDisplay: weapon name, ammo (current/magazine + reserve), rarity color border; show 0/0 for melee
    - Implement Minimap: current zone boundary, next zone boundary, player position and facing direction
    - Implement KillFeed: last 5 eliminations, each entry removed after 5 seconds
    - Implement AliveCounter: numeric value updated immediately on elimination
    - Implement Compass: cardinal directions (N, S, E, W) and degree heading based on player facing
    - Implement DamageIndicator: directional, pointing toward damage source, persists 2 seconds
    - Implement storm indicators: both damage indicator and directional guide displayed together or neither (paired display)
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 6.4_

  - [x] 9.2 Write property tests for HUD
    - **Property 15: Storm indicators paired display**
    - **Property 20: Kill feed queue management**
    - **Property 22: Compass heading calculation**
    - **Validates: Requirements 6.4, 8.4, 8.5, 8.6**

- [x] 10. Checkpoint - Gameplay systems verification
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Implement authentication and progress persistence
  - [x] 11.1 Implement AuthManager class
    - Create `scripts/auth_manager.gd` with auth_state (GUEST/AUTHENTICATED), user_id, provider
    - Implement `generate_guest_id()` returning UUID v4 format (36 characters, correct hyphen positions, version nibble = 4)
    - Implement `login(provider, credentials)` supporting Google, Facebook, email/password
    - Implement email validation (RFC 5322) and password validation (8-64 characters)
    - Implement `logout()` and `get_current_user_id()`
    - _Requirements: 10.1, 10.2_

  - [x] 11.2 Implement ProgressStore with SQLite
    - Create `scripts/progress_store.gd` with SQLite database integration
    - Create SQLite schema: `player_profile`, `match_history`, `settings` tables as defined in design
    - Implement `initialize(user_id)` with data integrity validation
    - Implement `save_match_result(result)` with error handling — retain unsaved results in memory on failure
    - Implement `get_career_stats()` computing: total_matches, wins, total_kills, avg_kills (total_kills/total_matches), win_rate ((wins/total_matches) × 100 rounded to 1 decimal)
    - Implement `get_match_history(limit)` returning results keyed by user_id
    - Implement `migrate_guest_to_account(guest_id, account_id)` — move all data, discard guest on failure
    - Implement `validate_data_integrity()` — create new file and show recovery notification on failure
    - Ensure user data isolation: queries scoped to current user_id only
    - _Requirements: 10.3, 10.4, 10.5, 10.6, 10.7, 10.8_

  - [x] 11.3 Write property tests for auth and progress
    - **Property 25: User identity and auth validation**
    - **Property 26: Progress data integrity**
    - **Property 27: User data isolation**
    - **Property 28: Guest-to-account migration**
    - **Property 4: Character selection round-trip**
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5, 10.7, 2.5**

- [x] 12. Implement audio system
  - [x] 12.1 Implement AudioManager class
    - Create `scripts/audio_manager.gd` with volume controls (music, sfx, voice: 0-100), spatial_audio_enabled
    - Implement `play_3d_sound(clip, position, max_distance)` with distance attenuation (zero at max range): gunshots 100m, footsteps 30m, explosions 150m
    - Implement `play_ui_sound(clip)` for non-spatial UI sounds
    - Implement `play_music(track)` for lobby, drop phase, victory screen
    - Implement `play_storm_ambient()` — continuous while in storm, silent failure if audio unavailable
    - Implement `play_own_footstep()` — lower volume, no directional spatialization
    - Implement distinct audio cues for zone warnings, item pickups, eliminations
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_

  - [x] 12.2 Write property test for audio distance attenuation
    - **Property 29: Audio distance attenuation**
    - **Validates: Requirements 12.1**

- [x] 13. Implement character selection and match settings UI
  - [x] 13.1 Implement CharacterSelector scene
    - Create `scenes/character_selector.tscn` and `scripts/character_selector.gd`
    - Display 3 characters (Blitz, Titan, Phantom) with male/female variant toggle
    - Implement 360-degree horizontal rotation preview of selected character
    - Persist last selected character/variant as default for next match
    - Default to Blitz male if no previous selection exists
    - Load selected character model within 5 seconds; show error with retry/alternate on failure
    - If player starts match without confirming, use previously persisted selection
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [x] 13.2 Implement MatchSettings scene
    - Create `scenes/match_settings.tscn` and `scripts/match_settings.gd`
    - Bot difficulty selector (Easy/Medium/Hard, default: Medium)
    - Bot count slider/input (10-99, default: 50) — block confirmation if outside range
    - Zone shrink speed selector (Slow/Normal/Fast, default: Normal)
    - Display estimated match duration (rounded to nearest minute, minimum 1) — update within 1 second of setting change
    - Block match confirmation until all settings are valid
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5_

  - [x] 13.3 Write property test for match settings validation
    - **Property 32: Match settings validation**
    - **Validates: Requirements 15.2, 15.4, 15.5**

- [x] 14. Implement main menu and navigation
  - [x] 14.1 Implement MainMenu and Settings scenes
    - Create `scenes/main_menu.tscn` and `scripts/main_menu.gd`
    - Display options: Play, Characters, Career Stats, Settings, Login/Player ID
    - Show selected character 3D model (default Blitz male if none selected)
    - Transition to Character Selector or match lobby within 3 seconds on Play
    - Create `scenes/settings.tscn` with sub-sections: Controls, Graphics, Audio, Account
    - Implement Career Stats screen: total matches, wins, total kills, avg kills, win rate
    - Implement back button navigation on all sub-screens
    - Apply consistent blocky cartoon art style, color palette, and font across all menus
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 10.5_

- [x] 15. Implement performance management and adaptive quality
  - [x] 15.1 Implement RenderManager with adaptive quality
    - Create `scripts/render_manager.gd` with graphics quality presets (Low, Medium, High)
    - Each preset adjusts: draw distance, shadow quality, particle effects
    - Monitor available device memory during match
    - If memory < 200MB and not at lowest preset: reduce quality by one level, show brief indicator
    - If memory < 100MB at lowest preset: preserve match state, display warning about potential match end
    - Target 30+ FPS on mid-range devices (4GB RAM, Snapdragon 600 series) with up to 20 bots visible
    - Ensure installed size under 500MB, support Android 8.0+ (API 26)
    - Map loading to Drop Phase within 15 seconds on minimum spec devices
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7_

  - [x] 15.2 Write property test for adaptive quality reduction
    - **Property 31: Adaptive quality reduction**
    - **Validates: Requirements 13.5**

- [x] 16. Implement map rendering and drop phase visuals
  - [x] 16.1 Implement map scene with named locations and terrain
    - Create map scene with minimum 8 named locations, each with unique layout
    - Implement varied terrain: urban, open fields, forested, elevated (each ≥ 15% of map)
    - Render in blocky colorful art style consistent with characters
    - Display named location labels during Drop Phase, hide after Drop Phase ends
    - Implement loot glow with color-coded rarity tier
    - Ensure map is fully loaded without external streaming
    - _Requirements: 11.1, 11.2, 11.4, 11.5, 11.6, 7.6_

- [x] 17. Checkpoint - Full integration verification
  - Ensure all tests pass, ask the user if questions arise.

- [x] 18. Wire all systems together and implement match flow
  - [x] 18.1 Integrate all systems into complete match loop
    - Wire MatchController → ZoneManager (phase progression, storm damage)
    - Wire MatchController → BotAIManager (spawn, update each frame, eliminations)
    - Wire MatchController → LootManager (initialize loot on match start)
    - Wire Player → InventorySystem → WeaponSystem (pickup, fire, reload)
    - Wire InputController → Player character (movement, aiming, actions)
    - Wire ZoneManager → HUDManager (zone warnings, minimap updates)
    - Wire MatchController → HUDManager (kill feed, alive count, match state)
    - Wire MatchController → ProgressStore (save match results on end)
    - Wire AudioManager to gameplay events (gunshots, footsteps, zone warnings, eliminations, storm ambient)
    - Wire CharacterSelector → MatchController (selected character into match)
    - Wire MatchSettings → MatchController (difficulty, bot count, zone speed)
    - Implement victory/defeat screens with match statistics
    - Ensure entire match completes without network connectivity
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 3.5_

- [x] 19. Final checkpoint - Complete game verification
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical breakpoints
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- All implementation uses GDScript for Godot 4.x as specified in the design
- The game is fully offline — no network mocking needed for tests
- SQLite is used for local persistence (no backend server)
- Character models use Fortnite Lego-inspired blocky art style throughout

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "3.1", "6.2"] },
    { "id": 2, "tasks": ["1.3", "1.4", "2.1", "3.2", "4.1"] },
    { "id": 3, "tasks": ["2.2", "2.3", "2.4", "4.2", "6.1"] },
    { "id": 4, "tasks": ["6.3", "7.1", "8.1", "11.1"] },
    { "id": 5, "tasks": ["7.2", "8.2", "9.1", "11.2"] },
    { "id": 6, "tasks": ["9.2", "11.3", "12.1", "13.1", "13.2"] },
    { "id": 7, "tasks": ["12.2", "13.3", "14.1", "15.1"] },
    { "id": 8, "tasks": ["15.2", "16.1"] },
    { "id": 9, "tasks": ["18.1"] }
  ]
}
```
