extends Control
class_name CarryOverPanel

const GlassActionButtonClass = preload("res://Scripts/UI/glass_action_button.gd")

## CarryOverPanel
##
## Displays after the RoundWinnerPanel when advancing to the next channel.
## Allows the player to select which items to carry over based on the
## next channel's ChannelDifficultyData configuration.
## Emits carryover_confirmed with the selected types when player confirms.

signal carryover_confirmed(selected_types: Array[String])
signal panel_closed

# Configuration
var _allowed_count: int = 0
var _allowed_types: Array[String] = []
var _next_channel: int = 1

# Selection state
var _selected_types: Array[String] = []
var _toggle_buttons: Dictionary = {}  # type_string -> GlassActionButton
var _row_palettes: Dictionary = {}    # type_string -> {"base": Dictionary, "selected": Dictionary}

# Display names for carry-over types
const TYPE_DISPLAY_NAMES := {
	"power_ups": "Power-Ups",
	"consumables": "Consumables",
	"colored_dice": "Colored Dice",
	"mods": "Mods",
	"consoles": "Gaming Console",
	"money": "Money",
	"scorecard_levels": "Scorecard Levels"
}

# Colors for carry-over type labels — also used as the accent on each row's
# toggle button
const TYPE_COLORS := {
	"power_ups": Color(0.5, 0.9, 1.0),
	"consumables": Color(1.0, 0.7, 0.3),
	"colored_dice": Color(0.8, 0.5, 1.0),
	"mods": Color(0.4, 1.0, 0.6),
	"consoles": Color(1.0, 0.5, 0.5),
	"money": Color(1.0, 0.95, 0.4),
	"scorecard_levels": Color(0.7, 0.85, 1.0)
}

# Base palette for the carry-over toggle buttons, derived from the panel's
# purple style (matches the confirm button); accent_color/glow_color are
# overridden per row with TYPE_COLORS
const CARRYOVER_BUTTON_PALETTE := {
	"base_color": Color(0.3, 0.15, 0.5, 1.0),
	"mid_color": Color(0.4, 0.2, 0.6, 1.0),
	"accent_color": Color(0.6, 0.3, 0.9, 1.0),
	"glow_color": Color(0.7, 0.4, 1.0, 1.0),
	"rim_color": Color(0.968627, 0.941176, 1.0, 1.0),
	"font_color": Color(0.968627, 0.941176, 1.0, 1.0),
	"font_outline_color": Color(0.129412, 0.121569, 0.2, 1.0),
	"outline_size": 1
}

const BACKDROP_SHADER_PATH := "res://Scripts/Shaders/panel_backdrop.gdshader"
const PANEL_CORNER_RADIUS := 16.0

# UI Components
var overlay: ColorRect
var panel_container: PanelContainer
var backdrop_fx_rect: ColorRect
var title_label: Label
var subtitle_label: Label
var counter_label: Label
var rows_container: VBoxContainer
var confirm_button = null
var _type_rows: Array[Control] = []

# Font
var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

# Animation
var _animation_tween: Tween
var _is_animating: bool = false

@onready var _tfx := get_node("/root/TweenFXHelper")


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


## show_panel(allowed_count: int, allowed_types: Array[String], next_channel: int) -> void
##
## Shows the carry-over selection panel.
## @param allowed_count: Maximum number of items player can select
## @param allowed_types: Which carry-over categories are available
## @param next_channel: The channel number the player is advancing to
func show_panel(allowed_count: int, allowed_types: Array[String], next_channel: int) -> void:
	_allowed_count = allowed_count
	_allowed_types = allowed_types
	_next_channel = next_channel
	_selected_types.clear()
	_toggle_buttons.clear()
	_row_palettes.clear()
	_type_rows.clear()
	
	print("[CarryOverPanel] Showing panel for Channel %d: %d selections from %s" % [next_channel, allowed_count, str(allowed_types)])
	
	_rebuild_type_rows()
	_update_display()
	
	# Position to fill viewport — reset anchors to avoid conflicts with Node2D parent
	var viewport = get_viewport()
	if viewport:
		var viewport_rect = viewport.get_visible_rect()
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 0.0
		anchor_bottom = 0.0
		global_position = Vector2.ZERO
		size = viewport_rect.size
		z_index = 100
		
		# Re-center the panel container explicitly using its real content-fit
		# size — the panel grows past its 550px minimum when many rows exist,
		# so centering on custom_minimum_size pushes the bottom off screen.
		if panel_container:
			var panel_size = panel_container.get_combined_minimum_size()
			panel_container.size = panel_size
			panel_container.position = (viewport_rect.size - panel_size) / 2.0
	
	visible = true
	# Juice: panel swoosh sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_panel_swoosh"):
		audio_mgr.play_panel_swoosh()
	_animate_entrance()


## _build_ui() -> void
##
## Programmatically builds the carry-over panel UI.
func _build_ui() -> void:
	# Create semi-transparent overlay
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Create centered panel container — positioned explicitly in show_panel()
	panel_container = PanelContainer.new()
	panel_container.name = "CarryOverPanel"
	panel_container.custom_minimum_size = Vector2(480, 550)
	panel_container.size = Vector2(480, 550)
	
	# Create custom StyleBox with a soft purple border glow
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.12, 0.98)
	style.border_color = Color(0.6, 0.3, 0.9, 1.0)
	style.set_border_width_all(5)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.6, 0.3, 0.9, 0.6)
	style.shadow_size = 14
	panel_container.add_theme_stylebox_override("panel", style)
	
	# Add as sibling of overlay (NOT child) so overlay modulate doesn't
	# multiply with panel modulate during animations.
	add_child(panel_container)
	
	# Shader backdrop behind all panel content (gradient, vignette, grain, sheen)
	backdrop_fx_rect = _create_backdrop_fx_rect()
	panel_container.resized.connect(_update_backdrop_fx_size)
	
	# Main vertical container
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 8)
	panel_container.add_child(main_vbox)
	
	# Add margin container for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	main_vbox.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	content_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(content_vbox)
	
	# Title
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "CHOOSE YOUR CARRY-OVERS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", vcr_font)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	content_vbox.add_child(title_label)
	
	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = "Select up to 5 items to keep"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_override("font", vcr_font)
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	content_vbox.add_child(subtitle_label)
	
	# Separator
	var sep1 = HSeparator.new()
	content_vbox.add_child(sep1)
	
	# Counter label
	counter_label = Label.new()
	counter_label.name = "CounterLabel"
	counter_label.text = "0 / 5 selected"
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_label.add_theme_font_override("font", vcr_font)
	counter_label.add_theme_font_size_override("font_size", 18)
	counter_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	content_vbox.add_child(counter_label)
	
	# Toggle button rows container (populated dynamically)
	rows_container = VBoxContainer.new()
	rows_container.name = "RowsContainer"
	rows_container.add_theme_constant_override("separation", 6)
	content_vbox.add_child(rows_container)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	content_vbox.add_child(spacer)
	
	# Separator
	var sep2 = HSeparator.new()
	content_vbox.add_child(sep2)
	
	# Confirm button
	confirm_button = GlassActionButtonClass.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.configure(
		"CONFIRM",
		Vector2(250, 50),
		{
			"base_color": Color(0.3, 0.15, 0.5, 1.0),
			"mid_color": Color(0.4, 0.2, 0.6, 1.0),
			"accent_color": Color(0.6, 0.3, 0.9, 1.0),
			"glow_color": Color(0.7, 0.4, 1.0, 1.0),
			"rim_color": Color(0.968627, 0.941176, 1.0, 1.0),
			"font_color": Color(0.968627, 0.941176, 1.0, 1.0),
			"font_outline_color": Color(0.129412, 0.121569, 0.2, 1.0),
			"outline_size": 1
		},
		22,
		vcr_font
	)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	confirm_button.pressed.connect(_on_confirm_pressed)
	content_vbox.add_child(confirm_button)


## _create_backdrop_fx_rect() -> ColorRect
## Builds a full-rect ColorRect with the panel backdrop shader and inserts it
## as the panel's first child so content draws on top. Mirrors the FX-rect
## pattern used by ShopItem.
func _create_backdrop_fx_rect() -> ColorRect:
	var fx_rect := ColorRect.new()
	fx_rect.name = "BackdropFxRect"
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_rect.color = Color.WHITE
	var shader := load(BACKDROP_SHADER_PATH) as Shader
	if shader:
		var fx_material := ShaderMaterial.new()
		fx_material.shader = shader
		fx_material.set_shader_parameter("corner_radius", PANEL_CORNER_RADIUS)
		fx_rect.material = fx_material
	else:
		push_error("[CarryOverPanel] Failed to load shader: " + BACKDROP_SHADER_PATH)
	panel_container.add_child(fx_rect)
	panel_container.move_child(fx_rect, 0)
	backdrop_fx_rect = fx_rect
	_update_backdrop_fx_size()
	return fx_rect


## _update_backdrop_fx_size()
## Pushes the panel's current size into the backdrop shader so its rounded
## mask tracks layout. Connected to the panel's resized signal.
func _update_backdrop_fx_size() -> void:
	if backdrop_fx_rect == null or backdrop_fx_rect.material == null or panel_container == null:
		return
	var panel_size := panel_container.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = panel_container.custom_minimum_size
	(backdrop_fx_rect.material as ShaderMaterial).set_shader_parameter("rect_size", panel_size)


## _rebuild_type_rows() -> void
##
## Rebuilds the toggle button rows based on current allowed types.
## Clears existing rows and creates new ones.
func _rebuild_type_rows() -> void:
	# Clear existing rows
	for child in rows_container.get_children():
		child.queue_free()
	_toggle_buttons.clear()
	_row_palettes.clear()
	_type_rows.clear()
	
	if _allowed_count <= 0:
		# No carry-overs allowed — show informational message
		var info_label = Label.new()
		info_label.text = "This channel allows no carry-overs.\nEverything resets!"
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.add_theme_font_override("font", vcr_font)
		info_label.add_theme_font_size_override("font_size", 16)
		info_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows_container.add_child(info_label)
		_type_rows.append(info_label)
		return
	
	# Create a toggle button row for each allowed type
	for type_key in _allowed_types:
		var row = _create_type_row(type_key)
		rows_container.add_child(row)
		_type_rows.append(row)


## _create_type_row(type_key: String) -> HBoxContainer
##
## Creates a single row with a centered toggle GlassActionButton for a
## carry-over type. Selection is shown by enlarging the button and swapping
## it to a brighter per-type palette — the layout never shifts.
func _create_type_row(type_key: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.name = "Row_" + type_key
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.custom_minimum_size = Vector2(0, 44)
	
	# Toggle button — purple palette with a per-type accent color; the
	# selected palette leans fully into the type color so selection is obvious
	var accent: Color = TYPE_COLORS.get(type_key, Color(0.6, 0.3, 0.9))
	var base_palette := CARRYOVER_BUTTON_PALETTE.duplicate()
	base_palette["accent_color"] = accent
	base_palette["glow_color"] = accent.lightened(0.2)
	var selected_palette := CARRYOVER_BUTTON_PALETTE.duplicate()
	selected_palette["base_color"] = accent.darkened(0.55)
	selected_palette["mid_color"] = accent.darkened(0.3)
	selected_palette["accent_color"] = accent.lightened(0.2)
	selected_palette["glow_color"] = accent.lightened(0.4)
	_row_palettes[type_key] = {"base": base_palette, "selected": selected_palette}
	
	var button = GlassActionButtonClass.new()
	button.name = "Toggle_" + type_key
	button.toggle_mode = true
	button.configure(
		TYPE_DISPLAY_NAMES.get(type_key, type_key),
		Vector2(300, 40),
		base_palette,
		17,
		vcr_font
	)
	# Center pivot so the selected scale-up grows evenly around the middle
	button.pivot_offset = Vector2(150, 20)
	button.toggled.connect(func(is_toggled: bool) -> void: _on_type_toggled(type_key, is_toggled))
	hbox.add_child(button)
	
	_toggle_buttons[type_key] = button
	
	return hbox


## _on_type_toggled(type_key: String, is_toggled: bool) -> void
##
## Handles a row button being toggled. Updates selection state and enforces
## the max count, reverting (with a denied shake) when at the limit.
## Selection is shown by enlarging the button and swapping to the selected
## palette — the row layout stays centered and never shifts.
func _on_type_toggled(type_key: String, is_toggled: bool) -> void:
	var button = _toggle_buttons.get(type_key)
	if is_toggled:
		if _selected_types.size() >= _allowed_count:
			# Can't select more — revert the toggle and shake the button
			if button:
				button.set_toggled(false)
				if _tfx:
					_tfx.button_denied(button)
			return
		_selected_types.append(type_key)
		if button:
			button.set_palette(_row_palettes[type_key]["selected"])
			_tween_button_scale(button, 1.12)
	else:
		_selected_types.erase(type_key)
		if button:
			button.set_palette(_row_palettes[type_key]["base"])
			_tween_button_scale(button, 1.0)
	
	_update_toggle_states()
	_update_display()
	
	# Jelly the row for feedback
	var row = rows_container.get_node_or_null("Row_" + type_key)
	if row and _tfx:
		TweenFX.jelly(row, 0.3, 0.1, 1)


## _tween_button_scale(button: GlassActionButton, target_scale: float) -> void
##
## Smoothly scales a row button to indicate selection state.
func _tween_button_scale(button: GlassActionButton, target_scale: float) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * target_scale, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


## _update_toggle_states() -> void
##
## Enables/disables row buttons based on whether max selections are reached.
## Toggled buttons stay enabled (so they can be un-toggled); untoggled ones
## get disabled while at the limit.
func _update_toggle_states() -> void:
	var at_max = _selected_types.size() >= _allowed_count
	for type_key in _toggle_buttons:
		var button = _toggle_buttons[type_key]
		if at_max and not button.is_toggled():
			button.set_button_disabled(true)
		else:
			button.set_button_disabled(false)


## _update_display() -> void
##
## Updates subtitle, counter, and button based on current state.
func _update_display() -> void:
	if _allowed_count <= 0:
		title_label.text = "NO CARRY-OVERS ALLOWED"
		subtitle_label.text = "Mall Zone %02d requires a fresh start" % _next_channel
		counter_label.visible = false
		confirm_button.set_button_text("CONTINUE")
		confirm_button.set_button_disabled(false)
	else:
		title_label.text = "CHOOSE YOUR CARRY-OVERS"
		subtitle_label.text = "Select up to %s items to keep for Mall Zone %s" % [NumberFormatter.format_int(_allowed_count), NumberFormatter.format_int(_next_channel)]
		counter_label.visible = true
		counter_label.text = "%s / %s selected" % [NumberFormatter.format_int(_selected_types.size()), NumberFormatter.format_int(_allowed_count)]
		confirm_button.set_button_text("CONFIRM")
		confirm_button.set_button_disabled(false)
		
		# Color the counter based on how full it is
		if _selected_types.size() >= _allowed_count:
			counter_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		elif _selected_types.size() > 0:
			counter_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
		else:
			counter_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


## _on_confirm_pressed() -> void
##
## Handles the confirm button press. Emits selection and hides panel.
func _on_confirm_pressed() -> void:
	if _is_animating:
		return
	
	print("[CarryOverPanel] Confirmed carry-overs: %s" % str(_selected_types))
	_hide_panel()


## _hide_panel() -> void
##
## Animates the panel hiding, then emits signals.
func _hide_panel() -> void:
	if _is_animating:
		return
	_is_animating = true
	
	if _animation_tween:
		_animation_tween.kill()
	
	# Drop out the panel
	var exit_tween = TweenFX.drop_out(panel_container, 0.4, 600.0)
	
	# Fade overlay in parallel
	_animation_tween = create_tween()
	_animation_tween.tween_property(overlay, "modulate:a", 0.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)\
		.set_delay(0.1)
	
	await exit_tween.finished
	
	visible = false
	panel_container.visible = false
	_is_animating = false
	
	# Make a copy of selected types before emitting
	var selected_copy: Array[String] = []
	for t in _selected_types:
		selected_copy.append(t)
	
	emit_signal("carryover_confirmed", selected_copy)
	emit_signal("panel_closed")


## _animate_entrance() -> void
##
## Animates the panel appearing with staggered type rows.
func _animate_entrance() -> void:
	if _animation_tween:
		_animation_tween.kill()
	_is_animating = true
	
	# Setup initial states — overlay starts invisible
	overlay.modulate.a = 0.0
	
	# Reset panel to desired FINAL state so TweenFX.drop_in captures correct
	# targets. drop_in reads current modulate.a / scale as the "original" to
	# tween back to, so they must be the intended end values (1.0 / ONE).
	panel_container.modulate.a = 1.0
	panel_container.scale = Vector2.ONE
	panel_container.visible = false  # Hide until overlay fade completes
	
	# Set pivot to center so scale animations look correct
	panel_container.pivot_offset = panel_container.size / 2.0
	
	# Hide type rows for stagger animation
	for row in _type_rows:
		row.modulate.a = 0.0
		row.position.x = -50.0
	
	# Fade in overlay
	_animation_tween = create_tween()
	_animation_tween.tween_property(overlay, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD)
	
	await _animation_tween.finished
	
	# Make panel visible and drop it in with bounce
	panel_container.visible = true
	var drop_tween = TweenFX.drop_in(panel_container, 0.6, 150.0, Vector2(1.3, 0.7))
	await drop_tween.finished
	
	# Jelly settle on the panel
	TweenFX.jelly(panel_container, 0.4, 0.08, 1)
	
	# Stagger animate type rows
	for i in range(_type_rows.size()):
		var row = _type_rows[i]
		var row_tween = create_tween()
		row_tween.set_parallel(true)
		row_tween.tween_property(row, "modulate:a", 1.0, 0.2)\
			.set_delay(i * 0.08)
		row_tween.tween_property(row, "position:x", 0.0, 0.3)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)\
			.set_delay(i * 0.08)
		if i == _type_rows.size() - 1:
			await row_tween.finished
	
	_is_animating = false
