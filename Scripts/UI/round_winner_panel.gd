extends Control
class_name RoundWinnerPanel

## RoundWinnerPanel
##
## Displays when the player completes all 6 rounds (wins the game).
## Shows "You Win!" and round stats, with a "Next Channel" button
## that advances to the next difficulty channel and restarts.

signal next_channel_pressed
signal panel_closed

# References
var channel_manager = null

# UI Components
var overlay: ColorRect
var panel_container: PanelContainer
var title_label: Label
var channel_label: Label
var stats_vbox: VBoxContainer
var score_row: HBoxContainer
var target_row: HBoxContainer
var turns_row: HBoxContainer
var rounds_row: HBoxContainer
var next_channel_button: Button

# Stats data
var _final_score: int = 0
var _target_score: int = 0
var _turns_used: int = 0
var _current_channel: int = 1
var _rounds_completed: int = 6

# Font
var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

# Animation
var _animation_tween: Tween


func _ready() -> void:
	visible = false
	_build_ui()


## set_channel_manager(manager) -> void
##
## Sets the ChannelManager reference.
func set_channel_manager(manager) -> void:
	channel_manager = manager


## show_winner_panel(data: Dictionary) -> void
##
## Shows the winner panel with stats from the completed run.
## @param data: Dictionary containing:
##   - final_score: int - Total score achieved
##   - target_score: int - Challenge target score
##   - turns_used: int - Number of turns used
##   - current_channel: int - Current channel number
##   - rounds_completed: int - Number of rounds completed (should be 6)
func show_winner_panel(data: Dictionary) -> void:
	print("[RoundWinnerPanel] Showing winner panel with data:", data)
	
	_final_score = data.get("final_score", 0)
	_target_score = data.get("target_score", 0)
	_turns_used = data.get("turns_used", 0)
	_current_channel = data.get("current_channel", 1)
	_rounds_completed = data.get("rounds_completed", 6)
	
	_update_display()
	
	# Position to fill viewport
	var viewport = get_viewport()
	if viewport:
		var viewport_rect = viewport.get_visible_rect()
		global_position = Vector2.ZERO
		size = viewport_rect.size
		z_index = 100
	
	visible = true
	_animate_entrance()


## _build_ui() -> void
##
## Programmatically builds the winner panel UI.
func _build_ui() -> void:
	# Create semi-transparent overlay
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Create centered panel container
	panel_container = PanelContainer.new()
	panel_container.name = "WinnerPanel"
	panel_container.custom_minimum_size = Vector2(450, 500)
	panel_container.set_anchors_preset(Control.PRESET_CENTER)
	panel_container.offset_left = -225
	panel_container.offset_top = -250
	panel_container.offset_right = 225
	panel_container.offset_bottom = 250
	panel_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Load and apply theme
	var theme_path = "res://Resources/UI/powerup_hover_theme.tres"
	var panel_theme = load(theme_path) as Theme
	if panel_theme:
		panel_container.theme = panel_theme
	
	# Create custom StyleBox for winner panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.08, 0.98)
	style.border_color = Color(0.4, 0.8, 0.3, 1.0)
	style.set_border_width_all(5)
	style.set_corner_radius_all(16)
	panel_container.add_theme_stylebox_override("panel", style)
	
	overlay.add_child(panel_container)
	
	# Main vertical container
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 15)
	panel_container.add_child(main_vbox)
	
	# Add margin container for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	main_vbox.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(content_vbox)
	
	# Title - "YOU WIN!"
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "YOU WIN!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", vcr_font)
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	content_vbox.add_child(title_label)
	
	# Channel label
	channel_label = Label.new()
	channel_label.name = "ChannelLabel"
	channel_label.text = "Channel 01 Complete!"
	channel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	channel_label.add_theme_font_override("font", vcr_font)
	channel_label.add_theme_font_size_override("font_size", 22)
	channel_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	content_vbox.add_child(channel_label)
	
	# Separator
	var sep1 = HSeparator.new()
	content_vbox.add_child(sep1)
	
	# Stats section
	var stats_title = Label.new()
	stats_title.text = "ROUND STATS"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_override("font", vcr_font)
	stats_title.add_theme_font_size_override("font_size", 20)
	stats_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	content_vbox.add_child(stats_title)
	
	stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 10)
	content_vbox.add_child(stats_vbox)
	
	# Score achieved
	score_row = _create_stat_row("Final Score:", "0")
	stats_vbox.add_child(score_row)
	
	# Target score
	target_row = _create_stat_row("Target Score:", "0")
	stats_vbox.add_child(target_row)
	
	# Turns used
	turns_row = _create_stat_row("Turns Used:", "0")
	stats_vbox.add_child(turns_row)
	
	# Rounds completed
	rounds_row = _create_stat_row("Rounds:", "6/6")
	stats_vbox.add_child(rounds_row)
	
	# Separator
	var sep2 = HSeparator.new()
	content_vbox.add_child(sep2)
	
	# Next channel info
	var next_info = Label.new()
	next_info.text = "Ready for the next challenge?"
	next_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_info.add_theme_font_override("font", vcr_font)
	next_info.add_theme_font_size_override("font_size", 16)
	next_info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	content_vbox.add_child(next_info)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	content_vbox.add_child(spacer)
	
	# Next Channel button
	next_channel_button = Button.new()
	next_channel_button.name = "NextChannelButton"
	next_channel_button.text = "NEXT CHANNEL"
	next_channel_button.custom_minimum_size = Vector2(250, 60)
	next_channel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_channel_button.add_theme_font_override("font", vcr_font)
	next_channel_button.add_theme_font_size_override("font_size", 22)
	
	# Create button style
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.5, 0.25, 1.0)
	btn_style.border_color = Color(0.3, 0.8, 0.35, 1.0)
	btn_style.set_border_width_all(3)
	btn_style.set_corner_radius_all(12)
	next_channel_button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.6, 0.3, 1.0)
	btn_hover.border_color = Color(0.4, 1.0, 0.45, 1.0)
	next_channel_button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.15, 0.4, 0.2, 1.0)
	next_channel_button.add_theme_stylebox_override("pressed", btn_pressed)
	
	next_channel_button.pressed.connect(_on_next_channel_pressed)
	content_vbox.add_child(next_channel_button)


## _create_stat_row(label_text: String, value_text: String) -> HBoxContainer
##
## Creates a stat row with label and value.
func _create_stat_row(label_text: String, value_text: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", vcr_font)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hbox.add_child(label)
	
	var value = Label.new()
	value.name = "Value"
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_override("font", vcr_font)
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	hbox.add_child(value)
	
	return hbox


## _update_display() -> void
##
## Updates all display elements with current stats.
func _update_display() -> void:
	channel_label.text = "Channel %02d Complete!" % _current_channel
	
	# Update stat values
	var score_value = score_row.get_node("Value") as Label
	if score_value:
		score_value.text = str(_final_score)
	
	var target_value = target_row.get_node("Value") as Label
	if target_value:
		target_value.text = str(_target_score)
	
	var turns_value = turns_row.get_node("Value") as Label
	if turns_value:
		turns_value.text = str(_turns_used)
	
	var rounds_value = rounds_row.get_node("Value") as Label
	if rounds_value:
		rounds_value.text = "%d/6" % _rounds_completed
	
	# Update button text with next channel info
	if channel_manager:
		var max_channel = 20
		if channel_manager.get("MAX_CHANNEL"):
			max_channel = channel_manager.MAX_CHANNEL
		var next_channel = mini(_current_channel + 1, max_channel)
		var next_mult = channel_manager.get_difficulty_multiplier(next_channel)
		next_channel_button.text = "NEXT: CH %02d (%.1fx)" % [next_channel, next_mult]


## _on_next_channel_pressed() -> void
##
## Handles the next channel button being pressed.
func _on_next_channel_pressed() -> void:
	print("[RoundWinnerPanel] Next channel button pressed")
	_hide_panel()
	emit_signal("next_channel_pressed")


## _hide_panel() -> void
##
## Animates the panel hiding.
func _hide_panel() -> void:
	if _animation_tween:
		_animation_tween.kill()
	
	_animation_tween = create_tween()
	_animation_tween.set_parallel(true)
	
	_animation_tween.tween_property(overlay, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	_animation_tween.tween_property(panel_container, "scale", Vector2(0.8, 0.8), 0.2)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	await _animation_tween.finished
	
	visible = false
	emit_signal("panel_closed")


## _animate_entrance() -> void
##
## Animates the panel appearing with celebration effects.
func _animate_entrance() -> void:
	if _animation_tween:
		_animation_tween.kill()
	
	panel_container.scale = Vector2(0.3, 0.3)
	panel_container.modulate.a = 0.0
	overlay.modulate.a = 0.0
	title_label.modulate.a = 0.0
	
	_animation_tween = create_tween()
	
	# Fade in overlay
	_animation_tween.tween_property(overlay, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	# Scale and fade in panel
	_animation_tween.parallel().tween_property(panel_container, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	_animation_tween.parallel().tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.5)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	
	# Delayed title flash
	_animation_tween.tween_property(title_label, "modulate:a", 1.0, 0.2)\
		.set_delay(0.3)
	
	# Title pulse animation
	await _animation_tween.finished
	_animate_title_pulse()


## _animate_title_pulse() -> void
##
## Creates a pulsing glow effect on the title.
func _animate_title_pulse() -> void:
	var pulse_tween = create_tween()
	pulse_tween.set_loops(3)
	
	pulse_tween.tween_property(title_label, "modulate", Color(0.5, 1.0, 0.6), 0.3)\
		.set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(title_label, "modulate", Color(1.0, 1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_SINE)


## hide_panel() -> void
##
## Public method to hide the panel.
func hide_panel() -> void:
	_hide_panel()
