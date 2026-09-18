## Career Stats screen UI controller.
## Displays total matches, wins, total kills, avg kills per match, and win rate.
## Implements back button navigation (Requirement 14.6).
class_name CareerStats
extends Control


## Emitted when the player presses the back button.
signal back_pressed

## Emitted when the player presses "Play Now" from the empty state.
signal play_pressed


## Reference to the ProgressStore for loading career statistics.
var _progress_store: ProgressStore = null

## Cached career stats data.
var _stats: Dictionary = {}

## Whether the count-up/stagger reveal has already played this screen visit,
## so repeated _refresh_stats() calls (ready + injection) don't re-animate.
var _has_animated: bool = false


## UI node references.
@onready var back_button: Button = %BackButton
@onready var title_label: Label = %TitleLabel
@onready var total_matches_label: Label = %TotalMatchesLabel
@onready var wins_label: Label = %WinsLabel
@onready var total_kills_label: Label = %TotalKillsLabel
@onready var avg_kills_label: Label = %AvgKillsLabel
@onready var win_rate_label: Label = %WinRateLabel
@onready var no_data_label: Label = %NoDataLabel

## Grouping containers (toggled together instead of per-label).
@onready var hero_panel: PanelContainer = %HeroPanel
@onready var stat_grid: GridContainer = %StatGrid
@onready var no_data_container: VBoxContainer = %NoDataContainer
@onready var play_now_button: Button = %PlayNowButton


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
	play_now_button.pressed.connect(_on_play_now_pressed)
	# Default focus on Back; the empty state re-focuses its Play CTA below.
	back_button.grab_focus.call_deferred()


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

	if _has_animated:
		# Subsequent refreshes: set final values directly, no re-animation.
		total_matches_label.text = "%d" % total_matches
		wins_label.text = "%d" % wins
		total_kills_label.text = "%d" % total_kills
		avg_kills_label.text = "%.1f" % avg_kills
		win_rate_label.text = "%.1f%%" % win_rate
		return

	_has_animated = true

	# First reveal: numbers count up so they "land", and the cards cascade in.
	# The hero win-rate is the headline metric, so it counts over the full duration.
	Motion.count_to_float(win_rate_label, 0.0, win_rate, 1, "%")
	Motion.count_to(total_matches_label, 0, total_matches)
	Motion.count_to(wins_label, 0, wins)
	Motion.count_to(total_kills_label, 0, total_kills)
	Motion.count_to_float(avg_kills_label, 0.0, avg_kills, 1)

	# Cascade the hero panel then the four stat cards into view.
	Motion.stagger_in([hero_panel] + stat_grid.get_children())


## Show the no-data state when no matches have been played.
func _show_no_data() -> void:
	no_data_container.visible = true
	hero_panel.visible = false
	stat_grid.visible = false
	# When empty, the Play CTA is the primary action — focus it.
	play_now_button.grab_focus.call_deferred()


## Show the stats groups and hide the no-data message.
func _show_stats() -> void:
	no_data_container.visible = false
	hero_panel.visible = true
	stat_grid.visible = true


## Called when the back button is pressed.
func _on_back_pressed() -> void:
	back_pressed.emit()


## Called when the empty-state "Play Now" button is pressed.
func _on_play_now_pressed() -> void:
	play_pressed.emit()


## Get the cached career stats.
func get_stats() -> Dictionary:
	return _stats
