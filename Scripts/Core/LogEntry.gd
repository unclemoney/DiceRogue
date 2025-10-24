extends Resource
class_name LogEntry

## LogEntry
##
## Represents a single entry in the game's logbook system.
## Tracks detailed information about each hand scored including dice values,
## modifiers, calculation steps, and the final score.

@export var timestamp: float
@export var turn_number: int
@export var dice_values: Array[int]
@export var dice_colors: Array[String]
@export var dice_mods: Array[String]
@export var scorecard_category: String
@export var scorecard_section: String
@export var consumables_applied: Array[String]
@export var powerups_applied: Array[String]
@export var base_score: int
@export var modifier_effects: Array[Dictionary]
@export var final_score: int
@export var calculation_summary: String
@export var formatted_log_line: String
@export var breakdown_info: Dictionary = {}

## _init()
##
## Initialize a new log entry with all the required data.
func _init(
	p_dice_values: Array[int] = [],
	p_dice_colors: Array[String] = [],
	p_dice_mods: Array[String] = [],
	p_category: String = "",
	p_section: String = "",
	p_consumables: Array[String] = [],
	p_powerups: Array[String] = [],
	p_base_score: int = 0,
	p_effects: Array[Dictionary] = [],
	p_final_score: int = 0,
	p_turn: int = 0,
	p_breakdown_info: Dictionary = {}
):
	timestamp = Time.get_unix_time_from_system()
	turn_number = p_turn
	dice_values = p_dice_values.duplicate()
	dice_colors = p_dice_colors.duplicate()
	dice_mods = p_dice_mods.duplicate()
	scorecard_category = p_category
	scorecard_section = p_section
	consumables_applied = p_consumables.duplicate()
	powerups_applied = p_powerups.duplicate()
	base_score = p_base_score
	modifier_effects = p_effects.duplicate()
	final_score = p_final_score
	breakdown_info = p_breakdown_info.duplicate()
	calculation_summary = _generate_calculation_summary()
	formatted_log_line = _generate_formatted_log_line()

## _generate_calculation_summary()
##
## Creates a detailed breakdown of the calculation steps.
func _generate_calculation_summary() -> String:
	# If we have detailed breakdown info, use it for rich formatting
	if breakdown_info.has("base_score") and breakdown_info.has("has_modifiers"):
		return _generate_detailed_calculation_summary()
	
	# Fallback to basic summary for legacy entries
	var summary = "Base Score: %d" % base_score
	
	if modifier_effects.size() > 0:
		summary += " → "
		for i in range(modifier_effects.size()):
			var effect = modifier_effects[i]
			summary += effect.get("description", "Unknown Effect")
			if i < modifier_effects.size() - 1:
				summary += " → "
	
	summary += " = %d pts" % final_score
	return summary

## _generate_detailed_calculation_summary()
##
## Creates a rich breakdown using detailed scoring information.
func _generate_detailed_calculation_summary() -> String:
	if not breakdown_info.has("base_score"):
		return _format_category_name(scorecard_category) + ": " + str(final_score) + " pts"
	
	var category_display = breakdown_info.get("category_display", _format_category_name(scorecard_category))
	var base = breakdown_info.get("base_score", base_score)
	var final = breakdown_info.get("final_score", final_score)
	
	# If no modifiers were applied, show simple format
	if not breakdown_info.get("has_modifiers", false):
		return "%s: %d pts" % [category_display, final]
	
	# Build detailed breakdown with modifiers
	var calculation_parts = []
	var current_value = base
	
	# Start with base score
	calculation_parts.append(str(base))
	
	# Add additives section if any
	var total_additive = breakdown_info.get("total_additive", 0)
	if total_additive > 0:
		var additive_details = []
		
		# Use specific additive sources if available
		if breakdown_info.has("additive_sources") and breakdown_info.additive_sources.size() > 0:
			for source_info in breakdown_info.additive_sources:
				var source_name = _format_modifier_name(source_info.name)
				additive_details.append("%d %s" % [source_info.value, source_name])
		else:
			# Fallback to old logic if specific sources not available
			var regular_additive = breakdown_info.get("regular_additive", 0)
			if regular_additive > 0:
				var powerups = breakdown_info.get("active_powerups", [])
				var consumables = breakdown_info.get("active_consumables", [])
				
				if powerups.size() > 0:
					var powerup_names = []
					for powerup in powerups:
						powerup_names.append(_format_modifier_name(powerup))
					additive_details.append("%d %s" % [regular_additive, ", ".join(powerup_names)])
				elif consumables.size() > 0:
					var consumable_names = []
					for consumable in consumables:
						consumable_names.append(_format_modifier_name(consumable))
					additive_details.append("%d %s" % [regular_additive, ", ".join(consumable_names)])
				else:
					additive_details.append("%d bonus" % regular_additive)
		
		# Red dice additives
		var red_additive = breakdown_info.get("dice_color_additive", 0)
		if red_additive > 0:
			additive_details.append("%d red dice" % red_additive)
		
		if additive_details.size() > 0:
			calculation_parts.append("+" + "+".join(additive_details))
		
		current_value = breakdown_info.get("score_after_additives", current_value)
	
	# Add multipliers section if any
	var total_multiplier = breakdown_info.get("total_multiplier", 1.0)
	if total_multiplier != 1.0:
		var multiplier_details = []
		
		# Use specific multiplier sources if available
		if breakdown_info.has("multiplier_sources") and breakdown_info.multiplier_sources.size() > 0:
			for source_info in breakdown_info.multiplier_sources:
				var source_name = _format_modifier_name(source_info.name)
				multiplier_details.append("×%.1f %s" % [source_info.value, source_name])
		else:
			# Fallback to old logic if specific sources not available
			var regular_multiplier = breakdown_info.get("regular_multiplier", 1.0)
			if regular_multiplier != 1.0:
				var powerups = breakdown_info.get("active_powerups", [])
				var consumables = breakdown_info.get("active_consumables", [])
				
				if powerups.size() > 0:
					var powerup_names = []
					for powerup in powerups:
						powerup_names.append(_format_modifier_name(powerup))
					multiplier_details.append("×%.1f %s" % [regular_multiplier, ", ".join(powerup_names)])
				elif consumables.size() > 0:
					var consumable_names = []
					for consumable in consumables:
						consumable_names.append(_format_modifier_name(consumable))
					multiplier_details.append("×%.1f %s" % [regular_multiplier, ", ".join(consumable_names)])
				else:
					multiplier_details.append("×%.1f" % regular_multiplier)
		
		# Purple dice multipliers
		var purple_multiplier = breakdown_info.get("dice_color_multiplier", 1.0)
		if purple_multiplier != 1.0:
			multiplier_details.append("×%.1f purple dice" % purple_multiplier)
		
		if multiplier_details.size() > 0:
			# If we have both additives and multipliers, wrap the additive part in parentheses
			if total_additive > 0:
				var base_and_additive = "(" + " ".join(calculation_parts) + ")"
				calculation_parts = [base_and_additive]
			
			calculation_parts.append_array(multiplier_details)
	
	# Format the final calculation
	var calculation_str = " ".join(calculation_parts)
	return "%s: %s = %d pts" % [category_display, calculation_str, final]

## _format_modifier_name()
##
## Format modifier source names for display (remove prefixes, make readable).
func _format_modifier_name(source_name: String) -> String:
	var formatted = source_name
	
	# Remove common prefixes
	formatted = formatted.replace("powerup_", "").replace("consumable_", "").replace("mod_", "")
	
	# Handle specific known modifiers
	match formatted.to_lower():
		"pinhead", "pin_head": return "PinHead"
		"hot_streak": return "Hot Streak"
		"lucky_seven": return "Lucky Seven"
		"double_down": return "Double Down"
		"score_reroll": return "Score Reroll"
		"any_score": return "Any Score"
		"duplicate": return "Duplicate"
		"poor_house_bonus": return "Poor House"
		"the_consumer_is_always_right": return "The Consumer is Always Right"
		_: return formatted.capitalize().replace("_", " ")

## _generate_formatted_log_line()
##
## Creates a concise, readable one-line summary for UI display.
func _generate_formatted_log_line() -> String:
	var dice_str = str(dice_values)
	var colors_str = ""
	
	# Add color information if available
	if dice_colors.size() > 0:
		var color_abbrev = []
		for color in dice_colors:
			match color.to_lower():
				"red": color_abbrev.append("R")
				"blue": color_abbrev.append("B")
				"green": color_abbrev.append("G")
				"yellow": color_abbrev.append("Y")
				"purple": color_abbrev.append("P")
				"white": color_abbrev.append("W")
				_: color_abbrev.append("?")
		colors_str = " (" + ",".join(color_abbrev) + ")"
	
	var category_display = _format_category_name(scorecard_category)
	
	var modifiers_str = ""
	if has_modifiers():
		var mod_parts = []
		for effect in modifier_effects:
			var effect_desc = effect.get("short_description", effect.get("description", ""))
			if effect_desc != "":
				mod_parts.append(effect_desc)
		
		if mod_parts.size() > 0:
			modifiers_str = " +" + "+".join(mod_parts)
	
	var score_change = ""
	if final_score != base_score:
		score_change = " (%d→%d)" % [base_score, final_score]
	else:
		score_change = " (%d)" % base_score
	
	return "Turn %d: %s%s → %s%s%s = %d pts" % [
		turn_number, dice_str, colors_str, category_display, 
		score_change, modifiers_str, final_score
	]

## _format_category_name()
##
## Convert internal category names to display-friendly names.
func _format_category_name(category: String) -> String:
	match category.to_lower():
		"ones": return "Ones"
		"twos": return "Twos"
		"threes": return "Threes"
		"fours": return "Fours"
		"fives": return "Fives"
		"sixes": return "Sixes"
		"three_of_a_kind": return "3 of a Kind"
		"four_of_a_kind": return "4 of a Kind"
		"full_house": return "Full House"
		"small_straight": return "Small Straight"
		"large_straight": return "Large Straight"
		"yahtzee": return "Yahtzee"
		"chance": return "Chance"
		_: return category.capitalize()

## has_modifiers()
##
## Check if this entry has any modifier effects applied.
func has_modifiers() -> bool:
	return (powerups_applied.size() > 0 or 
			consumables_applied.size() > 0 or 
			dice_mods.size() > 0 or 
			modifier_effects.size() > 0)

## get_total_modifier_value()
##
## Calculate the total point change from all modifiers.
func get_total_modifier_value() -> int:
	return final_score - base_score

## get_timestamp_string()
##
## Get a human-readable timestamp string.
func get_timestamp_string() -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(int(timestamp))
	return "%02d:%02d:%02d" % [datetime.hour, datetime.minute, datetime.second]

## matches_filter()
##
## Check if this entry matches the given filter criteria.
func matches_filter(filter_dict: Dictionary) -> bool:
	if filter_dict.has("category") and filter_dict.category != "" and filter_dict.category != scorecard_category:
		return false
	
	if filter_dict.has("section") and filter_dict.section != "" and filter_dict.section != scorecard_section:
		return false
	
	if filter_dict.has("has_powerups") and filter_dict.has_powerups and powerups_applied.size() == 0:
		return false
	
	if filter_dict.has("has_consumables") and filter_dict.has_consumables and consumables_applied.size() == 0:
		return false
	
	if filter_dict.has("min_score") and final_score < filter_dict.min_score:
		return false
	
	if filter_dict.has("max_score") and final_score > filter_dict.max_score:
		return false
	
	if filter_dict.has("turn_range") and filter_dict.turn_range.size() >= 2:
		var min_turn = filter_dict.turn_range[0]
		var max_turn = filter_dict.turn_range[1]
		if turn_number < min_turn or turn_number > max_turn:
			return false
	
	return true

## to_dictionary()
##
## Convert this log entry to a dictionary for serialization.
func to_dictionary() -> Dictionary:
	return {
		"timestamp": timestamp,
		"turn_number": turn_number,
		"dice_values": dice_values,
		"dice_colors": dice_colors,
		"dice_mods": dice_mods,
		"scorecard_category": scorecard_category,
		"scorecard_section": scorecard_section,
		"consumables_applied": consumables_applied,
		"powerups_applied": powerups_applied,
		"base_score": base_score,
		"modifier_effects": modifier_effects,
		"final_score": final_score,
		"calculation_summary": calculation_summary,
		"formatted_log_line": formatted_log_line
	}

## from_dictionary()
##
## Create a LogEntry from a dictionary (for deserialization).
static func from_dictionary(dict: Dictionary) -> LogEntry:
	var entry = LogEntry.new()
	entry.timestamp = dict.get("timestamp", 0.0)
	entry.turn_number = dict.get("turn_number", 0)
	entry.dice_values = dict.get("dice_values", [])
	entry.dice_colors = dict.get("dice_colors", [])
	entry.dice_mods = dict.get("dice_mods", [])
	entry.scorecard_category = dict.get("scorecard_category", "")
	entry.scorecard_section = dict.get("scorecard_section", "")
	entry.consumables_applied = dict.get("consumables_applied", [])
	entry.powerups_applied = dict.get("powerups_applied", [])
	entry.base_score = dict.get("base_score", 0)
	entry.modifier_effects = dict.get("modifier_effects", [])
	entry.final_score = dict.get("final_score", 0)
	entry.calculation_summary = dict.get("calculation_summary", "")
	entry.formatted_log_line = dict.get("formatted_log_line", "")
	return entry