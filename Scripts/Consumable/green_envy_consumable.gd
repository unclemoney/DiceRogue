extends Consumable
class_name GreenEnvyConsumable

# Track the registered modifier name for cleanup
var modifier_source_name: String = "green_envy_consumable"
var _game_controller_ref: GameController = null
var _scorecard_ref: Scorecard = null

func _ready() -> void:
	add_to_group("consumables")
	print("[GreenEnvyConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[GreenEnvyConsumable] Invalid target passed to apply()")
		apply_succeeded = false
		return
	
	print("[GreenEnvyConsumable] Applying green dice 10x multiplier for this turn")
	
	# Access the ScoreModifierManager autoload to register a temporary multiplier
	var multiplier_manager = ScoreModifierManager
	if not multiplier_manager:
		push_error("[GreenEnvyConsumable] ScoreModifierManager not found as autoload")
		apply_succeeded = false
		return
	
	if not game_controller.scorecard:
		push_error("[GreenEnvyConsumable] No scorecard found")
		apply_succeeded = false
		return
	_game_controller_ref = game_controller
	_scorecard_ref = game_controller.scorecard

	# Connect to scoring events to apply the green dice bonus
	if not game_controller.scorecard.is_connected("score_assigned", _on_score_assigned):
		game_controller.scorecard.score_assigned.connect(_on_score_assigned)
		print("[GreenEnvyConsumable] Connected to score_assigned signal")
	
	print("[GreenEnvyConsumable] Applied successfully - waiting for scoring event")

## _on_score_assigned(_section, _category, _score)
##
## Called when a score is assigned. Checks for green dice in current dice hand
## and applies 10x multiplier to green dice money earned this turn.
func _on_score_assigned(_section: int, _category: String, _score: int) -> void:
	print("[GreenEnvyConsumable] Score assigned - checking for green dice effects")
	
	var game_controller = _game_controller_ref
	if not game_controller:
		game_controller = get_node_or_null("/root/GameController")
	if not game_controller:
		game_controller = get_tree().get_first_node_in_group("game_controller")
	
	if not game_controller:
		push_error("[GreenEnvyConsumable] Could not find GameController")
		_cleanup_and_disconnect(null)
		return
	
	# Get the dice color manager to check current dice
	var dice_color_manager = DiceColorManager
	if not dice_color_manager:
		push_error("[GreenEnvyConsumable] DiceColorManager not found as autoload")
		_cleanup_and_disconnect(game_controller)
		return
	
	# Get current dice from the dice hand
	if not game_controller.dice_hand:
		push_error("[GreenEnvyConsumable] No dice hand found")
		_cleanup_and_disconnect(game_controller)
		return
	
	var current_dice = game_controller.dice_hand.get_all_dice()
	if current_dice.is_empty():
		print("[GreenEnvyConsumable] No dice in hand - no green dice to multiply")
		_cleanup_and_disconnect(game_controller)
		return
	
	# Calculate green dice effects
	var color_effects = dice_color_manager.calculate_color_effects(current_dice)
	var green_money = color_effects.get("green_money", 0)
	var green_count = color_effects.get("green_count", 0)
	
	print("[GreenEnvyConsumable] Found %d green dice worth $%d" % [green_count, green_money])
	
	if green_count > 0 and green_money > 0:
		# Apply 10x multiplier to green dice money (9x additional since base is already counted)
		var bonus_money = green_money * 9  # 10x total = original + 9x bonus
		
		var player_economy = get_node("/root/PlayerEconomy")
		if player_economy:
			player_economy.add_money(bonus_money)
			print("[GreenEnvyConsumable] Applied 10x multiplier: +$%d bonus (total green effect: $%d)" % [bonus_money, green_money * 10])
		else:
			push_error("[GreenEnvyConsumable] PlayerEconomy autoload not found")
	else:
		print("[GreenEnvyConsumable] No green dice scored - consumable had no effect")
	
	# Clean up and disconnect after use
	_cleanup_and_disconnect(game_controller)

## _cleanup_and_disconnect(game_controller)
##
## Disconnects from signals and cleans up the consumable effect
func _cleanup_and_disconnect(game_controller: GameController) -> void:
	var scorecard = _scorecard_ref
	if game_controller and game_controller.scorecard:
		scorecard = game_controller.scorecard
	if is_instance_valid(scorecard):
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
			print("[GreenEnvyConsumable] Disconnected from score_assigned signal")
	_scorecard_ref = null
	_game_controller_ref = null
	print("[GreenEnvyConsumable] Effect completed and cleaned up")


func _exit_tree() -> void:
	_cleanup_and_disconnect(null)