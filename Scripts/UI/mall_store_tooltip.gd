extends Control
class_name MallStoreTooltip

## MallStoreTooltip
##
## Thin wrapper shared by the mall selector and the in-game MallMapPopup.
## Owns one standard Tooltip instance and proxies content/placement to it;
## placement next to an anchor rect still goes through
## TweenFXHelper.place_tooltip, show/hide animation through the Tooltip
## itself. The public API (show_for / hide_tooltip / get_text) is unchanged
## for both screens and their tests — show_for now takes the renderer's
## Dictionary ({title, body?, flavor?, sections:[{text, style, label}]})
## instead of a pre-built string.
## Deliberately a plain Control, not a PanelContainer: as a PanelContainer
## the wrapper drew the default theme panel at its own (never positioned,
## i.e. 0,0) rect — the static "shadow" bug — and container child-fitting
## fought the inner tooltip's cursor-follow positioning.

var _tip: Tooltip
var _last_data: Dictionary = {}

@onready var _tfx := get_node_or_null("/root/TweenFXHelper")


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip = load("res://Scenes/UI/tooltip.tscn").instantiate()
	add_child(_tip)


## get_text() -> String
##
## Plain-text rendering of the last shown content (for tests).
func get_text() -> String:
	var lines: Array[String] = [str(_last_data.get("title", ""))]
	for section in _last_data.get("sections", []):
		var text: String = section.get("text", "")
		if section.get("label", "") != "":
			text = "%s: %s" % [section["label"], text]
		lines.append(text)
	return "\n".join(lines)


## show_for(anchor_rect, data, side) -> void
##
## Fills the standard Tooltip from data (setup + one add_section per entry
## in data["sections"]) and shows it next to the anchor rect (screen space).
func show_for(anchor_rect: Rect2, data: Dictionary, side: Side = SIDE_RIGHT) -> void:
	_last_data = data
	_tip.setup(data)
	for section in data.get("sections", []):
		_tip.add_section(section.get("text", ""), section.get("style", "plain"), section.get("label", ""))
	visible = true
	if _tfx:
		_tfx.place_tooltip(_tip, anchor_rect, side, false)
	else:
		_tip.global_position = anchor_rect.end + Vector2(12, -16)
	_tip.show_at(_tip.global_position, anchor_rect)


## is_showing() -> bool
##
## The inner Tooltip's visibility. The wrapper itself stays visible=true when
## TweenFX's stale guard hides the inner tooltip directly, so hosts must ask
## here instead of reading the wrapper's visible flag.
func is_showing() -> bool:
	return _tip != null and _tip.visible


## hide_tooltip(animate) -> void
##
## Hides the tooltip (standard fade+shrink, or instantly).
func hide_tooltip(animate: bool) -> void:
	visible = false
	_tip.hide()
	if not animate:
		_tip.visible = false
		_tip.modulate.a = 1.0
