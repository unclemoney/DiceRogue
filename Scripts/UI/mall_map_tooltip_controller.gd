extends Node
class_name MallMapTooltipController

## MallMapTooltipController
##
## Shared click-to-open tooltip state for both mall map screens. Hover never
## reaches this controller. The first left press while a tooltip is open is a
## dismissal-only click, so a neighbor cannot open until the next click.

var _tooltip: MallStoreTooltip
var _open_item: StringName = &""


## setup(tooltip) -> void
##
## Binds the shared tooltip wrapper owned by the host screen.
func setup(tooltip: MallStoreTooltip) -> void:
	_tooltip = tooltip
	_open_item = &""


## on_item_clicked(item_key, anchor_rect, data) -> void
##
## Opens a pinned tooltip when none is open. Any existing item closes first;
## the same item therefore toggles and a different item never neighbor-swaps.
func on_item_clicked(item_key: StringName, anchor_rect: Rect2, data: Dictionary) -> void:
	if _tooltip == null:
		return
	if is_open():
		dismiss()
		return
	_open_item = item_key
	_tooltip.show_for(anchor_rect, data, SIDE_RIGHT, false)


## handle_screen_click(event) -> bool
##
## Returns true when this left press dismissed an open tooltip. The host must
## mark that input handled so it cannot also activate a map item or UI control.
func handle_screen_click(event: InputEvent) -> bool:
	if not is_open():
		return false
	if not event is InputEventMouseButton:
		return false
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return false
	dismiss()
	return true


## dismiss(animate) -> void
##
## Clears logical ownership before hiding, including while show layout is pending.
func dismiss(animate: bool = true) -> void:
	_open_item = &""
	if _tooltip:
		_tooltip.hide_tooltip(animate)


## force_hide() -> void
##
## Immediately clears the tooltip when its host closes, reopens, or rebuilds.
func force_hide() -> void:
	dismiss(false)


## is_open() -> bool
##
## Tracks the requested open state even before the inner tooltip becomes visible.
func is_open() -> bool:
	return _open_item != &""


## current_item() -> StringName
##
## Returns the stable store key owning the open tooltip, or an empty key.
func current_item() -> StringName:
	return _open_item
