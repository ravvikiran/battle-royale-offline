## Match Settings UI controller.
## Manages bot difficulty, bot count, zone shrink speed, and estimated duration display.
## Blocks match confirmation until all settings are valid.
class_name MatchSettings
extends Control


## Emitted when the player confirms valid match settings.
signal settings_confirmed(settings: Dictionary)

## Emitted when the player cancels/goes back.
signal back_pressed


## Minimum allowed bot count.
const BOT_COUNT_MIN: int = 10

## Maximum allowed bot count.
const BOT_COUNT_MAX: int = 99

## Default bot count.
const BOT_COUNT_DEFAULT: int = 50


## Zone phase data loaded from data/zone_phases.json.
var _zone_phases_data: Dictionary = {}

## Current settings state.
var _bot_difficulty: int = Enums.Difficulty.MEDIUM
var _bot_count: int = BOT_COUNT_DEFAULT
var _zone_speed: int = Enums.ZoneShrinkSpeed.NORMAL
var _estimated_duration_minutes: int = 15

## Timer for debouncing duration estimate updates.
var _update_timer: Timer

## UI node references.
@onready var difficulty_option: OptionButton = %DifficultyOption
@onready var bot_count_slider: HSlider = %BotCountSlider
@onready var bot_count_label: Label = %BotCountLabel
@onready var bot_count_input: SpinBox = %BotCountInput
@onready var zone_speed_option: OptionButton = %ZoneSpeedOption
@onready var duration_label: Label = %DurationLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var back_button: Button = %BackButton
@onready var validation_label: Label = %ValidationLabel


func _ready() -> void:
	_load_zone_phases()
	_setup_ui()
	_setup_update_timer()
	_update_estimated_duration()
	_validate_settings()


## Load zone phase configuration from JSON data file.
func _load_zone_phases() -> void:
	var file := FileAccess.open("res://data/zone_phases.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		if error == OK:
			_zone_phases_data = json.data
		file.close()


## Set up UI elements with default values and connect signals.
func _setup_ui() -> void:
	# Difficulty selector (Easy/Medium/Hard, default: Medium)
	difficulty_option.clear()
	difficulty_option.add_item("Easy", Enums.Difficulty.EASY)
	difficulty_option.add_item("Medium", Enums.Difficulty.MEDIUM)
	difficulty_option.add_item("Hard", Enums.Difficulty.HARD)
	difficulty_option.selected = 1  # Medium default
	difficulty_option.item_selected.connect(_on_difficulty_changed)

	# Bot count slider (10-99, default 50)
	bot_count_slider.min_value = BOT_COUNT_MIN
	bot_count_slider.max_value = BOT_COUNT_MAX
	bot_count_slider.step = 1
	bot_count_slider.value = BOT_COUNT_DEFAULT
	bot_count_slider.value_changed.connect(_on_bot_count_slider_changed)

	# Bot count SpinBox input (10-99, default 50)
	bot_count_input.min_value = BOT_COUNT_MIN
	bot_count_input.max_value = BOT_COUNT_MAX
	bot_count_input.step = 1
	bot_count_input.value = BOT_COUNT_DEFAULT
	bot_count_input.value_changed.connect(_on_bot_count_input_changed)

	# Bot count label
	bot_count_label.text = str(BOT_COUNT_DEFAULT)

	# Zone speed selector (Slow/Normal/Fast, default: Normal)
	zone_speed_option.clear()
	zone_speed_option.add_item("Slow", Enums.ZoneShrinkSpeed.SLOW)
	zone_speed_option.add_item("Normal", Enums.ZoneShrinkSpeed.NORMAL)
	zone_speed_option.add_item("Fast", Enums.ZoneShrinkSpeed.FAST)
	zone_speed_option.selected = 1  # Normal default
	zone_speed_option.item_selected.connect(_on_zone_speed_changed)

	# Confirm and back buttons
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)


## Set up a timer to ensure duration updates happen within 1 second of changes.
func _setup_update_timer() -> void:
	_update_timer = Timer.new()
	_update_timer.one_shot = true
	_update_timer.wait_time = 0.1  # Update quickly, well within 1 second requirement
	_update_timer.timeout.connect(_update_estimated_duration)
	add_child(_update_timer)


## Called when difficulty selection changes.
func _on_difficulty_changed(index: int) -> void:
	_bot_difficulty = difficulty_option.get_item_id(index)
	_schedule_update()


## Called when bot count slider changes.
func _on_bot_count_slider_changed(value: float) -> void:
	_bot_count = int(value)
	bot_count_input.set_value_no_signal(value)
	bot_count_label.text = str(_bot_count)
	_schedule_update()


## Called when bot count SpinBox input changes.
func _on_bot_count_input_changed(value: float) -> void:
	_bot_count = int(value)
	bot_count_slider.set_value_no_signal(value)
	bot_count_label.text = str(_bot_count)
	_schedule_update()


## Called when zone speed selection changes.
func _on_zone_speed_changed(index: int) -> void:
	_zone_speed = zone_speed_option.get_item_id(index)
	_schedule_update()


## Schedule an update to estimated duration (ensures update within 1 second).
func _schedule_update() -> void:
	_update_timer.start()
	_validate_settings()


## Calculate and display estimated match duration.
## Duration = sum of (wait_seconds + shrink_seconds) for all phases, multiplied by speed multiplier.
## Rounded to nearest minute, minimum 1.
func _update_estimated_duration() -> void:
	_estimated_duration_minutes = calculate_estimated_duration(_bot_count, _zone_speed, _zone_phases_data)
	duration_label.text = "Estimated Duration: %d min" % _estimated_duration_minutes


## Static calculation of estimated match duration.
## Returns duration in minutes (rounded to nearest minute, minimum 1).
## Duration is a function of bot count and zone speed:
##   total_seconds = sum(phase wait + shrink) * speed_multiplier * (bot_count / 50.0)
static func calculate_estimated_duration(bot_count: int, zone_speed: int, zone_data: Dictionary) -> int:
	var total_seconds: float = 0.0

	# Sum all phase wait and shrink times
	if zone_data.has("phases"):
		for phase in zone_data["phases"]:
			total_seconds += phase.get("wait_seconds", 0)
			total_seconds += phase.get("shrink_seconds", 0)

	# Apply speed multiplier (SLOW: 1.5×, NORMAL: 1.0×, FAST: 0.6×)
	var speed_multiplier: float = _get_speed_multiplier(zone_speed, zone_data)
	total_seconds *= speed_multiplier

	# Factor in bot count: more bots = slightly longer matches.
	# Base estimate assumes 50 bots; scale linearly.
	var bot_factor: float = float(bot_count) / 50.0
	total_seconds *= bot_factor

	# Convert to minutes, round to nearest, minimum 1
	var minutes: int = int(round(total_seconds / 60.0))
	return maxi(minutes, 1)


## Get the speed multiplier for the given zone speed setting.
static func _get_speed_multiplier(zone_speed: int, zone_data: Dictionary) -> float:
	if zone_data.has("speed_multipliers"):
		var multipliers: Dictionary = zone_data["speed_multipliers"]
		match zone_speed:
			Enums.ZoneShrinkSpeed.SLOW:
				return multipliers.get("SLOW", 1.5)
			Enums.ZoneShrinkSpeed.NORMAL:
				return multipliers.get("NORMAL", 1.0)
			Enums.ZoneShrinkSpeed.FAST:
				return multipliers.get("FAST", 0.6)
	# Fallback defaults if zone_data is missing
	match zone_speed:
		Enums.ZoneShrinkSpeed.SLOW:
			return 1.5
		Enums.ZoneShrinkSpeed.NORMAL:
			return 1.0
		Enums.ZoneShrinkSpeed.FAST:
			return 0.6
	return 1.0


## Validate all settings and enable/disable confirm button.
## Blocks match confirmation until all settings are valid per Requirement 15.5.
func _validate_settings() -> void:
	var is_valid := true
	var validation_message := ""

	# Bot count must be in range 10-99 (Requirement 15.2)
	if _bot_count < BOT_COUNT_MIN or _bot_count > BOT_COUNT_MAX:
		is_valid = false
		validation_message = "Bot count must be between %d and %d." % [BOT_COUNT_MIN, BOT_COUNT_MAX]

	# Difficulty must be a valid enum value
	if _bot_difficulty < Enums.Difficulty.EASY or _bot_difficulty > Enums.Difficulty.HARD:
		is_valid = false
		validation_message = "Please select a valid difficulty."

	# Zone speed must be a valid enum value
	if _zone_speed < Enums.ZoneShrinkSpeed.SLOW or _zone_speed > Enums.ZoneShrinkSpeed.FAST:
		is_valid = false
		validation_message = "Please select a valid zone speed."

	confirm_button.disabled = not is_valid
	validation_label.text = validation_message
	validation_label.visible = not is_valid


## Called when confirm button is pressed.
func _on_confirm_pressed() -> void:
	if not _is_settings_valid():
		return

	var settings := {
		"bot_count": _bot_count,
		"bot_difficulty": _bot_difficulty,
		"zone_speed": _zone_speed,
		"estimated_duration_minutes": _estimated_duration_minutes
	}
	settings_confirmed.emit(settings)


## Called when back button is pressed.
func _on_back_pressed() -> void:
	back_pressed.emit()


## Check if current settings are valid.
func _is_settings_valid() -> bool:
	if _bot_count < BOT_COUNT_MIN or _bot_count > BOT_COUNT_MAX:
		return false
	if _bot_difficulty < Enums.Difficulty.EASY or _bot_difficulty > Enums.Difficulty.HARD:
		return false
	if _zone_speed < Enums.ZoneShrinkSpeed.SLOW or _zone_speed > Enums.ZoneShrinkSpeed.FAST:
		return false
	return true


## Get current settings as a dictionary.
func get_settings() -> Dictionary:
	return {
		"bot_count": _bot_count,
		"bot_difficulty": _bot_difficulty,
		"zone_speed": _zone_speed,
		"estimated_duration_minutes": _estimated_duration_minutes
	}


## Set bot count programmatically (for testing or external control).
## Values outside 10-99 are clamped to the valid range.
func set_bot_count(count: int) -> void:
	_bot_count = clampi(count, BOT_COUNT_MIN, BOT_COUNT_MAX)
	bot_count_slider.value = _bot_count
	bot_count_input.value = _bot_count
	bot_count_label.text = str(_bot_count)
	_schedule_update()


## Set difficulty programmatically.
func set_difficulty(difficulty: int) -> void:
	_bot_difficulty = clampi(difficulty, Enums.Difficulty.EASY, Enums.Difficulty.HARD)
	difficulty_option.selected = _bot_difficulty
	_schedule_update()


## Set zone speed programmatically.
func set_zone_speed(speed: int) -> void:
	_zone_speed = clampi(speed, Enums.ZoneShrinkSpeed.SLOW, Enums.ZoneShrinkSpeed.FAST)
	zone_speed_option.selected = _zone_speed
	_schedule_update()
