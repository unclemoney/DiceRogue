extends Control

## NewRoundPanel Visual Test
##
## Auto-opens the NewRoundPanel with sample data (challenge + 2 debuffs) so
## the backdrop shader and debuff rows can be visually verified.

const NEW_ROUND_SCENE = preload("res://Scenes/UI/new_round_panel.tscn")


func _ready() -> void:
	var panel = NEW_ROUND_SCENE.instantiate()
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.size = get_viewport_rect().size
	panel.setup({
		"channel": 2,
		"round_number": 3,
		"challenge_name": "Triple Threat",
		"challenge_desc": "Score 300 points while battling multiple debuffs.",
		"debuffs": [
			{"name": "Lock Dice", "glyph_id": 0, "difficulty_rating": 2},
			{"name": "Costly Roll", "glyph_id": 1, "difficulty_rating": 3}
		]
	})
	panel.show_panel()
	print("[NewRoundPanelVisualTest] Panel shown")
