## UITheme — the single source of truth for all UI design tokens.
##
## This class defines ONE type scale, ONE spacing rhythm (4/8px based), and a
## semantic color system. Every screen — whether built in a .tscn file or in code —
## should reference these tokens instead of hardcoding Color() literals, font sizes,
## or magic spacing numbers.
##
## Usage (code-built UI):
##   label.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
##   label.modulate = UITheme.TEXT_PRIMARY
##   vbox.add_theme_constant_override("separation", UITheme.SPACE_M)
##
## Usage (theme resource): call UITheme.build_theme() once at startup and register
## it as the project-wide default so Control nodes inherit consistent styling.
##
## Design rationale:
##   - Surfaces step in luminance so panels read as elevated above the background.
##   - Text tiers give clear hierarchy (primary > secondary > muted).
##   - Semantic colors (success/danger/warning/accent) are defined ONCE and reused.
class_name UITheme
extends RefCounted


# =============================================================
# COLOR SYSTEM — semantic, defined once
# =============================================================

# --- Surface levels (background → most elevated) ---
## App background — the deepest layer.
const SURFACE_BG := Color(0.07, 0.08, 0.11, 1.0)          # #12141C
## Default surface for screens (one step up from bg).
const SURFACE_1 := Color(0.10, 0.11, 0.15, 1.0)           # #1A1C26
## Elevated surface for panels/cards.
const SURFACE_2 := Color(0.14, 0.15, 0.20, 1.0)           # #242633
## Highest surface for popovers/toasts/active rows.
const SURFACE_3 := Color(0.18, 0.20, 0.26, 1.0)           # #2E3342

## Hairline border / divider color.
const BORDER := Color(0.28, 0.30, 0.38, 1.0)              # #474D61
## Subtle border for resting elements.
const BORDER_SUBTLE := Color(0.20, 0.22, 0.28, 1.0)       # #333846

# --- Text tiers ---
## Primary text — headings and key values.
const TEXT_PRIMARY := Color(0.96, 0.97, 1.0, 1.0)         # #F5F7FF
## Secondary text — body and labels.
const TEXT_SECONDARY := Color(0.78, 0.80, 0.86, 1.0)      # #C7CCDB
## Muted text — captions, hints, disabled-ish info.
const TEXT_MUTED := Color(0.55, 0.58, 0.66, 1.0)          # #8C94A8
## Text drawn on top of accent-colored fills.
const TEXT_ON_ACCENT := Color(0.05, 0.06, 0.09, 1.0)      # near-black

# --- Semantic accents ---
## Primary brand accent — main CTAs, highlights, focus.
const ACCENT := Color(0.26, 0.60, 1.0, 1.0)               # #4299FF
## Hover variant of accent.
const ACCENT_HOVER := Color(0.38, 0.68, 1.0, 1.0)         # #61ADFF
## Pressed variant of accent.
const ACCENT_PRESSED := Color(0.18, 0.48, 0.88, 1.0)      # #2E7AE0

## Success / positive (wins, unlocks, completed).
const SUCCESS := Color(0.24, 0.80, 0.44, 1.0)             # #3DCC70
## Danger / negative (defeat, errors, destructive).
const DANGER := Color(1.0, 0.42, 0.44, 1.0)               # #FF6B70 (WCAG 4.5:1 on panels)
## Warning / caution (validation, storm, low resources).
const WARNING := Color(1.0, 0.72, 0.20, 1.0)              # #FFB833
## Rare/epic flourish accent (XP, premium).
const ACCENT_XP := Color(0.70, 0.52, 1.0, 1.0)            # #B285FF (WCAG 4.5:1 on panels)
## Gold — victory, legendary, top placement.
const GOLD := Color(1.0, 0.84, 0.0, 1.0)                  # #FFD600
## Teal — battle pass / seasonal accent.
const ACCENT_TEAL := Color(0.0, 0.85, 0.72, 1.0)          # #00D9B8

# --- Tinted surface backgrounds for outcome screens ---
## Victory background wash (dark green).
const SURFACE_VICTORY := Color(0.05, 0.12, 0.07, 0.94)
## Defeat background wash (dark red).
const SURFACE_DEFEAT := Color(0.12, 0.05, 0.06, 0.94)


# =============================================================
# TYPE SCALE — one modular scale (~1.25 ratio), 8px-aligned
# =============================================================
## Display — the single largest text (main menu title only).
const FONT_DISPLAY := 48
## Title — screen headings.
const FONT_TITLE := 32
## Heading — section headings, large stats.
const FONT_HEADING := 24
## Subheading — emphasized rows, primary buttons.
const FONT_SUBHEADING := 20
## Body — default label/body text.
const FONT_BODY := 16
## Caption — secondary labels, metadata.
const FONT_CAPTION := 14
## Micro — dense metadata, timestamps, fine print.
const FONT_MICRO := 12


# =============================================================
# SPACING RHYTHM — 4/8px system. Use these, not arbitrary numbers.
# =============================================================
const SPACE_XXS := 4
const SPACE_XS := 8
const SPACE_S := 12
const SPACE_M := 16
const SPACE_L := 24
const SPACE_XL := 32
const SPACE_XXL := 40


# =============================================================
# RADII & SIZING
# =============================================================
## Standard corner radius for buttons/inputs.
const RADIUS_S := 6
## Corner radius for panels/cards.
const RADIUS_M := 10
## Minimum touch target (accessibility — 44px per WCAG/mobile guidance).
const TOUCH_MIN := 44

# --- Motion (used by the motion helper in a later area) ---
## Fast transition (hover, small value changes).
const DUR_FAST := 0.15
## Standard transition (enter/exit, bars).
const DUR_BASE := 0.22
## Slow transition (large reveals).
const DUR_SLOW := 0.30


# =============================================================
# THEME BUILDER — produces a Godot Theme so every Control inherits
# consistent button/label/panel styling without per-node overrides.
# =============================================================

## Builds and returns a complete Theme resource wired to the tokens above.
## Call once at startup and assign as the project default theme.
static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_BODY

	# --- Label defaults ---
	theme.set_color("font_color", "Label", TEXT_SECONDARY)
	theme.set_font_size("font_size", "Label", FONT_BODY)

	# --- Button styling (normal / hover / pressed / focus / disabled) ---
	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "Button", TEXT_ON_ACCENT)
	theme.set_color("font_focus_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "Button", TEXT_MUTED)
	theme.set_font_size("font_size", "Button", FONT_SUBHEADING)
	theme.set_constant("h_separation", "Button", SPACE_XS)

	theme.set_stylebox("normal", "Button", _button_box(SURFACE_2, BORDER_SUBTLE))
	theme.set_stylebox("hover", "Button", _button_box(SURFACE_3, ACCENT))
	theme.set_stylebox("pressed", "Button", _button_box(ACCENT_PRESSED, ACCENT))
	theme.set_stylebox("focus", "Button", _focus_box())
	theme.set_stylebox("disabled", "Button", _button_box(SURFACE_1, BORDER_SUBTLE))

	# --- Panel / PanelContainer ---
	theme.set_stylebox("panel", "PanelContainer", _panel_box())
	theme.set_stylebox("panel", "Panel", _panel_box())

	# --- ProgressBar ---
	theme.set_stylebox("background", "ProgressBar", _bar_bg_box())
	theme.set_stylebox("fill", "ProgressBar", _bar_fill_box())
	theme.set_color("font_color", "ProgressBar", TEXT_SECONDARY)
	theme.set_font_size("font_size", "ProgressBar", FONT_MICRO)

	# --- OptionButton / SpinBox share the Button look (they extend it) ---
	theme.set_stylebox("normal", "OptionButton", _button_box(SURFACE_2, BORDER_SUBTLE))
	theme.set_stylebox("hover", "OptionButton", _button_box(SURFACE_3, ACCENT))
	theme.set_stylebox("pressed", "OptionButton", _button_box(ACCENT_PRESSED, ACCENT))
	theme.set_stylebox("focus", "OptionButton", _focus_box())
	theme.set_color("font_color", "OptionButton", TEXT_PRIMARY)
	theme.set_font_size("font_size", "OptionButton", FONT_BODY)

	return theme


## Standard button stylebox with a given fill and border color.
static func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(RADIUS_S)
	box.content_margin_left = SPACE_M
	box.content_margin_right = SPACE_M
	box.content_margin_top = SPACE_XS
	box.content_margin_bottom = SPACE_XS
	return box


## Focus ring stylebox — visible, high-contrast outline for keyboard nav.
static func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)  # transparent fill; ring only
	box.border_color = ACCENT_HOVER
	box.set_border_width_all(2)
	box.set_corner_radius_all(RADIUS_S)
	box.draw_center = false
	return box


## Panel/card stylebox — elevated surface with subtle border.
static func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = SURFACE_2
	box.border_color = BORDER_SUBTLE
	box.set_border_width_all(1)
	box.set_corner_radius_all(RADIUS_M)
	box.content_margin_left = SPACE_M
	box.content_margin_right = SPACE_M
	box.content_margin_top = SPACE_S
	box.content_margin_bottom = SPACE_S
	return box


## Progress bar background track.
static func _bar_bg_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = SURFACE_1
	box.border_color = BORDER_SUBTLE
	box.set_border_width_all(1)
	box.set_corner_radius_all(RADIUS_S)
	return box


## Progress bar fill (accent).
static func _bar_fill_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ACCENT
	box.set_corner_radius_all(RADIUS_S)
	return box


# =============================================================
# RARITY HELPERS — consolidates the rarity color scale used across
# loot glow, weapon display, achievements, and battle pass.
# =============================================================
static func rarity_color(rarity_index: int) -> Color:
	match rarity_index:
		0: return Color(0.60, 0.62, 0.68, 1.0)  # Common — gray
		1: return SUCCESS                         # Uncommon — green
		2: return ACCENT                          # Rare — blue
		3: return ACCENT_XP                       # Epic — purple
		4: return GOLD                            # Legendary — gold
		_: return TEXT_MUTED


## Returns a color for a placement (1 = gold, top 5 = silver, top 10 = bronze).
static func placement_color(placement: int) -> Color:
	if placement <= 1:
		return GOLD
	elif placement <= 5:
		return Color(0.75, 0.76, 0.80, 1.0)  # silver
	elif placement <= 10:
		return Color(0.80, 0.52, 0.26, 1.0)  # bronze
	return TEXT_MUTED
