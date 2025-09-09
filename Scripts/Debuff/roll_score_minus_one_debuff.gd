extends Debuff
class_name RollScoreMinusOneDebuff

var scorecard: Scorecard = null
var turn_tracker: TurnTracker = null
var roll_count: int = 0

func _ready() -> void:
	add_to_group("debuffs")
	print("=== [RollScoreMinusOneDebuff] Ready and initialized ===")

func apply(target) -> void:
	print("[RollScoreMinusOneDebuff] Applying to target:", target.name if target else "null")
	var game_controller = target as GameController
	if game_controller:
		is_active = true
		
		# Get references to needed components
		scorecard = game_controller.scorecard
		if not scorecard:
			push_error("[RollScoreMinusOneDebuff] No scorecard found in game controller")
			return
			
		turn_tracker = game_controller.turn_tracker
		if not turn_tracker:
			push_error("[RollScoreMinusOneDebuff] No turn tracker found in game controller")
			return
		
		# Get dice hand to track rolls
		var dice_hand = game_controller.dice_hand
		if dice_hand:
			print("[RollScoreMinusOneDebuff] Getting dice_hand roll signals")
			
			# Try to connect to roll_complete (exists) instead of roll_started (missing)
			if dice_hand.has_signal("roll_complete"):
				if not dice_hand.is_connected("roll_complete", _on_roll_complete):
					dice_hand.roll_complete.connect(_on_roll_complete)
					print("[RollScoreMinusOneDebuff] Connected to dice_hand roll_complete")
				else:
					print("[RollScoreMinusOneDebuff] Already connected to roll_complete")
			else:
				push_error("[RollScoreMinusOneDebuff] DiceHand missing roll_complete signal")
		else:
			push_error("[RollScoreMinusOneDebuff] No dice_hand found in game controller")
			
		# Connect to scorecard for score modification
		if scorecard:
			scorecard.register_score_modifier(self)
			print("[RollScoreMinusOneDebuff] Registered as score modifier")
	
		print("[RollScoreMinusOneDebuff] Roll penalty active - current roll count:", roll_count)
	else:
		push_error("[RollScoreMinusOneDebuff] Invalid target passed to apply() - expected GameController")

# Rename this function to match the signal we're now connecting to
func _on_roll_complete() -> void:
	if is_active:
		roll_count += 1
		print("[RollScoreMinusOneDebuff] Roll count increased to:", roll_count)

# Rename this method
func modify_score(section: int, category: String, score: int) -> int:
	if not is_active:
		return score
		
	# Calculate penalty
	var final_score = max(0, score - roll_count)
	print("[RollScoreMinusOneDebuff] Applying roll penalty to score: ", 
		score, " - ", roll_count, " = ", final_score)
	
	return final_score

func remove() -> void:
	print("[RollScoreMinusOneDebuff] Removing effect")
	
	# Disconnect from dice hand
	var game_controller = target as GameController
	if game_controller and game_controller.dice_hand:
		var dice_hand = game_controller.dice_hand
		if dice_hand.is_connected("roll_complete", _on_roll_complete):
			dice_hand.roll_complete.disconnect(_on_roll_complete)
	
	# Disconnect from scorecard
	if scorecard:
		scorecard.unregister_score_modifier(self)
	
	is_active = false
	roll_count = 0
	print("[RollScoreMinusOneDebuff] Removed roll penalty effect")
