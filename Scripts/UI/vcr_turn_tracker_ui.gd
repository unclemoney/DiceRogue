extends Control
class_name VCRTurnTrackerUI

# VCR-style Turn Tracker with dynamic animations
var tracker: TurnTracker
var _channel_manager = null
var _bound_round_manager: RoundManager = null


const COLOR_ORANGE: Color = Color(1.0, 0.729412, 0.490196, 1.0) # ffba7d
const COLOR_MAGENTA: Color = Color(0.901961, 0.450980, 0.556863, 1.0) # e6738e
const COLOR_PURPLE: Color = Color(0.431373, 0.317647, 0.611765, 1.0) # 6e519c
const COLOR_BLUE: Color = Color(0.403922, 0.572549, 0.670588, 1.0) # 6792ab
const COLOR_TEAL: Color = Color(0.549020, 0.729412, 0.662745, 1.0) # 8cbaa9

# Mall-core display colors
const TRACKER_TEXT := Color(0.968627, 0.941176, 1.0, 1.0)
const TRACKER_TEXT_ACCENT := Color(0.917647, 1.0, 0.984314, 1.0)
const TRACKER_TEXT_DIM := Color(0.713725, 0.301961, 0.478431, 0.75)
const TRACKER_BG := Color(0.247059, 0.219608, 0.345098, 0.96)
const TRACKER_BORDER := Color(0.901961, 0.450980, 0.556863, 0.09)
const TRACKER_SHADOW := Color(0.137255, 0.411765, 0.415686, 0.3)
const TRACKER_FLASH := Color(0.47451, 0.886275, 0.890196, 1.0)

# Node references with exported paths for flexibility
@export var round_manager_path: NodePath
@onready var round_manager: RoundManager = get_node_or_null(round_manager_path)

# VCR Display Elements
@onready var vcr_display: Control = $VCRDisplay
@onready var turn_label: Label = $VCRDisplay/TurnLabel
@onready var rolls_label: Label = $VCRDisplay/RollsLabel
@onready var round_label: Label = $VCRDisplay/RoundLabel
@onready var channel_panel: Panel = $VCRDisplay/ChannelPanel
@onready var channel_label: Label = $VCRDisplay/ChannelPanel/ChannelLabel

# Animation components
var turn_tween: Tween
var rolls_tween: Tween
var round_tween: Tween
var channel_tween: Tween

func _ready() -> void:
	add_to_group("turn_tracker_ui")
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_compact_layout()
	_setup_vcr_styling()
	_connect_signals()
	_initialize_display()


func _build_compact_layout() -> void:
	if not vcr_display:
		return

	vcr_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	vcr_display.mouse_filter = Control.MOUSE_FILTER_PASS

	var background = get_node_or_null("BACKGROUND")
	if background:
		background.visible = false

	var vignette = get_node_or_null("ColorRect")
	if vignette:
		vignette.visible = false

	if vcr_display.get_node_or_null("MetricMargin"):
		return

	var metric_margin := MarginContainer.new()
	metric_margin.name = "MetricMargin"
	metric_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	metric_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	metric_margin.add_theme_constant_override("margin_left", 4)
	metric_margin.add_theme_constant_override("margin_top", 4)
	metric_margin.add_theme_constant_override("margin_right", 4)
	metric_margin.add_theme_constant_override("margin_bottom", 4)
	vcr_display.add_child(metric_margin)

	var metric_grid := GridContainer.new()
	metric_grid.name = "MetricGrid"
	metric_grid.columns = 2
	metric_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metric_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	metric_grid.add_theme_constant_override("h_separation", 6)
	metric_grid.add_theme_constant_override("v_separation", 6)
	metric_margin.add_child(metric_grid)

	_wrap_metric_label(turn_label, metric_grid)
	_wrap_metric_label(rolls_label, metric_grid)
	_wrap_metric_label(round_label, metric_grid)
	_wrap_channel_panel(metric_grid)


func _wrap_metric_label(label: Label, metric_grid: GridContainer) -> void:
	if not is_instance_valid(label):
		return

	var card := PanelContainer.new()
	card.name = "%sCard" % label.name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 32)
	_apply_metric_style(card)
	metric_grid.add_child(card)

	label.reparent(card, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _wrap_channel_panel(metric_grid: GridContainer) -> void:
	if not is_instance_valid(channel_panel):
		return

	channel_panel.reparent(metric_grid, false)
	channel_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	channel_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	channel_panel.custom_minimum_size = Vector2(0, 32)
	_apply_metric_style(channel_panel)

	if channel_label:
		channel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		channel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _apply_metric_style(control: Control) -> void:
	#var style := StyleBoxFlat.new()
	var theme := preload("res://Resources/UI/action_button_theme.tres")
	var style: StyleBoxFlat = theme.get_stylebox("panel", "Control").duplicate()
	style.bg_color = TRACKER_BG
	style.border_color = TRACKER_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.corner_detail = 6
	style.shadow_color = TRACKER_SHADOW
	style.shadow_size = 4
	control.add_theme_stylebox_override("panel", style)

func _setup_vcr_styling() -> void:
	# Apply VCR font and styling to all labels
	var vcr_font := preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	
	if turn_label:
		turn_label.add_theme_font_override("font", vcr_font)
		turn_label.add_theme_font_size_override("font_size", 18)
		turn_label.add_theme_color_override("font_color", TRACKER_TEXT)
		turn_label.add_theme_color_override("font_outline_color", TRACKER_TEXT_DIM)
		turn_label.add_theme_constant_override("outline_size", 1)
	
	if rolls_label:
		rolls_label.add_theme_font_override("font", vcr_font)
		rolls_label.add_theme_font_size_override("font_size", 18)
		rolls_label.add_theme_color_override("font_color", TRACKER_TEXT)
		rolls_label.add_theme_color_override("font_outline_color", TRACKER_TEXT_DIM)
		rolls_label.add_theme_constant_override("outline_size", 1)
	
	if round_label:
		round_label.add_theme_font_override("font", vcr_font)
		round_label.add_theme_font_size_override("font_size", 18)
		round_label.add_theme_color_override("font_color", TRACKER_TEXT)
		round_label.add_theme_color_override("font_outline_color", TRACKER_TEXT_DIM)
		round_label.add_theme_constant_override("outline_size", 1)

	if channel_label:
		channel_label.add_theme_font_override("font", vcr_font)
		channel_label.add_theme_font_size_override("font_size", 18)
		channel_label.add_theme_color_override("font_color", TRACKER_TEXT_ACCENT)
		channel_label.add_theme_color_override("font_shadow_color", TRACKER_SHADOW)
		channel_label.add_theme_color_override("font_outline_color", TRACKER_TEXT_DIM)
		channel_label.add_theme_constant_override("outline_size", 1)
		channel_label.add_theme_constant_override("shadow_outline_size", 1)
		channel_label.add_theme_constant_override("shadow_offset_x", 0)
		channel_label.add_theme_constant_override("shadow_offset_y", 0)

func _connect_signals() -> void:
	# Connect to round manager if available
	if is_instance_valid(round_manager):
		bind_round_manager(round_manager)
	elif get_tree():
		var fallback_round_manager = get_tree().get_first_node_in_group("round_manager")
		if is_instance_valid(fallback_round_manager):
			bind_round_manager(fallback_round_manager)

func _initialize_display() -> void:
	if turn_label:
		turn_label.text = "TRN:--/13"

	if rolls_label:
		rolls_label.text = "RLL:--/3"

	var initial_round := 1
	if is_instance_valid(_bound_round_manager):
		initial_round = _bound_round_manager.get_current_round_number()
	_update_round_display(initial_round)

func bind_tracker(t: TurnTracker) -> void:
	if t == null:
		push_error("TurnTracker is null—cannot bind signals.")
		return

	if is_instance_valid(tracker):
		if tracker.turn_updated.is_connected(_on_turn_updated):
			tracker.turn_updated.disconnect(_on_turn_updated)
		if tracker.rolls_updated.is_connected(_on_rolls_updated):
			tracker.rolls_updated.disconnect(_on_rolls_updated)
		if tracker.max_rolls_changed.is_connected(_on_max_rolls_changed):
			tracker.max_rolls_changed.disconnect(_on_max_rolls_changed)

	tracker = t
	if not tracker.turn_updated.is_connected(_on_turn_updated):
		tracker.turn_updated.connect(_on_turn_updated)
	if not tracker.rolls_updated.is_connected(_on_rolls_updated):
		tracker.rolls_updated.connect(_on_rolls_updated)
	if not tracker.max_rolls_changed.is_connected(_on_max_rolls_changed):
		tracker.max_rolls_changed.connect(_on_max_rolls_changed)
	
	# Initialize display with current values
	_on_turn_updated(tracker.current_turn)
	_on_rolls_updated(tracker.rolls_left)


func _on_max_rolls_changed(_max_rolls: int) -> void:
	if tracker:
		_on_rolls_updated(tracker.rolls_left)

func _on_turn_updated(turn: int) -> void:
	if not tracker or not turn_label:
		return
	
	var max_turns := tracker.max_turns
	turn_label.text = "TRN:%s/%s" % [NumberFormatter.format_int(turn), NumberFormatter.format_int(max_turns)]
	turn_tween = _animate_label_change(turn_label, turn_tween)

func _on_rolls_updated(rolls: int) -> void:
	if not tracker or not rolls_label:
		return
	
	rolls_label.text = "RLL:%s/%s" % [NumberFormatter.format_int(rolls), NumberFormatter.format_int(tracker.MAX_ROLLS)]
	
	# Change color based on extra rolls
	if tracker.MAX_ROLLS > 3:
		rolls_label.add_theme_color_override("font_color", TRACKER_TEXT_ACCENT)
	else:
		rolls_label.add_theme_color_override("font_color", TRACKER_TEXT)
	
	rolls_tween = _animate_label_change(rolls_label, rolls_tween)


func bind_round_manager(rm: RoundManager) -> void:
	if rm == null:
		push_error("RoundManager is null—cannot bind signals.")
		return

	if is_instance_valid(_bound_round_manager) and _bound_round_manager.round_started.is_connected(_on_round_changed):
		_bound_round_manager.round_started.disconnect(_on_round_changed)

	_bound_round_manager = rm
	round_manager = rm

	if not round_manager.round_started.is_connected(_on_round_changed):
		round_manager.round_started.connect(_on_round_changed)

	_update_round_display(round_manager.get_current_round_number())

func _on_round_changed(round_number: int) -> void:
	_update_round_display(round_number)

func _update_round_display(round_number: int) -> void:
	if round_label:
		round_label.text = "RND:%s" % NumberFormatter.format_int(maxi(round_number, 1))
		round_tween = _animate_label_change(round_label, round_tween)

## bind_channel_manager(cm)
##
## Binds the ChannelManager to this UI, connecting channel_changed signal.
## Initializes the channel display from the manager's current state.
## Notes: Must be called after the ChannelManager node is ready.
func bind_channel_manager(cm) -> void:
	if cm == null:
		push_error("ChannelManager is null—cannot bind signals.")
		return

	if _channel_manager and _channel_manager.channel_changed.is_connected(_on_channel_changed):
		_channel_manager.channel_changed.disconnect(_on_channel_changed)

	_channel_manager = cm
	if not cm.channel_changed.is_connected(_on_channel_changed):
		cm.channel_changed.connect(_on_channel_changed)
	_update_channel_display(cm.current_channel)

func _on_channel_changed(channel: int) -> void:
	_update_channel_display(channel)
	channel_tween = _animate_label_change(channel_label, channel_tween)

func _update_channel_display(channel: int) -> void:
	if channel_label:
		channel_label.text = "CH:%02d" % channel

func _animate_label_change(label: Label, tween_ref: Tween) -> Tween:
	if not label:
		return tween_ref
	
	# Kill existing tween for this label
	if tween_ref and tween_ref.is_valid():
		tween_ref.kill()
	
	var next_tween = create_tween()
	next_tween.set_parallel(true)
	var original_color := label.get_theme_color("font_color")
	var highlight_target := TRACKER_FLASH
	if label == channel_label:
		highlight_target = Color(0.886275, 0.560784, 0.72549, 1.0)
	var highlighted_color := original_color.lerp(highlight_target, 0.5)
	
	# Punchy scale bounce
	next_tween.tween_method(func(s): label.scale = Vector2(s, s), 1.0, 1.18, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	next_tween.tween_method(func(s): label.scale = Vector2(s, s), 1.18, 1.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Color flash
	next_tween.tween_method(
		func(color): label.add_theme_color_override("font_color", color),
		original_color,
		highlighted_color,
		0.08
	)
	next_tween.tween_method(
		func(color): label.add_theme_color_override("font_color", color),
		highlighted_color,
		original_color,
		0.2
	)

	return next_tween


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
		rolls_label.add_theme_color_override("font_color", TRACKER_TEXT)

	if round_label:
		round_label.text = "RND:--"

	# NOTE: Do NOT reset channel_label here — it was already updated
	# correctly by the channel_changed signal before this function is called.
	# Blanking it would overwrite the correct "Channel: XX" text.