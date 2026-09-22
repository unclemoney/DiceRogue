extends PanelContainer
class_name MallStoreTooltip

## MallStoreTooltip
##
## One tooltip component shared by the mall selector and the in-game
## MallMapPopup. Owns the panel styling, the label, placement next to an
## anchor rect, and the fade+slide show / fade-out hide animation.
## Replaces the tooltip plumbing previously duplicated in both screens.

const VCR_FONT: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

var _label: Label
var _show_tween: Tween

@onready var _tfx := get_node_or_null("/root/TweenFXHelper")


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4000
	custom_minimum_size = Vector2(220, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.14, 0.98)
	style.border_color = Color(0.95, 0.86, 0.42, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(220, 0)
	_label.add_theme_font_override("font", VCR_FONT)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.88))
	margin.add_child(_label)


## get_text() -> String
##
## Current tooltip text (for tests).
func get_text() -> String:
	return _label.text


## show_for(anchor_rect, text, side) -> void
##
## Shows the tooltip next to the anchor rect (screen space) with a fade and
## a slight upward slide.
func show_for(anchor_rect: Rect2, text: String, side: Side = SIDE_RIGHT) -> void:
	_label.text = text
	visible = true
	reset_size()
	if _tfx:
		_tfx.place_tooltip(self, anchor_rect, side, true)
	else:
		global_position = anchor_rect.end + Vector2(12, -16)
	_animate_in()


## hide_tooltip(animate) -> void
##
## Fades the tooltip out (or hides instantly).
func hide_tooltip(animate: bool) -> void:
	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()
	if not animate:
		visible = false
		modulate.a = 1.0
		return
	if _tfx and visible:
		var tween: Tween = _tfx.tooltip_fade_out(self, 0.08)
		if tween:
			tween.finished.connect(_on_fade_out_finished)
			return
	visible = false


func _on_fade_out_finished() -> void:
	visible = false
	modulate.a = 1.0


func _animate_in() -> void:
	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()
	var target_pos := global_position
	global_position = target_pos + Vector2(0, 8)
	modulate.a = 0.0
	_show_tween = create_tween()
	_show_tween.set_parallel(true)
	_show_tween.tween_property(self, "global_position", target_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_show_tween.tween_property(self, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
