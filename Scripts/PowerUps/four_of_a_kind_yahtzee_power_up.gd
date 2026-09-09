extends PowerUp
class_name FourOfAKindYahtzeePowerUp

## FourOfAKindYahtzeePowerUp
##
## An epic PowerUp that lets four-of-a-kind count as a Yahtzee with a
## reduced payout of 25 points (vs 50).
## Example: [4,4,4,4,2] scores 25 in the yahtzee category.
##
## CATEGORY SCORE ONLY: does not trigger bonus Yahtzee logic
## (yahtzee_bonus_achieved, joker rules, YahtzeeBonusMult) because
## ScoreEvaluator.is_yahtzee() is deliberately left unchanged.
##
## Uses a property-based approach on the Scorecard to enable the bend.

var _debug_enabled: bool = OS.is_debug_build()

# Reference to target scorecard
var scorecard_ref: Scorecard = null

func _ready() -> void:
	add_to_group("power_ups")
	if _debug_enabled:
		print("[FourOfAKindYahtzeePowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	if _debug_enabled:
		print("=== Applying FourOfAKindYahtzeePowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[FourOfAKindYahtzeePowerUp] Target is not a Scorecard")
		return
	
	# Store reference to the scorecard
	scorecard_ref = scorecard
	
	# Enable four-kind yahtzees on the scorecard
	scorecard.allow_four_kind_yahtzee = true
	if _debug_enabled:
		print("[FourOfAKindYahtzeePowerUp] Enabled four-kind yahtzees on scorecard")
	
	# Connect to tree_exiting for cleanup
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	if _debug_enabled:
		print("[FourOfAKindYahtzeePowerUp] Applied successfully - four-of-a-kind scores 25 as Yahtzee")

func remove(target) -> void:
	if _debug_enabled:
		print("=== Removing FourOfAKindYahtzeePowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		# Disable four-kind yahtzees
		scorecard.allow_four_kind_yahtzee = false
		if _debug_enabled:
			print("[FourOfAKindYahtzeePowerUp] Disabled four-kind yahtzees on scorecard")
	
	scorecard_ref = null

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if scorecard_ref:
		scorecard_ref.allow_four_kind_yahtzee = false
		if _debug_enabled:
			print("[FourOfAKindYahtzeePowerUp] Cleanup: Disabled four-kind yahtzees")
