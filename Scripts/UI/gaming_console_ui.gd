extends Control
class_name GamingConsoleUI

## GamingConsoleUI
##
## Coordinates the owned gaming console presentation.
## Shows a compact horizontal VIP spine in the HUD and a single-card
## fan-out view in an overlay while preserving the existing gameplay API.

signal activate_pressed
signal console_removed

const GamingConsoleSpineScene := preload("res://Scenes/UI/gaming_console_spine.tscn")
const GamingConsoleVIPCardScene := preload("res://Scenes/UI/gaming_console_vip_card.tscn")
const FanOverlayHelperRef = preload("res://Scripts/UI/fan_overlay_helper.gd")

@export var gaming_console_manager_path: NodePath

var _console_data: GamingConsoleData = null
var _console_instance: GamingConsole = null
var _tfx = null

var _bg_panel: PanelContainer = null
var _compact_spine = null
var _vip_card = null
var _fan_background: ColorRect = null
var _is_fanned: bool = false

# Power Glove popup
var _power_glove_popup: PanelContainer = null
# Cartridge Tilt popup
var _tilt_popup: PanelContainer = null

var _blast_glow_active: bool = false
var _nes_die_buttons: Array = []

var vcr_font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

const VCR_GREEN := Color(0.2, 1.0, 0.3, 1.0)
const VCR_GREEN_BRIGHT := Color(0.4, 1.0, 0.5, 1.0)
const PANEL_BG := Color(0.247059, 0.219608, 0.345098, 0.56)
const PANEL_SURFACE := Color(0.247059, 0.219608, 0.345098, 0.98)
const PANEL_BORDER := Color(0.713725, 0.301961, 0.478431, 1.0)
const PANEL_ACCENT := Color(0.137255, 0.411765, 0.415686, 1.0)
const PANEL_TEXT := Color(0.968627, 0.941176, 1.0, 1.0)
const PANEL_OUTLINE := Color(0.129412, 0.121569, 0.2, 1.0)
const READY_ACCENT := Color(0.984314, 0.839216, 0.294118, 1.0)
const PASSIVE_ACCENT := Color(0.392157, 0.866667, 0.521569, 1.0)
const USED_ACCENT := Color(0.713725, 0.301961, 0.478431, 1.0)
const MUTED_STATUS := Color(0.745098, 0.721569, 0.819608, 1.0)
const FAN_CARD_WIDTH_RATIO := 0.20
const FAN_CARD_MIN_WIDTH := 220.0
const FAN_CARD_MAX_WIDTH := 384.0
const FAN_CARD_MAX_HEIGHT_RATIO := 0.60


func _ready() -> void:
	_tfx = get_node_or_null("/root/TweenFXHelper")
	z_index = 100
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(0.0, 92.0)
	scale = Vector2.ONE
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if _is_fanned and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _vip_card and not _vip_card.get_global_rect().has_point(mouse_event.position):
				_close_vip_card()
				get_viewport().set_input_as_handled()
				return
	if _is_fanned and event.is_action_pressed("ui_cancel"):
		_close_vip_card()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_bg_panel = PanelContainer.new()
	_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style = _build_panel_style(PANEL_BORDER, PANEL_BG)
	bg_style.content_margin_left = 4.0
	bg_style.content_margin_top = 4.0
	bg_style.content_margin_right = 4.0
	bg_style.content_margin_bottom = 4.0
	_bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(_bg_panel)

	var content_margin := MarginContainer.new()
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_margin.add_theme_constant_override("margin_left", 2)
	content_margin.add_theme_constant_override("margin_top", 2)
	content_margin.add_theme_constant_override("margin_right", 2)
	content_margin.add_theme_constant_override("margin_bottom", 2)
	_bg_panel.add_child(content_margin)

	_compact_spine = GamingConsoleSpineScene.instantiate()
	_compact_spine.name = "GamingConsoleSpine"
	_compact_spine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_spine.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_compact_spine.activate_pressed.connect(_on_activate_pressed)
	_compact_spine.card_pressed.connect(_open_vip_card)
	content_margin.add_child(_compact_spine)

	_fan_background = FanOverlayHelperRef.create_background("GamingConsoleFanBackground")
	_fan_background.color = Color(0.03, 0.02, 0.05, 0.92)
	_fan_background.top_level = true
	_fan_background.z_index = 180
	_fan_background.gui_input.connect(_on_fan_background_input)
	add_child(_fan_background)

	_vip_card = GamingConsoleVIPCardScene.instantiate()
	_vip_card.name = "GamingConsoleVIPCard"
	_vip_card.top_level = true
	_vip_card.z_index = 181
	_vip_card.visible = false
	_vip_card.activate_pressed.connect(_on_activate_pressed)
	add_child(_vip_card)


func _gui_input(event: InputEvent) -> void:
	if _is_fanned or not _console_instance or not _console_data:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_open_vip_card()
			get_viewport().set_input_as_handled()


## show_console(data, instance)
##
## Displays the console UI for the given console.
func show_console(data: GamingConsoleData, instance: GamingConsole) -> void:
	_console_data = data
	_console_instance = instance
	_blast_glow_active = false
	_connect_console_signals(instance)

	_restore_fan_overlay_state()
	_compact_spine.set_console(data, instance)
	_vip_card.set_console(data, instance)
	visible = true
	_update_button_state()
	print("[GamingConsoleUI] Showing console: %s" % data.display_name)


## hide_console()
##
## Hides the console UI.
func hide_console() -> void:
	if _console_instance:
		_disconnect_console_signals(_console_instance)
	_blast_glow_active = false
	_console_data = null
	_console_instance = null
	visible = false
	_restore_fan_overlay_state()
	_hide_power_glove_popup()
	_hide_tilt_popup()
	_clear_nes_die_buttons()
	if _compact_spine:
		_compact_spine.clear_console()
	if _vip_card:
		_vip_card.clear_console()
	emit_signal("console_removed")


func _on_activate_pressed() -> void:
	if _console_instance and _console_instance.can_activate():
		_console_instance.activate()
		emit_signal("activate_pressed")
		_update_button_state()


func _on_uses_changed(_remaining: int) -> void:
	_update_button_state()


func _on_description_updated(_new_desc: String) -> void:
	_update_button_state()


func _update_button_state() -> void:
	if not _console_instance or not _console_data:
		return

	var button_text := "ACTIVATE"
	var button_disabled := true
	var accent_color := PANEL_ACCENT
	var pulse := false
	var status_text := "ROLL TO ENABLE"
	var status_color := MUTED_STATUS
	var led_color := PANEL_ACCENT

	if _is_waiting_for_die():
		button_text = "PICK DIE"
		button_disabled = true
		accent_color = READY_ACCENT
		status_text = "SELECT A DIE TO ADJUST"
		status_color = READY_ACCENT
		led_color = READY_ACCENT
	elif _is_waiting_for_tilt_choice():
		button_text = "CHOOSE..."
		button_disabled = true
		accent_color = PANEL_BORDER
		status_text = "SHIFT ALL UNLOCKED DICE"
		status_color = PANEL_BORDER.lightened(0.15)
		led_color = PANEL_BORDER.lightened(0.08)
	elif _console_instance.is_passive():
		button_disabled = true
		accent_color = PASSIVE_ACCENT
		status_text = "PASSIVE EFFECT ONLINE"
		status_color = PASSIVE_ACCENT
		led_color = PASSIVE_ACCENT
		if _blast_glow_active:
			button_text = "1.5x READY"
			accent_color = READY_ACCENT
			pulse = true
			status_text = "BONUS MULTIPLIER ARMED"
			status_color = READY_ACCENT
			led_color = READY_ACCENT
		else:
			button_text = "ACTIVE"
	elif _console_instance.uses_remaining <= 0:
		button_text = "USED"
		button_disabled = true
		accent_color = USED_ACCENT
		status_text = "ROUND SPENT"
		status_color = USED_ACCENT.lightened(0.08)
		led_color = USED_ACCENT
	else:
		button_text = _get_active_button_text()
		button_disabled = not _console_instance.can_activate()
		pulse = _console_instance.can_activate()
		accent_color = PANEL_ACCENT if _console_instance.can_activate() else PANEL_BORDER
		led_color = accent_color
		if _console_instance is AtariConsole:
			if button_text == "READY":
				status_text = "SAVE CURRENT DICE STATE"
			else:
				status_text = "RESTORE SAVED DICE STATE"
			status_color = accent_color.lightened(0.15)
		elif _console_instance is NesConsole:
			status_text = "ADJUST ONE DIE BY +/-1"
			status_color = accent_color.lightened(0.15)
		elif _console_instance is SegaSaturnConsole:
			status_text = "SHIFT ALL UNLOCKED DICE"
			status_color = accent_color.lightened(0.15)
		elif _console_instance.can_activate():
			status_text = "READY TO ACTIVATE"
			status_color = accent_color.lightened(0.15)
		else:
			status_text = "ROLL TO ENABLE"
			status_color = MUTED_STATUS

	var description_text := _get_console_description()
	_compact_spine.set_button_state(button_text, button_disabled, accent_color, pulse)
	_compact_spine.set_status_text(status_text, status_color)
	_compact_spine.set_led_color(led_color)

	_vip_card.set_button_state(button_text, button_disabled, accent_color, pulse)
	_vip_card.set_status_text(status_text, status_color)
	_vip_card.set_description(description_text)


func _get_active_button_text() -> String:
	if _console_instance is AtariConsole:
		var atari := _console_instance as AtariConsole
		if atari.uses_remaining > 0:
			return "READY" if atari.current_mode == AtariConsole.SaveMode.SAVE else "RESTORE"
	return "ACTIVATE"


func _get_console_description() -> String:
	if _console_instance:
		var runtime_description := _console_instance.get_power_description()
		if runtime_description != "":
			return runtime_description
	if _console_data:
		return _console_data.description
	return ""


func _is_waiting_for_die() -> bool:
	if _console_instance is NesConsole:
		return (_console_instance as NesConsole).is_waiting_for_die()
	return false


func _is_waiting_for_tilt_choice() -> bool:
	if _console_instance is SegaSaturnConsole:
		return (_console_instance as SegaSaturnConsole).is_waiting_for_choice()
	return false


## reset_for_new_round()
##
## Refreshes the button state after round reset.
func reset_for_new_round() -> void:
	_update_button_state()


## refresh_button_state()
##
## Called by GameController after dice are rolled to update activation readiness.
func refresh_button_state() -> void:
	_update_button_state()


func _connect_console_signals(instance: GamingConsole) -> void:
	if not instance:
		return
	if instance.has_signal("description_updated"):
		if not instance.is_connected("description_updated", _on_description_updated):
			instance.description_updated.connect(_on_description_updated)
	if not instance.is_connected("uses_changed", _on_uses_changed):
		instance.uses_changed.connect(_on_uses_changed)

	if instance is NesConsole:
		if not instance.is_connected("awaiting_die_click", _on_awaiting_die_click):
			instance.awaiting_die_click.connect(_on_awaiting_die_click)
		if not instance.is_connected("die_adjustment_complete", _on_die_adjustment_complete):
			instance.die_adjustment_complete.connect(_on_die_adjustment_complete)

	if instance is SegaSaturnConsole:
		if not instance.is_connected("awaiting_tilt_choice", _on_awaiting_tilt_choice):
			instance.awaiting_tilt_choice.connect(_on_awaiting_tilt_choice)
		if not instance.is_connected("tilt_complete", _on_tilt_complete):
			instance.tilt_complete.connect(_on_tilt_complete)

	if instance is SnesConsole:
		if not instance.is_connected("blast_ready", _on_blast_ready):
			instance.blast_ready.connect(_on_blast_ready)
		if not instance.is_connected("blast_consumed", _on_blast_consumed):
			instance.blast_consumed.connect(_on_blast_consumed)


func _disconnect_console_signals(instance: GamingConsole) -> void:
	if not instance:
		return
	if instance.has_signal("description_updated"):
		if instance.is_connected("description_updated", _on_description_updated):
			instance.description_updated.disconnect(_on_description_updated)
	if instance.is_connected("uses_changed", _on_uses_changed):
		instance.uses_changed.disconnect(_on_uses_changed)

	if instance is SnesConsole:
		if instance.is_connected("blast_ready", _on_blast_ready):
			instance.blast_ready.disconnect(_on_blast_ready)
		if instance.is_connected("blast_consumed", _on_blast_consumed):
			instance.blast_consumed.disconnect(_on_blast_consumed)

	if instance is SegaSaturnConsole:
		if instance.is_connected("awaiting_tilt_choice", _on_awaiting_tilt_choice):
			instance.awaiting_tilt_choice.disconnect(_on_awaiting_tilt_choice)
		if instance.is_connected("tilt_complete", _on_tilt_complete):
			instance.tilt_complete.disconnect(_on_tilt_complete)

	if instance is NesConsole:
		if instance.is_connected("awaiting_die_click", _on_awaiting_die_click):
			instance.awaiting_die_click.disconnect(_on_awaiting_die_click)
		if instance.is_connected("die_adjustment_complete", _on_die_adjustment_complete):
			instance.die_adjustment_complete.disconnect(_on_die_adjustment_complete)
		var nes := instance as NesConsole
		if nes.dice_hand_ref and nes.dice_hand_ref.is_connected("roll_started", _clear_nes_die_buttons):
			nes.dice_hand_ref.roll_started.disconnect(_clear_nes_die_buttons)


# ── Fan Overlay ──────────────────────────────────────────

func _open_vip_card() -> void:
	if not _console_instance or not _console_data or _is_fanned:
		return

	var viewport_size := get_viewport_rect().size
	var card_size := _get_vip_card_size(viewport_size)
	_vip_card.set_card_size(card_size)
	var target_position := _get_vip_card_target_position(viewport_size)
	_fan_background.visible = true
	_fan_background.modulate.a = 0.0
	_fan_background.position = Vector2.ZERO
	_fan_background.size = viewport_size
	_fan_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vip_card.visible = true
	_vip_card.position = target_position - Vector2(0.0, maxf(120.0, card_size.y * 0.38))
	_vip_card.modulate.a = 0.0

	var bg_tween := create_tween()
	bg_tween.tween_property(_fan_background, "modulate:a", 1.0, 0.22)

	var card_tween := create_tween().set_parallel()
	card_tween.tween_property(_vip_card, "position", target_position, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card_tween.tween_property(_vip_card, "modulate:a", 1.0, 0.28)

	_is_fanned = true


func _close_vip_card() -> void:
	if not _is_fanned:
		return
	_is_fanned = false

	var bg_tween := create_tween()
	bg_tween.tween_property(_fan_background, "modulate:a", 0.0, 0.18)

	var card_tween := create_tween().set_parallel()
	card_tween.tween_property(_vip_card, "position", _vip_card.position + Vector2(0.0, 180.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	card_tween.tween_property(_vip_card, "modulate:a", 0.0, 0.18)
	card_tween.finished.connect(_restore_fan_overlay_state)


func _restore_fan_overlay_state() -> void:
	_is_fanned = false
	if _fan_background:
		_fan_background.visible = false
		_fan_background.modulate.a = 1.0
	if _vip_card:
		_vip_card.visible = false
		_vip_card.modulate.a = 1.0
		_vip_card.position = Vector2.ZERO


func _get_vip_card_target_position(viewport_size: Vector2) -> Vector2:
	var card_size: Vector2 = _vip_card.get_card_size()
	if card_size == Vector2.ZERO:
		card_size = _get_vip_card_size(viewport_size)
	return Vector2(
		floor((viewport_size.x - card_size.x) * 0.5),
		floor((viewport_size.y - card_size.y) * 0.5)
	)


func _get_vip_card_size(viewport_size: Vector2) -> Vector2:
	var base_size: Vector2 = _vip_card.get_card_size()
	if base_size == Vector2.ZERO:
		base_size = _vip_card.custom_minimum_size
	var aspect: float = base_size.x / maxf(base_size.y, 1.0)
	var width := clampf(viewport_size.x * FAN_CARD_WIDTH_RATIO, FAN_CARD_MIN_WIDTH, FAN_CARD_MAX_WIDTH)
	var height := width / maxf(aspect, 0.001)
	var max_height := viewport_size.y * FAN_CARD_MAX_HEIGHT_RATIO
	if height > max_height:
		height = max_height
		width = height * aspect
	return Vector2(roundf(width), roundf(height))


func _on_fan_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_close_vip_card()


# ── Blast Processing Glow ────────────────────────────────

func _on_blast_ready() -> void:
	_blast_glow_active = true
	_update_button_state()


func _on_blast_consumed() -> void:
	_blast_glow_active = false
	_update_button_state()


# ── Power Glove Per-Die Buttons ──────────────────────────

func _on_awaiting_die_click() -> void:
	_update_button_state()
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

	if not nes.dice_hand_ref.is_connected("roll_started", _clear_nes_die_buttons):
		nes.dice_hand_ref.roll_started.connect(_clear_nes_die_buttons)

	for die in nes.dice_hand_ref.get_all_dice():
		var state = die.get_state()
		if state == Dice.DiceState.ROLLED or state == Dice.DiceState.LOCKED:
			var panel = PanelContainer.new()
			panel.z_index = 150

			var style = _build_panel_style(PANEL_ACCENT, PANEL_SURFACE)
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
			plus_btn.custom_minimum_size = Vector2(26, 20)
			_apply_button_style(plus_btn, PANEL_ACCENT, 10)
			plus_btn.pressed.connect(_on_nes_die_adjust.bind(die, 1))
			if _tfx:
				plus_btn.mouse_entered.connect(_tfx.button_hover.bind(plus_btn))
				plus_btn.mouse_exited.connect(_tfx.button_unhover.bind(plus_btn))
				plus_btn.pressed.connect(_tfx.button_press.bind(plus_btn))
			hbox.add_child(plus_btn)

			var minus_btn = Button.new()
			minus_btn.text = "-1"
			minus_btn.add_theme_font_override("font", vcr_font)
			minus_btn.custom_minimum_size = Vector2(26, 20)
			_apply_button_style(minus_btn, PANEL_BORDER, 10)
			minus_btn.pressed.connect(_on_nes_die_adjust.bind(die, -1))
			if _tfx:
				minus_btn.mouse_entered.connect(_tfx.button_hover.bind(minus_btn))
				minus_btn.mouse_exited.connect(_tfx.button_unhover.bind(minus_btn))
				minus_btn.pressed.connect(_tfx.button_press.bind(minus_btn))
			hbox.add_child(minus_btn)

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
	_update_button_state()
	_show_tilt_popup()


func _on_tilt_complete() -> void:
	_hide_tilt_popup()
	_update_button_state()


func _show_tilt_popup() -> void:
	if _tilt_popup:
		_tilt_popup.queue_free()

	_tilt_popup = PanelContainer.new()
	_tilt_popup.z_index = 150

	var style = _build_panel_style(PANEL_BORDER, PANEL_SURFACE)
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
	plus_btn.custom_minimum_size = Vector2(70, 30)
	_apply_button_style(plus_btn, PANEL_ACCENT, 14)
	plus_btn.pressed.connect(_on_tilt_choice.bind(1))
	if _tfx:
		plus_btn.mouse_entered.connect(_tfx.button_hover.bind(plus_btn))
		plus_btn.mouse_exited.connect(_tfx.button_unhover.bind(plus_btn))
		plus_btn.pressed.connect(_tfx.button_press.bind(plus_btn))
	hbox.add_child(plus_btn)

	var minus_btn = Button.new()
	minus_btn.text = "-1 ALL"
	minus_btn.add_theme_font_override("font", vcr_font)
	minus_btn.custom_minimum_size = Vector2(70, 30)
	_apply_button_style(minus_btn, PANEL_BORDER, 14)
	minus_btn.pressed.connect(_on_tilt_choice.bind(-1))
	if _tfx:
		minus_btn.mouse_entered.connect(_tfx.button_hover.bind(minus_btn))
		minus_btn.mouse_exited.connect(_tfx.button_unhover.bind(minus_btn))
		minus_btn.pressed.connect(_tfx.button_press.bind(minus_btn))
	hbox.add_child(minus_btn)

	_tilt_popup.position = global_position + Vector2(0, -50)
	get_tree().root.add_child(_tilt_popup)


func _build_panel_style(accent_color: Color, bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.corner_detail = 6
	style.shadow_color = Color(0.070588, 0.062745, 0.101961, 0.45)
	style.shadow_size = 4
	return style


func _apply_button_style(button: Button, accent_color: Color, font_size: int = 12) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", PANEL_TEXT)
	button.add_theme_color_override("font_hover_color", PANEL_TEXT)
	button.add_theme_color_override("font_pressed_color", PANEL_TEXT)
	button.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	button.add_theme_constant_override("outline_size", 1)

	var normal = StyleBoxFlat.new()
	normal.bg_color = accent_color.darkened(0.28)
	normal.border_color = accent_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(4)
	button.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = accent_color
	hover.border_color = accent_color.lightened(0.1)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(8)
	hover.set_content_margin_all(4)
	button.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = accent_color.darkened(0.42)
	pressed.border_color = accent_color.darkened(0.18)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(8)
	pressed.set_content_margin_all(4)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)


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
