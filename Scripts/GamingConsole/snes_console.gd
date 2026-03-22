extends GamingConsole
class_name SnesConsole

## SnesConsole — Blast Processing
##
## PASSIVE: Tracks how many categories have been scored this channel.
## Every 3rd category scored gets a 1.5× multiplier applied to that score.
## Visual feedback: console icon flash + VCR text.

var scorecard_ref: Scorecard = null
var categories_scored: int = 0
var blast_interval: int = 3
var blast_multiplier: float = 1.5
var modifier_source_name: String = "blast_processing"


func apply(target) -> void:
	super.apply(target)
	scorecard_ref = target as Scorecard
	if not scorecard_ref:
		push_error("[SnesConsole] Target is not a Scorecard")
		return

	if not scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.connect(_on_score_assigned)
	if not scorecard_ref.is_connected("score_auto_assigned", _on_score_auto_assigned):
		scorecard_ref.score_auto_assigned.connect(_on_score_auto_assigned)

	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	print("[SnesConsole] Applied — Blast Processing tracking categories")


func remove(_target_node) -> void:
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		if scorecard_ref.is_connected("score_auto_assigned", _on_score_auto_assigned):
			scorecard_ref.score_auto_assigned.disconnect(_on_score_auto_assigned)
	if ScoreModifierManager.has_multiplier(modifier_source_name):
		ScoreModifierManager.unregister_multiplier(modifier_source_name)
	scorecard_ref = null
	super.remove(_target_node)


func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	_track_category_scored()


func _on_score_auto_assigned(_section: Scorecard.Section, _category: String, _score: int, _breakdown_info: Dictionary = {}) -> void:
	_track_category_scored()


func _track_category_scored() -> void:
	categories_scored += 1
	print("[SnesConsole] Categories scored: %d" % categories_scored)

	if categories_scored % blast_interval == 0:
		# Register multiplier for the NEXT score
		ScoreModifierManager.register_multiplier(modifier_source_name, blast_multiplier)
		print("[SnesConsole] BLAST PROCESSING! 1.5x multiplier active for next score")
		emit_signal("activated")
	else:
		# Remove multiplier if it was active
		if ScoreModifierManager.has_multiplier(modifier_source_name):
			ScoreModifierManager.unregister_multiplier(modifier_source_name)

	emit_signal("description_updated", get_power_description())


func reset_for_new_round() -> void:
	# Don't reset categories_scored — tracks across the whole channel
	uses_remaining = uses_per_round
	emit_signal("uses_changed", uses_remaining)


func is_passive() -> bool:
	return true


func can_activate() -> bool:
	return false


func activate() -> void:
	pass


func get_power_description() -> String:
	var next_blast = blast_interval - (categories_scored % blast_interval)
	var has_mult = ScoreModifierManager.has_multiplier(modifier_source_name)
	if has_mult:
		return "Blast Processing: 1.5x ACTIVE! Every %d categories scored. [%d scored, next in %d]" % [blast_interval, categories_scored, blast_interval]
	return "Blast Processing: Every %d categories scored gets 1.5x. [%d scored, next in %d]" % [blast_interval, categories_scored, next_blast]


func _on_tree_exiting() -> void:
	if ScoreModifierManager and ScoreModifierManager.has_multiplier(modifier_source_name):
		ScoreModifierManager.unregister_multiplier(modifier_source_name)
	scorecard_ref = null
