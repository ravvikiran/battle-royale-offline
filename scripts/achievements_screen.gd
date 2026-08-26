## Achievements display screen showing all achievements grouped by category.
## Shows progress bars for progressive achievements, unlock status,
## and XP rewards. Filterable by category with completion percentage.
class_name AchievementsScreen
extends Control


## Emitted when the player wants to go back
signal back_pressed()


## UI references
var _back_button: Button = null
var _category_tabs: HBoxContainer = null
var _achievement_list: VBoxContainer = null
var _completion_label: Label = null
var _scroll_container: ScrollContainer = null

## Reference to achievements manager
var _achievements_manager: AchievementsManager = null

## Currently selected category filter (-1 = all)
var _selected_category: int = -1

## Category names for display
const CATEGORY_NAMES: Dictionary = {
	Enums.AchievementCategory.COMBAT: "Combat",
	Enums.AchievementCategory.SURVIVAL: "Survival",
	Enums.AchievementCategory.VICTORY: "Victory",
	Enums.AchievementCategory.MASTERY: "Mastery",
	Enums.AchievementCategory.EXPLORATION: "Exploration",
	Enums.AchievementCategory.SOCIAL: "Social",
}

## Rarity colors
const RARITY_COLORS: Dictionary = {
	Enums.AchievementRarity.BRONZE: Color(0.8, 0.5, 0.2),
	Enums.AchievementRarity.SILVER: Color(0.75, 0.75, 0.75),
	Enums.AchievementRarity.GOLD: Color(1.0, 0.84, 0.0),
	Enums.AchievementRarity.PLATINUM: Color(0.4, 0.8, 1.0),
	Enums.AchievementRarity.DIAMOND: Color(0.7, 0.3, 1.0),
}


func _ready() -> void:
	_build_ui()


## Sets the achievements manager reference
func set_achievements_manager(manager: AchievementsManager) -> void:
	_achievements_manager = manager
	_refresh_display()


## Builds the UI
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)

	_back_button = Button.new()
	_back_button.text = "< Back"
	_back_button.custom_minimum_size = Vector2(120, 48)
	_back_button.pressed.connect(func(): back_pressed.emit())
	header.add_child(_back_button)

	var title := Label.new()
	title.text = "ACHIEVEMENTS"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_completion_label = Label.new()
	_completion_label.text = "0% Complete"
	_completion_label.add_theme_font_size_override("font_size", 18)
	_completion_label.modulate = Color(1.0, 0.84, 0.0)
	header.add_child(_completion_label)

	# Category tabs
	_category_tabs = HBoxContainer.new()
	_category_tabs.add_theme_constant_override("separation", 8)
	_category_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_category_tabs)

	# "All" tab
	var all_btn := Button.new()
	all_btn.text = "All"
	all_btn.custom_minimum_size = Vector2(80, 36)
	all_btn.pressed.connect(func(): _filter_category(-1))
	_category_tabs.add_child(all_btn)

	# Category-specific tabs
	for cat in CATEGORY_NAMES.keys():
		var btn := Button.new()
		btn.text = CATEGORY_NAMES[cat]
		btn.custom_minimum_size = Vector2(100, 36)
		btn.pressed.connect(_filter_category.bind(cat))
		_category_tabs.add_child(btn)

	# Scrollable achievement list
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll_container)

	_achievement_list = VBoxContainer.new()
	_achievement_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievement_list.add_theme_constant_override("separation", 8)
	_scroll_container.add_child(_achievement_list)


## Filters achievements by category
func _filter_category(category: int) -> void:
	_selected_category = category
	_refresh_display()


## Refreshes the achievement list display
func _refresh_display() -> void:
	if _achievements_manager == null:
		return

	# Clear existing entries
	for child in _achievement_list.get_children():
		child.queue_free()

	# Update completion percentage
	var pct: float = _achievements_manager.get_completion_percentage() * 100.0
	_completion_label.text = "%.0f%% Complete (%d/%d)" % [
		pct, 
		_achievements_manager.get_unlocked_count(), 
		_achievements_manager.get_total_count()
	]

	# Get achievements to display
	var achievements: Dictionary = _achievements_manager.get_all_achievements()
	var sorted_ids: Array = achievements.keys()

	# Sort: unlocked first, then by category, then by rarity
	sorted_ids.sort_custom(func(a, b):
		var ach_a: Dictionary = achievements[a]
		var ach_b: Dictionary = achievements[b]
		var unlocked_a: bool = _achievements_manager.is_unlocked(a)
		var unlocked_b: bool = _achievements_manager.is_unlocked(b)
		if unlocked_a != unlocked_b:
			return unlocked_a  # Unlocked first
		return ach_a.get("rarity", 0) > ach_b.get("rarity", 0)  # Higher rarity first
	)

	for ach_id in sorted_ids:
		var ach: Dictionary = achievements[ach_id]

		# Apply category filter
		if _selected_category >= 0 and ach.get("category", -1) != _selected_category:
			continue

		# Skip hidden achievements that aren't unlocked
		if ach.get("hidden", false) and not _achievements_manager.is_unlocked(ach_id):
			continue

		_achievement_list.add_child(_create_achievement_entry(ach_id, ach))


## Creates a single achievement display entry
func _create_achievement_entry(ach_id: String, ach: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 72)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	var is_unlocked: bool = _achievements_manager.is_unlocked(ach_id)
	var rarity: Enums.AchievementRarity = ach.get("rarity", Enums.AchievementRarity.BRONZE)
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)

	# Rarity badge / icon placeholder
	var badge := Label.new()
	badge.text = "★" if is_unlocked else "☆"
	badge.add_theme_font_size_override("font_size", 28)
	badge.modulate = rarity_color if is_unlocked else Color(0.4, 0.4, 0.4)
	badge.custom_minimum_size = Vector2(40, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(badge)

	# Name and description
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = ach.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.modulate = rarity_color if is_unlocked else Color(0.6, 0.6, 0.6)
	info_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = ach.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.modulate = Color(0.7, 0.7, 0.7)
	info_vbox.add_child(desc_label)

	# Progress bar (for progressive achievements)
	var target: int = ach.get("target", 1)
	if target > 1:
		var progress_bar := ProgressBar.new()
		progress_bar.min_value = 0
		progress_bar.max_value = target
		progress_bar.value = _achievements_manager.get_progress(ach_id)
		progress_bar.show_percentage = false
		progress_bar.custom_minimum_size = Vector2(0, 12)
		info_vbox.add_child(progress_bar)

		var progress_label := Label.new()
		progress_label.text = "%d / %d" % [_achievements_manager.get_progress(ach_id), target]
		progress_label.add_theme_font_size_override("font_size", 11)
		progress_label.modulate = Color(0.6, 0.6, 0.6)
		info_vbox.add_child(progress_label)

	# XP reward
	var xp_label := Label.new()
	xp_label.text = "+%d XP" % ach.get("xp_reward", 0)
	xp_label.add_theme_font_size_override("font_size", 14)
	xp_label.modulate = Color(0.6, 0.4, 1.0) if not is_unlocked else Color(0.3, 0.8, 0.3)
	xp_label.custom_minimum_size = Vector2(80, 0)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(xp_label)

	# Dim entire panel if locked
	if not is_unlocked:
		panel.modulate = Color(0.7, 0.7, 0.7, 0.9)

	return panel
