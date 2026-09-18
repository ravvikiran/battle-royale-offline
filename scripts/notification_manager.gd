## Manages in-game notifications, toasts, and popup announcements.
## Handles achievement unlocks, level-ups, challenge completions, streak
## announcements, and general informational messages.
## Queues notifications to prevent overlap and provides smooth animations.
class_name NotificationManager
extends CanvasLayer


## Emitted when a notification is displayed
signal notification_shown(notification_data: Dictionary)

## Emitted when all queued notifications have been shown
signal queue_empty()


## Queue of pending notifications
var _notification_queue: Array = []

## Currently displaying notification
var _current_notification: Dictionary = {}

## Whether a notification is currently being displayed
var _is_showing: bool = false

## Timer for auto-dismiss
var _display_timer: float = 0.0

## Animation progress (0.0 to 1.0)
var _anim_progress: float = 0.0

## Animation state
var _anim_state: String = "idle"  # "slide_in", "hold", "slide_out", "idle"

## UI containers
var _toast_container: PanelContainer = null
var _toast_label: Label = null
var _toast_subtitle: Label = null
var _toast_icon: TextureRect = null
var _achievement_popup: PanelContainer = null
var _level_up_popup: PanelContainer = null
var _streak_label: Label = null

## Banner stack for persistent indicators (kill streak, daily challenge progress)
var _banner_stack: VBoxContainer = null


## Notification display durations by type
const DURATIONS: Dictionary = {
	"toast": 3.0,
	"achievement": 5.0,
	"level_up": 4.0,
	"challenge": 3.5,
	"streak": 2.0,
	"xp_gain": 2.5,
	"battle_pass": 4.0,
	"hot_drop": 3.0,
}

## Animation speeds
const SLIDE_IN_SPEED: float = 4.0
const SLIDE_OUT_SPEED: float = 6.0

## Maximum queued notifications before dropping oldest
const MAX_QUEUE_SIZE: int = 10

## Notification priority levels (higher = shown first)
const PRIORITY: Dictionary = {
	"level_up": 100,
	"achievement": 90,
	"battle_pass": 85,
	"streak": 80,
	"challenge": 70,
	"xp_gain": 50,
	"hot_drop": 60,
	"toast": 30,
}


func _ready() -> void:
	layer = 100  # Always on top
	_build_ui()


func _process(delta: float) -> void:
	match _anim_state:
		"slide_in":
			_anim_progress += delta * SLIDE_IN_SPEED
			if _anim_progress >= 1.0:
				_anim_progress = 1.0
				_anim_state = "hold"
			_update_animation()
		"hold":
			_display_timer -= delta
			if _display_timer <= 0.0:
				_anim_state = "slide_out"
				_anim_progress = 1.0
		"slide_out":
			_anim_progress -= delta * SLIDE_OUT_SPEED
			if _anim_progress <= 0.0:
				_anim_progress = 0.0
				_anim_state = "idle"
				_hide_current()
				_show_next()
			_update_animation()
		"idle":
			if not _notification_queue.is_empty() and not _is_showing:
				_show_next()


## Builds notification UI elements
func _build_ui() -> void:
	# Toast notification (top-center slide down)
	_toast_container = PanelContainer.new()
	_toast_container.visible = false
	_toast_container.custom_minimum_size = Vector2(400, 80)
	_toast_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_container.position = Vector2(-200, -100)  # Start off-screen
	add_child(_toast_container)

	var toast_vbox := VBoxContainer.new()
	toast_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	toast_vbox.add_theme_constant_override("separation", 4)
	_toast_container.add_child(toast_vbox)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", UITheme.FONT_SUBHEADING)
	toast_vbox.add_child(_toast_label)

	_toast_subtitle = Label.new()
	_toast_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_subtitle.add_theme_font_size_override("font_size", UITheme.FONT_CAPTION)
	_toast_subtitle.modulate = UITheme.TEXT_SECONDARY
	toast_vbox.add_child(_toast_subtitle)

	# Streak announcement (center screen, large text)
	_streak_label = Label.new()
	_streak_label.visible = false
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_streak_label.set_anchors_preset(Control.PRESET_CENTER)
	_streak_label.add_theme_font_size_override("font_size", UITheme.FONT_DISPLAY)
	_streak_label.modulate = UITheme.GOLD
	add_child(_streak_label)

	# Banner stack (left side, for persistent indicators)
	_banner_stack = VBoxContainer.new()
	_banner_stack.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_banner_stack.position = Vector2(20, -100)
	_banner_stack.add_theme_constant_override("separation", 8)
	add_child(_banner_stack)


## Queues a toast notification
func show_toast(title: String, subtitle: String = "", duration: float = -1.0) -> void:
	_queue_notification({
		"type": "toast",
		"title": title,
		"subtitle": subtitle,
		"duration": duration if duration > 0.0 else DURATIONS["toast"]
	})


## Shows an achievement unlock notification
func show_achievement_unlock(achievement_data: Dictionary) -> void:
	var title: String = "Achievement Unlocked!"
	var name: String = achievement_data.get("name", "Unknown")
	var xp: int = achievement_data.get("xp_reward", 0)
	_queue_notification({
		"type": "achievement",
		"title": title,
		"subtitle": "%s (+%d XP)" % [name, xp],
		"duration": DURATIONS["achievement"],
		"color": UITheme.GOLD
	})


## Shows a level-up notification
func show_level_up(new_level: int, rewards: Array) -> void:
	var reward_text := ""
	if rewards.size() > 0:
		reward_text = " - " + rewards[0].get("name", "Reward")
	_queue_notification({
		"type": "level_up",
		"title": "LEVEL UP!",
		"subtitle": "Level %d%s" % [new_level, reward_text],
		"duration": DURATIONS["level_up"],
		"color": UITheme.ACCENT
	})


## Shows a challenge completed notification
func show_challenge_complete(challenge: Dictionary) -> void:
	var xp: int = challenge.get("xp", 0)
	_queue_notification({
		"type": "challenge",
		"title": "Challenge Complete!",
		"subtitle": "%s (+%d XP)" % [challenge.get("description", ""), xp],
		"duration": DURATIONS["challenge"],
		"color": UITheme.SUCCESS
	})


## Shows a kill streak announcement (center screen, large)
func show_streak_announcement(streak_text: String, kill_count: int) -> void:
	_queue_notification({
		"type": "streak",
		"title": streak_text,
		"subtitle": "%d Kills" % kill_count,
		"duration": DURATIONS["streak"],
		"color": UITheme.WARNING
	})


## Shows XP gained feedback
func show_xp_gain(amount: int, source_text: String) -> void:
	_queue_notification({
		"type": "xp_gain",
		"title": "+%d XP" % amount,
		"subtitle": source_text,
		"duration": DURATIONS["xp_gain"],
		"color": UITheme.ACCENT_XP
	})


## Shows battle pass tier reached
func show_battle_pass_tier(tier: int, rewards: Array) -> void:
	var reward_names: Array = []
	for r in rewards:
		reward_names.append(r.get("name", "Reward"))
	_queue_notification({
		"type": "battle_pass",
		"title": "Season Tier %d!" % tier,
		"subtitle": ", ".join(reward_names) if reward_names.size() > 0 else "New tier reached",
		"duration": DURATIONS["battle_pass"],
		"color": UITheme.ACCENT_TEAL
	})


## Shows hot drop zone notification
func show_hot_drop(zone_name: String) -> void:
	_queue_notification({
		"type": "hot_drop",
		"title": zone_name,
		"subtitle": "High risk, high reward!",
		"duration": DURATIONS["hot_drop"],
		"color": UITheme.DANGER
	})


## Queues a notification with priority sorting
func _queue_notification(notification: Dictionary) -> void:
	if _notification_queue.size() >= MAX_QUEUE_SIZE:
		_notification_queue.pop_front()  # Drop oldest

	_notification_queue.append(notification)

	# Sort by priority (higher priority first)
	_notification_queue.sort_custom(func(a, b):
		return PRIORITY.get(a.get("type", "toast"), 0) > PRIORITY.get(b.get("type", "toast"), 0)
	)


## Shows the next notification in the queue
func _show_next() -> void:
	if _notification_queue.is_empty():
		_is_showing = false
		queue_empty.emit()
		return

	_current_notification = _notification_queue.pop_front()
	_is_showing = true
	_display_timer = _current_notification.get("duration", 3.0)
	_anim_progress = 0.0
	_anim_state = "slide_in"

	var ntype: String = _current_notification.get("type", "toast")
	var title: String = _current_notification.get("title", "")
	var subtitle: String = _current_notification.get("subtitle", "")
	var color: Color = _current_notification.get("color", Color.WHITE)

	if ntype == "streak":
		_streak_label.text = title
		_streak_label.modulate = Color(color.r, color.g, color.b, 0.0)
		_streak_label.visible = true
		_toast_container.visible = false
	else:
		_toast_label.text = title
		_toast_subtitle.text = subtitle
		_toast_label.modulate = color
		_toast_container.visible = true
		_streak_label.visible = false

	notification_shown.emit(_current_notification)


## Hides the current notification
func _hide_current() -> void:
	_toast_container.visible = false
	_streak_label.visible = false
	_is_showing = false
	_current_notification = {}


## Updates animation positions/opacity based on progress
func _update_animation() -> void:
	var ntype: String = _current_notification.get("type", "toast")

	if ntype == "streak":
		# Fade in/out + scale effect
		var alpha: float = _anim_progress
		var color: Color = _current_notification.get("color", Color(1.0, 0.8, 0.0))
		_streak_label.modulate = Color(color.r, color.g, color.b, alpha)
		# Scale effect via font size (crude but effective in Godot UI)
		var base_size: int = UITheme.FONT_DISPLAY
		var scale_bonus: int = int((1.0 - _anim_progress) * 20.0) if _anim_state == "slide_in" else 0
		_streak_label.add_theme_font_size_override("font_size", base_size + scale_bonus)
	else:
		# Slide from top
		var target_y: float = 20.0  # Final resting position
		var start_y: float = -100.0  # Off-screen
		var current_y: float = lerpf(start_y, target_y, _ease_out_cubic(_anim_progress))
		_toast_container.position.y = current_y
		_toast_container.modulate.a = _anim_progress


## Cubic ease-out for smooth animation
func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)
