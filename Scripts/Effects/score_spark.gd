extends Control
class_name ScoreSpark

## ScoreSpark
##
## A single flying scoring number for the score-sink sequence: mall-core
## glass chip + upright VCR label. Externally driven — the
## ScoringAnimationController positions it along a spiral path each frame
## via fly_update(). Contains no tweens or timers of its own.

const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

@export var base_font_size: int = 24
@export var outline_size: int = 4
@export var panel_padding: int = 8

var panel: Panel
var label: Label

## _ready()
##
## Builds the chip + label. Side-effects: none beyond child creation.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = RenderLayers.Z_SCREEN_FX

	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

## setup(value, font_size_scale, text_color, panel_style)
##
## Configure text, size, color and the chip shell. The chip is centered on
## the node origin so global_position always refers to the visual center.
func setup(value: String, font_size_scale: float, text_color: Color, panel_style: Dictionary = {}) -> void:
	if not label or not panel:
		push_error("[ScoreSpark] setup() called before _ready()")
		return

	label.text = value
	label.add_theme_font_override("font", VCR_FONT)
	label.add_theme_font_size_override("font_size", int(base_font_size * font_size_scale))
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", outline_size)

	# Square chip centered on the node origin, label upright at the same center.
	var label_min = label.get_minimum_size()
	var side = max(label_min.x, label_min.y) + panel_padding * 2
	panel.size = Vector2(side, side)
	panel.position = Vector2(-side / 2.0, -side / 2.0)
	label.position = Vector2(-label_min.x / 2.0, -label_min.y / 2.0)

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = panel_style.get("fill_color", Color(0.0, 0.0, 0.0, 0.9))
	style_box.border_color = panel_style.get("border_color", Color.TRANSPARENT)
	style_box.set_border_width_all(int(panel_style.get("border_width", 0)))
	style_box.set_corner_radius_all(int(panel_style.get("corner_radius", 14)))
	style_box.corner_detail = 8
	style_box.shadow_color = panel_style.get("shadow_color", Color.TRANSPARENT)
	style_box.shadow_size = int(panel_style.get("shadow_size", 0))
	panel.add_theme_stylebox_override("panel", style_box)

## fly_update(new_global_position, new_scale, alpha)
##
## Per-frame placement while spiraling into the sink. Called by the
## controller's tween_method; safe to call every frame.
func fly_update(new_global_position: Vector2, new_scale: float, alpha: float) -> void:
	global_position = new_global_position
	scale = Vector2.ONE * new_scale
	modulate.a = alpha
