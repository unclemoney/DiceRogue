extends Node
#class_name ScoreModifierManager

# Singleton pattern for managing all score modifiers in the game
# This centralizes both additive bonuses and multipliers from PowerUps, Debuffs, etc.

signal multiplier_changed(total_multiplier: float)
signal multiplier_registered(source_name: String, multiplier: float)
signal multiplier_unregistered(source_name: String)
signal additive_changed(total_additive: int)
signal additive_registered(source_name: String, additive: int)
signal additive_unregistered(source_name: String)

# Dictionary to track all active multipliers by their source name
var _active_multipliers: Dictionary = {}
# Dictionary to track all active additive bonuses by their source name
var _active_additives: Dictionary = {}

# Debug tracking
var _debug_enabled: bool = true

func _ready() -> void:
	add_to_group("score_modifier_manager")
	# Also add to old group for backward compatibility
	add_to_group("multiplier_manager")
	if _debug_enabled:
		print("[ScoreModifierManager] Singleton initialized")

# Register a new additive bonus from a source (PowerUp, Debuff, etc.)
func register_additive(source_name: String, additive: int) -> void:
	if _debug_enabled:
		print("[ScoreModifierManager] Registering additive from '", source_name, "': ", additive)
	
	var old_total = get_total_additive()
	var was_updating = _active_additives.has(source_name)
	var old_value = _active_additives.get(source_name, 0)
	
	_active_additives[source_name] = additive
	var new_total = get_total_additive()
	
	if _debug_enabled:
		if was_updating:
			print("[ScoreModifierManager] Updated existing additive '", source_name, "' from ", old_value, " to ", additive)
		else:
			print("[ScoreModifierManager] Added new additive '", source_name, "'")
		print("[ScoreModifierManager] Total additive changed from ", old_total, " to ", new_total)
		print("[ScoreModifierManager] Active additives: ", _active_additives)
	
	emit_signal("additive_registered", source_name, additive)
	emit_signal("additive_changed", new_total)

# Unregister an additive bonus when its source is removed
func unregister_additive(source_name: String) -> void:
	if not _active_additives.has(source_name):
		if _debug_enabled:
			print("[ScoreModifierManager] Warning: Attempted to unregister non-existent additive: ", source_name)
		return
	
	var old_total = get_total_additive()
	var removed_additive = _active_additives[source_name]
	_active_additives.erase(source_name)
	var new_total = get_total_additive()
	
	if _debug_enabled:
		print("[ScoreModifierManager] Unregistered additive from '", source_name, "': ", removed_additive)
		print("[ScoreModifierManager] Total additive changed from ", old_total, " to ", new_total)
		print("[ScoreModifierManager] Active additives: ", _active_additives)
	
	emit_signal("additive_unregistered", source_name)
	emit_signal("additive_changed", new_total)

# Get the total additive bonus by summing all active additives
func get_total_additive() -> int:
	if _active_additives.is_empty():
		return 0
	
	var total: int = 0
	for additive in _active_additives.values():
		total += additive
	
	return total

# Check if a specific source has an active additive
func has_additive(source_name: String) -> bool:
	return _active_additives.has(source_name)

# Get a specific additive value by source name
func get_additive(source_name: String) -> int:
	return _active_additives.get(source_name, 0)

# Get all active additive sources
func get_active_additive_sources() -> Array[String]:
	var sources: Array[String] = []
	sources.assign(_active_additives.keys())
	return sources

# Get count of active additives
func get_additive_count() -> int:
	return _active_additives.size()

# Register a new multiplier from a source (PowerUp, Debuff, etc.)
func register_multiplier(source_name: String, multiplier: float) -> void:
	if _debug_enabled:
		print("[ScoreModifierManager] Registering multiplier from '", source_name, "': ", multiplier)
	
	# Allow negative multipliers but warn about zero
	if multiplier == 0:
		push_warning("[ScoreModifierManager] Zero multiplier detected from " + source_name + " - this will zero out scores")
	
	# Validation warning for extremely high multipliers
	if abs(multiplier) > 100:
		push_warning("[ScoreModifierManager] Very high multiplier detected: " + str(multiplier) + " from " + source_name)
	
	var old_total = get_total_multiplier()
	var was_updating = _active_multipliers.has(source_name)
	var old_value = _active_multipliers.get(source_name, 0.0)
	
	_active_multipliers[source_name] = multiplier
	var new_total = get_total_multiplier()
	
	if _debug_enabled:
		if was_updating:
			print("[ScoreModifierManager] Updated existing multiplier '", source_name, "' from ", old_value, " to ", multiplier)
		else:
			print("[ScoreModifierManager] Added new multiplier '", source_name, "'")
		print("[ScoreModifierManager] Total multiplier changed from ", old_total, " to ", new_total)
		print("[ScoreModifierManager] Active multipliers: ", _active_multipliers)
		
		# Validate consistency
		_validate_state()
	
	emit_signal("multiplier_registered", source_name, multiplier)
	emit_signal("multiplier_changed", new_total)

# Unregister a multiplier when its source is removed
func unregister_multiplier(source_name: String) -> void:
	if not _active_multipliers.has(source_name):
		if _debug_enabled:
			print("[ScoreModifierManager] Warning: Attempted to unregister non-existent multiplier: ", source_name)
		return
	
	var old_total = get_total_multiplier()
	var removed_multiplier = _active_multipliers[source_name]
	_active_multipliers.erase(source_name)
	var new_total = get_total_multiplier()
	
	if _debug_enabled:
		print("[ScoreModifierManager] Unregistered multiplier from '", source_name, "': ", removed_multiplier)
		print("[ScoreModifierManager] Total multiplier changed from ", old_total, " to ", new_total)
		print("[ScoreModifierManager] Active multipliers: ", _active_multipliers)
	
	emit_signal("multiplier_unregistered", source_name)
	emit_signal("multiplier_changed", new_total)

# Get the total multiplier by multiplying all active multipliers together
func get_total_multiplier() -> float:
	if _active_multipliers.is_empty():
		return 1.0
	
	var total: float = 1.0
	for multiplier in _active_multipliers.values():
		total *= multiplier
	
	return total

# Check if a specific source has an active multiplier
func has_multiplier(source_name: String) -> bool:
	return _active_multipliers.has(source_name)

# Get a specific multiplier value by source name
func get_multiplier(source_name: String) -> float:
	return _active_multipliers.get(source_name, 1.0)

# Get all active multiplier sources
func get_active_sources() -> Array[String]:
	var sources: Array[String] = []
	sources.assign(_active_multipliers.keys())
	return sources

# Get count of active multipliers
func get_multiplier_count() -> int:
	return _active_multipliers.size()

# Reset all modifiers (for new games/rounds)
func reset() -> void:
	if _debug_enabled:
		print("[ScoreModifierManager] RESET CALLED - STACK TRACE:")
		print(get_stack())
		print("[ScoreModifierManager] Resetting all modifiers")
		print("[ScoreModifierManager] Clearing ", _active_multipliers.size(), " active multipliers")
		print("[ScoreModifierManager] Clearing ", _active_additives.size(), " active additives")
	
	var old_mult_total = get_total_multiplier()
	var old_add_total = get_total_additive()
	_active_multipliers.clear()
	_active_additives.clear()
	
	if _debug_enabled:
		print("[ScoreModifierManager] All modifiers cleared, totals reset")
	
	emit_signal("multiplier_changed", 1.0)
	emit_signal("additive_changed", 0)


# Enable/disable debug logging
func set_debug_enabled(enabled: bool) -> void:
	_debug_enabled = enabled
	if enabled:
		print("[ScoreModifierManager] Debug logging enabled")
	else:
		print("[ScoreModifierManager] Debug logging disabled")

# Validation function to check internal state consistency
func _validate_state() -> bool:
	var calculated_total = 1.0
	for multiplier in _active_multipliers.values():
		# Remove the <= 0 check to allow negative multipliers
		calculated_total *= multiplier
	
	var stored_total = get_total_multiplier()
	if abs(calculated_total - stored_total) > 0.001:  # Allow for floating point precision
		push_error("[ScoreModifierManager] VALIDATION ERROR: Total multiplier mismatch. Calculated: " + str(calculated_total) + ", Stored: " + str(stored_total))
		return false
	
	return true

# Enhanced debug function with validation
func debug_print_state() -> void:
	print("\n=== ScoreModifierManager State ===")
	print("Active multipliers: ", _active_multipliers)
	print("Total multiplier: ", get_total_multiplier())
	print("Multiplier count: ", get_multiplier_count())
	print("Active additives: ", _active_additives)
	print("Total additive: ", get_total_additive())
	print("Additive count: ", get_additive_count())
	
	# Show breakdown of calculation
	if not _active_multipliers.is_empty():
		print("Multiplier breakdown:")
		var running_total = 1.0
		for source in _active_multipliers:
			var multiplier = _active_multipliers[source]
			running_total *= multiplier
			print("  ", source, ": ", multiplier, " (running total: ", running_total, ")")
	
	if not _active_additives.is_empty():
		print("Additive breakdown:")
		var running_total = 0
		for source in _active_additives:
			var additive = _active_additives[source]
			running_total += additive
			print("  ", source, ": ", additive, " (running total: ", running_total, ")")
	
	# Validate state
	var is_valid = _validate_state()
	print("State validation: ", "PASSED" if is_valid else "FAILED")
	print("==============================\n")

# Check for potential issues and report them
func validate_and_report() -> Array[String]:
	var issues: Array[String] = []
	
	# Check for duplicate sources (shouldn't happen but let's be safe)
	var source_count = _active_multipliers.size()
	var unique_sources = []
	for source in _active_multipliers.keys():
		if source not in unique_sources:
			unique_sources.append(source)
	
	if unique_sources.size() != source_count:
		issues.append("Duplicate multiplier sources detected")
	
	# Check for extreme multipliers
	for source in _active_multipliers:
		var multiplier = _active_multipliers[source]
		if multiplier <= 0:
			issues.append("Invalid multiplier from " + source + ": " + str(multiplier))
		elif multiplier > 100:
			issues.append("Extremely high multiplier from " + source + ": " + str(multiplier))
		elif multiplier < 0.01:
			issues.append("Extremely low multiplier from " + source + ": " + str(multiplier))
	
	# Check total multiplier sanity
	var total = get_total_multiplier()
	if total > 1000:
		issues.append("Total multiplier is very high: " + str(total))
	elif total < 0.001:
		issues.append("Total multiplier is very low: " + str(total))
	
	# Check additive values
	for source in _active_additives:
		var additive = _active_additives[source]
		if additive > 1000:
			issues.append("Extremely high additive from " + source + ": " + str(additive))
		elif additive < -1000:
			issues.append("Extremely low additive from " + source + ": " + str(additive))
	
	return issues
