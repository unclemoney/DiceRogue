extends Control
class_name LoadedDiePicker

## LoadedDiePicker
##
## Two-phase popup used by LoadedDiceConsumable:
##   1. DIE_PICK — the player clicks a die on the board (root is
##      MOUSE_FILTER_IGNORE so clicks pass through to the dice; dice locking
##      is temporarily disabled so the click does not toggle lock).
##   2. VALUE_PICK — a centered panel offers one button per face (1..sides of
##      the clicked die), plus a Back button to return to die picking.
## Follows the project panel standards (Control root, full-rect ColorRect
## overlay, centered PanelContainer, powerup_hover_theme, position+modulate
## tweens only).

signal value_chosen(die: Dice, value: int)
signal picker_closed

enum Phase { DIE_PICK, VALUE_PICK }

const PANEL_BG := Color(0.247059, 0.219608, 0.345098, 0.98)
const PANEL_BORDER := Color(0.713725, 0.301961, 0.478431, 1.0)
const PANEL_TEXT := Color(0.968627, 0.941176, 1.0, 1.0)
const PANEL_TEXT_SOFT := Color(0.780392, 0.733333, 0.866667, 1.0)
const PANEL_OUTLINE := Color(0.129412, 0.121569, 0.2, 1.0)
const VCR_FONT_PATH := "res://Resources/Font/VCR_OSD_MONO_1.001.ttf"
const PANEL_THEME_PATH := "res://Resources/UI/powerup_hover_theme.tres"

var _debug_enabled: bool = OS.is_debug_build()
var _phase: Phase = Phase.DIE_PICK
var _dice: Array = []
var _selected_die: Dice = null
var _saved_locking: Dictionary = {}  # Dice -> bool (locking_disabled before pick mode)

var _overlay: ColorRect = null
var _panel: PanelContainer = null
var _hint_label: Label = null
var _panel_original_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	visible = false


## open(dice_list: Array)
##
## Starts die-pick mode over the given dice. Dice must be Dice nodes.
func open(dice_list: Array) -> void:
	_dice.clear()
	for die in dice_list:
		if die is Dice and is_instance_valid(die):
			_dice.append(die)
	if _dice.is_empty():
		push_error("[LoadedDiePicker] open() called with no valid dice")
		return
	visible = true
	_enter_die_pick_phase()
	if _debug_enabled:
		print("[LoadedDiePicker] Opened in DIE_PICK phase with %d dice" % _dice.size())


## close()
##
## Restores dice interaction state, plays the exit tween, and frees the picker.
func close() -> void:
	_release_dice()
	await _animate_out()
	picker_closed.emit()
	queue_free()


## get_die_sides(die: Dice) -> int
##
## Returns the side count for a die (6 when no DiceData is assigned).
static func get_die_sides(die: Dice) -> int:
	if die and die.dice_data:
		return die.dice_data.sides
	return 6


func _enter_die_pick_phase() -> void:
	_phase = Phase.DIE_PICK
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_panel()
	_build_hint()
	_capture_dice()


func _enter_value_pick_phase(die: Dice) -> void:
	_phase = Phase.VALUE_PICK
	_selected_die = die
	_release_dice()
	_clear_hint()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_overlay()
	_build_value_panel(die)
	_animate_in()


## _capture_dice()
##
## Disables lock toggling on every die and listens for the player's click.
func _capture_dice() -> void:
	for die in _dice:
		if not is_instance_valid(die):
			continue
		_saved_locking[die] = die.locking_disabled
		die.locking_disabled = true
		if not die.is_connected("selected", _on_die_picked):
			die.selected.connect(_on_die_picked)


## _release_dice()
##
## Restores locking_disabled and disconnects click listeners from all dice.
func _release_dice() -> void:
	for die in _saved_locking.keys():
		if is_instance_valid(die):
			die.locking_disabled = _saved_locking[die]
			if die.is_connected("selected", _on_die_picked):
				die.selected.disconnect(_on_die_picked)
	_saved_locking.clear()


func _on_die_picked(die: Dice) -> void:
	if _phase != Phase.DIE_PICK:
		return
	if not _dice.has(die):
		return
	if die.current_state == Dice.DiceState.DISABLED:
		return
	if _debug_enabled:
		print("[LoadedDiePicker] Die picked, current value %d, sides %d" % [die.value, get_die_sides(die)])
	_enter_value_pick_phase(die)


func _build_hint() -> void:
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.text = "LOADED DICE — click a die"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_label.anchor_left = 0.5
	_hint_label.anchor_right = 0.5
	_hint_label.offset_left = -260
	_hint_label.offset_right = 260
	_hint_label.offset_top = 24
	_hint_label.add_theme_font_size_override("font_size", 28)
	_hint_label.add_theme_color_override("font_color", PANEL_TEXT)
	_hint_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	_hint_label.add_theme_constant_override("outline_size", 8)
	var vcr_font = load(VCR_FONT_PATH)
	if vcr_font:
		_hint_label.add_theme_font_override("font", vcr_font)
	add_child(_hint_label)


func _clear_hint() -> void:
	if _hint_label and is_instance_valid(_hint_label):
		_hint_label.queue_free()
	_hint_label = null


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)


func _build_value_panel(die: Dice) -> void:
	var sides := get_die_sides(die)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(360, 260)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -180
	_panel.offset_top = -130
	_panel.offset_right = 180
	_panel.offset_bottom = 130

	var theme_res = load(PANEL_THEME_PATH)
	if theme_res:
		_panel.theme = theme_res

	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.corner_detail = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "SET DIE TO… (d%d)" % sides
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", PANEL_TEXT)
	title.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	title.add_theme_constant_override("outline_size", 1)
	vbox.add_child(title)

	var grid = GridContainer.new()
	grid.name = "ValueGrid"
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.columns = 5
	if sides <= 9:
		grid.columns = 3
	vbox.add_child(grid)

	for face in range(1, sides + 1):
		var btn = _make_value_button(face)
		grid.add_child(btn)

	var back_btn = Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hook_button_fx(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)


func _make_value_button(face: int) -> Button:
	var btn = Button.new()
	btn.name = "Value%d" % face
	btn.text = str(face)
	btn.custom_minimum_size = Vector2(64, 64)
	btn.add_theme_font_size_override("font_size", 24)
	_hook_button_fx(btn)
	btn.pressed.connect(_on_value_button_pressed.bind(face))
	return btn


## _hook_button_fx(btn: Button)
##
## Connects TweenFXHelper hover/press juice when the autoload is available.
func _hook_button_fx(btn: Button) -> void:
	var tfx = get_node_or_null("/root/TweenFXHelper")
	if not tfx:
		return
	btn.mouse_entered.connect(tfx.button_hover.bind(btn))
	btn.mouse_exited.connect(tfx.button_unhover.bind(btn))
	btn.pressed.connect(tfx.button_press.bind(btn))


func _on_value_button_pressed(value: int) -> void:
	if _phase != Phase.VALUE_PICK:
		return
	if not is_instance_valid(_selected_die):
		return
	if _debug_enabled:
		print("[LoadedDiePicker] Value chosen: %d" % value)
	value_chosen.emit(_selected_die, value)


func _on_back_pressed() -> void:
	if _phase != Phase.VALUE_PICK:
		return
	_selected_die = null
	_clear_panel()
	_enter_die_pick_phase()


func _clear_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _animate_in() -> void:
	if _overlay:
		_overlay.modulate.a = 0.0
	if _panel:
		await get_tree().process_frame
		_panel_original_pos = _panel.position
		_panel.modulate.a = 0.0
		_panel.position = _panel_original_pos - Vector2(0, 240)

	var tween = create_tween()
	if _overlay:
		tween.parallel().tween_property(_overlay, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _panel:
		tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_panel, "position", _panel_original_pos + Vector2(0, 12), 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(_panel, "position", _panel_original_pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animate_out() -> void:
	var tween = create_tween()
	if _panel and is_instance_valid(_panel):
		tween.parallel().tween_property(_panel, "position:y", _panel_original_pos.y + 260.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _overlay and is_instance_valid(_overlay):
		tween.parallel().tween_property(_overlay, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
