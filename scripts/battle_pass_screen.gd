## Battle Pass display screen showing seasonal tier progression.
## Displays all 50 tiers with free and premium tracks, current progress,
## and reward previews. Allows claiming unlocked rewards.
class_name BattlePassScreen
extends Control


## Emitted when the player wants to go back
signal back_pressed()


## UI references
var _back_button: Button = null
var _tier_scroll: ScrollContainer = null
var _tier_container: HBoxContainer = null
var _progress_label: Label = null
var _season_label: Label = null
var _xp_bar: ProgressBar = null
var _xp_label: Label = null
var _claim_all_btn: Button = null

## Reference to battle pass system
var _battle_pass: BattlePass = null


func _ready() -> void:
	_build_ui()


## Sets the battle pass reference
func set_battle_pass(bp: BattlePass) -> void:
	_battle_pass = bp
	_refresh_display()


## Builds the UI
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
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

	_season_label = Label.new()
	_season_label.text = "Season 1: First Drop"
	_season_label.add_theme_font_size_override("font_size", 28)
	_season_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_season_label)

	_claim_all_btn = Button.new()
	_claim_all_btn.text = "Claim All"
	_claim_all_btn.custom_minimum_size = Vector2(120, 48)
	_claim_all_btn.pressed.connect(_on_claim_all)
	header.add_child(_claim_all_btn)

	# Progress bar
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 12)
	root.add_child(progress_row)

	_progress_label = Label.new()
	_progress_label.text = "Tier 0 / 50"
	_progress_label.add_theme_font_size_override("font_size", 18)
	_progress_label.custom_minimum_size = Vector2(120, 0)
	progress_row.add_child(_progress_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.min_value = 0.0
	_xp_bar.max_value = 1.0
	_xp_bar.value = 0.0
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(300, 24)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.text = "0 / 200 XP"
	_xp_label.add_theme_font_size_override("font_size", 14)
	_xp_label.modulate = Color(0.6, 0.8, 1.0)
	progress_row.add_child(_xp_label)

	# Tier scroll (horizontal)
	_tier_scroll = ScrollContainer.new()
	_tier_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tier_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_tier_scroll)

	_tier_container = HBoxContainer.new()
	_tier_container.add_theme_constant_override("separation", 4)
	_tier_scroll.add_child(_tier_container)


## Refreshes the entire display
func _refresh_display() -> void:
	if _battle_pass == null:
		return

	_season_label.text = _battle_pass.get_season_name()
	_progress_label.text = "Tier %d / %d" % [_battle_pass.current_tier, BattlePass.MAX_TIER]
	_xp_bar.value = _battle_pass.get_tier_progress()

	var next_xp: int = _battle_pass.get_xp_for_tier(_battle_pass.current_tier + 1)
	_xp_label.text = "%d / %d XP" % [_battle_pass.current_tier_xp, next_xp]

	# Clear existing tier cards
	for child in _tier_container.get_children():
		child.queue_free()

	# Create tier cards
	for tier in range(1, BattlePass.MAX_TIER + 1):
		_tier_container.add_child(_create_tier_card(tier))

	# Update claim button visibility
	_claim_all_btn.visible = _battle_pass.get_unclaimed_rewards().size() > 0


## Creates a single tier card
func _create_tier_card(tier: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(100, 200)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var is_reached: bool = tier <= _battle_pass.current_tier
	var is_current: bool = tier == _battle_pass.current_tier + 1

	# Tier number
	var tier_label := Label.new()
	tier_label.text = str(tier)
	tier_label.add_theme_font_size_override("font_size", 16)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.modulate = Color(1.0, 0.84, 0.0) if is_reached else Color(0.5, 0.5, 0.5)
	if is_current:
		tier_label.modulate = Color(0.3, 0.8, 1.0)
	vbox.add_child(tier_label)

	# Free reward
	var free_reward: Dictionary = BattlePass.FREE_REWARDS.get(tier, {})
	var free_label := Label.new()
	if not free_reward.is_empty():
		free_label.text = free_reward.get("name", "---")
		free_label.modulate = Color(0.2, 0.8, 0.2) if is_reached else Color(0.5, 0.5, 0.5)
	else:
		free_label.text = "---"
		free_label.modulate = Color(0.3, 0.3, 0.3)
	free_label.add_theme_font_size_override("font_size", 11)
	free_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	free_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(free_label)

	# Premium reward
	var prem_reward: Dictionary = BattlePass.PREMIUM_REWARDS.get(tier, {})
	var prem_label := Label.new()
	if not prem_reward.is_empty():
		prem_label.text = prem_reward.get("name", "---")
		if _battle_pass.is_premium:
			prem_label.modulate = Color(0.6, 0.3, 1.0) if is_reached else Color(0.4, 0.4, 0.4)
		else:
			prem_label.modulate = Color(0.3, 0.3, 0.3, 0.5)  # Locked
	else:
		prem_label.text = "---"
		prem_label.modulate = Color(0.3, 0.3, 0.3)
	prem_label.add_theme_font_size_override("font_size", 11)
	prem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prem_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(prem_label)

	# Highlight current tier
	if is_current:
		card.modulate = Color(1.2, 1.2, 1.2)
	elif not is_reached:
		card.modulate = Color(0.6, 0.6, 0.6)

	return card


## Claims all available rewards
func _on_claim_all() -> void:
	if _battle_pass == null:
		return
	var unclaimed: Array = _battle_pass.get_unclaimed_rewards()
	for reward in unclaimed:
		var tier: int = reward.get("tier", 0)
		_battle_pass.claim_tier_rewards(tier)
	_refresh_display()
