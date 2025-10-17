extends PowerUp
class_name PinHeadPowerUp

## PinHeadPowerUp
##
## When a hand is scored, this PowerUp picks a random dice from the dice hand
## and uses that dice's value as a multiplier for the current score.
##
## Example: Player rolls small straight (1,2,3,4,5) with base score 30.
## If randomizer picks the 3, final score becomes 30 x 3 = 90.

# Reference to the scorecard and dice hand to listen for scoring and get dice values
var scorecard_ref: Scorecard = null
var dice_hand_ref: DiceHand = null
var game_controller_ref: GameController = null

# Track statistics for description updates
var total_multiplications: int = 0
var total_bonus_points: int = 0
var last_multiplier: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[PinHeadPowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	print("=== Applying PinHeadPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[PinHeadPowerUp] Target is not a Scorecard")
		return
	
	# Store a reference to the scorecard
	scorecard_ref = scorecard
	
	# Get references to dice hand, game controller, and scorecard UI through the tree
	if get_tree():
		dice_hand_ref = get_tree().get_first_node_in_group("dice_hand")
		game_controller_ref = get_tree().get_first_node_in_group("game_controller")
	
	if not dice_hand_ref:
		push_error("[PinHeadPowerUp] Could not find DiceHand in scene tree")
		return
	
	if not game_controller_ref:
		push_error("[PinHeadPowerUp] Could not find GameController in scene tree")
		return
	
	# Connect to the ScoreCardUI's about_to_score signal (fires BEFORE scoring)
	var scorecard_ui = game_controller_ref.score_card_ui if game_controller_ref else null
	if scorecard_ui:
		if not scorecard_ui.is_connected("about_to_score", _on_about_to_score):
			scorecard_ui.about_to_score.connect(_on_about_to_score)
			print("[PinHeadPowerUp] Connected to about_to_score signal")
	else:
		push_error("[PinHeadPowerUp] Could not find ScoreCardUI in GameController")
		return
	
	# Also connect to score_assigned signal for statistics tracking (fires AFTER scoring)
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[PinHeadPowerUp] Connected to score_assigned signal for stats")
	
	print("[PinHeadPowerUp] Found DiceHand, GameController, and ScoreCardUI references")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(target) -> void:
	print("=== Removing PinHeadPowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		# Disconnect signals
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
			print("[PinHeadPowerUp] Disconnected from score_assigned signal")
	
	# Disconnect from ScoreCardUI signal
	var scorecard_ui = game_controller_ref.score_card_ui if game_controller_ref else null
	if scorecard_ui:
		if scorecard_ui.is_connected("about_to_score", _on_about_to_score):
			scorecard_ui.about_to_score.disconnect(_on_about_to_score)
			print("[PinHeadPowerUp] Disconnected from about_to_score signal")
	
	# Unregister any active multiplier from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_multiplier("pin_head")
			print("[PinHeadPowerUp] Multiplier unregistered from ScoreModifierManager")
	
	scorecard_ref = null
	dice_hand_ref = null
	game_controller_ref = null

func _on_about_to_score(section: Scorecard.Section, category: String, dice_values: Array[int]) -> void:
	print("\n=== PinHeadPowerUp About To Score ===")
	print("[PinHeadPowerUp] About to score - Section:", section, "Category:", category, "Dice:", dice_values)
	
	# Only apply the multiplier if we have valid dice
	if dice_values.is_empty():
		print("[PinHeadPowerUp] No dice values, skipping multiplier")
		return
	
	# Pick a random dice value as the multiplier
	var multiplier = dice_values[randi() % dice_values.size()]
	last_multiplier = multiplier
	
	print("[PinHeadPowerUp] Randomly selected dice value:", multiplier)
	print("[PinHeadPowerUp] This multiplier will be applied to the score calculation")
	
	# Register the multiplier with ScoreModifierManager BEFORE scoring happens
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			# First unregister any existing multiplier, then register the new one
			manager.unregister_multiplier("pin_head")
			manager.register_multiplier("pin_head", multiplier)
			print("[PinHeadPowerUp] Registered multiplier of", multiplier, "with ScoreModifierManager")
			
			# Update description
			emit_signal("description_updated", id, get_current_description())
			
			# Update UI
			if is_inside_tree():
				_update_power_up_icons()
		else:
			push_error("[PinHeadPowerUp] Could not access ScoreModifierManager")
	else:
		push_error("[PinHeadPowerUp] ScoreModifierManager not available")

func _on_score_assigned(section: Scorecard.Section, category: String, score: int) -> void:
	print("\n=== PinHeadPowerUp Score Assigned (Stats Update) ===")
	print("[PinHeadPowerUp] Score assigned - Section:", section, "Category:", category, "Score:", score)
	
	# Update statistics if we had applied a multiplier
	if last_multiplier > 0:
		total_multiplications += 1
		var base_score = float(score) / float(last_multiplier) if last_multiplier > 0 else float(score)
		var bonus_points = score - base_score
		total_bonus_points += int(bonus_points)
		
		print("[PinHeadPowerUp] Estimated base score:", base_score, "Final score:", score, "Bonus:", bonus_points)
		
		# Update description
		emit_signal("description_updated", id, get_current_description())
		
		# Update UI
		if is_inside_tree():
			_update_power_up_icons()
	
	# Clear the multiplier after scoring is complete
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_multiplier("pin_head")
			print("[PinHeadPowerUp] Cleared multiplier after scoring")

func get_current_description() -> String:
	var base_desc = "When scoring, picks a random dice value as multiplier"
	
	if total_multiplications > 0:
		var progress_desc = "\nActivations: %d (Last: x%d)\nBonus points: +%d" % [total_multiplications, last_multiplier, total_bonus_points]
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
		var icon = power_up_ui.get_power_up_icon("pin_head")
		if icon:
			icon.update_hover_description()

func _is_score_modifier_manager_available() -> bool:
	# Check if ScoreModifierManager exists as an autoload singleton
	if Engine.has_singleton("ScoreModifierManager"):
		return true
	
	# Fallback: check if it exists in the scene tree as a group member
	if get_tree():
		var group_node = get_tree().get_first_node_in_group("score_modifier_manager")
		if group_node:
			return true
		# Also check old group name for backward compatibility
		var old_group_node = get_tree().get_first_node_in_group("multiplier_manager")
		if old_group_node:
			return true
	
	return false

func _get_score_modifier_manager():
	# Check if ScoreModifierManager exists as an autoload singleton
	if Engine.has_singleton("ScoreModifierManager"):
		return ScoreModifierManager
	
	# Fallback: check new group name first
	if get_tree():
		var group_node = get_tree().get_first_node_in_group("score_modifier_manager")
		if group_node:
			return group_node
		# Then check old group name for backward compatibility
		var old_group_node = get_tree().get_first_node_in_group("multiplier_manager")
		if old_group_node:
			return old_group_node
	
	return null

func _on_tree_exiting() -> void:
	print("[PinHeadPowerUp] Node is being destroyed, cleaning up")
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	
	# Disconnect from ScoreCardUI signal
	var scorecard_ui = get_tree().get_first_node_in_group("game_controller")
	if scorecard_ui:
		scorecard_ui = scorecard_ui.score_card_ui
		if scorecard_ui and scorecard_ui.is_connected("about_to_score", _on_about_to_score):
			scorecard_ui.about_to_score.disconnect(_on_about_to_score)
	
	# Unregister from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_multiplier("pin_head")
			print("[PinHeadPowerUp] Multiplier unregistered from ScoreModifierManager")