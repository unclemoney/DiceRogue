extends PowerUp
class_name FoursomePowerUp

signal multiplier_active(is_active: bool)

var _active_scorecard: Scorecard = null

func apply(target) -> void:
	var scorecard = target as Scorecard
	if scorecard:
		print("\n=== Applying FoursomePowerUp ===")
		print("[FoursomePowerUp] Target scorecard:", scorecard)
		_active_scorecard = scorecard
		scorecard.set_score_multiplier(_apply_foursome_bonus)
		print("[FoursomePowerUp] Score multiplier set")
		emit_signal("multiplier_active", true)
	else:
		push_error("[FoursomePowerUp] Invalid target passed to apply()")

func remove(target) -> void:
	var scorecard = target as Scorecard
	if scorecard and scorecard == _active_scorecard:
		print("[FoursomePowerUp] Removing from scorecard")
		scorecard.clear_score_multiplier()
		_active_scorecard = null
		emit_signal("multiplier_active", false)
	else:
		push_error("[FoursomePowerUp] Invalid target passed to remove()")

func _apply_foursome_bonus(category: String, base_score: int, values: Array[int]) -> int:
	print("\n=== Foursome Bonus Calculation ===")
	print("[FoursomePowerUp] Category:", category)
	print("[FoursomePowerUp] Base score:", base_score)
	print("[FoursomePowerUp] Values:", values)
	
	# Check if 4s are involved in the score
	var has_fours = values.has(4)
	print("[FoursomePowerUp] Has fours:", has_fours)
	
	if not has_fours:
		print("[FoursomePowerUp] No fours - returning base score")
		return base_score
		
	print("[FoursomePowerUp] Found 4s in roll, applying multiplier")
	var final_score: int
	
	match category:
		"fours":
			final_score = base_score * 4
			print("[FoursomePowerUp] Fours category - multiplying by 4:", final_score)
		"three_of_a_kind", "four_of_a_kind", "full_house", "small_straight", "large_straight", "chance":
			final_score = base_score * 4
			print("[FoursomePowerUp] Lower section category - multiplying by 4:", final_score)
		"yahtzee":
			if values.count(4) >= 5:
				final_score = base_score * 4
				print("[FoursomePowerUp] Yahtzee of fours - multiplying by 4:", final_score)
			else:
				final_score = base_score
				print("[FoursomePowerUp] Non-four yahtzee - keeping base score")
		_:
			final_score = base_score
			print("[FoursomePowerUp] Unhandled category - keeping base score")
	
	print("[FoursomePowerUp] Final score:", final_score)
	return final_score
