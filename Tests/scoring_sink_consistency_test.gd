extends Node
class_name ScoringSinkConsistencyTest

## ScoringSinkConsistencyTest
##
## Headless verification of the score-sink display contract:
##   - milestones are floor/truncated (int of the float running score),
##   - the sink never displays a value above the authoritative final score
##     that the blow-up would later reduce because of rounding,
##   - the blow-up target equals the last displayed milestone,
##   - a debuff penalty chip subtracts inside the additive stage,
##   - a mid-animation restart emits no stale animation_sequence_complete.
##
## Run: godot --path <project> Tests/scoring_sink_consistency_test.tscn
## Exits 0 on PASS, 1 on FAIL.

const MockScoringRigScript = preload("res://Tests/mock_scoring_rig.gd")

var _failures: int = 0
var scoring_controller: ScoringAnimationController
var rig: MockScoringRig

var _max_display_seen: int = 0
var _completions: int = 0
var _expected_final: int = -1


func _ready() -> void:
	print("[ScoringSinkConsistencyTest] Initializing...")
	rig = MockScoringRigScript.new()
	rig.name = "MockScoringRig"
	add_child(rig)

	scoring_controller = ScoringAnimationController.new()
	scoring_controller.name = "ScoringAnimationController"
	add_child(scoring_controller)
	scoring_controller.animation_sequence_complete.connect(_on_sequence_complete)

	await get_tree().create_timer(0.6).timeout
	await _run_scenario_penalty_decimal()
	await _run_scenario_decimal_floor()
	await _run_scenario_restart_no_stale_completion()

	if _failures == 0:
		print("[ScoringSinkConsistencyTest] ALL TESTS PASSED")
		get_tree().quit(0)
	else:
		print("[ScoringSinkConsistencyTest] %d TEST(S) FAILED" % _failures)
		get_tree().quit(1)


func _process(_delta: float) -> void:
	if scoring_controller and scoring_controller.animation_in_progress:
		_max_display_seen = maxi(_max_display_seen, scoring_controller.get_running_display_score())


func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		push_error("  FAIL: %s" % label)


func _on_sequence_complete() -> void:
	_completions += 1


func _begin_scenario(expected_final: int) -> void:
	_expected_final = expected_final
	_max_display_seen = 0


func _finish_scenario(label: String) -> void:
	_assert(scoring_controller.get_running_display_score() == _expected_final,
		"%s: final displayed score == authoritative %d" % [label, _expected_final])
	_assert(_max_display_seen <= _expected_final,
		"%s: sink never displayed a value above the final score (max seen %d)" % [label, _max_display_seen])


## Scenario A: Rolling Penalty chip + decimal multiplier.
## dice [4,4,3] = 11, penalty -2 -> 9, x1.5 -> 13.5 -> int = 13.
## Old nearest-rounding would have displayed 14 before dropping to 13.
func _run_scenario_penalty_decimal() -> void:
	print("[ScoringSinkConsistencyTest] Scenario A: penalty additive + decimal multiplier")
	_begin_scenario(13)
	rig.configure([4, 4, 3], [], [])
	var breakdown = _build_breakdown([4, 4, 3],
		[{"name": "roll_score_minus_one", "category": "debuff", "value": -2}],
		[],
		{"effective_regular_multiplier": 1.5})
	scoring_controller.start_scoring_animation(13, "test_penalty", breakdown)
	await scoring_controller.animation_sequence_complete
	_finish_scenario("A")


## Scenario B: pure decimal multiplier floors instead of rounding up.
## dice [5,6] = 11, x1.5 -> 16.5 -> int = 16 (round() would show 17).
func _run_scenario_decimal_floor() -> void:
	print("[ScoringSinkConsistencyTest] Scenario B: decimal multiplier floor")
	_begin_scenario(16)
	rig.configure([5, 6], [], [])
	var breakdown = _build_breakdown([5, 6], [], [],
		{"effective_regular_multiplier": 1.5})
	scoring_controller.start_scoring_animation(16, "test_decimal", breakdown)
	await scoring_controller.animation_sequence_complete
	_finish_scenario("B")


## Scenario C: a scoring event mid-animation restarts the sequence. The
## interrupted sequence must NOT emit animation_sequence_complete; exactly
## one completion fires, for the second event.
func _run_scenario_restart_no_stale_completion() -> void:
	print("[ScoringSinkConsistencyTest] Scenario C: restart emits no stale completion")
	var completions_before := _completions
	_begin_scenario(16)

	rig.configure([4, 4, 3], [], [])
	var first = _build_breakdown([4, 4, 3],
		[{"name": "roll_score_minus_one", "category": "debuff", "value": -2}],
		[],
		{"effective_regular_multiplier": 1.5})
	scoring_controller.start_scoring_animation(13, "test_penalty", first)

	await get_tree().create_timer(0.8).timeout
	_assert(scoring_controller.animation_in_progress, "C: first sequence still running at interrupt time")

	rig.configure([5, 6], [], [])
	var second = _build_breakdown([5, 6], [], [],
		{"effective_regular_multiplier": 1.5})
	scoring_controller.start_scoring_animation(16, "test_decimal", second)

	await scoring_controller.animation_sequence_complete
	# Give any stale emitter a frame to (incorrectly) fire
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(_completions - completions_before == 1,
		"C: exactly one completion emitted across the restart (got %d)" % (_completions - completions_before))
	_finish_scenario("C")


## _build_breakdown(dice_values, additive_sources, multiplier_sources, extras) -> Dictionary
##
## Synthetic breakdown_info mirroring Scorecard.calculate_score_with_breakdown.
func _build_breakdown(dice_values: Array, additive_sources: Array, multiplier_sources: Array, extras: Dictionary = {}) -> Dictionary:
	var used: Array = []
	var base = 0
	for i in range(dice_values.size()):
		used.append(i)
		base += int(dice_values[i])
	var breakdown = {
		"base_score": base,
		"dice_values": dice_values,
		"used_dice_indices": used,
		"active_consumables": [],
		"active_powerups": [],
		"additive_sources": additive_sources,
		"multiplier_sources": multiplier_sources,
	}
	for key in extras.keys():
		breakdown[key] = extras[key]
	return breakdown
