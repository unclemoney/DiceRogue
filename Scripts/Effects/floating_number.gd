extends Control
class_name FloatingNumber

## FloatingNumber
##
## A reusable component for creating floating number effects that animate
## upward and fade out. Used for score values, bonuses, and other numeric feedback.

signal animation_complete

# Animation configuration
@export var float_speed: float = 750.0
@export var float_duration: float = 1.25
@export var base_font_size: int = 24
@export var fade_delay: float = 0.3

# Visual configuration
@export var default_color: Color = Color.YELLOW
@export var outline_color: Color = Color.BLACK
@export var outline_size: int = 4

# Panel configuration
@export var panel_padding: int = 8
@export var panel_color: Color = Color(0, 0, 0, 1)

# Dark color palette the panel randomly picks from
const PANEL_DARK_COLORS: Array = [
	Color(0.0,  0.0,  0.0,  1.0),  # Black
	Color(0.05, 0.05, 0.2,  1.0),  # Dark navy
	Color(0.15, 0.0,  0.0,  1.0),  # Dark crimson
	Color(0.0,  0.1,  0.0,  1.0),  # Dark forest green
	Color(0.1,  0.0,  0.15, 1.0),  # Dark purple
	Color(0.0,  0.1,  0.1,  1.0),  # Dark teal
	Color(0.12, 0.06, 0.0,  1.0),  # Dark brown
	Color(0.08, 0.08, 0.08, 1.0),  # Very dark gray
]

# VCR Font resource
const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

var panel: ColorRect
var label: Label
var animation_tween: Tween

## _ready()
##
## Initialize the floating number component.
func _ready() -> void:
	# Create background panel (added first so it renders behind label)
	panel = ColorRect.new()
	panel.color = panel_color
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	
	# Create the label
	label = Label.new()
	add_child(label)
	
	# Set up basic properties
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## setup(value, font_size_scale, color)
##
## Configure the floating number with text, size, and color.
func setup(value: String, font_size_scale: float = 1.0, color: Color = default_color) -> void:
	if not label:
		push_error("[FloatingNumber] Label not initialized!")
		return
	
	label.text = value
	
	# Calculate font size
	var final_font_size = int(base_font_size * font_size_scale)
	
	# Apply VCR font and styling
	label.add_theme_font_override("font", VCR_FONT)
	label.add_theme_font_size_override("font_size", final_font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	
	# Center the label
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# Size and position the background panel, apply random rotation
	_setup_panel()

## _setup_panel()
##
## Size the background panel to a square based on label text size,
## center it behind the label, and randomly rotate ONLY the panel (0° or 45°).
## The label is never rotated so text always reads upright.
func _setup_panel() -> void:
	if not panel or not label:
		return
	
	# Get the label's natural text size after theme overrides are applied
	var label_min = label.get_minimum_size()
	
	# Make the panel square using the largest dimension + padding
	var side = max(label_min.x, label_min.y) + panel_padding * 2
	panel.size = Vector2(side, side)
	
	# Center the square panel at the node origin (same center as the label)
	panel.position = Vector2(-side / 2.0, -side / 2.0)
	
	# Set panel pivot to its own center so rotation stays centered behind the text
	panel.pivot_offset = Vector2(side / 2.0, side / 2.0)
	
	# Center label at the node origin (always upright, never rotated)
	label.position = Vector2(-label_min.x / 2.0, -label_min.y / 2.0)
	label.rotation = 0.0
	
	# Randomly rotate ONLY the panel — the label is unaffected
	var angles = [0.0, PI / 4.0]
	panel.rotation = angles[randi() % 2]
	
	# Pick a random dark color from the palette
	panel.color = PANEL_DARK_COLORS[randi() % PANEL_DARK_COLORS.size()]

## start_animation()
##
## Begin the floating animation sequence.
func start_animation() -> void:
	if animation_tween and animation_tween.is_valid():
		animation_tween.kill()
	
	animation_tween = create_tween()
	animation_tween.set_parallel(true)
	
	var start_position = global_position
	var end_position = start_position + Vector2(0, -float_speed)
	
	# Animate position upward
	animation_tween.tween_property(self, "global_position", end_position, float_duration)
	
	# Fade out after delay
	animation_tween.tween_property(self, "modulate:a", 0.0, float_duration - fade_delay).set_delay(fade_delay)
	
	# Emit completion signal and remove self
	animation_tween.tween_callback(_on_animation_complete).set_delay(float_duration)

## _on_animation_complete()
##
## Handle animation completion cleanup.
func _on_animation_complete() -> void:
	animation_complete.emit()
	queue_free()

## create_floating_number(parent, target_position, value, font_scale, color)
##
## Static utility function to create and start a floating number effect.
static func create_floating_number(parent: Node, target_position: Vector2, value: String, 
	font_scale: float = 1.0, color: Color = Color.YELLOW) -> FloatingNumber:
	
	var floating_number = preload("res://Scripts/Effects/floating_number.gd").new()
	parent.add_child(floating_number)
	
	floating_number.global_position = target_position
	floating_number.setup(value, font_scale, color)
	floating_number.start_animation()
	
	return floating_number