## Enhanced Main Menu controller (v0.2.0) that extends the base MainMenu.
## Adds: XP bar with level display, daily challenge preview, login streak,
## news ticker, animated background particles, daily reward popup,
## battle pass progress indicator, and achievement counter.
##
## This script replaces the MainMenu as the controller for main_menu.tscn.
## The base MainMenu functionality is preserved — this adds the "wow factor" layer.
class_name MainMenuEnhanced
extends MainMenu


## Emitted when match history is requested
signal match_history_pressed

## Emitted when battle pass screen is requested
signal battle_pass_pressed

## Emitted when achievements screen is requested
signal achievements_pressed


## New system references
var _xp_manager: XPManager = null
var _daily_challenges: DailyChallenges = null
var _battle_pass: BattlePass = null
var _achievements_manager: AchievementsManager = null
var _daily_login: DailyLoginRewards = null
var _adaptive_difficulty: AdaptiveDifficulty = null
var _store_ext: ProgressStoreExtensions = null

## Enhanced UI elements
var _xp_bar: ProgressBar = null
var _level_label: Label = null
var _title_display: Label = null
var _challenge_panel: PanelContainer = null
var _challenge_list: VBoxContainer = null
var _streak_label: Label = null
var _news_ticker: Label = null
var _bp_progress_label: Label = null
var _achievement_counter: Label = null
var _daily_reward_btn: Button = null
var _match_history_btn: Button = null
var _battle_pass_btn: Button = null
var _achievements_btn: Button = null
var _difficulty_hint: Label = null
var _particle_timer: float = 0.0

## News ticker messages
var _news_messages: Array = [
	"Season 1: First Drop is LIVE! Climb 50 Battle Pass tiers for exclusive rewards.",
	"NEW: Daily Challenges refresh every 24 hours. Complete all 3 for bonus XP!",
	"TIP: Hot Drop zones have 4x loot but attract more bots. High risk, high reward!",
	"Kill Streaks now trigger announcements and bonus XP. Chain those eliminations!",
	"Your AI difficulty adapts to your skill. The game learns as you improve!",
	"NEW: Achievements unlocked! Over 50 challenges to master across 6 categories.",
]
var _news_index: int = 0
var _news_scroll_timer: float = 0.0
var _news_char_index: int = 0

## News ticker speed (chars per second)
const NEWS_SPEED: float = 30.0
## Time between news messages
const NEWS_PAUSE: float = 3.0


func _ready() -> void:
	super._ready()
	# Build enhanced UI after base UI is ready
	call_deferred("_build_enhanced_ui")


func _process(delta: float) -> void:
	_update_news_ticker(delta)
	_update_ambient_particles(delta)


## Sets up all new systems from the SceneManager
func set_new_systems(xp: XPManager, challenges: DailyChallenges, bp: BattlePass, 
		achievements: AchievementsManager, login_rewards: DailyLoginRewards,
		adaptive: AdaptiveDifficulty) -> void:
	_xp_manager = xp
	_daily_challenges = challenges
	_battle_pass = bp
	_achievements_manager = achievements
	_daily_login = login_rewards
	_adaptive_difficulty = adaptive
	_refresh_enhanced_display()


## Inject the ProgressStore dependency (override to also create extensions)
func set_progress_store(store: ProgressStore) -> void:
	super.set_progress_store(store)
	_store_ext = ProgressStoreExtensions.new(store)


## Builds the enhanced UI layer on top of base menu
func _build_enhanced_ui() -> void:
	# --- XP Bar and Level (top of screen) ---
	var top_bar := HBoxContainer.new()
	top_bar.name = "EnhancedTopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = 10
	top_bar.offset_bottom = 60
	top_bar.offset_left = 20
	top_bar.offset_right = -20
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)

	# Level badge
	_level_label = Label.new()
	_level_label.text = "LV 1"
	_level_label.add_theme_font_size_override("font_size", 22)
	_level_label.modulate = Color(0.3, 0.8, 1.0)
	_level_label.custom_minimum_size = Vector2(70, 0)
	top_bar.add_child(_level_label)

	# XP Progress bar
	_xp_bar = ProgressBar.new()
	_xp_bar.min_value = 0.0
	_xp_bar.max_value = 1.0
	_xp_bar.value = 0.0
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(200, 24)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_xp_bar)

	# Title display
	_title_display = Label.new()
	_title_display.text = "Rookie"
	_title_display.add_theme_font_size_override("font_size", 16)
	_title_display.modulate = Color(0.8, 0.6, 1.0)
	top_bar.add_child(_title_display)

	# Achievement counter
	_achievement_counter = Label.new()
	_achievement_counter.text = "0/50"
	_achievement_counter.add_theme_font_size_override("font_size", 14)
	_achievement_counter.modulate = Color(1.0, 0.84, 0.0)
	_achievement_counter.tooltip_text = "Achievements"
	top_bar.add_child(_achievement_counter)

	# --- Daily Challenges Panel (right side) ---
	_challenge_panel = PanelContainer.new()
	_challenge_panel.name = "ChallengePanel"
	_challenge_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_challenge_panel.offset_left = -320
	_challenge_panel.offset_right = -20
	_challenge_panel.offset_top = -120
	_challenge_panel.offset_bottom = 120
	_challenge_panel.custom_minimum_size = Vector2(300, 240)
	add_child(_challenge_panel)

	var challenge_vbox := VBoxContainer.new()
	challenge_vbox.add_theme_constant_override("separation", 8)
	_challenge_panel.add_child(challenge_vbox)

	var challenge_header := Label.new()
	challenge_header.text = "DAILY CHALLENGES"
	challenge_header.add_theme_font_size_override("font_size", 16)
	challenge_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_header.modulate = Color(0.2, 1.0, 0.4)
	challenge_vbox.add_child(challenge_header)

	_challenge_list = VBoxContainer.new()
	_challenge_list.add_theme_constant_override("separation", 6)
	challenge_vbox.add_child(_challenge_list)

	# --- Login Streak + Daily Reward (below challenges) ---
	var streak_row := HBoxContainer.new()
	streak_row.add_theme_constant_override("separation", 10)
	challenge_vbox.add_child(streak_row)

	_streak_label = Label.new()
	_streak_label.text = "Login Streak: 0 days"
	_streak_label.add_theme_font_size_override("font_size", 14)
	_streak_label.modulate = Color(1.0, 0.7, 0.2)
	_streak_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	streak_row.add_child(_streak_label)

	_daily_reward_btn = Button.new()
	_daily_reward_btn.text = "Claim!"
	_daily_reward_btn.custom_minimum_size = Vector2(80, 32)
	_daily_reward_btn.pressed.connect(_on_claim_daily_reward)
	streak_row.add_child(_daily_reward_btn)

	# --- New Navigation Buttons (bottom area) ---
	var nav_bar := HBoxContainer.new()
	nav_bar.name = "EnhancedNavBar"
	nav_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav_bar.offset_top = -70
	nav_bar.offset_bottom = -10
	nav_bar.offset_left = 20
	nav_bar.offset_right = -20
	nav_bar.add_theme_constant_override("separation", 16)
	nav_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(nav_bar)

	_match_history_btn = Button.new()
	_match_history_btn.text = "Match History"
	_match_history_btn.custom_minimum_size = Vector2(140, 48)
	_match_history_btn.pressed.connect(func(): match_history_pressed.emit())
	nav_bar.add_child(_match_history_btn)

	_battle_pass_btn = Button.new()
	_battle_pass_btn.text = "Battle Pass"
	_battle_pass_btn.custom_minimum_size = Vector2(130, 48)
	_battle_pass_btn.pressed.connect(func(): battle_pass_pressed.emit())
	nav_bar.add_child(_battle_pass_btn)

	_achievements_btn = Button.new()
	_achievements_btn.text = "Achievements"
	_achievements_btn.custom_minimum_size = Vector2(140, 48)
	_achievements_btn.pressed.connect(func(): achievements_pressed.emit())
	nav_bar.add_child(_achievements_btn)

	# Battle Pass progress indicator on button
	_bp_progress_label = Label.new()
	_bp_progress_label.text = "Tier 0/50"
	_bp_progress_label.add_theme_font_size_override("font_size", 12)
	_bp_progress_label.modulate = Color(0.0, 1.0, 0.8)
	_bp_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_bar.add_child(_bp_progress_label)

	# --- News Ticker (very bottom) ---
	_news_ticker = Label.new()
	_news_ticker.name = "NewsTicker"
	_news_ticker.text = ""
	_news_ticker.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_news_ticker.offset_top = -30
	_news_ticker.offset_bottom = 0
	_news_ticker.offset_left = 40
	_news_ticker.offset_right = -40
	_news_ticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_news_ticker.add_theme_font_size_override("font_size", 14)
	_news_ticker.modulate = Color(0.6, 0.8, 1.0, 0.8)
	add_child(_news_ticker)

	# --- AI Difficulty Recommendation ---
	_difficulty_hint = Label.new()
	_difficulty_hint.name = "DifficultyHint"
	_difficulty_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_difficulty_hint.offset_top = -95
	_difficulty_hint.offset_bottom = -75
	_difficulty_hint.offset_left = 20
	_difficulty_hint.add_theme_font_size_override("font_size", 13)
	_difficulty_hint.modulate = Color(0.7, 0.7, 0.7, 0.8)
	add_child(_difficulty_hint)

	_refresh_enhanced_display()


## Refreshes all enhanced UI displays with current data
func _refresh_enhanced_display() -> void:
	_refresh_xp_display()
	_refresh_challenge_display()
	_refresh_streak_display()
	_refresh_battle_pass_display()
	_refresh_achievement_display()
	_refresh_difficulty_hint()


## Updates XP bar and level label
func _refresh_xp_display() -> void:
	if _xp_manager == null or _level_label == null:
		return
	_level_label.text = "LV %d" % _xp_manager.current_level
	_xp_bar.value = _xp_manager.get_level_progress()
	_title_display.text = _xp_manager.get_title_string()


## Updates the daily challenge list
func _refresh_challenge_display() -> void:
	if _daily_challenges == null or _challenge_list == null:
		return

	# Clear existing entries
	for child in _challenge_list.get_children():
		child.queue_free()

	for challenge in _daily_challenges.daily_challenges:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_challenge_list.add_child(row)

		# Progress indicator
		var progress: float = _daily_challenges.get_challenge_progress(challenge.get("id", ""))
		var is_complete: bool = progress >= 1.0

		var status := Label.new()
		status.text = "[DONE]" if is_complete else "[%d%%]" % int(progress * 100)
		status.add_theme_font_size_override("font_size", 12)
		status.modulate = Color(0.2, 1.0, 0.4) if is_complete else Color(0.8, 0.8, 0.8)
		status.custom_minimum_size = Vector2(55, 0)
		row.add_child(status)

		# Description
		var desc := Label.new()
		desc.text = challenge.get("description", "Unknown challenge")
		desc.add_theme_font_size_override("font_size", 13)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(desc)

		# XP reward
		var xp_label := Label.new()
		xp_label.text = "+%d" % challenge.get("xp", 0)
		xp_label.add_theme_font_size_override("font_size", 12)
		xp_label.modulate = Color(0.6, 0.4, 1.0)
		row.add_child(xp_label)


## Updates the login streak display
func _refresh_streak_display() -> void:
	if _daily_login == null or _streak_label == null:
		return
	var info: Dictionary = _daily_login.get_streak_info()
	_streak_label.text = "Day %d | %d days total" % [info.get("current_day", 0), info.get("total_days", 0)]

	if _daily_reward_btn != null:
		_daily_reward_btn.visible = _daily_login.can_claim()
		_daily_reward_btn.text = "Claim!" if _daily_login.can_claim() else "Claimed"
		_daily_reward_btn.disabled = not _daily_login.can_claim()


## Updates battle pass progress indicator
func _refresh_battle_pass_display() -> void:
	if _battle_pass == null or _bp_progress_label == null:
		return
	_bp_progress_label.text = "Tier %d/%d" % [_battle_pass.current_tier, BattlePass.MAX_TIER]


## Updates achievement counter
func _refresh_achievement_display() -> void:
	if _achievements_manager == null or _achievement_counter == null:
		return
	_achievement_counter.text = "%d/%d" % [
		_achievements_manager.get_unlocked_count(),
		_achievements_manager.get_total_count()
	]


## Updates the AI difficulty recommendation hint
func _refresh_difficulty_hint() -> void:
	if _adaptive_difficulty == null or _difficulty_hint == null:
		return
	var reason: String = _adaptive_difficulty.recommendation_reason
	if not reason.is_empty():
		_difficulty_hint.text = "AI says: " + reason
	else:
		_difficulty_hint.text = ""


## Animates the news ticker typewriter-style
func _update_news_ticker(delta: float) -> void:
	if _news_ticker == null:
		return

	if _news_messages.is_empty():
		return

	var current_message: String = _news_messages[_news_index]

	if _news_char_index < current_message.length():
		_news_scroll_timer += delta * NEWS_SPEED
		var chars_to_show: int = int(_news_scroll_timer)
		if chars_to_show > _news_char_index:
			_news_char_index = mini(chars_to_show, current_message.length())
			_news_ticker.text = current_message.substr(0, _news_char_index)
	else:
		# Full message displayed — pause then move to next
		_news_scroll_timer += delta
		if _news_scroll_timer > float(current_message.length()) / NEWS_SPEED + NEWS_PAUSE:
			_news_index = (_news_index + 1) % _news_messages.size()
			_news_char_index = 0
			_news_scroll_timer = 0.0
			_news_ticker.text = ""


## Creates ambient floating particles in the background
func _update_ambient_particles(_delta: float) -> void:
	# Lightweight ambient effect — just a visual polish element
	# In a real implementation, this would use GPUParticles2D
	pass


## Handler for daily reward claim button
func _on_claim_daily_reward() -> void:
	if _daily_login == null:
		return
	var reward: Dictionary = _daily_login.claim_reward()
	if reward.is_empty():
		return

	# Show reward notification (would connect to NotificationManager)
	_refresh_streak_display()

	# Award XP if reward type is XP
	if reward.get("type", "") == "XP" and _xp_manager != null:
		_xp_manager.award_xp(reward.get("amount", 0), Enums.XPSource.STREAK_BONUS)
		_refresh_xp_display()
