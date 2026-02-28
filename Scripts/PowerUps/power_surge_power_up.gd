extends PowerUp
class_name PowerSurgePowerUp

## PowerSurgePowerUp
##
## Grants +0.15x multiplier per owned PowerUp at the time of scoring.
## Checks active_power_ups count each time about_to_score fires.
## Epic rarity, $400 price.

# References
var scorecard_ref: Scorecard = null
var score_card_ui_ref = null

# ScoreModifierManager source name
var modifier_source_name: String = "power_surge"

# Track for description
var last_power_up_count: int = 0
var mult_per_power_up: float = 0.15

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying PowerSurgePowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[PowerSurgePowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Get score_card_ui from tree
	var tree = scorecard.get_tree()
	if tree:
		var game_controller = tree.get_first_node_in_group("game_controller")
		if game_controller and game_controller.score_card_ui:
			score_card_ui_ref = game_controller.score_card_ui
	
	# Connect to about_to_score to register multiplier
	if score_card_ui_ref:
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
			print("[PowerSurgePowerUp] Connected to about_to_score signal")
	
	# Connect to score_assigned to clean up multiplier
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[PowerSurgePowerUp] Connected to score_assigned signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	# Count active power-ups from the GameController
	var game_controller = null
	if is_inside_tree() and get_tree():
		game_controller = get_tree().get_first_node_in_group("game_controller")
	
	if not game_controller:
		return
	
	var power_up_count = game_controller.active_power_ups.size()
	last_power_up_count = power_up_count
	
	# Calculate multiplier: 1.0 + (count * 0.15)
	var total_mult = 1.0 + (power_up_count * mult_per_power_up)
	
	ScoreModifierManager.register_multiplier(modifier_source_name, total_mult)
	print("[PowerSurgePowerUp] %d PowerUps owned — registered %.2fx multiplier" % [power_up_count, total_mult])

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Clean up multiplier after scoring
	if ScoreModifierManager.has_multiplier(modifier_source_name):
		ScoreModifierManager.unregister_multiplier(modifier_source_name)
		print("[PowerSurgePowerUp] Cleaned up multiplier after scoring")
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var total_mult = 1.0 + (last_power_up_count * mult_per_power_up)
	var base_desc = "+0.15x multiplier per owned PowerUp"
	base_desc += "\nPowerUps: %d (%.2fx)" % [last_power_up_count, total_mult]
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("power_surge")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing PowerSurgePowerUp ===")
	
	# Unregister from ScoreModifierManager
	if ScoreModifierManager.has_multiplier(modifier_source_name):
		ScoreModifierManager.unregister_multiplier(modifier_source_name)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
			print("[PowerSurgePowerUp] Disconnected from about_to_score signal")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
			print("[PowerSurgePowerUp] Disconnected from score_assigned signal")
	
	scorecard_ref = null
	score_card_ui_ref = null

func _on_tree_exiting() -> void:
	if ScoreModifierManager.has_multiplier(modifier_source_name):
		ScoreModifierManager.unregister_multiplier(modifier_source_name)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
