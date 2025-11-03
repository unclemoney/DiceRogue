extends Control
class_name VCRTurnTrackerUI

# VCR-style Turn Tracker with dynamic animations
var tracker: TurnTracker
var previous_money: int = 0

# VCR Display Colors
const VCR_GREEN := Color(0.2, 1.0, 0.3, 1.0)
const VCR_GREEN_BRIGHT := Color(0.4, 1.0, 0.5, 1.0)
const VCR_GREEN_DIM := Color(0.1, 0.8, 0.2, 1.0)

# Node references with exported paths for flexibility
@export var round_manager_path: NodePath
@onready var round_manager: RoundManager = get_node_or_null(round_manager_path)

# VCR Display Elements
@onready var money_label: Label = $VCRDisplay/MoneyLabel
@onready var turn_label: Label = $VCRDisplay/TurnLabel
@onready var rolls_label: Label = $VCRDisplay/RollsLabel
@onready var round_label: Label = $VCRDisplay/RoundLabel

# Animation components
@onready var money_tween: Tween
@onready var turn_tween: Tween
@onready var rolls_tween: Tween
@onready var round_tween: Tween

func _ready() -> void:
	_setup_vcr_styling()
	_connect_signals()
	_initialize_display()

func _setup_vcr_styling() -> void:
	# Apply VCR font and styling to all labels
	var vcr_font := preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	
	if money_label:
		money_label.add_theme_font_override("font", vcr_font)
		money_label.add_theme_font_size_override("font_size", 20)
		money_label.add_theme_color_override("font_color", VCR_GREEN)
	
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

func _connect_signals() -> void:
	# Connect to economy changes for money animations
	PlayerEconomy.money_changed.connect(_on_money_changed)
	previous_money = PlayerEconomy.money
	
	# Connect to round manager if available
	if round_manager:
		round_manager.round_started.connect(_on_round_changed)

func _initialize_display() -> void:
	_update_money_display()
	_update_round_display(1)  # Default to round 1

func bind_tracker(t: TurnTracker) -> void:
	if t == null:
		push_error("TurnTracker is null—cannot bind signals.")
		return
	
	tracker = t
	tracker.turn_updated.connect(_on_turn_updated)
	tracker.rolls_updated.connect(_on_rolls_updated)
	tracker.max_rolls_changed.connect(func(max_rolls): _on_rolls_updated(tracker.rolls_left))
	
	# Initialize display with current values
	_on_turn_updated(tracker.current_turn)
	_on_rolls_updated(tracker.rolls_left)

func _on_money_changed(new_amount: int, _change: int = 0) -> void:
	var money_gained := new_amount - previous_money
	previous_money = new_amount
	
	_update_money_display()
	_animate_money_change(money_gained)

func _update_money_display() -> void:
	if money_label:
		money_label.text = "$%d" % PlayerEconomy.money

func _animate_money_change(amount_gained: int) -> void:
	if not money_label or amount_gained == 0:
		return
	
	# Kill existing tween
	if money_tween:
		money_tween.kill()
	
	money_tween = create_tween()
	money_tween.set_parallel(true)
	
	# Scale bounce intensity based on amount gained
	var bounce_scale := 1.0
	var flash_intensity := 0.0
	
	if amount_gained > 0:
		# Positive money gain - bigger bounce for larger amounts
		bounce_scale = 1.0 + min(amount_gained * 0.02, 0.5)  # Cap at 1.5x scale
		flash_intensity = min(amount_gained * 0.1, 1.0)  # Brighter flash for more money
		
		# Scale animation
		money_tween.tween_method(_set_money_scale, 1.0, bounce_scale, 0.15)
		money_tween.tween_method(_set_money_scale, bounce_scale, 1.0, 0.25)
		
		# Color flash animation
		money_tween.tween_method(_set_money_color_flash, 0.0, flash_intensity, 0.1)
		money_tween.tween_method(_set_money_color_flash, flash_intensity, 0.0, 0.3)
	else:
		# Negative money - subtle red flash
		money_tween.tween_method(_set_money_color_negative, 0.0, 1.0, 0.1)
		money_tween.tween_method(_set_money_color_negative, 1.0, 0.0, 0.3)

func _set_money_scale(scale_value: float) -> void:
	if money_label:
		money_label.scale = Vector2(scale_value, scale_value)

func _set_money_color_flash(intensity: float) -> void:
	if money_label:
		var flash_color := VCR_GREEN.lerp(VCR_GREEN_BRIGHT, intensity)
		money_label.add_theme_color_override("font_color", flash_color)

func _set_money_color_negative(intensity: float) -> void:
	if money_label:
		var negative_color := VCR_GREEN.lerp(Color.RED, intensity * 0.5)
		money_label.add_theme_color_override("font_color", negative_color)

func _on_turn_updated(turn: int) -> void:
	if not tracker or not turn_label:
		return
	
	var max_turns := tracker.max_turns
	turn_label.text = "T:%d/%d" % [turn, max_turns]
	_animate_label_change(turn_label, turn_tween)

func _on_rolls_updated(rolls: int) -> void:
	if not tracker or not rolls_label:
		return
	
	rolls_label.text = "R:%d/%d" % [rolls, tracker.MAX_ROLLS]
	
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
		round_label.text = "RND:%d" % round_number
		_animate_label_change(round_label, round_tween)

func _animate_label_change(label: Label, tween_ref: Tween) -> void:
	if not label:
		return
	
	# Kill existing tween for this label
	if tween_ref:
		tween_ref.kill()
	
	tween_ref = create_tween()
	tween_ref.set_parallel(true)
	
	# Subtle pulse animation
	tween_ref.tween_method(func(scale): label.scale = Vector2(scale, scale), 1.0, 1.15, 0.1)
	tween_ref.tween_method(func(scale): label.scale = Vector2(scale, scale), 1.15, 1.0, 0.15)
	
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