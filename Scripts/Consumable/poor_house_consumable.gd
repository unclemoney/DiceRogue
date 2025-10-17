extends Consumable
class_name PoorHouseConsumable

# Signal for when money is transferred to score bonus
signal money_transferred_to_score(amount: int)

var bonus_applied: bool = false
var game_controller_ref: GameController = null

func _ready() -> void:
	add_to_group("consumables")
	print("[PoorHouseConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[PoorHouseConsumable] Invalid target passed to apply()")
		return
	
	# Store reference to game controller
	game_controller_ref = game_controller
	
	# Get the player's current money from PlayerEconomy
	var player_economy = get_node("/root/PlayerEconomy")
	if not player_economy:
		push_error("[PoorHouseConsumable] PlayerEconomy autoload not found")
		return
	
	var current_money = player_economy.get_money()
	if current_money <= 0:
		print("[PoorHouseConsumable] Player has no money to transfer")
		return
	
	# Transfer all money to the ScoreModifierManager as an additive bonus
	var score_modifier_manager = get_node("/root/ScoreModifierManager")
	if not score_modifier_manager:
		push_error("[PoorHouseConsumable] ScoreModifierManager autoload not found")
		return
	
	# Register the money as a one-time additive bonus
	score_modifier_manager.register_additive("poor_house_bonus", current_money)
	
	# Remove all money from the player
	player_economy.money = 0
	player_economy.emit_signal("money_changed", 0)
	
	# Connect to the scorecard to remove the bonus after first score
	if game_controller.scorecard:
		if not game_controller.scorecard.is_connected("score_auto_assigned", _on_score_assigned):
			game_controller.scorecard.score_auto_assigned.connect(_on_score_assigned)
	
	# Emit our custom signal
	emit_signal("money_transferred_to_score", current_money)
	
	print("[PoorHouseConsumable] Transferred $%d from player to next scored hand" % current_money)

func _on_score_assigned(_section: int, _category: String, _score: int) -> void:
	# Only process once
	if bonus_applied:
		return
	
	bonus_applied = true
	
	# Remove the poor house bonus from ScoreModifierManager
	var score_modifier_manager = get_node("/root/ScoreModifierManager")
	if score_modifier_manager:
		score_modifier_manager.unregister_additive("poor_house_bonus")
		print("[PoorHouseConsumable] Removed poor house bonus after score was applied")
	
	# Disconnect from the scorecard signal
	if game_controller_ref and game_controller_ref.scorecard:
		if game_controller_ref.scorecard.is_connected("score_auto_assigned", _on_score_assigned):
			game_controller_ref.scorecard.score_auto_assigned.disconnect(_on_score_assigned)