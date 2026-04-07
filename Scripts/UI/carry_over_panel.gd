extends Control
class_name CarryOverPanel

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
var _checkboxes: Dictionary = {}  # type_string -> CheckBox

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

# Colors for carry-over type labels
const TYPE_COLORS := {
	"power_ups": Color(0.5, 0.9, 1.0),
	"consumables": Color(1.0, 0.7, 0.3),
	"colored_dice": Color(0.8, 0.5, 1.0),
	"mods": Color(0.4, 1.0, 0.6),
	"consoles": Color(1.0, 0.5, 0.5),
	"money": Color(1.0, 0.95, 0.4),
	"scorecard_levels": Color(0.7, 0.85, 1.0)
}

# UI Components
var overlay: ColorRect
var panel_container: PanelContainer
var title_label: Label
var subtitle_label: Label
var counter_label: Label
var checkbox_container: VBoxContainer
var confirm_button: Button
var _checkbox_rows: Array[Control] = []

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
	_checkboxes.clear()
	_checkbox_rows.clear()
	
	print("[CarryOverPanel] Showing panel for Channel %d: %d selections from %s" % [next_channel, allowed_count, str(allowed_types)])
	
	_rebuild_checkbox_list()
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
## Programmatically builds the carry-over panel UI.
func _build_ui() -> void:
	# Create semi-transparent overlay
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Create centered panel container
	panel_container = PanelContainer.new()
	panel_container.name = "CarryOverPanel"
	panel_container.custom_minimum_size = Vector2(480, 550)
	panel_container.set_anchors_preset(Control.PRESET_CENTER)
	panel_container.offset_left = -240
	panel_container.offset_top = -275
	panel_container.offset_right = 240
	panel_container.offset_bottom = 275
	panel_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Create custom StyleBox
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.12, 0.98)
	style.border_color = Color(0.6, 0.3, 0.9, 1.0)
	style.set_border_width_all(5)
	style.set_corner_radius_all(16)
	panel_container.add_theme_stylebox_override("panel", style)
	
	# Add as sibling of overlay (NOT child) so overlay modulate doesn't
	# multiply with panel modulate during animations.
	add_child(panel_container)
	
	# Main vertical container
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 12)
	panel_container.add_child(main_vbox)
	
	# Add margin container for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	main_vbox.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	content_vbox.add_theme_constant_override("separation", 12)
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
	
	# Checkbox container (populated dynamically)
	checkbox_container = VBoxContainer.new()
	checkbox_container.name = "CheckboxContainer"
	checkbox_container.add_theme_constant_override("separation", 8)
	content_vbox.add_child(checkbox_container)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content_vbox.add_child(spacer)
	
	# Separator
	var sep2 = HSeparator.new()
	content_vbox.add_child(sep2)
	
	# Confirm button
	confirm_button = Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = "CONFIRM"
	confirm_button.custom_minimum_size = Vector2(250, 55)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_button.add_theme_font_override("font", vcr_font)
	confirm_button.add_theme_font_size_override("font_size", 22)
	
	# Button style
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.15, 0.5, 1.0)
	btn_style.border_color = Color(0.6, 0.3, 0.9, 1.0)
	btn_style.set_border_width_all(3)
	btn_style.set_corner_radius_all(12)
	confirm_button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.4, 0.2, 0.6, 1.0)
	btn_hover.border_color = Color(0.7, 0.4, 1.0, 1.0)
	confirm_button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.2, 0.1, 0.35, 1.0)
	confirm_button.add_theme_stylebox_override("pressed", btn_pressed)
	
	var btn_disabled = btn_style.duplicate()
	btn_disabled.bg_color = Color(0.15, 0.1, 0.2, 0.6)
	btn_disabled.border_color = Color(0.3, 0.2, 0.4, 0.6)
	confirm_button.add_theme_stylebox_override("disabled", btn_disabled)
	
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.mouse_entered.connect(_tfx.button_hover.bind(confirm_button))
	confirm_button.mouse_exited.connect(_tfx.button_unhover.bind(confirm_button))
	confirm_button.pressed.connect(_tfx.button_press.bind(confirm_button))
	content_vbox.add_child(confirm_button)


## _rebuild_checkbox_list() -> void
##
## Rebuilds the checkbox rows based on current allowed types.
## Clears existing rows and creates new ones.
func _rebuild_checkbox_list() -> void:
	# Clear existing checkbox rows
	for child in checkbox_container.get_children():
		child.queue_free()
	_checkboxes.clear()
	_checkbox_rows.clear()
	
	if _allowed_count <= 0:
		# No carry-overs allowed — show informational message
		var info_label = Label.new()
		info_label.text = "This channel allows no carry-overs.\nEverything resets!"
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.add_theme_font_override("font", vcr_font)
		info_label.add_theme_font_size_override("font_size", 16)
		info_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		checkbox_container.add_child(info_label)
		_checkbox_rows.append(info_label)
		return
	
	# Create a checkbox row for each allowed type
	for type_key in _allowed_types:
		var row = _create_checkbox_row(type_key)
		checkbox_container.add_child(row)
		_checkbox_rows.append(row)


## _create_checkbox_row(type_key: String) -> HBoxContainer
##
## Creates a single checkbox row with label and checkbox for a carry-over type.
func _create_checkbox_row(type_key: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.name = "Row_" + type_key
	hbox.add_theme_constant_override("separation", 12)
	hbox.custom_minimum_size = Vector2(0, 36)
	
	# Type label
	var label = Label.new()
	label.text = TYPE_DISPLAY_NAMES.get(type_key, type_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", vcr_font)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", TYPE_COLORS.get(type_key, Color(0.8, 0.8, 0.8)))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)
	
	# Checkbox
	var checkbox = CheckBox.new()
	checkbox.name = "Check_" + type_key
	checkbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	checkbox.add_theme_font_override("font", vcr_font)
	checkbox.add_theme_font_size_override("font_size", 18)
	checkbox.toggled.connect(_on_checkbox_toggled.bind(type_key))
	hbox.add_child(checkbox)
	
	_checkboxes[type_key] = checkbox
	
	return hbox


## _on_checkbox_toggled(pressed: bool, type_key: String) -> void
##
## Handles a checkbox being toggled. Updates selection state and enforces max count.
func _on_checkbox_toggled(pressed: bool, type_key: String) -> void:
	if pressed:
		if _selected_types.size() < _allowed_count:
			_selected_types.append(type_key)
		else:
			# Can't select more — revert the checkbox
			_checkboxes[type_key].set_pressed_no_signal(false)
			return
	else:
		_selected_types.erase(type_key)
	
	_update_checkbox_states()
	_update_display()
	
	# Jelly the checkbox row for feedback
	var row = checkbox_container.get_node_or_null("Row_" + type_key)
	if row and _tfx:
		TweenFX.jelly(row, 0.3, 0.1, 1)


## _update_checkbox_states() -> void
##
## Enables/disables checkboxes based on whether max selections are reached.
## Already-checked boxes stay enabled (for unchecking), unchecked ones get disabled.
func _update_checkbox_states() -> void:
	var at_max = _selected_types.size() >= _allowed_count
	for type_key in _checkboxes:
		var cb = _checkboxes[type_key] as CheckBox
		if at_max and not cb.button_pressed:
			cb.disabled = true
		else:
			cb.disabled = false


## _update_display() -> void
##
## Updates subtitle, counter, and button based on current state.
func _update_display() -> void:
	if _allowed_count <= 0:
		title_label.text = "NO CARRY-OVERS ALLOWED"
		subtitle_label.text = "Channel %02d requires a fresh start" % _next_channel
		counter_label.visible = false
		confirm_button.text = "CONTINUE"
		confirm_button.disabled = false
	else:
		title_label.text = "CHOOSE YOUR CARRY-OVERS"
		subtitle_label.text = "Select up to %d items to keep for Channel %02d" % [_allowed_count, _next_channel]
		counter_label.visible = true
		counter_label.text = "%d / %d selected" % [_selected_types.size(), _allowed_count]
		confirm_button.text = "CONFIRM"
		confirm_button.disabled = false
		
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
## Animates the panel appearing with staggered checkbox rows.
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
	
	# Hide checkbox rows for stagger animation
	for row in _checkbox_rows:
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
	
	# Stagger animate checkbox rows
	for i in range(_checkbox_rows.size()):
		var row = _checkbox_rows[i]
		var row_tween = create_tween()
		row_tween.set_parallel(true)
		row_tween.tween_property(row, "modulate:a", 1.0, 0.2)\
			.set_delay(i * 0.08)
		row_tween.tween_property(row, "position:x", 0.0, 0.3)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)\
			.set_delay(i * 0.08)
		if i == _checkbox_rows.size() - 1:
			await row_tween.finished
	
	_is_animating = false
