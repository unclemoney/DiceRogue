extends Control
class_name VCRTurnTrackerUI

# VCR-style Turn Tracker with dynamic animations
var tracker: TurnTracker
var _channel_manager = null

# VCR Display Colors
const VCR_GREEN := Color(0.2, 1.0, 0.3, 1.0)
const VCR_GREEN_BRIGHT := Color(0.4, 1.0, 0.5, 1.0)
const VCR_GREEN_DIM := Color(0.1, 0.8, 0.2, 1.0)

# Node references with exported paths for flexibility
@export var round_manager_path: NodePath
@onready var round_manager: RoundManager = get_node_or_null(round_manager_path)

# VCR Display Elements
@onready var turn_label: Label = $VCRDisplay/TurnLabel
@onready var rolls_label: Label = $VCRDisplay/RollsLabel
@onready var round_label: Label = $VCRDisplay/RoundLabel
@onready var channel_label: Label = $VCRDisplay/ChannelPanel/ChannelLabel

# Animation components
@onready var turn_tween: Tween
@onready var rolls_tween: Tween
@onready var round_tween: Tween
var channel_tween: Tween

func _ready() -> void:
	add_to_group("turn_tracker_ui")
	_setup_vcr_styling()
	_connect_signals()
	_initialize_display()

func _setup_vcr_styling() -> void:
	# Apply VCR font and styling to all labels
	var vcr_font := preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	
	if turn_label:
		turn_label.add_theme_font_override("font", vcr_font)
		turn_label.add_theme_font_size_override("font_size", 20)
		turn_label.add_theme_color_override("font_color", VCR_GREEN)
	
	if rolls_label:
		rolls_label.add_theme_font_override("font", vcr_font)
		rolls_label.add_theme_font_size_override("font_size", 20)
		rolls_label.add_theme_color_override("font_color", VCR_GREEN)
	
	if round_label:
		round_label.add_theme_font_override("font", vcr_font)
		round_label.add_theme_font_size_override("font_size", 20)
		round_label.add_theme_color_override("font_color", VCR_GREEN)

	if channel_label:
		channel_label.add_theme_font_override("font", vcr_font)
		channel_label.add_theme_font_size_override("font_size", 16)
		channel_label.add_theme_color_override("font_color", VCR_GREEN_BRIGHT)
		channel_label.add_theme_color_override("font_shadow_color", VCR_GREEN_DIM)
		channel_label.add_theme_constant_override("shadow_outline_size", 1)
		channel_label.add_theme_constant_override("shadow_offset_x", 0)
		channel_label.add_theme_constant_override("shadow_offset_y", 0)

func _connect_signals() -> void:
	# Connect to round manager if available
	if round_manager:
		round_manager.round_started.connect(_on_round_changed)

func _initialize_display() -> void:
	_update_round_display(1)  # Default to round 1

func bind_tracker(t: TurnTracker) -> void:
	if t == null:
		push_error("TurnTracker is null—cannot bind signals.")
		return
	
	tracker = t
	tracker.turn_updated.connect(_on_turn_updated)
	tracker.rolls_updated.connect(_on_rolls_updated)
	tracker.max_rolls_changed.connect(func(_max_rolls): _on_rolls_updated(tracker.rolls_left))
	
	# Initialize display with current values
	_on_turn_updated(tracker.current_turn)
	_on_rolls_updated(tracker.rolls_left)

func _on_turn_updated(turn: int) -> void:
	if not tracker or not turn_label:
		return
	
	var max_turns := tracker.max_turns
	turn_label.text = "TRN:%s/%s" % [NumberFormatter.format_int(turn), NumberFormatter.format_int(max_turns)]
	_animate_label_change(turn_label, turn_tween)

func _on_rolls_updated(rolls: int) -> void:
	if not tracker or not rolls_label:
		return
	
	rolls_label.text = "RLL:%s/%s" % [NumberFormatter.format_int(rolls), NumberFormatter.format_int(tracker.MAX_ROLLS)]
	
	# Change color based on extra rolls
	if tracker.MAX_ROLLS > 3:
		rolls_label.add_theme_color_override("font_color", VCR_GREEN_BRIGHT)
	else:
		rolls_label.add_theme_color_override("font_color", VCR_GREEN)
	
	_animate_label_change(rolls_label, rolls_tween)

func _on_round_changed(round_number: int) -> void:
	_update_round_display(round_number)

func _update_round_display(round_number: int) -> void:
	if round_label:
		round_label.text = "RND:%s" % NumberFormatter.format_int(round_number)
		_animate_label_change(round_label, round_tween)

## bind_channel_manager(cm)
##
## Binds the ChannelManager to this UI, connecting channel_changed signal.
## Initializes the channel display from the manager's current state.
## Notes: Must be called after the ChannelManager node is ready.
func bind_channel_manager(cm) -> void:
	if cm == null:
		push_error("ChannelManager is null—cannot bind signals.")
		return
	_channel_manager = cm
	cm.channel_changed.connect(_on_channel_changed)
	_update_channel_display(cm.current_channel)

func _on_channel_changed(channel: int) -> void:
	_update_channel_display(channel)
	_animate_label_change(channel_label, channel_tween)

func _update_channel_display(channel: int) -> void:
	if channel_label:
		channel_label.text = "Channel: %02d" % channel

func _animate_label_change(label: Label, tween_ref: Tween) -> void:
	if not label:
		return
	
	# Kill existing tween for this label
	if tween_ref:
		tween_ref.kill()
	
	tween_ref = create_tween()
	tween_ref.set_parallel(true)
	
	# Subtle pulse animation
	tween_ref.tween_method(func(s): label.scale = Vector2(s, s), 1.0, 1.15, 0.1)
	tween_ref.tween_method(func(s): label.scale = Vector2(s, s), 1.15, 1.0, 0.15)
	
	# Brief color brightening
	var original_color := label.get_theme_color("font_color")
	tween_ref.tween_method(
		func(color): label.add_theme_color_override("font_color", color),
		original_color,
		VCR_GREEN_BRIGHT,
		0.1
	)
	tween_ref.tween_method(
		func(color): label.add_theme_color_override("font_color", color),
		VCR_GREEN_BRIGHT,
		original_color,
		0.15
	)


## reset_for_new_channel()
##
## Resets the VCR display to initial state (blank/waiting) for new channel.
## Called when player advances to a new channel.
func reset_for_new_channel() -> void:
	print("[VCRTurnTrackerUI] Resetting display for new channel")
	
	if turn_label:
		turn_label.text = "TRN:--/13"

	if rolls_label:
		rolls_label.text = "RLL:--/3"
		rolls_label.add_theme_color_override("font_color", VCR_GREEN)

	if round_label:
		round_label.text = "RND:--"

	# NOTE: Do NOT reset channel_label here — it was already updated
	# correctly by the channel_changed signal before this function is called.
	# Blanking it would overwrite the correct "Channel: XX" text.