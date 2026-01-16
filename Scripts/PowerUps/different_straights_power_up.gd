extends PowerUp
class_name DifferentStraightsPowerUp

## DifferentStraightsPowerUp
##
## A rare PowerUp that allows straights to have one gap of 1.
## Example: [1,2,3,4,6] counts as a large straight (gap between 4 and 6)
## Example: [2,3,5,6] counts as a small straight (gap between 3 and 5)
## 
## Uses a property-based approach on the Scorecard to enable gap detection.

# Reference to target scorecard
var scorecard_ref: Scorecard = null

func _ready() -> void:
	add_to_group("power_ups")
	print("[DifferentStraightsPowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	print("=== Applying DifferentStraightsPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[DifferentStraightsPowerUp] Target is not a Scorecard")
		return
	
	# Store reference to the scorecard
	scorecard_ref = scorecard
	
	# Enable gap straights on the scorecard
	scorecard.allow_gap_straights = true
	print("[DifferentStraightsPowerUp] Enabled gap straights on scorecard")
	
	# Connect to tree_exiting for cleanup
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	print("[DifferentStraightsPowerUp] Applied successfully - straights can now have one gap")

func remove(target) -> void:
	print("=== Removing DifferentStraightsPowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		# Disable gap straights
		scorecard.allow_gap_straights = false
		print("[DifferentStraightsPowerUp] Disabled gap straights on scorecard")
	
	scorecard_ref = null

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if scorecard_ref:
		scorecard_ref.allow_gap_straights = false
		print("[DifferentStraightsPowerUp] Cleanup: Disabled gap straights")
