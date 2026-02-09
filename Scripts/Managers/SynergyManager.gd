# SynergyManager.gd
extends Node
class_name SynergyManager

## SynergyManager
##
## Tracks active PowerUp ratings and calculates synergy bonuses.
## Awards scoring bonuses when:
## - 5+ PowerUps share the same rating: +50 additive per set of 5
## - One of each rating (G, PG, PG-13, R, NC-17): 5x multiplier (Rainbow Bonus)
##
## Registers bonuses with ScoreModifierManager and emits signals for UI updates.

signal synergy_activated(synergy_type: String, bonus_value: float)
signal synergy_deactivated(synergy_type: String)
signal synergies_updated

## Rating constants for clarity
const RATING_G := "G"
const RATING_PG := "PG"
const RATING_PG13 := "PG-13"
const RATING_R := "R"
const RATING_NC17 := "NC-17"

## All valid ratings for iteration
const ALL_RATINGS := [RATING_G, RATING_PG, RATING_PG13, RATING_R, RATING_NC17]

## Synergy bonus values
const MATCHING_SET_BONUS := 50  # +50 additive per 5 matching ratings
const MATCHING_SET_SIZE := 5   # Number of same-rated PowerUps needed for bonus
const RAINBOW_MULTIPLIER := 5.0  # 5x multiplier for having all 5 ratings

## Internal state: counts of PowerUps by rating
var _rating_counts: Dictionary = {}  # rating -> count

## Track registered synergy bonuses by source name
var _active_synergies: Dictionary = {}  # synergy_id -> bonus_value

## Reference to PowerUpManager for rating lookups
var _power_up_manager: PowerUpManager = null

## Debug logging
var _debug_enabled: bool = true


func _ready() -> void:
	add_to_group("synergy_manager")
	_initialize_rating_counts()
	if _debug_enabled:
		print("[SynergyManager] Initialized")


func _initialize_rating_counts() -> void:
	## Reset all rating counts to zero
	for rating in ALL_RATINGS:
		_rating_counts[rating] = 0


## connect_to_game_controller(gc)
##
## Connects to GameController signals to track PowerUp grants and revocations.
## Should be called from GameController._ready() after manager is instantiated.
func connect_to_game_controller(gc: GameController) -> void:
	if gc.power_up_granted.is_connected(_on_power_up_granted):
		return  # Already connected
	
	gc.power_up_granted.connect(_on_power_up_granted)
	gc.power_up_revoked.connect(_on_power_up_revoked)
	
	# Get PowerUpManager reference from GameController
	_power_up_manager = gc.pu_manager
	
	if _debug_enabled:
		print("[SynergyManager] Connected to GameController signals")


## _on_power_up_granted(id, power_up)
##
## Called when a PowerUp is granted. Updates rating counts and recalculates synergies.
func _on_power_up_granted(id: String, _power_up: PowerUp) -> void:
	var rating := _get_power_up_rating(id)
	if rating.is_empty():
		if _debug_enabled:
			print("[SynergyManager] Warning: Could not find rating for PowerUp '%s'" % id)
		return
	
	# Increment rating count
	if _rating_counts.has(rating):
		_rating_counts[rating] += 1
	else:
		_rating_counts[rating] = 1
	
	if _debug_enabled:
		print("[SynergyManager] PowerUp granted: %s (rating: %s)" % [id, rating])
		print("[SynergyManager] Rating counts: ", _rating_counts)
	
	_recalculate_synergies()


## _on_power_up_revoked(id)
##
## Called when a PowerUp is revoked. Updates rating counts and recalculates synergies.
func _on_power_up_revoked(id: String) -> void:
	var rating := _get_power_up_rating(id)
	if rating.is_empty():
		if _debug_enabled:
			print("[SynergyManager] Warning: Could not find rating for revoked PowerUp '%s'" % id)
		return
	
	# Decrement rating count
	if _rating_counts.has(rating):
		_rating_counts[rating] = max(0, _rating_counts[rating] - 1)
	
	if _debug_enabled:
		print("[SynergyManager] PowerUp revoked: %s (rating: %s)" % [id, rating])
		print("[SynergyManager] Rating counts: ", _rating_counts)
	
	_recalculate_synergies()


## _get_power_up_rating(id) -> String
##
## Looks up the rating for a PowerUp by its ID using PowerUpManager.
func _get_power_up_rating(id: String) -> String:
	if _power_up_manager == null:
		# Try to find PowerUpManager in tree
		_power_up_manager = get_tree().get_first_node_in_group("power_up_manager") as PowerUpManager
	
	if _power_up_manager == null:
		push_error("[SynergyManager] PowerUpManager not found")
		return ""
	
	var data: PowerUpData = _power_up_manager.get_def(id)
	if data == null:
		push_error("[SynergyManager] PowerUpData not found for id: %s" % id)
		return ""
	
	return data.rating


## _recalculate_synergies()
##
## Recalculates all synergy bonuses based on current rating counts.
## Updates ScoreModifierManager with new bonus values.
func _recalculate_synergies() -> void:
	var manager = _get_score_modifier_manager()
	if manager == null:
		push_error("[SynergyManager] ScoreModifierManager not found")
		return
	
	# Calculate matching set bonuses for each rating
	for rating in ALL_RATINGS:
		_update_matching_set_bonus(rating, manager)
	
	# Calculate rainbow bonus
	_update_rainbow_bonus(manager)
	
	emit_signal("synergies_updated")


## _update_matching_set_bonus(rating, manager)
##
## Calculates and registers additive bonuses for matching sets of a given rating.
## Each set of 5 same-rated PowerUps grants +50 additive.
func _update_matching_set_bonus(rating: String, manager) -> void:
	var count: int = _rating_counts.get(rating, 0)
	@warning_ignore("integer_division")
	var sets: int = count / MATCHING_SET_SIZE
	var total_bonus: int = sets * MATCHING_SET_BONUS
	
	var source_name := "synergy_%s_sets" % rating.replace("-", "_")  # e.g., "synergy_PG_13_sets"
	var previous_bonus: int = _active_synergies.get(source_name, 0)
	
	if total_bonus > 0:
		# Register or update the additive bonus
		manager.register_additive(source_name, total_bonus)
		_active_synergies[source_name] = total_bonus
		
		if previous_bonus != total_bonus:
			if _debug_enabled:
				print("[SynergyManager] %s set bonus: +%d additive (%d sets of %d)" % [rating, total_bonus, sets, MATCHING_SET_SIZE])
			emit_signal("synergy_activated", source_name, total_bonus)
	else:
		# Remove bonus if it was previously active
		if _active_synergies.has(source_name):
			manager.unregister_additive(source_name)
			_active_synergies.erase(source_name)
			if _debug_enabled:
				print("[SynergyManager] %s set bonus removed" % rating)
			emit_signal("synergy_deactivated", source_name)


## _update_rainbow_bonus(manager)
##
## Calculates and registers the rainbow multiplier bonus.
## Having at least one PowerUp of each rating (G, PG, PG-13, R, NC-17) grants 5x multiplier.
func _update_rainbow_bonus(manager) -> void:
	var has_rainbow := true
	
	# Check if we have at least one of each rating
	for rating in ALL_RATINGS:
		if _rating_counts.get(rating, 0) < 1:
			has_rainbow = false
			break
	
	var source_name := "synergy_rainbow"
	var was_active: bool = _active_synergies.has(source_name)
	
	if has_rainbow:
		# Register the multiplier bonus
		manager.register_multiplier(source_name, RAINBOW_MULTIPLIER)
		_active_synergies[source_name] = RAINBOW_MULTIPLIER
		
		if not was_active:
			if _debug_enabled:
				print("[SynergyManager] Rainbow bonus activated: %.1fx multiplier" % RAINBOW_MULTIPLIER)
			emit_signal("synergy_activated", source_name, RAINBOW_MULTIPLIER)
	else:
		# Remove bonus if it was previously active
		if was_active:
			manager.unregister_multiplier(source_name)
			_active_synergies.erase(source_name)
			if _debug_enabled:
				print("[SynergyManager] Rainbow bonus deactivated")
			emit_signal("synergy_deactivated", source_name)


## _get_score_modifier_manager()
##
## Helper to find the ScoreModifierManager singleton or node.
func _get_score_modifier_manager():
	# ScoreModifierManager is a registered autoload — use direct reference
	return ScoreModifierManager


## get_rating_counts() -> Dictionary
##
## Returns a copy of the current rating counts for UI display.
func get_rating_counts() -> Dictionary:
	return _rating_counts.duplicate()


## get_active_synergies() -> Dictionary
##
## Returns a copy of currently active synergy bonuses.
func get_active_synergies() -> Dictionary:
	return _active_synergies.duplicate()


## get_total_matching_bonus() -> int
##
## Returns the total additive bonus from all matching set synergies.
func get_total_matching_bonus() -> int:
	var total: int = 0
	for rating in ALL_RATINGS:
		var source_name := "synergy_%s_sets" % rating.replace("-", "_")
		total += _active_synergies.get(source_name, 0)
	return total


## has_rainbow_bonus() -> bool
##
## Returns true if the rainbow multiplier is currently active.
func has_rainbow_bonus() -> bool:
	return _active_synergies.has("synergy_rainbow")


## get_short_rating(rating) -> String
##
## Returns shortened display version of rating.
## PG-13 -> "13", NC-17 -> "17", others unchanged.
static func get_short_rating(rating: String) -> String:
	match rating:
		"PG-13":
			return "13"
		"NC-17":
			return "17"
		_:
			return rating


## reset()
##
## Clears all synergy tracking. Called when game resets.
func reset() -> void:
	var manager = _get_score_modifier_manager()
	
	# Unregister all active synergies
	if manager:
		for source_name in _active_synergies.keys():
			if source_name.begins_with("synergy_rainbow"):
				manager.unregister_multiplier(source_name)
			else:
				manager.unregister_additive(source_name)
	
	_active_synergies.clear()
	_initialize_rating_counts()
	
	if _debug_enabled:
		print("[SynergyManager] Reset complete")
	
	emit_signal("synergies_updated")


## debug_print_status()
##
## Prints current synergy status for debugging.
func debug_print_status() -> void:
	print("=== SynergyManager Status ===")
	print("Rating Counts:")
	for rating in ALL_RATINGS:
		var count: int = _rating_counts.get(rating, 0)
		@warning_ignore("integer_division")
		var sets: int = count / MATCHING_SET_SIZE
		print("  %s: %d (sets: %d)" % [rating, count, sets])
	print("Active Synergies:")
	for synergy_id in _active_synergies:
		print("  %s: %s" % [synergy_id, _active_synergies[synergy_id]])
	print("Total Matching Bonus: +%d" % get_total_matching_bonus())
	print("Rainbow Active: %s" % has_rainbow_bonus())
	print("=============================")
