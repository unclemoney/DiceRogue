extends Control

## CarryOverPanel Fit Test
##
## Auto-opens the CarryOverPanel with the worst case (all 7 types) so the
## panel's on-screen fit can be visually verified via screenshot.

const CARRY_OVER_SCENE = preload("res://Scenes/UI/CarryOverPanel.tscn")


func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel = CARRY_OVER_SCENE.instantiate()
	add_child(panel)
	var types: Array[String] = ["power_ups", "consumables", "colored_dice", "mods", "consoles", "money", "scorecard_levels"]
	panel.show_panel(5, types, 2)
	print("[CarryOverPanelFitTest] Panel shown with all 7 types")
