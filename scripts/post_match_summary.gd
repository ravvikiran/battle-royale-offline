## Post-match summary overlay that shows XP breakdown, level progress,
## achievement unlocks, challenge completions, and battle pass progress.
## Animates each section sequentially for maximum impact.
## Displayed on the victory/defeat screen before the action buttons.
class_name PostMatchSummary
extends Control


## Emitted when the summary animation is complete and player can proceed
signal summary_complete()


## UI references
var _xp_breakdown_container: VBoxContainer = null
var _total_xp_label: Label = null
var _level_progress_bar: ProgressBar = null
var _level_label: Label = null
var _achievement_list: VBoxContainer = null
var _challenge_list: VBoxContainer = null
var _bp_progress: ProgressBar = null
var _bp_label: Label = null
var _skip_button: Button = null

## Animation state
var _anim_queue: Array = []
var _current_anim_index: int = 0
var _anim_timer: float = 0.0
var _is_animating: bool = false
var _total_xp_displayed: int = 0
var _target_xp: int = 0

## Data to display
var _xp_breakdown: Dictionary = {}
var _new_achievements: Array = []
var _completed_challenges: Array = []
var _level_before: int = 1
var _level_after: int = 1
var _bp_tier_before: int = 0
var _bp_tier_after: int = 0

## Timings
const LINE_DELAY: float = 0.5
const XP_COUNT_SPEED: float = 200.0  # XP per second for counting animation
const BAR_FILL_SPEED: float = 2.0  # Progress bar fill speed


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	if _is_animating:
		_process_animation(delta)


## Sets up the summary with post-match data
func setup(data: Dictionary) -> void:
	_xp_breakdown = data.get("xp_breakdown", {})
	_new_achievements = data.get("achievements_unlocked", [])
	_completed_challenges = data.get("challenges_completed", [])
	_level_before = data.get("level_before", 1)
	_level_after = data.get("level_after", 1)
	_bp_tier_before = data.get("bp_tier_before", 0)
	_bp_tier_after = data.get("bp_tier_after", 0)

	# Calculate total XP
	_target_xp = 0
	for val in _xp_breakdown.values():
		_target_xp += val

	_build_animation_queue()
	_start_animation()


## Builds the UI layout
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", UITheme.SPACE_S)
	add_child(root)

	# Title
	var title := Label.new()
	title.text = "MATCH SUMMARY"
	title.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = UITheme.GOLD
	root.add_child(title)

	# XP Breakdown
	var xp_header := Label.new()
	xp_header.text = "XP EARNED"
	xp_header.add_theme_font_size_override("font_size", UITheme.FONT_SUBHEADING)
	xp_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(xp_header)

	_xp_breakdown_container = VBoxContainer.new()
	_xp_breakdown_container.add_theme_constant_override("separation", UITheme.SPACE_XXS)
	root.add_child(_xp_breakdown_container)

	# Total XP
	_total_xp_label = Label.new()
	_total_xp_label.text = "Total: 0 XP"
	_total_xp_label.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
	_total_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_xp_label.modulate = UITheme.ACCENT_XP
	root.add_child(_total_xp_label)

	# Level progress
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", UITheme.SPACE_S)
	level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(level_row)

	_level_label = Label.new()
	_level_label.text = "Level 1"
	_level_label.add_theme_font_size_override("font_size", UITheme.FONT_SUBHEADING)
	level_row.add_child(_level_label)

	_level_progress_bar = ProgressBar.new()
	_level_progress_bar.min_value = 0.0
	_level_progress_bar.max_value = 1.0
	_level_progress_bar.value = 0.0
	_level_progress_bar.show_percentage = false
	_level_progress_bar.custom_minimum_size = Vector2(200, UITheme.SPACE_L)
	level_row.add_child(_level_progress_bar)

	# Achievements unlocked
	_achievement_list = VBoxContainer.new()
	_achievement_list.add_theme_constant_override("separation", UITheme.SPACE_XXS)
	root.add_child(_achievement_list)

	# Challenges completed
	_challenge_list = VBoxContainer.new()
	_challenge_list.add_theme_constant_override("separation", UITheme.SPACE_XXS)
	root.add_child(_challenge_list)

	# Battle Pass progress
	var bp_row := HBoxContainer.new()
	bp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bp_row.add_theme_constant_override("separation", UITheme.SPACE_S)
	root.add_child(bp_row)

	_bp_label = Label.new()
	_bp_label.text = "Battle Pass"
	_bp_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	_bp_label.modulate = UITheme.ACCENT_TEAL
	bp_row.add_child(_bp_label)

	_bp_progress = ProgressBar.new()
	_bp_progress.min_value = 0.0
	_bp_progress.max_value = 50.0
	_bp_progress.value = 0.0
	_bp_progress.show_percentage = false
	_bp_progress.custom_minimum_size = Vector2(200, UITheme.SPACE_M)
	bp_row.add_child(_bp_progress)

	# Skip button
	_skip_button = Button.new()
	_skip_button.text = "Continue >"
	_skip_button.custom_minimum_size = Vector2(150, UITheme.TOUCH_MIN)
	_skip_button.pressed.connect(_skip_animation)
	_skip_button.visible = false
	root.add_child(_skip_button)


## Builds the animation queue
func _build_animation_queue() -> void:
	_anim_queue.clear()

	# Each XP source appears as a line
	var source_names: Dictionary = {
		"kills": "Eliminations",
		"placement": "Placement Bonus",
		"win_bonus": "Victory Bonus",
		"survival": "Survival Time",
		"first_match_bonus": "First Match of Day",
	}

	for key in _xp_breakdown.keys():
		var name: String = source_names.get(key, key.capitalize())
		_anim_queue.append({
			"type": "xp_line",
			"name": name,
			"amount": _xp_breakdown[key],
			"delay": LINE_DELAY
		})

	# Level up animation
	if _level_after > _level_before:
		_anim_queue.append({
			"type": "level_up",
			"from": _level_before,
			"to": _level_after,
			"delay": 0.8
		})

	# Achievement unlocks
	for ach_id in _new_achievements:
		_anim_queue.append({
			"type": "achievement",
			"id": ach_id,
			"delay": LINE_DELAY
		})

	# Challenge completions
	for challenge in _completed_challenges:
		_anim_queue.append({
			"type": "challenge",
			"data": challenge,
			"delay": LINE_DELAY
		})

	# Battle pass progress
	if _bp_tier_after > _bp_tier_before:
		_anim_queue.append({
			"type": "bp_tier",
			"from": _bp_tier_before,
			"to": _bp_tier_after,
			"delay": 0.8
		})

	# Final: show continue button
	_anim_queue.append({
		"type": "show_continue",
		"delay": 0.5
	})


## Starts the animation sequence
func _start_animation() -> void:
	_is_animating = true
	_current_anim_index = 0
	_anim_timer = 0.3  # Initial delay
	_total_xp_displayed = 0


## Processes the animation each frame
func _process_animation(delta: float) -> void:
	_anim_timer -= delta
	if _anim_timer > 0.0:
		return

	if _current_anim_index >= _anim_queue.size():
		_is_animating = false
		return

	var anim: Dictionary = _anim_queue[_current_anim_index]
	_play_anim_step(anim)
	_anim_timer = anim.get("delay", LINE_DELAY)
	_current_anim_index += 1


## Plays a single animation step
func _play_anim_step(anim: Dictionary) -> void:
	match anim.get("type", ""):
		"xp_line":
			var row := HBoxContainer.new()
			_xp_breakdown_container.add_child(row)
			
			var name_label := Label.new()
			name_label.text = anim.get("name", "")
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			row.add_child(name_label)
			
			var xp_label := Label.new()
			xp_label.text = "+%d XP" % anim.get("amount", 0)
			xp_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			xp_label.modulate = UITheme.ACCENT_XP
			row.add_child(xp_label)
			
			_total_xp_displayed += anim.get("amount", 0)
			_total_xp_label.text = "Total: %d XP" % _total_xp_displayed

		"level_up":
			_level_label.text = "Level %d → %d!" % [anim.get("from", 1), anim.get("to", 1)]
			_level_label.modulate = UITheme.ACCENT
			_level_progress_bar.value = 0.2  # Show some progress into new level

		"achievement":
			var label := Label.new()
			label.text = "★ Achievement Unlocked: " + anim.get("id", "").replace("_", " ").capitalize()
			label.add_theme_font_size_override("font_size", UITheme.FONT_CAPTION)
			label.modulate = UITheme.GOLD
			_achievement_list.add_child(label)

		"challenge":
			var challenge: Dictionary = anim.get("data", {})
			var label := Label.new()
			label.text = "✓ Challenge: " + challenge.get("description", "Completed")
			label.add_theme_font_size_override("font_size", UITheme.FONT_CAPTION)
			label.modulate = UITheme.SUCCESS
			_challenge_list.add_child(label)

		"bp_tier":
			_bp_label.text = "Battle Pass: Tier %d → %d" % [anim.get("from", 0), anim.get("to", 0)]
			_bp_progress.value = float(anim.get("to", 0))

		"show_continue":
			_skip_button.visible = true


## Skips the remaining animation and shows everything immediately
func _skip_animation() -> void:
	_is_animating = false

	# Show all remaining items instantly
	while _current_anim_index < _anim_queue.size():
		_play_anim_step(_anim_queue[_current_anim_index])
		_current_anim_index += 1

	_skip_button.visible = false
	summary_complete.emit()
