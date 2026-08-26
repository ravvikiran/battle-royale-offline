## Core enumerations for the Battle Royale Offline game.
## Provides all shared enums used across game systems via class_name.
class_name Enums
extends RefCounted


## Match lifecycle states
enum MatchState {
	LOBBY,
	DROP,
	ACTIVE,
	ENDED
}

## Weapon category classifications
enum WeaponCategory {
	AR,
	SHOTGUN,
	SMG,
	SNIPER,
	PISTOL
}

## Weapon and loot rarity tiers (index used for damage/accuracy modifiers)
enum RarityTier {
	COMMON,    ## Index 0
	UNCOMMON,  ## Index 1
	RARE,      ## Index 2
	EPIC,      ## Index 3
	LEGENDARY  ## Index 4
}

## Bot AI finite state machine states
enum BotState {
	LOOTING,
	ROAMING,
	ENGAGING,
	FLEEING,
	HEALING
}

## Bot difficulty levels
enum Difficulty {
	EASY,
	MEDIUM,
	HARD
}

## Zone phase states (waiting before shrink, or actively shrinking)
enum PhaseState {
	WAITING,
	SHRINKING
}

## Zone shrink speed presets with time multipliers
enum ZoneShrinkSpeed {
	SLOW,    ## 1.5x multiplier (slower shrink)
	NORMAL,  ## 1.0x multiplier
	FAST     ## 0.6x multiplier (faster shrink)
}

## Player authentication states
enum AuthState {
	GUEST,
	AUTHENTICATED
}

## Supported authentication providers
enum AuthProvider {
	GOOGLE,
	FACEBOOK,
	EMAIL
}

## Consumable item types
enum ConsumableType {
	BANDAGE,
	MEDKIT,
	SHIELD_POTION
}

## Weapon firing modes
enum FireMode {
	TAP,
	HOLD
}


# ============================
# NEW SYSTEMS - v0.2.0
# ============================


## Achievement categories for grouping and display
enum AchievementCategory {
	COMBAT,       ## Kill-based achievements
	SURVIVAL,     ## Survival time and zone-related
	VICTORY,      ## Win-based achievements
	MASTERY,      ## Weapon/character mastery
	EXPLORATION,  ## Map exploration and loot
	SOCIAL        ## Sharing and community
}

## Achievement rarity for display styling
enum AchievementRarity {
	BRONZE,
	SILVER,
	GOLD,
	PLATINUM,
	DIAMOND
}

## Kill streak tiers with escalating rewards
enum KillStreak {
	NONE,          ## 0 kills
	FIRST_BLOOD,   ## 1st kill of match
	DOUBLE_KILL,   ## 2 rapid kills
	TRIPLE_KILL,   ## 3 rapid kills
	QUAD_KILL,     ## 4 rapid kills
	RAMPAGE,       ## 5 rapid kills
	UNSTOPPABLE,   ## 7 rapid kills
	GODLIKE,       ## 10 rapid kills
	LEGENDARY      ## 15+ rapid kills
}

## XP event types for tracking XP sources
enum XPSource {
	KILL,
	ASSIST,
	SURVIVAL_TIME,
	PLACEMENT,
	DAILY_CHALLENGE,
	ACHIEVEMENT,
	WIN_BONUS,
	FIRST_MATCH_OF_DAY,
	STREAK_BONUS,
	BATTLE_PASS_BONUS
}

## Daily challenge types
enum ChallengeType {
	KILL_COUNT,          ## Get X kills in a single match
	TOTAL_KILLS,         ## Get X total kills across matches
	WIN_MATCH,           ## Win a match
	TOP_PLACEMENT,       ## Finish top X
	USE_WEAPON_CATEGORY, ## Get kills with specific weapon type
	SURVIVE_TIME,        ## Survive for X seconds
	DEAL_DAMAGE,         ## Deal X total damage
	HEADSHOT_KILLS,      ## Not implemented yet but future-ready
	NO_DAMAGE_WIN,       ## Win without taking damage
	STORM_SURVIVAL,      ## Survive X seconds in storm
	LOOT_ITEMS,          ## Pick up X items
	PLAY_CHARACTER       ## Play a match as specific character
}

## Challenge difficulty tiers
enum ChallengeDifficulty {
	EASY,       ## Quick to complete, low XP
	MEDIUM,     ## Moderate effort, decent XP
	HARD,       ## Significant effort, high XP
	LEGENDARY   ## Very difficult, massive XP
}

## Battle pass tier types
enum BattlePassTier {
	FREE,
	PREMIUM
}

## Reward types for battle pass, achievements, and challenges
enum RewardType {
	XP,
	CHARACTER_SKIN,
	WEAPON_SKIN,
	TITLE,
	BANNER,
	EMOTE,
	TRAIL_EFFECT,
	DROP_EFFECT,
	CURRENCY
}

## Combat feedback types
enum CombatFeedback {
	HIT_MARKER,
	HEADSHOT_MARKER,
	KILL_CONFIRM,
	DAMAGE_NUMBER,
	SHIELD_CRACK,
	ELIMINATION_BANNER,
	STREAK_ANNOUNCEMENT
}

## Screen effect types for juice/feel
enum ScreenEffect {
	SHAKE_LIGHT,      ## Small hit received
	SHAKE_MEDIUM,     ## Significant damage
	SHAKE_HEAVY,      ## Near-death or explosion
	PULSE_DAMAGE,     ## Red vignette on damage
	PULSE_HEAL,       ## Green pulse on heal
	PULSE_SHIELD,     ## Blue pulse on shield gain
	FLASH_KILL,       ## White flash on kill confirm
	ZOOM_SNIPER,      ## Scope zoom effect
	SPEED_LINES,      ## Fast movement indicator
	LOW_HP_VIGNETTE   ## Persistent red edges at low HP
}

## Drop zone heat levels for hot drop system
enum DropZoneHeat {
	COLD,      ## Few bots, low loot
	WARM,      ## Average bots and loot
	HOT,       ## Many bots, high loot density
	INFERNO    ## Maximum danger, legendary loot guaranteed
}

## Player title unlockable via achievements
enum PlayerTitle {
	ROOKIE,
	SURVIVOR,
	WARRIOR,
	VETERAN,
	CHAMPION,
	LEGEND,
	APEX_PREDATOR
}

## Season identifiers
enum Season {
	SEASON_1,
	SEASON_2,
	SEASON_3,
	SEASON_4
}

## Analytics event types for future tracking
enum AnalyticsEvent {
	MATCH_START,
	MATCH_END,
	ELIMINATION,
	DEATH,
	LOOT_PICKUP,
	ZONE_DAMAGE,
	ACHIEVEMENT_UNLOCK,
	CHALLENGE_COMPLETE,
	LEVEL_UP,
	BATTLE_PASS_TIER,
	SESSION_START,
	SESSION_END
}
