extends PowerUp
class_name OneRollWonderPowerUp

## OneRollWonderPowerUp
##
## If the player scores on their first roll (0 rerolls used), grants +40 additive.
## Uses the conditional about_to_score pattern — registers before scoring, unregisters after.
## Rare rarity, $250 price.

# References
var scorecard_ref: Scorecard = null
var turn_tracker_ref: TurnTracker = null
var score_card_ui_ref = null

# ScoreModifierManager source name
var modifier_source_name: String = "one_roll_wonder"

# Track for description
var times_triggered: int = 0
var bonus_amount: int = 40

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying OneRollWonderPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[OneRollWonderPowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Get turn tracker and score_card_ui from tree
	var tree = scorecard.get_tree()
	if tree:
		turn_tracker_ref = tree.get_first_node_in_group("turn_tracker")
		
		var game_controller = tree.get_first_node_in_group("game_controller")
		if game_controller and game_controller.score_card_ui:
			score_card_ui_ref = game_controller.score_card_ui
	
	# Connect to about_to_score to conditionally register additive
	if score_card_ui_ref:
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
			print("[OneRollWonderPowerUp] Connected to about_to_score signal")
	
	# Connect to score_assigned to clean up additive
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[OneRollWonderPowerUp] Connected to score_assigned signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	if not turn_tracker_ref:
		return
	
	# Check if this is the first roll (0 rerolls used)
	# rolls_left == MAX_ROLLS - 1 means only 1 roll was used (the initial roll)
	var rolls_used = turn_tracker_ref.MAX_ROLLS - turn_tracker_ref.rolls_left
	
	if rolls_used <= 1:
		ScoreModifierManager.register_additive(modifier_source_name, bonus_amount)
		print("[OneRollWonderPowerUp] First roll! Registered +%d additive" % bonus_amount)
	else:
		print("[OneRollWonderPowerUp] Used %d rolls — no bonus" % rolls_used)

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Track triggers
	if ScoreModifierManager.has_additive(modifier_source_name):
		times_triggered += 1
	
	# Clean up additive after scoring
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
		print("[OneRollWonderPowerUp] Cleaned up additive after scoring")
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var base_desc = "Score on first roll = +%d additive" % bonus_amount
	if times_triggered > 0:
		base_desc += "\nTriggered: %d time(s)" % times_triggered
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("one_roll_wonder")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing OneRollWonderPowerUp ===")
	
	# Unregister from ScoreModifierManager
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
			print("[OneRollWonderPowerUp] Disconnected from about_to_score signal")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
			print("[OneRollWonderPowerUp] Disconnected from score_assigned signal")
	
	scorecard_ref = null
	turn_tracker_ref = null
	score_card_ui_ref = null

func _on_tree_exiting() -> void:
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
