extends Consumable
class_name ScoreRerollConsumable

func apply(target) -> void:
	var game_controller = target as Node
	if game_controller:
		var score_card_ui = game_controller.get_node(game_controller.score_card_ui_path)
		if score_card_ui:
			score_card_ui.allow_extra_score()
	else:
		push_error("[ScoreReroll] Invalid target passed to apply()")
