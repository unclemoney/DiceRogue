extends Control

## rep_pacing_test.gd
##
## Pins the REP pacing envelope for the new rebel-mode target: a steadily
## sassing player must be able to reach REP 60 (tier 4, NC-17 POGs) by the
## end of Mall Zone 2 Round 6 (~12 check-ins) but not trivially during Zone 1.

const Handler := preload("res://Scripts/Core/mom_logic_handler.gd")

@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel

var _failures: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	print("\n=== REP PACING TEST ===")
	await get_tree().process_frame
	_run_tests()
	_finish()


func _check(condition: bool, label: String) -> void:
	var status := "PASS" if condition else "FAIL"
	if not condition:
		_failures += 1
	var line := "%s: %s" % [status, label]
	print(line)
	_lines.append(line)


func _run_tests() -> void:
	# 1. Constants exist and are positive
	_check(GameController.REP_SASS_SUCCESS > 0, "REP_SASS_SUCCESS positive")
	_check(GameController.REP_DEFER_SUCCESS > 0, "REP_DEFER_SUCCESS positive")
	_check(GameController.REP_STORM_OFF > 0, "REP_STORM_OFF positive")
	_check(GameController.REP_POLITE_PUNISHMENT < 0, "REP_POLITE_PUNISHMENT negative")
	_check(GameController.REP_POLITE_CHECKIN < 0, "REP_POLITE_CHECKIN negative")

	# 2. Tier 4 threshold is 60
	_check(ProgressManager.REP_TIER_THRESHOLDS[4] == 60, "REP tier 4 threshold is 60")

	# 3. Reachable by the end of Mall Zone 2 Round 6: even the weakest
	#    positive sass gain over 12 check-ins must clear 60.
	var min_gain: int = mini(GameController.REP_SASS_SUCCESS, mini(GameController.REP_DEFER_SUCCESS, GameController.REP_STORM_OFF))
	_check(12 * min_gain >= 60, "weakest sass gain x 12 check-ins >= 60 (got %d)" % (12 * min_gain))

	# 4. Not trivial in Zone 1: even the strongest gain over 6 check-ins
	#    (rounds 1-6) must stay below 60.
	var max_gain: int = maxi(GameController.REP_SASS_SUCCESS, maxi(GameController.REP_DEFER_SUCCESS, GameController.REP_STORM_OFF))
	_check(6 * max_gain < 60, "strongest sass gain x 6 check-ins < 60 (got %d)" % (6 * max_gain))

	# 5. Realistic mixed sass trajectory: ~70% of 12 check-ins landing the
	#    base sass gain should clear 60.
	var mid_gain: int = GameController.REP_SASS_SUCCESS
	var realistic: int = int(12 * 0.7) * mid_gain
	_check(realistic >= 60, "70%% x 12 check-ins at sass gain >= 60 (got %d)" % realistic)

	# 6. The common neutral check-in root needs a real expected value that can
	#    support the Zone 2 target instead of relying on perfect storm-offs.
	var checkin_neutral: MomDialogNode = Handler.get_dialog_node("checkin_neutral")
	_check(checkin_neutral != null, "checkin_neutral node available for REP pacing")
	if checkin_neutral and checkin_neutral.responses.size() >= 3:
		var expected_gain := _expected_rep_gain_for_sassy_response(checkin_neutral.responses[2])
		_check(expected_gain >= 5.0, "checkin_neutral sassy expected REP gain >= 5.0 (got %.2f)" % expected_gain)

	# 7. Check-in window: standalone ChoresManager falls back to the zone-1 max
	var cm := ChoresManager.new()
	add_child(cm)
	_check(cm.get_checkin_max() == 7, "checkin max fallback is 7 (zone 1)")
	cm.queue_free()


func _expected_rep_gain_for_sassy_response(response: MomDialogResponse) -> float:
	if response == null or response.outcomes.is_empty():
		return 0.0
	var total_weight := response.get_total_weight()
	if total_weight <= 0.0:
		return 0.0
	var total_gain := 0.0
	for outcome in response.outcomes:
		if outcome == null:
			continue
		var gain := 0
		match outcome.effect:
			"defer_punishment":
				gain = GameController.REP_DEFER_SUCCESS
			"storms_off":
				gain = GameController.REP_STORM_OFF
			"apply_tier", "fine", "debuff", "confiscate_powerups", "remove_mod", "lock_cosmetics":
				gain = 0
			_:
				gain = GameController.REP_SASS_SUCCESS
		total_gain += (outcome.weight / total_weight) * float(gain)
	return total_gain


func _finish() -> void:
	var summary := ""
	if _failures == 0:
		summary = "ALL TESTS PASSED"
	else:
		summary = "%d TEST(S) FAILED" % _failures
	print("[RepPacingTest] " + summary)
	_lines.append("")
	_lines.append(summary)
	if results_label:
		results_label.text = "\n".join(_lines)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(_failures)
