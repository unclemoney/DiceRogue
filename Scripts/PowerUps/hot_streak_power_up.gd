extends PowerUp
class_name HotStreakPowerUp

## HotStreakPowerUp
##
## Gains +3 additive per consecutive turn scoring 15+. Resets to 0 on any
## turn scoring less than 15. Rewards consistent high scoring.
## Uncommon rarity, $125 price.

# References
var scorecard_ref: Scorecard = null

# ScoreModifierManager source name
var modifier_source_name: String = "hot_streak"

# Track streak
var streak_count: int = 0
var bonus_per_streak: int = 3
var score_threshold: int = 15

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying HotStreakPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[HotStreakPowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Connect to score_assigned to track streak
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[HotStreakPowerUp] Connected to score_assigned signal")
	
	if not scorecard.is_connected("score_auto_assigned", _on_score_assigned):
		scorecard.score_auto_assigned.connect(_on_score_assigned)
		print("[HotStreakPowerUp] Connected to score_auto_assigned signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	# Register initial additive (0 until first qualifying score)
	print("[HotStreakPowerUp] Applied — streak starts at 0")

func _on_score_assigned(_section: Scorecard.Section, _category: String, score: int, _breakdown_info: Dictionary = {}) -> void:
	if score >= score_threshold:
		streak_count += 1
		print("[HotStreakPowerUp] Score %d >= %d — streak now %d" % [score, score_threshold, streak_count])
	else:
		streak_count = 0
		print("[HotStreakPowerUp] Score %d < %d — streak reset" % [score, score_threshold])
	
	# Update the ScoreModifierManager
	var total_bonus = streak_count * bonus_per_streak
	if total_bonus > 0:
		ScoreModifierManager.register_additive(modifier_source_name, total_bonus)
	else:
		if ScoreModifierManager.has_additive(modifier_source_name):
			ScoreModifierManager.unregister_additive(modifier_source_name)
	
	print("[HotStreakPowerUp] Additive bonus: +%d" % total_bonus)
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var total_bonus = streak_count * bonus_per_streak
	var base_desc = "+3 per consecutive turn scoring 15+"
	base_desc += "\nStreak: %d (+%d bonus)" % [streak_count, total_bonus]
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("hot_streak")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing HotStreakPowerUp ===")
	
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
