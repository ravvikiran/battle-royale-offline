## Resource class representing a weapon's static data configuration.
## Stores all properties that define a weapon's behavior and stats.
class_name WeaponData
extends Resource


## The weapon's category (AR, SHOTGUN, SMG, SNIPER, PISTOL).
@export var category: Enums.WeaponCategory

## The weapon's display name (e.g., "Volt Repeater", "Boomstick").
@export var name: String

## The weapon's rarity tier affecting damage and accuracy.
@export var rarity: Enums.RarityTier

## Base damage per hit before rarity modifiers.
@export var base_damage: float

## Rounds fired per second.
@export var fire_rate: float

## Maximum rounds in a single magazine.
@export var magazine_size: int

## Time in seconds to reload the weapon.
@export var reload_time: float

## Effective range in meters (full damage within this distance).
@export var effective_range: float

## Base accuracy value (0.0 to 1.0) before rarity bonuses.
@export var accuracy_base: float


## Creates a WeaponData instance from a dictionary (e.g., parsed from JSON).
static func from_dict(data: Dictionary, weapon_rarity: Enums.RarityTier = Enums.RarityTier.COMMON) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.category = _parse_category(data.get("category", "AR"))
	weapon.name = data.get("name", "Unknown")
	weapon.rarity = weapon_rarity
	weapon.base_damage = float(data.get("base_damage", 0))
	weapon.fire_rate = float(data.get("fire_rate_rps", 1))
	weapon.magazine_size = int(data.get("magazine_size", 1))
	weapon.reload_time = float(data.get("reload_time_seconds", 1.0))
	weapon.effective_range = float(data.get("effective_range_meters", 10))
	weapon.accuracy_base = float(data.get("base_accuracy", 0.5))
	return weapon


## Parses a category string into the WeaponCategory enum value.
static func _parse_category(category_str: String) -> Enums.WeaponCategory:
	match category_str.to_upper():
		"AR":
			return Enums.WeaponCategory.AR
		"SHOTGUN":
			return Enums.WeaponCategory.SHOTGUN
		"SMG":
			return Enums.WeaponCategory.SMG
		"SNIPER":
			return Enums.WeaponCategory.SNIPER
		"PISTOL":
			return Enums.WeaponCategory.PISTOL
		_:
			return Enums.WeaponCategory.AR
