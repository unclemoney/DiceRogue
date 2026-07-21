extends Control
class_name RoundWinnerPanel

const GlassActionButtonClass = preload("res://Scripts/UI/glass_action_button.gd")

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
var rolls_row: HBoxContainer
var consumables_row: HBoxContainer
var turns_row: HBoxContainer
var rounds_row: HBoxContainer
var backdrop_fx_rect: ColorRect
var next_channel_button = null

# Stats data
var _final_score: int = 0
var _target_score: int = 0
var _turns_used: int = 0
var _current_channel: int = 1
var _rounds_completed: int = 6
var _rolls_used: int = 0
var _consumables_used: int = 0

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
##   - rolls_used: int - Rolls used across the zone's rounds
##   - consumables_used: int - Consumables used across the zone's rounds
func show_winner_panel(data: Dictionary) -> void:
	print("[RoundWinnerPanel] Showing winner panel with data:", data)
	
	_final_score = data.get("final_score", 0)
	_target_score = data.get("target_score", 0)
	_turns_used = data.get("turns_used", 0)
	_current_channel = data.get("current_channel", 1)
	_rounds_completed = data.get("rounds_completed", 6)
	_rolls_used = data.get("rolls_used", 0)
	_consumables_used = data.get("consumables_used", 0)
	
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
	style.bg_color = Color(0.247059, 0.219608, 0.345098, 0.98)
	style.border_color = Color(0.713725, 0.301961, 0.478431, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.corner_detail = 8
	style.shadow_color = Color(0.714, 0.302, 0.478, 0.6)
	style.shadow_size = 14
	panel_container.add_theme_stylebox_override("panel", style)
	
	overlay.add_child(panel_container)
	
	# Shader backdrop behind panel content (gradient/vignette/grain overlay)
	backdrop_fx_rect = _create_backdrop_fx_rect()
	if not panel_container.resized.is_connected(_update_backdrop_fx_rect_size):
		panel_container.resized.connect(_update_backdrop_fx_rect_size)
	call_deferred("_update_backdrop_fx_rect_size")
	
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
	title_label.add_theme_color_override("font_color", Color(0.47451, 0.886275, 0.890196, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
	title_label.add_theme_constant_override("outline_size", 1)
	content_vbox.add_child(title_label)
	
	# Channel label
	channel_label = Label.new()
	channel_label.name = "ChannelLabel"
	channel_label.text = "Mall Zone 01 Complete!"
	channel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	channel_label.add_theme_font_override("font", vcr_font)
	channel_label.add_theme_font_size_override("font_size", 22)
	channel_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	channel_label.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
	channel_label.add_theme_constant_override("outline_size", 1)
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
	stats_title.add_theme_color_override("font_color", Color(0.780392, 0.733333, 0.866667, 1.0))
	stats_title.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
	stats_title.add_theme_constant_override("outline_size", 1)
	content_vbox.add_child(stats_title)
	
	stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 10)
	content_vbox.add_child(stats_vbox)
	
	# Score achieved
	score_row = _create_stat_row("Total Points Scored:", "0")
	stats_vbox.add_child(score_row)
	
	# Target score
	target_row = _create_stat_row("Target Score:", "0")
	stats_vbox.add_child(target_row)
	
	# Rolls used across the zone
	rolls_row = _create_stat_row("Rolls Used:", "0")
	stats_vbox.add_child(rolls_row)
	
	# Consumables used across the zone
	consumables_row = _create_stat_row("Consumables Used:", "0")
	stats_vbox.add_child(consumables_row)
	
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
	next_info.add_theme_color_override("font_color", Color(0.780392, 0.733333, 0.866667, 1.0))
	next_info.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
	next_info.add_theme_constant_override("outline_size", 1)
	content_vbox.add_child(next_info)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	content_vbox.add_child(spacer)
	
	# Next Channel button
	next_channel_button = GlassActionButtonClass.new()
	next_channel_button.name = "NextChannelButton"
	next_channel_button.configure(
		"NEXT MALL ZONE",
		Vector2(320, 60),
		{
			"base_color": Color(0.137255, 0.411765, 0.415686, 0.92),
			"mid_color": Color(0.2, 0.56, 0.56, 0.96),
			"accent_color": Color(0.47451, 0.886275, 0.890196, 1.0),
			"glow_color": Color(0.6, 0.94, 0.96, 1.0),
			"rim_color": Color(0.968627, 0.941176, 1.0, 1.0),
			"font_color": Color(0.968627, 0.941176, 1.0, 1.0),
			"font_outline_color": Color(0.129412, 0.121569, 0.2, 1.0),
			"outline_size": 1
		},
		22,
		vcr_font
	)
	next_channel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
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


## _create_backdrop_fx_rect() -> ColorRect
## Builds a full-rect ColorRect with the panel backdrop shader and inserts it
## behind the WinnerPanel's other children so content draws on top.
func _create_backdrop_fx_rect() -> ColorRect:
	var fx_rect = ColorRect.new()
	fx_rect.name = "BackdropFxRect"
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_rect.color = Color.WHITE
	var shader_path = "res://Scripts/Shaders/panel_backdrop.gdshader"
	var shader = load(shader_path) as Shader
	if shader:
		var fx_material = ShaderMaterial.new()
		fx_material.shader = shader
		fx_material.set_shader_parameter("corner_radius", 20.0)
		fx_rect.material = fx_material
	else:
		push_error("[RoundWinnerPanel] Failed to load shader: " + shader_path)
	panel_container.add_child(fx_rect)
	panel_container.move_child(fx_rect, 0)
	return fx_rect


## _update_backdrop_fx_rect_size()
## Pushes the panel's current size into the backdrop shader so its rounded
## mask tracks layout. Called on build and whenever the panel resizes.
func _update_backdrop_fx_rect_size() -> void:
	if backdrop_fx_rect and backdrop_fx_rect.material and panel_container:
		var panel_size = panel_container.size
		if panel_size.x <= 0.0 or panel_size.y <= 0.0:
			panel_size = panel_container.custom_minimum_size
		(backdrop_fx_rect.material as ShaderMaterial).set_shader_parameter("rect_size", panel_size)


## _update_display() -> void
##
## Updates all display elements with current stats.
func _update_display() -> void:
	channel_label.text = "Mall Zone %02d Complete!" % _current_channel
	
	# Update stat values
	var score_value = score_row.get_node("Value") as Label
	if score_value:
		score_value.text = NumberFormatter.format_score(_final_score)
	
	var target_value = target_row.get_node("Value") as Label
	if target_value:
		target_value.text = NumberFormatter.format_score(_target_score)
	
	var rolls_value = rolls_row.get_node("Value") as Label
	if rolls_value:
		rolls_value.text = NumberFormatter.format_int(_rolls_used)
	
	var consumables_value = consumables_row.get_node("Value") as Label
	if consumables_value:
		consumables_value.text = NumberFormatter.format_int(_consumables_used)
	
	var turns_value = turns_row.get_node("Value") as Label
	if turns_value:
		turns_value.text = NumberFormatter.format_int(_turns_used)
	
	var rounds_value = rounds_row.get_node("Value") as Label
	if rounds_value:
		rounds_value.text = "%s/6" % NumberFormatter.format_int(_rounds_completed)
	
	# Update button text with next channel info
	if channel_manager:
		var max_channel = 20
		if channel_manager.get("MAX_CHANNEL"):
			max_channel = channel_manager.MAX_CHANNEL
		var next_channel = mini(_current_channel + 1, max_channel)
		next_channel_button.set_button_text("NEXT: MALL ZONE %02d" % next_channel)


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
