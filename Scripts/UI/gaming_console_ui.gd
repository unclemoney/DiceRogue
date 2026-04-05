extends Control
class_name GamingConsoleUI

## GamingConsoleUI
##
## Displays the currently owned gaming console above the VCR.
## Shows console icon, name, and an ACTIVATE button (or "ACTIVE" for passives).
## Includes TweenFX breathe pulse on the button and a hover tooltip.

signal activate_pressed
signal console_removed

@export var gaming_console_manager_path: NodePath

var _console_data: GamingConsoleData = null
var _console_instance: GamingConsole = null
var _tfx = null

# UI nodes (created dynamically)
var _icon_rect: TextureRect = null
var _name_label: Label = null
var _activate_button: Button = null
var _tooltip_panel: PanelContainer = null
var _tooltip_label: Label = null
var _container: VBoxContainer = null
var _bg_panel: PanelContainer = null

# Power Glove popup
var _power_glove_popup: PanelContainer = null
# Cartridge Tilt popup
var _tilt_popup: PanelContainer = null

var vcr_font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

const VCR_GREEN := Color(0.2, 1.0, 0.3, 1.0)
const VCR_GREEN_BRIGHT := Color(0.4, 1.0, 0.5, 1.0)


func _ready() -> void:
	_tfx = get_node_or_null("/root/TweenFXHelper")
	z_index = 100
	visible = false
	scale = Vector2(1.0, 1.0)
	_build_ui()
	#visible = true


func _build_ui() -> void:
	# Background panel
	_bg_panel = PanelContainer.new()
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.06, 0.12, 0.0)
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.9, 0.8, 0.3, 0.0)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.content_margin_left = 8.0
	bg_style.content_margin_top = 4.0
	bg_style.content_margin_right = 8.0
	bg_style.content_margin_bottom = 4.0
	_bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(_bg_panel)

	# HBox layout: icon | name | button
	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 8)
	_bg_panel.add_child(_container)

	# Activate button
	_activate_button = Button.new()
	_activate_button.text = "ACTIVATE"
	_activate_button.add_theme_font_override("font", vcr_font)
	_activate_button.add_theme_font_size_override("font_size", 12)
	_activate_button.custom_minimum_size = Vector2(90, 20)
	_activate_button.pressed.connect(_on_activate_pressed)
	_container.add_child(_activate_button)

	# Console icon
	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(40, 40)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_icon_rect.mouse_entered.connect(_show_tooltip)
	_icon_rect.mouse_exited.connect(_hide_tooltip)
	_container.add_child(_icon_rect)

	# Console name
	_name_label = Label.new()
	_name_label.add_theme_font_override("font", vcr_font)
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", VCR_GREEN_BRIGHT)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.text = ""
	#_container.add_child(_name_label)



	if _tfx:
		_activate_button.mouse_entered.connect(_tfx.button_hover.bind(_activate_button))
		_activate_button.mouse_exited.connect(_tfx.button_unhover.bind(_activate_button))
		_activate_button.pressed.connect(_tfx.button_press.bind(_activate_button))

	# Tooltip (hidden by default)
	_build_tooltip()


func _build_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 140
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.98)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(1, 0.8, 0.2, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_override("font", vcr_font)
	_tooltip_label.add_theme_font_size_override("font_size", 14)
	_tooltip_label.add_theme_color_override("font_color", Color(1, 0.98, 0.9, 1))
	_tooltip_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_tooltip_label.add_theme_constant_override("outline_size", 1)
	_tooltip_panel.add_child(_tooltip_label)

	add_child(_tooltip_panel)


## show_console(data, instance)
##
## Displays the console UI for the given console.
func show_console(data: GamingConsoleData, instance: GamingConsole) -> void:
	_console_data = data
	_console_instance = instance

	if data.icon:
		_icon_rect.texture = data.icon
	_name_label.text = data.display_name

	if instance.is_passive():
		_activate_button.text = "ACTIVE"
		_activate_button.disabled = true
	else:
		_activate_button.text = "ACTIVATE"
		_activate_button.disabled = false
		if _tfx:
			_tfx.idle_pulse(_activate_button)

	# Connect description updates
	if instance.has_signal("description_updated"):
		if not instance.is_connected("description_updated", _on_description_updated):
			instance.description_updated.connect(_on_description_updated)

	# Connect uses_changed for button state
	if not instance.is_connected("uses_changed", _on_uses_changed):
		instance.uses_changed.connect(_on_uses_changed)

	# Connect Power Glove signals
	if instance is NesConsole:
		if not instance.is_connected("awaiting_die_click", _on_awaiting_die_click):
			instance.awaiting_die_click.connect(_on_awaiting_die_click)
		if not instance.is_connected("die_adjustment_complete", _on_die_adjustment_complete):
			instance.die_adjustment_complete.connect(_on_die_adjustment_complete)

	# Connect Cartridge Tilt signals
	if instance is SegaSaturnConsole:
		if not instance.is_connected("awaiting_tilt_choice", _on_awaiting_tilt_choice):
			instance.awaiting_tilt_choice.connect(_on_awaiting_tilt_choice)
		if not instance.is_connected("tilt_complete", _on_tilt_complete):
			instance.tilt_complete.connect(_on_tilt_complete)

	# Connect Blast Processing glow signals
	if instance is SnesConsole:
		if not instance.is_connected("blast_ready", _on_blast_ready):
			instance.blast_ready.connect(_on_blast_ready)
		if not instance.is_connected("blast_consumed", _on_blast_consumed):
			instance.blast_consumed.connect(_on_blast_consumed)

	visible = true
	print("[GamingConsoleUI] Showing console: %s" % data.display_name)


## hide_console()
##
## Hides the console UI.
func hide_console() -> void:
	if _console_instance:
		if _console_instance.has_signal("description_updated"):
			if _console_instance.is_connected("description_updated", _on_description_updated):
				_console_instance.description_updated.disconnect(_on_description_updated)
		if _console_instance.is_connected("uses_changed", _on_uses_changed):
			_console_instance.uses_changed.disconnect(_on_uses_changed)
		if _console_instance is SnesConsole:
			if _console_instance.is_connected("blast_ready", _on_blast_ready):
				_console_instance.blast_ready.disconnect(_on_blast_ready)
			if _console_instance.is_connected("blast_consumed", _on_blast_consumed):
				_console_instance.blast_consumed.disconnect(_on_blast_consumed)
		if _console_instance is NesConsole:
			var nes = _console_instance as NesConsole
			if nes.dice_hand_ref and nes.dice_hand_ref.is_connected("roll_started", _clear_nes_die_buttons):
				nes.dice_hand_ref.roll_started.disconnect(_clear_nes_die_buttons)
	_blast_glow_active = false
	if _activate_button:
		_activate_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_console_data = null
	_console_instance = null
	visible = false
	_hide_power_glove_popup()
	_hide_tilt_popup()
	_clear_nes_die_buttons()
	emit_signal("console_removed")


func _on_activate_pressed() -> void:
	if _console_instance and _console_instance.can_activate():
		_console_instance.activate()
		emit_signal("activate_pressed")
		_update_button_state()


func _on_uses_changed(_remaining: int) -> void:
	_update_button_state()


func _on_description_updated(_new_desc: String) -> void:
	# Update Atari console button to reflect its current save/load mode
	if _console_instance is AtariConsole and _activate_button:
		var atari := _console_instance as AtariConsole
		if not atari.is_passive() and atari.uses_remaining > 0:
			_activate_button.text = "READY" if atari.current_mode == AtariConsole.SaveMode.SAVE else "RESTORE"


func _update_button_state() -> void:
	if not _console_instance:
		return
	if _console_instance.is_passive():
		_activate_button.text = "ACTIVE"
		_activate_button.disabled = true
		return
	if _console_instance.uses_remaining <= 0:
		_activate_button.text = "USED"
		_activate_button.disabled = true
		if _tfx:
			_tfx.stop_effect(_activate_button)
	else:
		if _console_instance.can_activate():
			_activate_button.text = "ACTIVATE"
			_activate_button.disabled = false
			if _tfx:
				_tfx.idle_pulse(_activate_button)
		else:
			_activate_button.text = "ACTIVATE"
			_activate_button.disabled = true


## reset_for_new_round()
##
## Refreshes the button state after round reset.
func reset_for_new_round() -> void:
	_update_button_state()
	if _console_instance and not _console_instance.is_passive():
		if _tfx and _console_instance.uses_remaining > 0:
			_tfx.idle_pulse(_activate_button)


## refresh_button_state()
##
## Called by GameController after dice are rolled to update activation readiness.
func refresh_button_state() -> void:
	_update_button_state()


# ── Tooltip ──────────────────────────────────────────────

func _show_tooltip() -> void:
	if not _console_instance or not _tooltip_panel:
		return
	_tooltip_label.text = _console_instance.get_power_description()
	_tooltip_panel.visible = true
	_tooltip_panel.position = Vector2(0, -_tooltip_panel.size.y - 8)


func _hide_tooltip() -> void:
	if _tooltip_panel:
		_tooltip_panel.visible = false


# ── Blast Processing Glow ────────────────────────────────

var _blast_glow_active: bool = false

func _on_blast_ready() -> void:
	_blast_glow_active = true
	if _activate_button and _console_instance and _console_instance.is_passive():
		_activate_button.text = "1.5x READY"
		_activate_button.modulate = Color(1.0, 0.9, 0.2, 1.0)
		if _tfx:
			_tfx.idle_pulse(_activate_button)


func _on_blast_consumed() -> void:
	_blast_glow_active = false
	if _activate_button and _console_instance and _console_instance.is_passive():
		_activate_button.text = "ACTIVE"
		_activate_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if _tfx:
			_tfx.stop_effect(_activate_button)


# ── Power Glove Per-Die Buttons ──────────────────────────

var _nes_die_buttons: Array = []

func _on_awaiting_die_click() -> void:
	_activate_button.text = "PICK DIE"
	_activate_button.disabled = true
	_spawn_nes_die_buttons()


func _on_die_adjustment_complete() -> void:
	_clear_nes_die_buttons()
	_update_button_state()


## _spawn_nes_die_buttons()
##
## Spawns +1/-1 button pairs above each rolled/locked die.
## Clicking a button adjusts that specific die and removes all buttons.
func _spawn_nes_die_buttons() -> void:
	_clear_nes_die_buttons()
	var nes = _console_instance as NesConsole
	if not nes or not nes.dice_hand_ref:
		return

	# Connect roll_started to clean up buttons when player rolls again
	if not nes.dice_hand_ref.is_connected("roll_started", _clear_nes_die_buttons):
		nes.dice_hand_ref.roll_started.connect(_clear_nes_die_buttons)

	for die in nes.dice_hand_ref.get_all_dice():
		var state = die.get_state()
		if state == Dice.DiceState.ROLLED or state == Dice.DiceState.LOCKED:
			var panel = PanelContainer.new()
			panel.z_index = 150

			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.08, 0.06, 0.12, 0.98)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color(1, 0.8, 0.2, 1)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_right = 4
			style.corner_radius_bottom_left = 4
			style.content_margin_left = 4.0
			style.content_margin_top = 4.0
			style.content_margin_right = 4.0
			style.content_margin_bottom = 4.0
			panel.add_theme_stylebox_override("panel", style)

			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 4)
			panel.add_child(hbox)

			var plus_btn = Button.new()
			plus_btn.text = "+1"
			plus_btn.add_theme_font_override("font", vcr_font)
			plus_btn.add_theme_font_size_override("font_size", 10)
			plus_btn.custom_minimum_size = Vector2(26, 20)
			plus_btn.pressed.connect(_on_nes_die_adjust.bind(die, 1))
			hbox.add_child(plus_btn)

			var minus_btn = Button.new()
			minus_btn.text = "-1"
			minus_btn.add_theme_font_override("font", vcr_font)
			minus_btn.add_theme_font_size_override("font_size", 10)
			minus_btn.custom_minimum_size = Vector2(26, 20)
			minus_btn.pressed.connect(_on_nes_die_adjust.bind(die, -1))
			hbox.add_child(minus_btn)

			# Position centered above the die
			panel.position = die.global_position + Vector2(-20, -45)
			get_tree().root.add_child(panel)
			_nes_die_buttons.append(panel)


func _on_nes_die_adjust(die: Dice, amount: int) -> void:
	var nes = _console_instance as NesConsole
	if nes:
		nes.adjust_specific_die(die, amount)


func _clear_nes_die_buttons() -> void:
	for btn in _nes_die_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_nes_die_buttons.clear()


func _hide_power_glove_popup() -> void:
	if _power_glove_popup and is_instance_valid(_power_glove_popup):
		_power_glove_popup.queue_free()
		_power_glove_popup = null
	_clear_nes_die_buttons()


# ── Cartridge Tilt Popup ─────────────────────────────────

func _on_awaiting_tilt_choice() -> void:
	_activate_button.text = "CHOOSE..."
	_activate_button.disabled = true
	_show_tilt_popup()


func _on_tilt_complete() -> void:
	_hide_tilt_popup()
	_update_button_state()


func _show_tilt_popup() -> void:
	if _tilt_popup:
		_tilt_popup.queue_free()

	_tilt_popup = PanelContainer.new()
	_tilt_popup.z_index = 150

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.98)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1, 0.8, 0.2, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	_tilt_popup.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_tilt_popup.add_child(hbox)

	var plus_btn = Button.new()
	plus_btn.text = "+1 ALL"
	plus_btn.add_theme_font_override("font", vcr_font)
	plus_btn.add_theme_font_size_override("font_size", 14)
	plus_btn.custom_minimum_size = Vector2(70, 30)
	plus_btn.pressed.connect(_on_tilt_choice.bind(1))
	hbox.add_child(plus_btn)

	var minus_btn = Button.new()
	minus_btn.text = "-1 ALL"
	minus_btn.add_theme_font_override("font", vcr_font)
	minus_btn.add_theme_font_size_override("font_size", 14)
	minus_btn.custom_minimum_size = Vector2(70, 30)
	minus_btn.pressed.connect(_on_tilt_choice.bind(-1))
	hbox.add_child(minus_btn)

	# Position above the console UI
	_tilt_popup.position = global_position + Vector2(0, -50)
	get_tree().root.add_child(_tilt_popup)


func _on_tilt_choice(amount: int) -> void:
	var saturn = _console_instance as SegaSaturnConsole
	if saturn:
		saturn.apply_tilt(amount)
	_hide_tilt_popup()
	_update_button_state()


func _hide_tilt_popup() -> void:
	if _tilt_popup and is_instance_valid(_tilt_popup):
		_tilt_popup.queue_free()
		_tilt_popup = null
