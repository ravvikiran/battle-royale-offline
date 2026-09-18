## Match History browser screen with detailed per-match statistics.
## Shows a scrollable list of past matches with filtering and detailed views.
## Displays placement, kills, damage, survival time, character used, and XP earned.
class_name MatchHistoryScreen
extends Control


## Emitted when the player wants to return to the previous screen
signal back_pressed()

## Emitted when a specific match is selected for detail view
signal match_selected(match_data: Dictionary)

## Emitted when the player presses "Play a Match" from the empty state.
signal play_pressed()


## UI node references
var _back_button: Button = null
var _match_list_container: VBoxContainer = null
var _filter_container: HBoxContainer = null
var _detail_panel: PanelContainer = null
var _stats_summary: VBoxContainer = null
var _no_data_label: Label = null
var _filter_all_btn: Button = null
var _filter_wins_btn: Button = null
var _filter_character_btn: OptionButton = null
var _page_label: Label = null
var _prev_page_btn: Button = null
var _next_page_btn: Button = null

## Empty-state group: headline + hint + Play CTA. Distinct from the paginated list
## so we can show tailored guidance for "never played" vs "filter hides all".
var _empty_state: VBoxContainer = null
var _empty_headline: Label = null
var _empty_hint: Label = null
var _empty_play_btn: Button = null

## Loading indicator shown until set_progress_store() resolves the data.
var _loading_label: Label = null

## Whether match data has been loaded yet (drives the loading state).
var _data_loaded: bool = false

## Reference to progress store
var _progress_store: ProgressStore = null

## All loaded match history
var _all_matches: Array = []

## Currently filtered/displayed matches
var _filtered_matches: Array = []

## Current page (0-indexed)
var _current_page: int = 0

## Matches per page
const MATCHES_PER_PAGE: int = 10

## Current filter mode
var _filter_mode: String = "all"  # "all", "wins", "character"

## Selected character filter
var _filter_character: String = ""

## Whether the detail panel is showing
var _detail_visible: bool = false


func _ready() -> void:
	_build_ui()
	_connect_signals()


## Sets the progress store reference and loads data
func set_progress_store(store: ProgressStore) -> void:
	_progress_store = store
	_load_matches()
	_data_loaded = true
	if _loading_label != null:
		_loading_label.visible = false
	_apply_filter()
	_render_page()
	_render_summary_stats()


## Builds the complete UI layout
func _build_ui() -> void:
	# Root layout
	# Full-bleed background + consistent screen padding (matches .tscn screens).
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.SURFACE_BG
	add_child(bg)

	var screen_margin := MarginContainer.new()
	screen_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_margin.add_theme_constant_override("margin_left", UITheme.SPACE_XXL)
	screen_margin.add_theme_constant_override("margin_top", UITheme.SPACE_XXL)
	screen_margin.add_theme_constant_override("margin_right", UITheme.SPACE_XXL)
	screen_margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_XXL)
	add_child(screen_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UITheme.SPACE_M)
	screen_margin.add_child(root)

	# --- Header ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UITheme.SPACE_L)
	root.add_child(header)

	_back_button = Button.new()
	_back_button.text = "< Back"
	_back_button.custom_minimum_size = Vector2(120, UITheme.TOUCH_MIN)
	header.add_child(_back_button)

	var title := Label.new()
	title.text = "MATCH HISTORY"
	title.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	title.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Spacer to balance back button
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(120, 0)
	header.add_child(spacer)

	# --- Summary Stats Bar ---
	_stats_summary = VBoxContainer.new()
	root.add_child(_stats_summary)

	var stats_panel := PanelContainer.new()
	_stats_summary.add_child(stats_panel)
	var stats_hbox := HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", UITheme.SPACE_XXL)
	stats_panel.add_child(stats_hbox)

	# Stats will be populated in _render_summary_stats()
	for label_name in ["Total Matches", "Win Rate", "Avg Kills", "Best Streak", "Avg Placement"]:
		var stat_vbox := VBoxContainer.new()
		stat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		stats_hbox.add_child(stat_vbox)

		var stat_label := Label.new()
		stat_label.text = "0"
		stat_label.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
		stat_label.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_label.name = label_name.replace(" ", "") + "Value"
		stat_vbox.add_child(stat_label)

		var stat_title := Label.new()
		stat_title.text = label_name
		stat_title.add_theme_font_size_override("font_size", UITheme.FONT_CAPTION)
		stat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_title.modulate = UITheme.TEXT_MUTED
		stat_vbox.add_child(stat_title)

	# --- Filter Bar ---
	_filter_container = HBoxContainer.new()
	_filter_container.add_theme_constant_override("separation", UITheme.SPACE_S)
	root.add_child(_filter_container)

	_filter_all_btn = Button.new()
	_filter_all_btn.text = "All Matches"
	_filter_all_btn.toggle_mode = true
	_filter_all_btn.button_pressed = true
	_filter_all_btn.custom_minimum_size = Vector2(140, UITheme.TOUCH_MIN)
	_filter_container.add_child(_filter_all_btn)

	_filter_wins_btn = Button.new()
	_filter_wins_btn.text = "Wins Only"
	_filter_wins_btn.toggle_mode = true
	_filter_wins_btn.custom_minimum_size = Vector2(120, UITheme.TOUCH_MIN)
	_filter_container.add_child(_filter_wins_btn)

	_filter_character_btn = OptionButton.new()
	_filter_character_btn.add_item("All Characters", 0)
	_filter_character_btn.add_item("Blitz", 1)
	_filter_character_btn.add_item("Titan", 2)
	_filter_character_btn.add_item("Phantom", 3)
	_filter_character_btn.custom_minimum_size = Vector2(160, UITheme.TOUCH_MIN)
	_filter_container.add_child(_filter_character_btn)

	# --- Match List (Scrollable) ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_match_list_container = VBoxContainer.new()
	_match_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_match_list_container.add_theme_constant_override("separation", UITheme.SPACE_XS)
	scroll.add_child(_match_list_container)

	# Loading state — shown until data resolves (prevents a flash of "empty").
	_loading_label = Label.new()
	_loading_label.text = "Loading match history…"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", UITheme.FONT_SUBHEADING)
	_loading_label.modulate = UITheme.TEXT_MUTED
	_loading_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_match_list_container.add_child(_loading_label)

	# Empty-state group (headline + hint + optional Play CTA). Content is set
	# contextually in _render_page() for true-empty vs filtered-empty.
	_empty_state = VBoxContainer.new()
	_empty_state.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty_state.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_state.add_theme_constant_override("separation", UITheme.SPACE_S)
	_empty_state.visible = false
	_match_list_container.add_child(_empty_state)

	_empty_headline = Label.new()
	_empty_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_headline.add_theme_font_size_override("font_size", UITheme.FONT_SUBHEADING)
	_empty_headline.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	_empty_state.add_child(_empty_headline)

	_empty_hint = Label.new()
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_empty_hint.add_theme_font_size_override("font_size", UITheme.FONT_CAPTION)
	_empty_hint.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_empty_state.add_child(_empty_hint)

	_empty_play_btn = Button.new()
	_empty_play_btn.text = "Play a Match"
	_empty_play_btn.custom_minimum_size = Vector2(200, UITheme.TOUCH_MIN)
	_empty_play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_empty_play_btn.pressed.connect(func(): play_pressed.emit())
	_empty_state.add_child(_empty_play_btn)

	# Kept for backwards compatibility with any external refs; superseded by
	# the richer _empty_state group above and left hidden.
	_no_data_label = Label.new()
	_no_data_label.visible = false
	_match_list_container.add_child(_no_data_label)

	# --- Pagination ---
	var pagination := HBoxContainer.new()
	pagination.alignment = BoxContainer.ALIGNMENT_CENTER
	pagination.add_theme_constant_override("separation", UITheme.SPACE_L)
	root.add_child(pagination)

	_prev_page_btn = Button.new()
	_prev_page_btn.text = "< Prev"
	_prev_page_btn.custom_minimum_size = Vector2(100, UITheme.TOUCH_MIN)
	pagination.add_child(_prev_page_btn)

	_page_label = Label.new()
	_page_label.text = "Page 1 / 1"
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.custom_minimum_size = Vector2(120, 0)
	pagination.add_child(_page_label)

	_next_page_btn = Button.new()
	_next_page_btn.text = "Next >"
	_next_page_btn.custom_minimum_size = Vector2(100, UITheme.TOUCH_MIN)
	pagination.add_child(_next_page_btn)

	# --- Detail Panel (overlay, initially hidden) ---
	_detail_panel = PanelContainer.new()
	_detail_panel.visible = false
	_detail_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_detail_panel.custom_minimum_size = Vector2(600, 400)
	add_child(_detail_panel)


## Connects all button signals
func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_filter_all_btn.pressed.connect(_on_filter_all)
	_filter_wins_btn.pressed.connect(_on_filter_wins)
	_filter_character_btn.item_selected.connect(_on_filter_character)
	_prev_page_btn.pressed.connect(_on_prev_page)
	_next_page_btn.pressed.connect(_on_next_page)

	# Initial keyboard/controller focus.
	_back_button.grab_focus.call_deferred()


## Loads all matches from ProgressStore
func _load_matches() -> void:
	if _progress_store == null:
		return
	_all_matches = _progress_store.get_match_history(200)


## Applies the current filter to the match list
func _apply_filter() -> void:
	match _filter_mode:
		"all":
			_filtered_matches = _all_matches.duplicate()
		"wins":
			_filtered_matches = _all_matches.filter(func(m): return m.get("placement", 99) == 1)
		"character":
			if _filter_character.is_empty():
				_filtered_matches = _all_matches.duplicate()
			else:
				_filtered_matches = _all_matches.filter(
					func(m): return m.get("character_name", "") == _filter_character)

	_current_page = 0
	_render_page()


## Shows the contextual empty state: distinguishes "never played" (offer to play)
## from "filter hides everything" (offer to clear the filter).
func _show_empty_state() -> void:
	_empty_state.visible = true

	if _all_matches.is_empty():
		# True empty — the player has no history at all.
		_empty_headline.text = "No matches yet"
		_empty_hint.text = "Play your first match to start building your history — placements, kills, and win rate all tracked here."
		_empty_play_btn.visible = true
	else:
		# Filtered empty — data exists, the active filter just excludes it all.
		var filter_desc := "this filter"
		match _filter_mode:
			"wins":
				filter_desc = "the Wins filter"
			"character":
				filter_desc = "this character"
		_empty_headline.text = "No matches match %s" % filter_desc
		_empty_hint.text = "Try switching back to All Matches to see your full history."
		_empty_play_btn.visible = false


## Renders the current page of matches
func _render_page() -> void:
	# Still loading — don't render list or empty state yet.
	if not _data_loaded:
		if _loading_label != null:
			_loading_label.visible = true
		_empty_state.visible = false
		return

	# Clear existing match entries, preserving the persistent state nodes.
	for child in _match_list_container.get_children():
		if child != _no_data_label and child != _empty_state and child != _loading_label:
			child.queue_free()

	if _loading_label != null:
		_loading_label.visible = false

	if _filtered_matches.size() == 0:
		_show_empty_state()
		_page_label.text = "Page 0 / 0"
		_prev_page_btn.disabled = true
		_next_page_btn.disabled = true
		return

	_empty_state.visible = false

	var total_pages: int = ceili(float(_filtered_matches.size()) / float(MATCHES_PER_PAGE))
	_current_page = clampi(_current_page, 0, total_pages - 1)

	var start_idx: int = _current_page * MATCHES_PER_PAGE
	var end_idx: int = mini(start_idx + MATCHES_PER_PAGE, _filtered_matches.size())

	for i in range(start_idx, end_idx):
		var match_entry := _create_match_entry(_filtered_matches[i], i + 1)
		_match_list_container.add_child(match_entry)

	# Update pagination
	_page_label.text = "Page %d / %d" % [_current_page + 1, total_pages]
	_prev_page_btn.disabled = (_current_page == 0)
	_next_page_btn.disabled = (_current_page >= total_pages - 1)


## Creates a single match entry row
func _create_match_entry(match_data: Dictionary, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UITheme.SPACE_L)
	panel.add_child(hbox)

	var placement: int = match_data.get("placement", 0)
	var is_win: bool = placement == 1

	# Placement badge
	var placement_label := Label.new()
	placement_label.text = "#%d" % placement
	placement_label.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
	placement_label.custom_minimum_size = Vector2(60, 0)
	placement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placement_label.modulate = UITheme.placement_color(placement)
	hbox.add_child(placement_label)

	# Win/Loss indicator
	var result_label := Label.new()
	result_label.text = "VICTORY" if is_win else "ELIMINATED"
	result_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	result_label.custom_minimum_size = Vector2(120, 0)
	result_label.modulate = UITheme.SUCCESS if is_win else UITheme.DANGER
	hbox.add_child(result_label)

	# Character
	var char_label := Label.new()
	char_label.text = match_data.get("character_name", "Unknown")
	char_label.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(char_label)

	# Kills
	var kills_label := Label.new()
	kills_label.text = "%d kills" % match_data.get("kills", 0)
	kills_label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(kills_label)

	# Damage
	var dmg_label := Label.new()
	dmg_label.text = "%d dmg" % int(match_data.get("damage_dealt", 0.0))
	dmg_label.custom_minimum_size = Vector2(90, 0)
	hbox.add_child(dmg_label)

	# Survival time
	var time_secs: int = match_data.get("survival_time_seconds", 0)
	var time_label := Label.new()
	time_label.text = "%d:%02d" % [time_secs / 60, time_secs % 60]
	time_label.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(time_label)

	# Difficulty
	var diff_label := Label.new()
	diff_label.text = match_data.get("bot_difficulty", "MEDIUM")
	diff_label.custom_minimum_size = Vector2(80, 0)
	diff_label.add_theme_font_size_override("font_size", UITheme.FONT_CAPTION)
	match diff_label.text:
		"EASY":
			diff_label.modulate = UITheme.SUCCESS
		"MEDIUM":
			diff_label.modulate = UITheme.WARNING
		"HARD":
			diff_label.modulate = UITheme.DANGER
	hbox.add_child(diff_label)

	# Date
	var date_label := Label.new()
	var timestamp: String = match_data.get("timestamp", "")
	if timestamp.length() >= 10:
		date_label.text = timestamp.substr(0, 10)
	else:
		date_label.text = "Unknown"
	date_label.add_theme_font_size_override("font_size", UITheme.FONT_MICRO)
	date_label.modulate = UITheme.TEXT_MUTED
	hbox.add_child(date_label)

	# Make entire row clickable
	var click_btn := Button.new()
	click_btn.flat = true
	click_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_btn.modulate = Color(1, 1, 1, 0)  # Invisible overlay
	click_btn.pressed.connect(func(): _on_match_clicked(match_data))
	panel.add_child(click_btn)

	return panel


## Renders the summary statistics bar
func _render_summary_stats() -> void:
	# Hide the whole summary bar when there's no history, so a row of zeros
	# doesn't compete with the empty-state message.
	if _all_matches.size() == 0:
		if _stats_summary != null:
			_stats_summary.visible = false
		return

	if _stats_summary != null:
		_stats_summary.visible = true

	var total: int = _all_matches.size()
	var wins: int = 0
	var total_kills: int = 0
	var best_streak: int = 0
	var total_placement: int = 0

	for m in _all_matches:
		if m.get("placement", 99) == 1:
			wins += 1
		total_kills += m.get("kills", 0)
		total_placement += m.get("placement", 50)

	var win_rate: float = float(wins) / float(total) * 100.0
	var avg_kills: float = float(total_kills) / float(total)
	var avg_placement: float = float(total_placement) / float(total)

	# Update labels via stats_summary panel
	var stats_panel := _stats_summary.get_child(0)
	if stats_panel == null:
		return
	var stats_hbox := stats_panel.get_child(0)
	if stats_hbox == null:
		return

	var values: Array = [
		str(total),
		"%.1f%%" % win_rate,
		"%.1f" % avg_kills,
		str(best_streak),
		"#%.1f" % avg_placement
	]

	for i in range(mini(values.size(), stats_hbox.get_child_count())):
		var stat_vbox := stats_hbox.get_child(i)
		if stat_vbox.get_child_count() > 0:
			var value_label: Label = stat_vbox.get_child(0)
			value_label.text = values[i]


## Signal handlers

func _on_back_pressed() -> void:
	back_pressed.emit()


func _on_filter_all() -> void:
	_filter_mode = "all"
	_filter_all_btn.button_pressed = true
	_filter_wins_btn.button_pressed = false
	_apply_filter()


func _on_filter_wins() -> void:
	_filter_mode = "wins"
	_filter_all_btn.button_pressed = false
	_filter_wins_btn.button_pressed = true
	_apply_filter()


func _on_filter_character(index: int) -> void:
	match index:
		0: _filter_character = ""
		1: _filter_character = "BLITZ"
		2: _filter_character = "TITAN"
		3: _filter_character = "PHANTOM"
	
	if _filter_character.is_empty():
		_filter_mode = "all"
	else:
		_filter_mode = "character"
	_apply_filter()


func _on_prev_page() -> void:
	if _current_page > 0:
		_current_page -= 1
		_render_page()


func _on_next_page() -> void:
	var total_pages: int = ceili(float(_filtered_matches.size()) / float(MATCHES_PER_PAGE))
	if _current_page < total_pages - 1:
		_current_page += 1
		_render_page()


func _on_match_clicked(match_data: Dictionary) -> void:
	match_selected.emit(match_data)
	_show_detail_panel(match_data)


## Shows a detailed view of a specific match
func _show_detail_panel(match_data: Dictionary) -> void:
	# Clear existing detail content
	for child in _detail_panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_S)
	_detail_panel.add_child(vbox)

	var placement: int = match_data.get("placement", 0)
	var is_win: bool = placement == 1

	# Title
	var title := Label.new()
	title.text = "VICTORY ROYALE!" if is_win else "Match Details"
	title.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = UITheme.GOLD if is_win else UITheme.TEXT_PRIMARY
	vbox.add_child(title)

	# Stats grid
	var stats: Array = [
		["Placement", "#%d / %d" % [placement, match_data.get("total_participants", 50)]],
		["Eliminations", str(match_data.get("kills", 0))],
		["Damage Dealt", str(int(match_data.get("damage_dealt", 0.0)))],
		["Survival Time", "%d:%02d" % [match_data.get("survival_time_seconds", 0) / 60, match_data.get("survival_time_seconds", 0) % 60]],
		["Character", match_data.get("character_name", "Unknown")],
		["Difficulty", match_data.get("bot_difficulty", "MEDIUM")],
		["Bot Count", str(match_data.get("bot_count", 50))],
		["Date", match_data.get("timestamp", "Unknown").substr(0, 10) if match_data.get("timestamp", "").length() >= 10 else "Unknown"],
	]

	for stat in stats:
		var row := HBoxContainer.new()
		vbox.add_child(row)

		var key_label := Label.new()
		key_label.text = stat[0] + ":"
		key_label.custom_minimum_size = Vector2(150, 0)
		key_label.modulate = UITheme.TEXT_MUTED
		row.add_child(key_label)

		var val_label := Label.new()
		val_label.text = stat[1]
		val_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(val_label)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 44)
	close_btn.pressed.connect(func(): _detail_panel.visible = false)
	vbox.add_child(close_btn)

	_detail_panel.visible = true
	_detail_visible = true
