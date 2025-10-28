extends Control
class_name FloatingNumber

## FloatingNumber
##
## A reusable component for creating floating number effects that animate
## upward and fade out. Used for score values, bonuses, and other numeric feedback.

signal animation_complete

# Animation configuration
@export var float_speed: float = 50.0
@export var float_duration: float = 1.5
@export var base_font_size: int = 24
@export var fade_delay: float = 0.3

# Visual configuration
@export var default_color: Color = Color.YELLOW
@export var outline_color: Color = Color.BLACK
@export var outline_size: int = 2

# VCR Font resource
const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

var label: Label
var animation_tween: Tween

## _ready()
##
## Initialize the floating number component.
func _ready() -> void:
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