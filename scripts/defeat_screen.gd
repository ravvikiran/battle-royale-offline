## Defeat screen displayed when the player is eliminated (placement > 1).
## Shows match statistics: kills, damage dealt, survival time, placement, character used.
## Provides options to return to lobby or play again.
## Requirements: 1.6
class_name DefeatScreen
extends Control


## Emitted when the player chooses to return to the main menu.
signal return_to_menu_pressed

## Emitted when the player chooses to play again with the same settings.
signal play_again_pressed


## Match result data displayed on this screen.
var match_result: Dictionary = {}


## UI node references.
@onready var title_label: Label = %TitleLabel
@onready var placement_label: Label = %PlacementLabel
@onready var kills_label: Label = %KillsLabel
@onready var damage_label: Label = %DamageLabel
@onready var survival_time_label: Label = %SurvivalTimeLabel
@onready var character_label: Label = %CharacterLabel
@onready var difficulty_label: Label = %DifficultyLabel
@onready var bot_count_label: Label = %BotCountLabel
@onready var return_button: Button = %ReturnButton
@onready var play_again_button: Button = %PlayAgainButton


func _ready() -> void:
	_setup_ui()
	if not match_result.is_empty():
		_display_results()


## Sets up button connections.
func _setup_ui() -> void:
	return_button.pressed.connect(_on_return_pressed)
	play_again_button.pressed.connect(_on_play_again_pressed)


## Sets the match result data and updates the display.
func set_match_result(result: Dictionary) -> void:
	match_result = result
	if is_inside_tree():
		_display_results()


## Displays the match results on screen.
func _display_results() -> void:
	title_label.text = "ELIMINATED"

	var placement: int = match_result.get("placement", 0)
	var total: int = match_result.get("total_participants", 0)
	placement_label.text = "#%d / %d" % [placement, total]

	var kills: int = match_result.get("kills", 0)
	kills_label.text = "Kills: %d" % kills

	var damage: float = match_result.get("damage_dealt", 0.0)
	damage_label.text = "Damage: %d" % int(damage)

	var survival_seconds: float = match_result.get("survival_time_seconds", 0.0)
	var minutes: int = int(survival_seconds) / 60
	var seconds: int = int(survival_seconds) % 60
	survival_time_label.text = "Survived: %d:%02d" % [minutes, seconds]

	var character: String = match_result.get("character", "BLITZ")
	var variant: String = match_result.get("variant", "MALE")
	character_label.text = "%s (%s)" % [character.capitalize(), variant.capitalize()]

	var difficulty_val = match_result.get("bot_difficulty", Enums.Difficulty.MEDIUM)
	difficulty_label.text = "Difficulty: %s" % _difficulty_to_display(difficulty_val)

	var bot_count: int = match_result.get("bot_count", 50)
	bot_count_label.text = "Bots: %d" % bot_count


## Converts difficulty value to display string.
func _difficulty_to_display(difficulty) -> String:
	if difficulty is String:
		return difficulty.capitalize()
	match int(difficulty):
		Enums.Difficulty.EASY:
			return "Easy"
		Enums.Difficulty.MEDIUM:
			return "Medium"
		Enums.Difficulty.HARD:
			return "Hard"
		_:
			return "Medium"


## Called when return to menu button is pressed.
func _on_return_pressed() -> void:
	return_to_menu_pressed.emit()


## Called when play again button is pressed.
func _on_play_again_pressed() -> void:
	play_again_pressed.emit()
