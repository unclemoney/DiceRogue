extends PowerUp
class_name ChallengeEaserPowerUp

## ChallengeEaserPowerUp
##
## Epic PowerUp that reduces all challenge score requirements by 20%.
## Makes completing challenges easier by lowering the target score.
## Sets GameController.challenge_score_modifier to 0.8.
## Price: $450, Rarity: Epic

const REDUCTION_PERCENT: float = 0.20  # 20% reduction

var game_controller_ref: GameController = null
var challenges_eased: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(_target) -> void:
	print("=== Applying ChallengeEaserPowerUp ===")
	
	game_controller_ref = get_tree().get_first_node_in_group("game_controller") as GameController
	if not game_controller_ref:
		push_error("[ChallengeEaserPowerUp] GameController not found")
		return
	
	# Apply the challenge score modifier directly on GameController
	game_controller_ref.challenge_score_modifier *= (1.0 - REDUCTION_PERCENT)
	print("[ChallengeEaserPowerUp] Challenge score modifier set to %.2f (targets reduced by %.0f%%)" % [game_controller_ref.challenge_score_modifier, REDUCTION_PERCENT * 100])
	challenges_eased += 1
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing ChallengeEaserPowerUp ===")
	if game_controller_ref:
		# Undo our reduction
		game_controller_ref.challenge_score_modifier /= (1.0 - REDUCTION_PERCENT)
		print("[ChallengeEaserPowerUp] Restored challenge score modifier to %.2f" % game_controller_ref.challenge_score_modifier)
	game_controller_ref = null

func get_current_description() -> String:
	return "Challenge score targets reduced by %.0f%%.\nMakes challenges easier to complete!" % (REDUCTION_PERCENT * 100)

func _on_tree_exiting() -> void:
	if game_controller_ref:
		game_controller_ref.challenge_score_modifier /= (1.0 - REDUCTION_PERCENT)
