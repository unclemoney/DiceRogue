extends Node
class_name MallIconTooltipController

## MallIconTooltipController
##
## Shared hover-timing logic for the mall store icons, used by both mall
## screens so they behave identically:
## - Tooltip shows only after the pointer rests on an icon for 150ms.
## - On exit the tooltip stays for a 100ms grace period.
## - Moving directly to a neighboring icon swaps the content in place —
##   no hide/reshow flicker.

const SHOW_DELAY := 0.15
const EXIT_GRACE := 0.10

var _tooltip: MallStoreTooltip
var _rect_provider: Callable
var _text_provider: Callable
var _current_icon: MallStoreIcon = null
var _pending_icon: MallStoreIcon = null
var _show_token := 0
var _hide_token := 0


## setup(tooltip, rect_provider, text_provider) -> void
##
## rect_provider: Callable(MallStoreIcon) -> Rect2 (screen space).
## text_provider: Callable(MallStoreIcon) -> Dictionary (Tooltip.setup shape).
func setup(tooltip: MallStoreTooltip, rect_provider: Callable, text_provider: Callable) -> void:
	_tooltip = tooltip
	_rect_provider = rect_provider
	_text_provider = text_provider


## has_pending() -> bool — a show is waiting out the 150ms rest delay.
func has_pending() -> bool:
	return _pending_icon != null


## current_icon() -> MallStoreIcon — the icon that owns the visible tooltip.
func current_icon() -> MallStoreIcon:
	return _current_icon


## is_busy() -> bool — a tooltip is shown or a show is pending. Host screens
## use this to keep zone hover from fighting plaque hover.
func is_busy() -> bool:
	return _pending_icon != null or _current_icon != null


## is_showing() -> bool — the inner tooltip is actually on screen.
func is_showing() -> bool:
	return _tooltip != null and _tooltip.is_showing()


func on_icon_hovered(icon: MallStoreIcon) -> void:
	if _tooltip == null or not is_inside_tree():
		return
	_hide_token += 1  # cancel any pending exit-grace hide
	if _current_icon == icon:
		if is_showing():
			return
		# TweenFX's stale guard auto-hid the tooltip without an exit signal
		# ever reaching us — treat this as a fresh hover, not a no-op.
		_current_icon = null
	if _current_icon != null and _tooltip.visible:
		# Neighbor swap: replace content in place, no hide/reshow.
		_pending_icon = null
		_show_token += 1
		_current_icon = icon
		_tooltip.show_for(_rect_provider.call(icon), _text_provider.call(icon), SIDE_RIGHT)
		return
	_pending_icon = icon
	_show_token += 1
	var token := _show_token
	await get_tree().create_timer(SHOW_DELAY).timeout
	if token != _show_token or _pending_icon != icon:
		return
	_pending_icon = null
	# The plaque's exit signal can be missed on fast movement; without this
	# re-check the tooltip pops under a cursor that already left, and the
	# TweenFX stale guard kills it a frame later (half-appearing tween).
	var rect: Rect2 = _rect_provider.call(icon)
	if rect.has_area() and not rect.grow(24.0).has_point(get_viewport().get_mouse_position()):
		_current_icon = null
		return
	_current_icon = icon
	_tooltip.show_for(rect, _text_provider.call(icon), SIDE_RIGHT)


func on_icon_unhovered(icon: MallStoreIcon) -> void:
	if _tooltip == null or not is_inside_tree():
		return
	if _pending_icon == icon:
		_pending_icon = null
		_show_token += 1  # cancel the pending show
	if _current_icon != icon:
		return
	_hide_token += 1
	var token := _hide_token
	await get_tree().create_timer(EXIT_GRACE).timeout
	if token != _hide_token:
		return
	_current_icon = null
	_tooltip.hide_tooltip(true)


## force_hide() -> void
##
## Cancels pending timers and hides immediately (screen closing).
func force_hide() -> void:
	_show_token += 1
	_hide_token += 1
	_pending_icon = null
	_current_icon = null
	if _tooltip:
		_tooltip.hide_tooltip(false)
