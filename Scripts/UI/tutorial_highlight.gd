# Scripts/UI/tutorial_highlight.gd
extends CanvasLayer

## TutorialHighlight
##
## Provides visual highlighting for UI elements during the tutorial.
## Creates a semi-transparent backdrop with a cutout around the highlighted element,
## a golden pulsing border, and an optional "CLICK HERE" indicator.

# Golden color matching game UI
const GOLDEN_COLOR := Color(1.0, 0.85, 0.32, 1.0)
const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const BORDER_WIDTH := 4
const PULSE_DURATION := 1.2
const PULSE_SCALE_MIN := 1.0
const PULSE_SCALE_MAX := 1.05
const INDICATOR_BOUNCE_HEIGHT := 10.0
const INDICATOR_BOUNCE_DURATION := 0.6

# Fonts
var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

# UI Components
var backdrop: ColorRect
var highlight_panel: Panel
var click_indicator: Label
var target_node: CanvasItem = null  # Can be Control or Node2D

# Manual overrides
var _manual_size: Vector2 = Vector2.ZERO
var _manual_offset: Vector2 = Vector2.ZERO

# Animation
var pulse_tween: Tween
var bounce_tween: Tween
var _update_position: bool = false


func _ready() -> void:
	# Ensure highlight works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide_highlight()


func _process(_delta: float) -> void:
	if _update_position and target_node and is_instance_valid(target_node):
		_update_highlight_position()


## _build_ui()
##
## Creates the highlight UI components programmatically.
func _build_ui() -> void:
	# Semi-transparent backdrop (covers entire screen)
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	
	# Highlight panel with golden border (positioned over target)
	highlight_panel = Panel.new()
	highlight_panel.name = "HighlightPanel"
	highlight_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create golden border style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)  # Transparent center
	style.border_color = GOLDEN_COLOR
	style.set_border_width_all(BORDER_WIDTH)
	style.set_corner_radius_all(8)
	highlight_panel.add_theme_stylebox_override("panel", style)
	add_child(highlight_panel)
	
	# Click indicator label
	click_indicator = Label.new()
	click_indicator.name = "ClickIndicator"
	click_indicator.text = "↓ CLICK HERE ↓"
	click_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	click_indicator.add_theme_font_override("font", vcr_font)
	click_indicator.add_theme_font_size_override("font_size", 18)
	click_indicator.add_theme_color_override("font_color", GOLDEN_COLOR)
	click_indicator.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	click_indicator.add_theme_constant_override("shadow_offset_x", 2)
	click_indicator.add_theme_constant_override("shadow_offset_y", 2)
	click_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(click_indicator)


## show_highlight(target, show_indicator, manual_size, manual_offset, show_backdrop)
##
## Shows the highlight around a target node (Control or Node2D).
##
## @param target: The CanvasItem node to highlight (Control or Node2D)
## @param show_indicator: Whether to show the "CLICK HERE" indicator
## @param manual_size: Manual size override (Vector2.ZERO for auto)
## @param manual_offset: Manual position offset
## @param show_backdrop: Whether to show the dimming backdrop
func show_highlight(target: CanvasItem, show_indicator: bool = false, manual_size: Vector2 = Vector2.ZERO, manual_offset: Vector2 = Vector2.ZERO, show_backdrop: bool = true) -> void:
	if not target or not is_instance_valid(target):
		push_error("[TutorialHighlight] Invalid target node")
		hide_highlight()
		return
	
	target_node = target
	_manual_size = manual_size
	_manual_offset = manual_offset
	_update_position = true
	
	# Show components
	if show_backdrop:
		backdrop.show()
	else:
		backdrop.hide()
	highlight_panel.show()
	
	if show_indicator:
		click_indicator.show()
		_start_bounce_animation()
	else:
		click_indicator.hide()
	
	# Update position immediately
	_update_highlight_position()
	
	# Start pulse animation
	_start_pulse_animation()
	
	print("[TutorialHighlight] Highlighting: %s" % target.name)


## hide_highlight()
##
## Hides all highlight components.
func hide_highlight() -> void:
	_update_position = false
	target_node = null
	
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	if bounce_tween and bounce_tween.is_valid():
		bounce_tween.kill()
	
	if backdrop:
		backdrop.hide()
	if highlight_panel:
		highlight_panel.hide()
	if click_indicator:
		click_indicator.hide()


## _update_highlight_position()
##
## Updates the position and size of the highlight to match the target.
## Supports both Control nodes (using get_global_rect) and Node2D nodes.
func _update_highlight_position() -> void:
	if not target_node or not is_instance_valid(target_node):
		return
	
	# Get target's global rect - works differently for Control vs Node2D
	var target_rect: Rect2
	if target_node is Control:
		target_rect = (target_node as Control).get_global_rect()
	elif target_node is Node2D:
		# For Node2D, estimate rect from children or use a default size
		var node2d := target_node as Node2D
		var estimated_size := _estimate_node2d_size(node2d)
		var global_pos := node2d.global_position
		target_rect = Rect2(global_pos - estimated_size / 2, estimated_size)
	else:
		push_warning("[TutorialHighlight] Unknown target type: %s" % target_node.get_class())
		return
	
	# Apply manual size override if specified
	if _manual_size != Vector2.ZERO:
		var center = target_rect.get_center()
		target_rect.position = center - _manual_size / 2
		target_rect.size = _manual_size
	
	# Apply manual offset
	if _manual_offset != Vector2.ZERO:
		target_rect.position += _manual_offset
	
	# Add padding around the highlight
	var padding := 8.0
	var highlight_rect = Rect2(
		target_rect.position.x - padding,
		target_rect.position.y - padding,
		target_rect.size.x + padding * 2,
		target_rect.size.y + padding * 2
	)
	
	# Position highlight panel
	highlight_panel.position = highlight_rect.position
	highlight_panel.size = highlight_rect.size
	
	# Position click indicator above the highlight
	if click_indicator.visible:
		var indicator_width = click_indicator.size.x
		click_indicator.position = Vector2(
			highlight_rect.position.x + (highlight_rect.size.x - indicator_width) / 2,
			highlight_rect.position.y - click_indicator.size.y - 10
		)
	
	# Update backdrop shader/mask to create cutout effect
	# For simplicity, we use a semi-transparent backdrop without cutout
	# The highlight panel on top provides visual focus


## _estimate_node2d_size(node)
##
## Estimates the bounding size of a Node2D based on its children.
## Used for highlighting Node2D nodes which don't have intrinsic size.
func _estimate_node2d_size(node: Node2D) -> Vector2:
	# Check for Sprite2D children first
	var sprites := node.find_children("*", "Sprite2D", true, false)
	if sprites.size() > 0:
		var bounds := Rect2()
		var first := true
		for sprite in sprites:
			var s := sprite as Sprite2D
			if s.texture:
				var sprite_rect := Rect2(s.global_position - s.texture.get_size() / 2, s.texture.get_size())
				if first:
					bounds = sprite_rect
					first = false
				else:
					bounds = bounds.merge(sprite_rect)
		if not first:
			return bounds.size
	
	# Check for other Node2D children and estimate from their positions
	var children := node.get_children()
	if children.size() > 0:
		var min_pos := Vector2.INF
		var max_pos := Vector2(-INF, -INF)
		for child in children:
			if child is Node2D:
				var c := child as Node2D
				min_pos.x = min(min_pos.x, c.position.x)
				min_pos.y = min(min_pos.y, c.position.y)
				max_pos.x = max(max_pos.x, c.position.x)
				max_pos.y = max(max_pos.y, c.position.y)
		if min_pos != Vector2.INF:
			var width := max_pos.x - min_pos.x + 100  # Add some buffer
			var height := max_pos.y - min_pos.y + 100
			return Vector2(max(width, 200), max(height, 100))
	
	# Default fallback size for DiceHand and similar
	return Vector2(400, 150)


## _start_pulse_animation()
##
## Starts the pulsing scale animation on the highlight panel.
func _start_pulse_animation() -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	# Store original size for scaling
	var original_pivot = highlight_panel.size / 2
	highlight_panel.pivot_offset = original_pivot
	
	pulse_tween.tween_property(highlight_panel, "scale", Vector2(PULSE_SCALE_MAX, PULSE_SCALE_MAX), PULSE_DURATION / 2)
	pulse_tween.tween_property(highlight_panel, "scale", Vector2(PULSE_SCALE_MIN, PULSE_SCALE_MIN), PULSE_DURATION / 2)


## _start_bounce_animation()
##
## Starts the bouncing animation on the click indicator.
func _start_bounce_animation() -> void:
	if bounce_tween and bounce_tween.is_valid():
		bounce_tween.kill()
	
	# Store base Y position after layout
	await get_tree().process_frame
	var base_y = click_indicator.position.y
	
	bounce_tween = create_tween()
	bounce_tween.set_loops()
	bounce_tween.set_trans(Tween.TRANS_SINE)
	bounce_tween.set_ease(Tween.EASE_IN_OUT)
	
	bounce_tween.tween_property(click_indicator, "position:y", base_y - INDICATOR_BOUNCE_HEIGHT, INDICATOR_BOUNCE_DURATION / 2)
	bounce_tween.tween_property(click_indicator, "position:y", base_y, INDICATOR_BOUNCE_DURATION / 2)


## set_backdrop_visible(visible)
##
## Shows or hides the backdrop (useful if highlight should appear without dimming).
func set_backdrop_visible(visible_flag: bool) -> void:
	if backdrop:
		backdrop.visible = visible_flag


## set_highlight_color(color)
##
## Changes the highlight border color.
func set_highlight_color(color: Color) -> void:
	if highlight_panel:
		var style = highlight_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			var new_style = style.duplicate() as StyleBoxFlat
			new_style.border_color = color
			highlight_panel.add_theme_stylebox_override("panel", new_style)
	
	if click_indicator:
		click_indicator.add_theme_color_override("font_color", color)
