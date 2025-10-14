extends Node

## RollStats
##
## Autoload singleton that tracks game statistics such as yahtzees, 
## full houses, straights, and bonuses achieved during gameplay.
## Provides centralized statistics tracking for PowerUps and debug information.

# Yahtzee statistics
var yahtzees_rolled: int = 0
var yahtzee_bonuses_earned: int = 0

# Combination statistics
var three_of_a_kinds: int = 0
var four_of_a_kinds: int = 0
var full_houses: int = 0
var small_straights: int = 0
var large_straights: int = 0

# Bonus statistics
var upper_bonuses_earned: int = 0
var total_bonuses: int = 0

# Game statistics
var total_rolls: int = 0
var total_score: int = 0
var games_played: int = 0

# Signals for real-time updates
signal stats_updated
signal yahtzee_rolled
signal combination_achieved(combination_type: String)
signal bonus_achieved(bonus_type: String)

func _ready() -> void:
	print("[RollStats] Singleton initialized")

## Track when a yahtzee is rolled (first time)
func track_yahtzee_rolled() -> void:
	yahtzees_rolled += 1
	print("[RollStats] Yahtzee rolled! Total: %d" % yahtzees_rolled)
	emit_signal("stats_updated")
	emit_signal("yahtzee_rolled")
	emit_signal("combination_achieved", "yahtzee")

## Track when a yahtzee bonus is earned (additional yahtzees)
func track_yahtzee_bonus() -> void:
	yahtzee_bonuses_earned += 1
	total_bonuses += 1
	print("[RollStats] Yahtzee bonus earned! Total bonuses: %d" % yahtzee_bonuses_earned)
	emit_signal("stats_updated")
	emit_signal("bonus_achieved", "yahtzee_bonus")

## Track other combinations
func track_three_of_a_kind() -> void:
	three_of_a_kinds += 1
	emit_signal("stats_updated")
	emit_signal("combination_achieved", "three_of_a_kind")

func track_four_of_a_kind() -> void:
	four_of_a_kinds += 1
	emit_signal("stats_updated")
	emit_signal("combination_achieved", "four_of_a_kind")

func track_full_house() -> void:
	full_houses += 1
	emit_signal("stats_updated")
	emit_signal("combination_achieved", "full_house")

func track_small_straight() -> void:
	small_straights += 1
	emit_signal("stats_updated")
	emit_signal("combination_achieved", "small_straight")

func track_large_straight() -> void:
	large_straights += 1
	emit_signal("stats_updated")
	emit_signal("combination_achieved", "large_straight")

## Track upper section bonus
func track_upper_bonus() -> void:
	upper_bonuses_earned += 1
	total_bonuses += 1
	print("[RollStats] Upper bonus earned! Total: %d" % upper_bonuses_earned)
	emit_signal("stats_updated")
	emit_signal("bonus_achieved", "upper_bonus")

## Track dice rolls
func track_roll() -> void:
	total_rolls += 1
	emit_signal("stats_updated")

## Track final game score
func track_game_completed(final_score: int) -> void:
	total_score = final_score
	games_played += 1
	emit_signal("stats_updated")

## Reset statistics for new game
func reset_stats() -> void:
	print("[RollStats] Resetting statistics for new game")
	yahtzees_rolled = 0
	yahtzee_bonuses_earned = 0
	three_of_a_kinds = 0
	four_of_a_kinds = 0
	full_houses = 0
	small_straights = 0
	large_straights = 0
	upper_bonuses_earned = 0
	total_bonuses = 0
	total_rolls = 0
	total_score = 0
	emit_signal("stats_updated")

## Get formatted statistics string for display
func get_stats_summary() -> String:
	var summary = "=== ROLL STATISTICS ===\n"
	summary += "Games Played: %d\n" % games_played
	summary += "Total Rolls: %d\n" % total_rolls
	summary += "Final Score: %d\n" % total_score
	summary += "\n=== COMBINATIONS ===\n"
	summary += "Yahtzees: %d\n" % yahtzees_rolled
	summary += "Four of a Kind: %d\n" % four_of_a_kinds
	summary += "Full Houses: %d\n" % full_houses
	summary += "Three of a Kind: %d\n" % three_of_a_kinds
	summary += "Large Straights: %d\n" % large_straights
	summary += "Small Straights: %d\n" % small_straights
	summary += "\n=== BONUSES ===\n"
	summary += "Upper Bonuses: %d\n" % upper_bonuses_earned
	summary += "Yahtzee Bonuses: %d\n" % yahtzee_bonuses_earned
	summary += "Total Bonuses: %d\n" % total_bonuses
	return summary

## Get brief statistics for UI display
func get_brief_stats() -> String:
	return "Yahtzees: %d | Bonuses: %d | Rolls: %d" % [yahtzees_rolled, total_bonuses, total_rolls]