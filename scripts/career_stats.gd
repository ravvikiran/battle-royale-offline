## Career Stats screen UI controller.
## Displays total matches, wins, total kills, avg kills per match, and win rate.
## Implements back button navigation (Requirement 14.6).
class_name CareerStats
extends Control


## Emitted when the player presses the back button.
signal back_pressed


## Reference to the ProgressStore for loading career statistics.
var _progress_store: ProgressStore = null

## Cached career stats data.
var _stats: Dictionary = {}


## UI node references.
@onready var back_button: Button = %BackButton
@onready var title_label: Label = %TitleLabel
@onready var total_matches_label: Label = %TotalMatchesLabel
@onready var wins_label: Label = %WinsLabel
@onready var total_kills_label: Label = %TotalKillsLabel
@onready var avg_kills_label: Label = %AvgKillsLabel
@onready var win_rate_label: Label = %WinRateLabel
@onready var no_data_label: Label = %NoDataLabel


func _ready() -> void:
	_setup_ui()
	_refresh_stats()


## Inject the ProgressStore dependency.
func set_progress_store(store: ProgressStore) -> void:
	_progress_store = store
	_refresh_stats()


## Set up UI elements and connect signals.
func _setup_ui() -> void:
	back_button.pressed.connect(_on_back_pressed)


## Refresh the career stats display from the ProgressStore.
func _refresh_stats() -> void:
	if _progress_store == null:
		_show_no_data()
		return

	_stats = _progress_store.get_career_stats()

	var total_matches: int = _stats.get("total_matches", 0)

	if total_matches == 0:
		_show_no_data()
		return

	_show_stats()

	var wins: int = _stats.get("wins", 0)
	var total_kills: int = _stats.get("total_kills", 0)
	var avg_kills: float = _stats.get("avg_kills_per_match", 0.0)
	var win_rate: float = _stats.get("win_rate", 0.0)

	total_matches_label.text = "Total Matches: %d" % total_matches
	wins_label.text = "Wins: %d" % wins
	total_kills_label.text = "Total Kills: %d" % total_kills
	avg_kills_label.text = "Avg Kills/Match: %.1f" % avg_kills
	win_rate_label.text = "Win Rate: %.1f%%" % win_rate


## Show the no-data state when no matches have been played.
func _show_no_data() -> void:
	no_data_label.visible = true
	total_matches_label.visible = false
	wins_label.visible = false
	total_kills_label.visible = false
	avg_kills_label.visible = false
	win_rate_label.visible = false


## Show the stats labels and hide the no-data message.
func _show_stats() -> void:
	no_data_label.visible = false
	total_matches_label.visible = true
	wins_label.visible = true
	total_kills_label.visible = true
	avg_kills_label.visible = true
	win_rate_label.visible = true


## Called when the back button is pressed.
func _on_back_pressed() -> void:
	back_pressed.emit()


## Get the cached career stats.
func get_stats() -> Dictionary:
	return _stats
