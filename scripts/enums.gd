## Core enumerations for the Battle Royale Offline game.
## This autoload provides all shared enums used across game systems.
class_name Enums


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
