extends Control

## rep_pacing_test.gd
##
## Pins the REP pacing envelope for the 4-zone run: a steadily sassing
## player must be able to reach REP 60 (tier 4, NC-17 POGs) by Zone 4
## (round 19, ~18 check-ins) but not before Zone 2 (round 7, ~6 check-ins).

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

	# 3. Reachable by zone 4: even the weakest positive sass gain over 18
	#    check-ins must clear 60. (One check-in per round, rounds 1-18.)
	var min_gain: int = mini(GameController.REP_SASS_SUCCESS, mini(GameController.REP_DEFER_SUCCESS, GameController.REP_STORM_OFF))
	_check(18 * min_gain >= 60, "weakest sass gain x 18 check-ins >= 60 (got %d)" % (18 * min_gain))

	# 4. Not before zone 2: even the strongest gain over 6 check-ins (rounds
	#    1-6) must stay below 60.
	var max_gain: int = maxi(GameController.REP_SASS_SUCCESS, maxi(GameController.REP_DEFER_SUCCESS, GameController.REP_STORM_OFF))
	_check(6 * max_gain < 60, "strongest sass gain x 6 check-ins < 60 (got %d)" % (6 * max_gain))

	# 5. Realistic mixed sass trajectory: ~70% of 18 check-ins landing the
	#    mid-tier gain should clear 60.
	var mid_gain: int = GameController.REP_SASS_SUCCESS
	var realistic: int = int(18 * 0.7) * mid_gain
	_check(realistic >= 60, "70%% x 18 check-ins at sass gain >= 60 (got %d)" % realistic)

	# 6. Check-in window: standalone ChoresManager falls back to the zone-1 max
	var cm := ChoresManager.new()
	add_child(cm)
	_check(cm.get_checkin_max() == 7, "checkin max fallback is 7 (zone 1)")
	cm.queue_free()


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
