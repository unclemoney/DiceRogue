extends Node
#class_name ScoreModifierManager

## ScoreModifierManager
##
## Singleton node responsible for tracking all score modifiers (additives and multipliers)
## applied by PowerUps, Debuffs, Mods, and other systems. Emits signals when totals
## change so UI and gameplay systems can react.

signal multiplier_changed(total_multiplier: float)
signal multiplier_registered(source_name: String, multiplier: float)
signal multiplier_unregistered(source_name: String)
signal additive_changed(total_additive: int)
signal additive_registered(source_name: String, additive: int)
signal additive_unregistered(source_name: String)

## Internal state: maps of source_name -> value for active modifiers
var _active_multipliers: Dictionary = {}
var _active_additives: Dictionary = {}

## Enable verbose debug logging for development
var _debug_enabled: bool = true

## Division mode flag - when true, multipliers become dividers
var _division_mode: bool = false

## _ready()
##
## Lifecycle: add this node to helpful groups and print initialization when debugging.
func _ready() -> void:
	add_to_group("score_modifier_manager")
	# Also add to old group for backward compatibility
	add_to_group("multiplier_manager")
	if _debug_enabled:
		print("[ScoreModifierManager] Singleton initialized")

## register_additive(source_name, additive)
##
## Adds or updates a named additive bonus. Emits `additive_registered` and `additive_changed`.
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

## unregister_additive(source_name)
##
## Removes an additive provided by `source_name` and emits `additive_unregistered` and `additive_changed`.
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

## get_total_additive()
##
## Returns the sum of all active additive bonuses (int). Returns 0 when none are active.
func get_total_additive() -> int:
	if _active_additives.is_empty():
		return 0

	var total: int = 0
	for additive in _active_additives.values():
		total += additive

	return total

## has_additive(source_name)
##
## Returns true if `source_name` currently provides an additive bonus.
func has_additive(source_name: String) -> bool:
	return _active_additives.has(source_name)

## get_additive(source_name)
##
## Returns the additive provided by `source_name` or 0 if not present.
func get_additive(source_name: String) -> int:
	return _active_additives.get(source_name, 0)

## get_active_additive_sources()
##
## Returns an array of source names currently providing additive bonuses.
func get_active_additive_sources() -> Array[String]:
	var sources: Array[String] = []
	sources.assign(_active_additives.keys())
	return sources

## get_additive_count()
##
## Returns the number of active additive sources.
func get_additive_count() -> int:
	return _active_additives.size()

## register_multiplier(source_name, multiplier)
##
## Adds or updates a named multiplier. Emits `multiplier_registered` and `multiplier_changed`.
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

## unregister_multiplier(source_name)
##
## Removes a multiplier provided by `source_name` and emits `multiplier_unregistered` and `multiplier_changed`.
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

## get_total_multiplier()
##
## Returns the product of all active multipliers. Returns 1.0 when none are active.
## When division mode is active, converts multipliers to dividers (reciprocals).
func get_total_multiplier() -> float:
	if _active_multipliers.is_empty():
		return 1.0

	var total: float = 1.0
	for multiplier in _active_multipliers.values():
		if _division_mode and multiplier > 0:
			# Convert multiplier to divider (reciprocal)
			total *= (1.0 / multiplier)
		else:
			# Normal multiplication
			total *= multiplier

	return total

## has_multiplier(source_name)
##
## Returns true if `source_name` currently provides a multiplier.
func has_multiplier(source_name: String) -> bool:
	return _active_multipliers.has(source_name)

## get_multiplier(source_name)
##
## Returns the multiplier provided by `source_name` or 1.0 if not present.
func get_multiplier(source_name: String) -> float:
	return _active_multipliers.get(source_name, 1.0)

## get_active_sources()
##
## Returns an array of source names currently providing multipliers.
func get_active_sources() -> Array[String]:
	var sources: Array[String] = []
	sources.assign(_active_multipliers.keys())
	return sources

## get_multiplier_count()
##
## Returns the number of active multiplier sources.
func get_multiplier_count() -> int:
	return _active_multipliers.size()

## reset()
##
## Clears all active modifiers (used when starting new games/rounds) and emits changed signals.
func reset() -> void:
	if _debug_enabled:
		print("[ScoreModifierManager] RESET CALLED - STACK TRACE:")
		print(get_stack())
		print("[ScoreModifierManager] Resetting all modifiers")
		print("[ScoreModifierManager] Clearing ", _active_multipliers.size(), " active multipliers")
		print("[ScoreModifierManager] Clearing ", _active_additives.size(), " active additives")

	var _old_mult_total = get_total_multiplier()
	var _old_add_total = get_total_additive()
	_active_multipliers.clear()
	_active_additives.clear()

	if _debug_enabled:
		print("[ScoreModifierManager] All modifiers cleared, totals reset")

	emit_signal("multiplier_changed", 1.0)
	emit_signal("additive_changed", 0)


## set_debug_enabled(enabled)
##
## Toggles verbose debug logging for this manager.
func set_debug_enabled(enabled: bool) -> void:
	_debug_enabled = enabled
	if enabled:
		print("[ScoreModifierManager] Debug logging enabled")
	else:
		print("[ScoreModifierManager] Debug logging disabled")

## set_division_mode(enabled)
##
## Enables or disables division mode. When enabled, all multipliers become dividers.
## Used by TheDivisionDebuff to convert multiplier power-ups into penalties.
func set_division_mode(enabled: bool) -> void:
	var old_mode = _division_mode
	_division_mode = enabled
	
	if _debug_enabled:
		if enabled:
			print("[ScoreModifierManager] Division mode ENABLED - multipliers now divide scores")
		else:
			print("[ScoreModifierManager] Division mode DISABLED - multipliers work normally")
	
	# Emit signal if the mode actually changed
	if old_mode != enabled:
		var new_total = get_total_multiplier()
		emit_signal("multiplier_changed", new_total)

## is_division_mode() -> bool
##
## Returns true if division mode is currently active.
func is_division_mode() -> bool:
	return _division_mode

## _validate_state()
##
## Internal helper to validate that the product of tracked multipliers matches
## the computed total multiplier. Returns true when consistent.
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

## debug_print_state()
##
## Developer helper: prints debug state and runs an internal validation check.
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

## validate_and_report()
##
## Scans internal state and returns an array of human-readable issue strings for any
## suspicious values or inconsistent data. Useful for automated checks or developer debugging.
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
