extends PowerUp
class_name MeltingDicePowerUp

## MeltingDicePowerUp
##
## Starts with +80 additive bonus. Each time the player scores, the bonus
## decreases by 8 (minimum 0). Encourages strategic scoring early on.
## Common rarity, $50 price.

# References
var scorecard_ref: Scorecard = null

# ScoreModifierManager source name
var modifier_source_name: String = "melting_dice"

# Track the current additive value (starts at 80, decreases by 8 per score)
var current_additive: int = 80
var decay_amount: int = 8

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying MeltingDicePowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[MeltingDicePowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Connect to score_assigned to decay the additive
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[MeltingDicePowerUp] Connected to score_assigned signal")
	
	if not scorecard.is_connected("score_auto_assigned", _on_score_assigned):
		scorecard.score_auto_assigned.connect(_on_score_assigned)
		print("[MeltingDicePowerUp] Connected to score_auto_assigned signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	# Register the initial additive
	ScoreModifierManager.register_additive(modifier_source_name, current_additive)
	print("[MeltingDicePowerUp] Registered initial additive +%d" % current_additive)

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int, _breakdown_info: Dictionary = {}) -> void:
	# Decay the additive
	current_additive = max(current_additive - decay_amount, 0)
	
	# Update the ScoreModifierManager
	if current_additive > 0:
		ScoreModifierManager.register_additive(modifier_source_name, current_additive)
	else:
		if ScoreModifierManager.has_additive(modifier_source_name):
			ScoreModifierManager.unregister_additive(modifier_source_name)
	
	print("[MeltingDicePowerUp] Additive decayed to +%d" % current_additive)
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var base_desc = "Starts +80 additive, melts by 8 each score"
	base_desc += "\nCurrent bonus: +%d" % current_additive
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("melting_dice")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing MeltingDicePowerUp ===")
	
	# Unregister from ScoreModifierManager
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
		if scorecard.is_connected("score_auto_assigned", _on_score_assigned):
			scorecard.score_auto_assigned.disconnect(_on_score_assigned)
	
	scorecard_ref = null

func _on_tree_exiting() -> void:
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		if scorecard_ref.is_connected("score_auto_assigned", _on_score_assigned):
			scorecard_ref.score_auto_assigned.disconnect(_on_score_assigned)
