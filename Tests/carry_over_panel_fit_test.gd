extends Control

## CarryOverPanel Fit Test
##
## Auto-opens the CarryOverPanel with the worst case (all 7 types) so the
## panel's on-screen fit can be visually verified via screenshot.
## Simulates the real game flow: show (Zone 2), confirm, show again (Zone 3)
## on the SAME instance — the second show used to mis-measure the panel
## because queue_free()'d rows still counted toward its minimum size.
## Saves a screenshot of each show to user:// and quits.

const CARRY_OVER_SCENE = preload("res://Scenes/UI/CarryOverPanel.tscn")

var panel: CarryOverPanel
var _phase: int = 0


func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	panel = CARRY_OVER_SCENE.instantiate()
	add_child(panel)
	panel.carryover_confirmed.connect(_on_first_confirmed)
	var types: Array[String] = ["power_ups", "consumables", "colored_dice", "mods", "consoles", "money", "scorecard_levels"]
	panel.show_panel(5, types, 2)
	print("[CarryOverPanelFitTest] Panel shown with all 7 types (Zone 2)")

	# Select two rows so the dim/checkmark contrast is visible in the shot
	await get_tree().create_timer(1.5).timeout
	var buttons: Dictionary = panel._toggle_buttons
	var keys: Array = buttons.keys()
	buttons[keys[0]].set_toggled(true, true)
	buttons[keys[2]].set_toggled(true, true)

	await get_tree().create_timer(0.5).timeout
	_report_fit("Zone 2 (first show)")
	_save_shot("carry_over_fit_zone2.png")

	# Confirm and re-show, exactly like advancing to Zone 3
	panel._on_confirm_pressed()


func _on_first_confirmed(_selected: Array[String]) -> void:
	if _phase > 0:
		return
	_phase += 1
	var types: Array[String] = ["power_ups", "consumables", "colored_dice", "mods", "consoles", "money", "scorecard_levels"]
	panel.show_panel(5, types, 3)
	print("[CarryOverPanelFitTest] Panel re-shown with all 7 types (Zone 3)")

	await get_tree().create_timer(2.0).timeout
	var buttons: Dictionary = panel._toggle_buttons
	var keys: Array = buttons.keys()
	buttons[keys[1]].set_toggled(true, true)

	await get_tree().create_timer(0.5).timeout
	_report_fit("Zone 3 (second show)")
	_save_shot("carry_over_fit_zone3.png")
	get_tree().quit()


func _report_fit(label: String) -> void:
	var pc: PanelContainer = panel.panel_container
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var fits := pc.position.y >= 0.0 and pc.position.y + pc.size.y <= viewport_size.y
	print("[CarryOverPanelFitTest] %s: viewport=%s panel pos=%s size=%s fits=%s" % [
		label, str(viewport_size), str(pc.position), str(pc.size), str(fits)])


func _save_shot(file_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "user://" + file_name
	img.save_png(path)
	print("[CarryOverPanelFitTest] Saved %s" % ProjectSettings.globalize_path(path))
