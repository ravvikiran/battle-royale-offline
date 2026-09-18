## Motion — shared, reduced-motion-aware animation helpers.
##
## Every animation in the app should route through here so that:
##   1. Durations and easing are consistent (sourced from UITheme).
##   2. A single reduced-motion switch disables/*instantly-completes* all motion
##      for accessibility (respecting the OS / user preference).
##
## Reduced motion is honored per WCAG 2.3.3 (Animation from Interactions):
## when enabled, animated helpers apply the FINAL state immediately with no
## in-between tween, so behavior/outcomes are identical — only the motion is removed.
##
## Usage:
##   Motion.fade(overlay, 0.0, 1.0)          # fade a CanvasItem's alpha
##   Motion.press_pop(button)                 # tactile tap confirmation
##   if Motion.is_reduced_motion(): ...        # branch when needed
class_name Motion
extends RefCounted


## Project setting key that can force reduced motion on (bool).
## Defaults to false when unset. Lets users/QA toggle without code changes.
const SETTING_REDUCED_MOTION := "accessibility/reduced_motion"


## Cached reduced-motion state. Resolved lazily on first query.
static var _reduced_cached: int = -1  # -1 = unresolved, 0 = false, 1 = true


## Returns true when motion should be minimized (accessibility).
## Sourced from a project setting; can be overridden at runtime via set_reduced_motion().
static func is_reduced_motion() -> bool:
	if _reduced_cached == -1:
		var val := false
		if ProjectSettings.has_setting(SETTING_REDUCED_MOTION):
			val = bool(ProjectSettings.get_setting(SETTING_REDUCED_MOTION))
		_reduced_cached = 1 if val else 0
	return _reduced_cached == 1


## Explicitly sets the reduced-motion state at runtime (e.g. from a settings toggle).
static func set_reduced_motion(enabled: bool) -> void:
	_reduced_cached = 1 if enabled else 0


## Fades a CanvasItem's modulate alpha from `from_a` to `to_a` over `duration`.
## Returns the Tween (or null under reduced motion, where the final alpha is
## applied instantly). Safe to `await ...finished` — see fade_and_wait().
static func fade(target: CanvasItem, from_a: float, to_a: float, duration: float = -1.0) -> Tween:
	if target == null or not is_instance_valid(target):
		return null

	# Apply the starting alpha immediately so there is never a one-frame flash.
	var c := target.modulate
	target.modulate = Color(c.r, c.g, c.b, from_a)

	if is_reduced_motion() or duration == 0.0:
		var cc := target.modulate
		target.modulate = Color(cc.r, cc.g, cc.b, to_a)
		return null

	var dur := duration if duration > 0.0 else UITheme.DUR_BASE
	var tween := target.create_tween()
	tween.tween_property(target, "modulate:a", to_a, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tween


## Convenience: fade and always return something awaitable.
## Under reduced motion the final state is applied instantly and this returns
## immediately on the next idle frame.
static func fade_and_wait(target: CanvasItem, from_a: float, to_a: float, duration: float = -1.0) -> void:
	var t := fade(target, from_a, to_a, duration)
	if t != null:
		await t.finished
	else:
		# Yield a single frame so callers can `await` uniformly.
		await target.get_tree().process_frame


## Tactile "press pop" — a brief scale-down then back, confirming a tap in <100ms.
## No-op under reduced motion. Scales around the control's center via pivot_offset.
static func press_pop(target: Control, scale_amount: float = 0.96) -> void:
	if target == null or not is_instance_valid(target):
		return
	if is_reduced_motion():
		return

	# Pivot at center so the scale reads as a press, not a corner shrink.
	target.pivot_offset = target.size * 0.5

	var tween := target.create_tween()
	tween.tween_property(target, "scale", Vector2(scale_amount, scale_amount), UITheme.DUR_FAST * 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(target, "scale", Vector2.ONE, UITheme.DUR_FAST) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Highlight-on-update — a brief modulate flash to draw the eye to a value that
## just changed (e.g. an XP counter, a stat). No-op under reduced motion.
static func highlight(target: CanvasItem, flash_color: Color = UITheme.ACCENT) -> void:
	if target == null or not is_instance_valid(target):
		return
	if is_reduced_motion():
		return

	var original := target.modulate
	target.modulate = flash_color
	var tween := target.create_tween()
	tween.tween_property(target, "modulate", original, UITheme.DUR_SLOW) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Smoothly counts a Label from an old integer value to a new one, so numbers
## "roll up" instead of snapping. No-op-to-final under reduced motion.
static func count_to(label: Label, from_val: int, to_val: int, suffix: String = "", duration: float = -1.0) -> void:
	if label == null or not is_instance_valid(label):
		return
	if is_reduced_motion() or from_val == to_val:
		label.text = str(to_val) + suffix
		return

	var dur := duration if duration > 0.0 else UITheme.DUR_SLOW
	var tween := label.create_tween()
	# Tween an intermediate property via method callback.
	tween.tween_method(
		func(v: float): label.text = str(int(round(v))) + suffix,
		float(from_val), float(to_val), dur
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Like count_to but for fractional values (e.g. win rate 62.5%, avg kills 4.3).
## `decimals` controls precision; `suffix` is appended (e.g. "%").
## No-op-to-final under reduced motion.
static func count_to_float(label: Label, from_val: float, to_val: float, decimals: int = 1, suffix: String = "", duration: float = -1.0) -> void:
	if label == null or not is_instance_valid(label):
		return
	var fmt := "%%.%df%s" % [decimals, suffix]
	if is_reduced_motion() or is_equal_approx(from_val, to_val):
		label.text = fmt % to_val
		return

	var dur := duration if duration > 0.0 else UITheme.DUR_SLOW
	var tween := label.create_tween()
	tween.tween_method(
		func(v: float): label.text = fmt % v,
		from_val, to_val, dur
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Staggered enter: fades a list of CanvasItems in from transparent, each offset
## by `step` seconds, so a group of cards "cascades" in rather than popping at once.
## Under reduced motion all become visible instantly.
static func stagger_in(items: Array, step: float = 0.06, duration: float = -1.0) -> void:
	if is_reduced_motion():
		for it in items:
			if it is CanvasItem and is_instance_valid(it):
				var c: Color = it.modulate
				it.modulate = Color(c.r, c.g, c.b, 1.0)
		return

	var dur := duration if duration > 0.0 else UITheme.DUR_BASE
	var delay := 0.0
	for it in items:
		if not (it is CanvasItem) or not is_instance_valid(it):
			continue
		var ci: CanvasItem = it
		var c: Color = ci.modulate
		ci.modulate = Color(c.r, c.g, c.b, 0.0)
		var tween := ci.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(ci, "modulate:a", 1.0, dur) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		delay += step
