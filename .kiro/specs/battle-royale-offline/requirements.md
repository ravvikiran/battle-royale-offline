# Requirements Document

## Introduction

An offline Battle Royale mobile game for Android with a Fortnite Lego-inspired art style (blocky, colorful, cartoonish). Players compete against rule-based bots in a shrinking zone, looting weapons and eliminating opponents to be the last one standing. The game features 3 playable characters (each with male and female variants), Fortnite OG-inspired weapon categories with original names and designs, and a polished mobile UI. No backend servers, no AI integration — fully offline with optional social/email login and local progress saving.

## Glossary

- **Game_Client**: The Android mobile application that runs the entire game locally on the device
- **Player**: The human user controlling a character in a match
- **Bot**: A non-player character controlled by rule-based logic that competes against the Player
- **Match**: A single Battle Royale game session from drop to victory or elimination
- **Zone**: The playable area that shrinks over time, forcing players and bots into closer proximity
- **Safe_Zone**: The area inside the Zone boundary where the Player and Bots take no zone damage
- **Storm**: The area outside the Zone boundary that deals damage over time
- **Loot**: Weapons, ammo, and healing items scattered across the map that can be picked up
- **Character_Selector**: The screen where the Player chooses their playable character before a match
- **HUD**: The heads-up display showing health, shield, ammo, minimap, kill feed, and zone information during gameplay
- **Inventory_System**: The in-game system managing the Player's carried weapons and items
- **Bot_AI**: The rule-based decision system controlling Bot behavior (patrol, loot, engage, flee)
- **Progress_Store**: The local file system storing player scores, match history, and unlocks keyed by user ID or email
- **Weapon_Category**: Classification of weapons into types — Assault Rifle (AR), Shotgun, SMG, Sniper, Pistol
- **Rarity_Tier**: Weapon quality levels affecting damage and stats (Common, Uncommon, Rare, Epic, Legendary)
- **Drop_Phase**: The initial phase where the Player selects a landing location on the map
- **Elimination**: When a Player or Bot loses all health and is removed from the match
- **Victory_Royale**: The state achieved when the Player is the last one standing

## Requirements

### Requirement 1: Match Lifecycle

**User Story:** As a player, I want to start a Battle Royale match against bots, so that I can experience the full battle royale loop offline.

#### Acceptance Criteria

1. WHEN the Player starts a new match, THE Game_Client SHALL spawn the Player and up to 99 Bots on the map
2. WHEN the match begins, THE Game_Client SHALL initiate the Drop_Phase allowing the Player to select a landing location within 60 seconds, and IF the Player does not select a landing location within 60 seconds, THEN THE Game_Client SHALL automatically drop the Player at a random location within the Safe_Zone
3. WHILE the match is active, THE Zone SHALL shrink at predefined intervals forcing all participants toward the center
4. WHEN a participant enters the Storm, THE Game_Client SHALL apply damage over time to that participant proportional to the current Zone phase
5. WHEN only the Player remains alive, or WHEN the Player is eliminated at the exact same time as the final opponent, THE Game_Client SHALL display the Victory_Royale screen with match statistics including kills, damage dealt, survival time, and final placement
6. WHEN the Player is eliminated, THE Game_Client SHALL display a defeat screen with match statistics including kills, damage dealt, survival time, and placement among total participants
7. THE Game_Client SHALL complete an entire match without requiring any network connectivity
8. WHEN the Drop_Phase begins, THE Game_Client SHALL distribute all Bots to land at random locations across the map within 10 seconds of the Drop_Phase starting

### Requirement 2: Character Selection

**User Story:** As a player, I want to choose from multiple characters before a match, so that I can play as a character I like.

#### Acceptance Criteria

1. THE Character_Selector SHALL present 3 distinct playable characters to the Player
2. WHEN a character is selected, THE Character_Selector SHALL offer a male and female variant for that character (6 total models)
3. WHEN the Player confirms a character selection, THE Game_Client SHALL load the selected character model into the match within 5 seconds and reach LOADED status, and IF loading exceeds 5 seconds or fails to reach LOADED status within the time limit, THEN THE Game_Client SHALL display an error message allowing the Player to retry or select a different character
4. WHEN a character or variant is selected, THE Character_Selector SHALL display a full-body 3D preview of the selected character with 360-degree horizontal rotation capability, and rotation controls SHALL remain available even if the 3D preview fails to render
5. THE Game_Client SHALL persist the Player's last selected character and variant as the default for the next match
6. IF no previously selected character exists, THEN THE Character_Selector SHALL select the first character with its male variant as the active selection (not merely display defaults)
7. IF the Player attempts to start a match without confirming a character selection, THEN THE Game_Client SHALL use the previously selected character and variant (persisted from the last confirmed selection) and proceed to the match

### Requirement 3: Character Design

**User Story:** As a player, I want visually distinct characters with a blocky cartoon style, so that the game feels polished and fun.

#### Acceptance Criteria

1. THE Game_Client SHALL render all characters in a blocky, colorful, cartoonish art style consistent with a Lego-inspired aesthetic
2. THE Game_Client SHALL provide the following 3 playable characters:
   - **Blitz** — A nimble scout character with a sporty build, wearing a tactical vest and cap (male: short hair, female: ponytail)
   - **Titan** — A bulky heavy character with broad shoulders, wearing armored plating and a helmet visor (male: square jaw, female: braided hair under helmet)
   - **Phantom** — A sleek stealth character with a slim build, wearing a hooded cloak and face mask (male: hood up with goggles, female: hood down with short asymmetric hair)
3. THE Game_Client SHALL assign each character a dominant color palette (no two characters sharing the same primary hue) such that each character is identifiable by color at maximum camera zoom-out distance during gameplay, and SHALL provide fallback identification methods (silhouette, size, or icon) when color alone is insufficient due to lighting conditions or accessibility needs
4. THE Game_Client SHALL apply consistent Lego-style proportions to all character models with a head-to-body height ratio between 1:2 and 1:3, blocky limbs with no rounded joints, and simplified mitten-style hands
5. THE Game_Client SHALL render Bots using the same 3 character models (Blitz, Titan, Phantom) with randomized gender variants, distinguished from the Player's character by a visible team-neutral color tint or outline indicator
6. THE Game_Client SHALL give each character (Blitz, Titan, Phantom) a distinct silhouette through differing body proportions and headgear so that characters are identifiable without relying on color alone

### Requirement 4: Weapon System

**User Story:** As a player, I want to find and use various weapons during a match, so that I can engage bots with different combat strategies.

#### Acceptance Criteria

1. THE Game_Client SHALL provide weapons in 5 categories: Assault Rifle, Shotgun, SMG, Sniper Rifle, and Pistol
2. THE Game_Client SHALL assign original names and visual designs to all weapons distinct from any existing game IP:
   - AR category: "Volt Repeater"
   - Shotgun category: "Boomstick"
   - SMG category: "Buzzer"
   - Sniper category: "Longshot"
   - Pistol category: "Sideswipe"
3. WHEN the Player picks up a weapon, THE Inventory_System SHALL add the weapon to the Player's loadout (maximum 5 weapon slots), and IF the Player's loadout already contains 5 weapons, THEN THE Game_Client SHALL block the pickup entirely
4. THE Game_Client SHALL assign each weapon a Rarity_Tier (Common, Uncommon, Rare, Epic, Legendary) where each successive tier increases base damage by 10 percent and improves accuracy (reduces bullet spread) by 5 percent relative to the Common tier baseline
5. WHEN the Player fires a weapon, THE Game_Client SHALL apply damage using the weapon's base damage, rarity multiplier, and distance to target, where each category defines an effective range (AR: 50m, SMG: 30m, Shotgun: 10m, Sniper: 150m, Pistol: 35m) and damage falls off linearly to 50 percent at twice the effective range and to zero beyond that
6. THE Game_Client SHALL distribute weapons across the map as floor loot and inside loot containers with rarity probability weighted as: Common 40 percent, Uncommon 25 percent, Rare 20 percent, Epic 10 percent, Legendary 5 percent
7. THE Game_Client SHALL assign each weapon category a distinct fire rate (rounds per second) and magazine size: AR (5 rps, 30 rounds), Shotgun (1 rps, 5 rounds), SMG (8 rps, 25 rounds), Sniper (0.5 rps, 5 rounds), Pistol (3 rps, 12 rounds)
8. WHEN a weapon's magazine is empty, THE Game_Client SHALL allow the Player to attempt firing but SHALL display a reload prompt instead of firing, and THE Game_Client SHALL require the Player to reload before firing again, with reload time per category: AR (2 seconds), Shotgun (4 seconds), SMG (1.5 seconds), Sniper (3 seconds), Pistol (1 second)

### Requirement 5: Bot Behavior

**User Story:** As a player, I want bots to behave realistically, so that matches feel challenging and engaging.

#### Acceptance Criteria

1. THE Bot_AI SHALL operate using rule-based logic without requiring network connectivity or machine learning models
2. WHILE a Bot has no weapon, THE Bot_AI SHALL prioritize looting the nearest available weapon, UNLESS the Bot is in immediate danger (under fire, outside Safe_Zone, or health below 30 percent), in which case survival behaviors (fleeing, seeking cover, moving to Safe_Zone) SHALL take priority
3. WHILE a Bot is outside the Safe_Zone, THE Bot_AI SHALL move toward the Safe_Zone
4. WHEN a Bot detects the Player or another Bot within engagement range (50 meters for Easy, 75 meters for Medium, 100 meters for Hard difficulty), THE Bot_AI SHALL engage if its health is above 50 percent and it has a weapon equipped, or flee toward the nearest cover if its health is at or below 50 percent or it has no weapon
5. WHILE a Bot is in combat, THE Bot_AI SHALL use cover and strafe movement, and aim with a hit-rate accuracy of 15 to 25 percent on Easy, 30 to 45 percent on Medium, and 55 to 70 percent on Hard difficulty; WHEN a Bot's health drops below 30 percent during combat, THE Bot_AI SHALL continue using cover and strafe tactics while simultaneously disengaging toward the nearest safe position
6. THE Bot_AI SHALL support 3 difficulty levels (Easy, Medium, Hard) where Easy has a reaction time of 1500 to 2000 milliseconds, Medium has 800 to 1200 milliseconds, and Hard has 300 to 600 milliseconds before responding to threats, and where higher difficulty Bots prioritize using cover and flanking over direct engagement
7. WHEN a Bot's health drops below 30 percent, THE Bot_AI SHALL disengage from combat by moving to the nearest cover position and use a healing item if one is available in its inventory
8. WHILE a Bot has a weapon and is inside the Safe_Zone and no enemy is detected within engagement range, THE Bot_AI SHALL roam toward the nearest loot location or toward the center of the current Safe_Zone; WHEN an enemy is detected within engagement range during roaming, THE Bot_AI SHALL immediately cease roaming and transition to combat or flee behavior based on health and weapon status

### Requirement 6: Zone Mechanics

**User Story:** As a player, I want the playable area to shrink over time, so that matches have increasing tension and a defined end.

#### Acceptance Criteria

1. THE Game_Client SHALL display the current Zone boundary and next Zone boundary on the minimap and main view
2. THE Game_Client SHALL shrink the Zone in phases, where each phase specifies a wait time (between 30 and 120 seconds) before shrinking begins and a shrink duration (strictly between 20 and 90 seconds, rejecting any duration outside these bounds) during which the boundary moves to its next position
3. WHEN a Zone phase wait time begins, THE Game_Client SHALL provide a visual and audio warning to the Player at least 10 seconds before the Zone begins shrinking
4. WHILE the Player is in the Storm, THE HUD SHALL display both a damage indicator and directional guide toward the nearest point of the Safe_Zone boundary; IF either indicator fails to render, THEN THE HUD SHALL hide both indicators until both can be displayed together
5. THE Game_Client SHALL apply Storm damage per second that increases with each successive Zone phase, starting at 1 HP per second in phase 1 and increasing by at least 1 HP per second per subsequent phase
6. THE Game_Client SHALL use a minimum of 5 Zone phases per match, with the first Safe_Zone covering no more than 70 percent of the total map area and the final Safe_Zone having a radius no larger than 50 meters
7. THE Game_Client SHALL place each next Zone circle fully within the current Zone boundary at a randomized position

### Requirement 7: Loot and Inventory

**User Story:** As a player, I want to find healing items and manage my inventory, so that I can sustain myself throughout a match.

#### Acceptance Criteria

1. THE Game_Client SHALL spawn healing items (bandages, medkits, shield potions) as Loot across the map, with higher density in named locations and lower density in open areas consistent with the map's Loot distribution rules
2. WHEN the Player picks up a healing item, THE Inventory_System SHALL store the item in a dedicated consumable slot, stacking up to 5 bandages, 3 medkits, or 3 shield potions per stack
3. WHEN the Player uses a healing item, THE Game_Client SHALL restore the following after the usage animation completes: bandages restore 25 health over 3 seconds (capped at 75 health), medkits restore full health over 8 seconds, and shield potions restore 50 shield over 4 seconds (capped at 100 shield); IF the Player's current health is already at or above 75 when attempting to use a bandage, THEN THE Game_Client SHALL block the bandage use and no healing shall occur
4. THE Inventory_System SHALL limit the Player to carrying a maximum of 5 weapons and 3 stacks of consumable items
5. WHEN the Player's inventory is full, THE Game_Client SHALL prompt the Player to swap or discard an existing item before picking up a new one
6. THE Game_Client SHALL display Loot on the ground with a color-coded glow matching the item's Rarity_Tier
7. IF the healing item usage animation is cancelled for any reason (Player takes damage, moves, or any other interruption), THEN THE Game_Client SHALL cancel the healing effect and consume the item from the inventory

### Requirement 8: Heads-Up Display

**User Story:** As a player, I want clear on-screen information during gameplay, so that I can make informed decisions quickly.

#### Acceptance Criteria

1. THE HUD SHALL display the Player's current health and shield values as numeric text and proportional bar indicators that update within 1 frame of any health or shield change, displaying the actual value even if it exceeds 100
2. THE HUD SHALL display the currently equipped weapon name, its current ammo count out of magazine capacity, total reserve ammo, and a background or border color matching the weapon's Rarity_Tier; for weapons without an ammo system (such as melee weapons), THE HUD SHALL display 0/0 for ammo values
3. THE HUD SHALL display a minimap showing the current Zone boundary, next Zone boundary, and the Player's position and facing direction
4. THE HUD SHALL display a kill feed showing the most recent 5 Eliminations in the match, with each entry remaining visible for 5 seconds before being removed
5. THE HUD SHALL display the count of remaining alive participants as a numeric value updated immediately upon each Elimination
6. THE HUD SHALL display a compass at the top of the screen showing all cardinal directions (N, S, E, W) simultaneously and degree heading based on the Player's facing direction
7. WHILE the Player takes damage, THE HUD SHALL display a directional damage indicator pointing toward the source direction, persisting for 2 seconds after the last damage instance from that source

### Requirement 9: Controls and Input

**User Story:** As a player, I want intuitive touch controls optimized for mobile, so that I can move, aim, and shoot comfortably on a phone.

#### Acceptance Criteria

1. THE Game_Client SHALL provide a virtual joystick on the left side of the screen for character movement, appearing at the position where the Player first touches within the left-side activation area
2. THE Game_Client SHALL provide touch-and-drag aiming on the right side of the screen for camera control with a sensitivity setting adjustable from 1 (slowest) to 10 (fastest) in the Controls settings
3. THE Game_Client SHALL provide dedicated on-screen buttons for shooting, jumping, crouching, and reloading, each with a minimum touch target size of 44x44 density-independent pixels
4. THE Game_Client SHALL provide a weapon quick-switch bar displaying all occupied weapon slots (up to 5) allowing the Player to change weapons by tapping the desired slot
5. THE Game_Client SHALL allow the Player to customize control layout positions and button sizes in settings, constraining all elements to remain fully within the screen bounds and preventing overlap between interactive elements, with a reset-to-default option that restores the original layout regardless of current element positions or bounds constraints
6. THE Game_Client SHALL support both tap-to-shoot and hold-to-shoot firing modes configurable in settings, with tap-to-shoot as the default mode
7. THE Game_Client SHALL register all touch inputs (movement, aiming, button presses) within 50 milliseconds of contact; inputs exceeding 50 milliseconds SHALL be rejected to maintain strict responsiveness standards
8. WHILE the Player is using the virtual joystick, THE Game_Client SHALL move the character in the direction indicated by the joystick displacement relative to its center, with movement speed proportional to the displacement distance up to the joystick radius

### Requirement 10: User Authentication and Progress

**User Story:** As a player, I want to optionally log in and have my progress saved, so that I can track my stats over time.

#### Acceptance Criteria

1. THE Game_Client SHALL allow the Player to play without logging in using a locally generated unique ID (UUID v4 format, 36 characters)
2. WHERE the Player chooses to log in, THE Game_Client SHALL support authentication via Google, Facebook, or email/password, where email must be a valid email format and password must be between 8 and 64 characters in length
3. WHEN the Player completes a match, THE Progress_Store SHALL save match results (kills, placement out of total participants, survival time in seconds, and damage dealt) locally; the match SHALL NOT be considered successfully completed until the save operation succeeds
4. THE Progress_Store SHALL persist all data in a local file keyed by the Player's unique ID or email address
5. THE Game_Client SHALL display a career statistics screen showing total matches, wins, total kills, average kills per match, and win rate calculated as (wins divided by total matches) displayed as a percentage rounded to one decimal place
6. IF the local progress file fails a validity check on load, THEN THE Game_Client SHALL create a new progress file and display a data recovery notification to the Player indicating that previous data could not be recovered; this notification SHALL only appear when the validity check actually fails, not for other error scenarios
7. WHEN a guest Player logs in for the first time, THE Game_Client SHALL attempt to migrate the existing local progress data from the guest unique ID to the authenticated account, and IF migration fails due to corrupted local data or system errors, THEN THE Game_Client SHALL proceed with login and discard the guest progress data
8. IF the Progress_Store fails to save match results due to insufficient device storage, THEN THE Game_Client SHALL display a notification to the Player indicating that match results could not be saved and SHALL retain the unsaved match results in memory until the next successful save attempt

### Requirement 11: Map Design

**User Story:** As a player, I want a varied and interesting map to explore, so that each match feels engaging with different landing options.

#### Acceptance Criteria

1. THE Game_Client SHALL provide a single Battle Royale map with a minimum of 8 distinct named locations (points of interest), where each named location has a unique layout and is separated from other named locations by a minimum of 100 in-game meters
2. THE Game_Client SHALL include varied terrain types across the map including urban areas, open fields, forested zones, and elevated terrain, with each terrain type covering at least 15 percent of the total playable map area
3. THE Game_Client SHALL distribute Loot spawns such that named locations contain at least 3 times the loot spawn density (items per unit area) compared to open areas between named locations
4. THE Game_Client SHALL render the map and all map elements (including UI overlays and effects) in the same blocky, colorful art style as the characters with strict visual consistency across all elements
5. THE Game_Client SHALL support the map being fully loaded and playable without streaming from external sources
6. WHILE the Drop_Phase is active, THE Game_Client SHALL display all named location labels on the map view so the Player can identify landing options; WHEN the Drop_Phase ends, THE Game_Client SHALL hide all named location labels from the map view
7. THE Game_Client SHALL guarantee a minimum of 5 loot spawn points within each named location

### Requirement 12: Audio Design

**User Story:** As a player, I want immersive sound effects and audio cues, so that I can locate enemies and feel engaged in the action.

#### Acceptance Criteria

1. THE Game_Client SHALL play directional audio for gunshots, footsteps, and explosions with volume attenuation based on distance, audible up to 100 meters for gunshots, 30 meters for footsteps, and 150 meters for explosions, allowing the Player to identify sound source direction
2. THE Game_Client SHALL play distinct audio cues for Zone shrinking warnings, item pickups, and Eliminations
3. THE Game_Client SHALL provide background music during the lobby, Drop_Phase, and Victory_Royale screen
4. THE Game_Client SHALL allow the Player to independently adjust music volume, sound effects volume, and voice/announcer volume in settings, each on a scale from 0 (muted) to 100 (maximum)
5. WHILE the Player is in the Storm, THE Game_Client SHALL always attempt to play a continuous ambient storm audio effect, respecting the Player's volume settings (including mute); IF the audio system is unavailable, THE Game_Client SHALL allow silent failure without interrupting gameplay
6. THE Game_Client SHALL render the Player's own footsteps at a lower volume and without directional spatialization to distinguish them from enemy footsteps

### Requirement 13: Performance and Device Compatibility

**User Story:** As a player, I want the game to run smoothly on my Android phone, so that I can enjoy gameplay without lag or crashes.

#### Acceptance Criteria

1. THE Game_Client SHALL maintain a minimum of 30 frames per second for at least 95 percent of measured frames during active gameplay, applying this requirement only on devices with 4GB or more RAM and a mid-range processor (Snapdragon 600 series or equivalent) with up to 20 Bots visible on screen
2. THE Game_Client SHALL provide graphics quality settings (Low, Medium, High) allowing the Player to select a preset before or during a match, where each preset visibly adjusts rendering detail (draw distance, shadow quality, particle effects)
3. THE Game_Client SHALL support Android 8.0 (API level 26) and above
4. THE Game_Client SHALL limit the installed application size (APK plus required assets after initial install) to under 500MB
5. IF available device memory drops below 200MB during a match, THEN THE Game_Client SHALL reduce visual quality by at least one preset level and display a brief on-screen indicator informing the Player that quality has been reduced
6. WHEN the Player starts a match, THE Game_Client SHALL complete map loading and begin the Drop_Phase within 15 seconds on devices meeting the minimum specification (4GB RAM, Snapdragon 600 series or equivalent)
7. WHEN available device memory is below 100MB during a match and quality is already at the lowest preset, THE Game_Client SHALL preserve the current match state and display a warning indicating the match may need to end due to memory constraints

### Requirement 14: Main Menu and Navigation

**User Story:** As a player, I want a polished main menu with clear navigation, so that I can easily access all game features.

#### Acceptance Criteria

1. THE Game_Client SHALL display a main menu with options for: Play (start match), Characters, Career Stats, Settings, and a Login option that changes to display the Player's identifier when already authenticated
2. IF no character has been previously selected, THEN THE Game_Client SHALL display the default character (Blitz, male variant) on the main menu as a 3D model; otherwise THE Game_Client SHALL display the Player's currently selected character
3. WHEN the Player selects Play, THE Game_Client SHALL transition to the Character_Selector or directly to the match lobby within 3 seconds, and WHEN the Player confirms character selection, THE Game_Client SHALL transition to the match lobby within 3 seconds
4. THE Game_Client SHALL provide a Settings screen with sub-sections for Controls, Graphics, Audio, and Account
5. THE Game_Client SHALL apply the same color palette, font family, and UI component styling across all menu screens, matching the blocky cartoon art style defined for the game
6. WHEN the Player navigates to any sub-screen (Characters, Career Stats, Settings, or Login), THE Game_Client SHALL provide a visible back button that returns the Player to the main menu

### Requirement 15: Match Settings

**User Story:** As a player, I want to configure match parameters before playing, so that I can tailor the difficulty and experience to my preference.

#### Acceptance Criteria

1. THE Game_Client SHALL allow the Player to select Bot difficulty (Easy, Medium, Hard) before starting a match, with Medium as the default selection
2. THE Game_Client SHALL allow the Player to configure the number of Bots in a match (minimum 10, maximum 99) with a default value of 50
3. THE Game_Client SHALL allow the Player to select a Zone shrink speed (Slow, Normal, Fast) before starting a match, with Normal as the default selection
4. THE Game_Client SHALL display estimated match duration in minutes (rounded to the nearest whole minute, with a minimum display value of 1 minute) based on selected Bot count and Zone shrink speed, and SHALL update the estimate within 1 second of any setting change
5. WHEN the Player confirms match settings, THE Game_Client SHALL generate the match with the specified Bot difficulty, Bot count, and Zone shrink speed parameters; THE Game_Client SHALL block confirmation until all settings are valid (Bot count within 10-99 range, difficulty and zone speed selected)
