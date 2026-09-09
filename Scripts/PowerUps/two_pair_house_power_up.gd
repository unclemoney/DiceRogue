extends PowerUp
class_name TwoPairHousePowerUp

## TwoPairHousePowerUp
##
## A rare PowerUp that lets two pair count as a Full House for 25 points.
## Example: [3,3,5,5,1] scores 25 in the full_house category.
##
## Uses a property-based approach on the Scorecard to enable the bend.

var _debug_enabled: bool = OS.is_debug_build()

# Reference to target scorecard
var scorecard_ref: Scorecard = null

func _ready() -> void:
	add_to_group("power_ups")
	if _debug_enabled:
		print("[TwoPairHousePowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	if _debug_enabled:
		print("=== Applying TwoPairHousePowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[TwoPairHousePowerUp] Target is not a Scorecard")
		return
	
	# Store reference to the scorecard
	scorecard_ref = scorecard
	
	# Enable two-pair full houses on the scorecard
	scorecard.allow_two_pair_full_house = true
	if _debug_enabled:
		print("[TwoPairHousePowerUp] Enabled two-pair full houses on scorecard")
	
	# Connect to tree_exiting for cleanup
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	if _debug_enabled:
		print("[TwoPairHousePowerUp] Applied successfully - two pair scores 25 as Full House")

func remove(target) -> void:
	if _debug_enabled:
		print("=== Removing TwoPairHousePowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		# Disable two-pair full houses
		scorecard.allow_two_pair_full_house = false
		if _debug_enabled:
			print("[TwoPairHousePowerUp] Disabled two-pair full houses on scorecard")
	
	scorecard_ref = null

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if scorecard_ref:
		scorecard_ref.allow_two_pair_full_house = false
		if _debug_enabled:
			print("[TwoPairHousePowerUp] Cleanup: Disabled two-pair full houses")
