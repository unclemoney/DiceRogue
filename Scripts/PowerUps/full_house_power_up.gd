extends PowerUp
class_name FullHousePowerUp

## FullHousePowerUp
##
## Grants increasing money for every full house rolled throughout the game.
## Base reward: $7 per full house
## Scaling: Adds $7 for each additional full house rolled (e.g., 1st = $7, 2nd = $14, etc.)
##
## This PowerUp connects to the Scorecard to detect full house patterns in dice
## regardless of which category the player scores them in.

# Track full houses for this session
var total_full_houses_earned: int = 0
var base_money_per_full_house: int = 7

var scorecard_ref: Scorecard = null

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(_target) -> void:
	print("=== Applying FullHousePowerUp ===")
	
	# Find the scorecard in the scene
	scorecard_ref = get_tree().get_first_node_in_group("scorecard") as Scorecard
	if scorecard_ref:
		if not scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.connect(_on_score_assigned)
			print("[FullHousePowerUp] Connected to scorecard score_assigned signal")
	else:
		push_error("[FullHousePowerUp] Could not find Scorecard in scene")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_score_assigned(_section: Scorecard.Section, _category: String, score: int) -> void:
	if score <= 0:
		return
	
	# Check if the current dice values form a full house
	if DiceResults.values.size() >= 5 and ScoreEvaluatorSingleton.is_full_house(DiceResults.values):
		_grant_full_house_money()

func _grant_full_house_money() -> void:
	total_full_houses_earned += 1
	
	# Calculate scaled money reward: $7 for each full house rolled this game
	var money_reward = total_full_houses_earned * base_money_per_full_house
	
	# Add money to player's economy
	PlayerEconomy.add_money(money_reward)
	
	print("[FullHousePowerUp] Full house #%d rolled! Granted $%d (total full houses this game: %d)" % [total_full_houses_earned, money_reward, total_full_houses_earned])
	
	# Update the description to show current progress
	emit_signal("description_updated", id, get_current_description())
	
	# Update any power-up icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var base_desc = "+$7 for each full house (scaling with total rolled)"
	
	if total_full_houses_earned > 0:
		var next_reward = (total_full_houses_earned + 1) * base_money_per_full_house
		var progress_desc = "\nFull houses rolled: %d (next: $%d)" % [total_full_houses_earned, next_reward]
		return base_desc + progress_desc
	
	return base_desc

func _update_power_up_icons() -> void:
	# Guard against calling when not in tree or tree is null
	if not is_inside_tree() or not get_tree():
		return
	
	# Find the PowerUpUI in the scene
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		# Get the icon for this power-up
		var icon = power_up_ui.get_power_up_icon("full_house_bonus")
		if icon:
			# Update its description
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)

func remove(_target) -> void:
	print("=== Removing FullHousePowerUp ===")
	
	# Disconnect scorecard signals
	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	
	# Reset state
	total_full_houses_earned = 0
	scorecard_ref = null
