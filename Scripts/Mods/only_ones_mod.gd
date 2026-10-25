extends Mod
class_name OnlyOnesMod

@export var trigger_probability: float = 0.01

var _attached_die: Dice = null

func _ready() -> void:
	add_to_group("mods")
	print("[OnlyOnesMod] Ready")

## apply(dice_target)
##
## Attaches the mod to a die and connects its roll-completion signal.
func apply(dice_target) -> void:
	var dice = dice_target as Dice
	if dice:
		print("[OnlyOnesMod] Applied to die:", dice.name)
		_attached_die = dice
		target = dice_target
		_attached_die.rolled.connect(_on_die_roll_completed)
		emit_signal("mod_applied")
	else:
		push_error("[OnlyOnesMod] Invalid target passed to apply()")

## remove()
##
## Disconnects the mod from its attached die.
func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_roll_completed):
			_attached_die.rolled.disconnect(_on_die_roll_completed)
		_attached_die = null
	emit_signal("mod_removed")

## _on_die_roll_completed(_value)
##
## Forces the die to 1, then performs one independent trigger check per roll.
func _on_die_roll_completed(_value: int) -> void:
	_attached_die.value = 1
	_attached_die.update_visual()
	if GameRNG.randf() < trigger_probability:
		_on_trigger()

## _on_trigger()
##
## Scores the remaining target gap into the highest-value available category.
## set_score() emits score_changed, using the normal round-completion path.
func _on_trigger() -> void:
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not is_instance_valid(game_controller):
		return
	var scorecard = game_controller.scorecard as Scorecard
	if not scorecard:
		return
	var gap := int(game_controller._current_round_target) - scorecard.get_total_score()
	if gap <= 0:
		return
	var values: Array[int] = []
	if is_instance_valid(game_controller.dice_hand):
		values.assign(game_controller.dice_hand.get_current_dice_values())
	else:
		values.assign(DiceResults.values)
	var best_score := -1
	var best_section := Scorecard.Section.UPPER
	var best_category := ""
	for category in scorecard.upper_scores.keys():
		if scorecard.upper_scores[category] != null or not scorecard.is_category_available_for_dice_set(category):
			continue
		var category_score := scorecard.evaluate_category(category, values)
		if category_score > best_score:
			best_score = category_score
			best_section = Scorecard.Section.UPPER
			best_category = category
	for category in scorecard.lower_scores.keys():
		if scorecard.lower_scores[category] != null or not scorecard.is_category_available_for_dice_set(category):
			continue
		var category_score := scorecard.evaluate_category(category, values)
		if category_score > best_score:
			best_score = category_score
			best_section = Scorecard.Section.LOWER
			best_category = category
	if best_category.is_empty():
		return
	var snapshot := scorecard.create_direct_score_snapshot(best_section, best_category, gap, values, "only_ones")
	scorecard.set_score(best_section, best_category, gap, snapshot)
