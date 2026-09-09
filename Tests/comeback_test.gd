extends Node

## comeback_test.gd
##
## Headless auto-run tests for the Mulligan, Scratch Ticket, and Comeback Kid
## items. Prints OK/FAILED per check and quits 0 on pass, 1 on failure.
## Run:
##   Godot --headless --path <project> Tests/comeback_test.tscn --quit-after 60

var _failures := 0


func _ready() -> void:
	print("=== Comeback Test Suite ===")
	_test_mulligan_selection()
	_test_scratch_ticket()
	_test_comeback_kid()
	_finish()


func _ok(condition: bool, test_name: String) -> void:
	if condition:
		print("OK: %s" % test_name)
	else:
		_failures += 1
		print("FAILED: %s" % test_name)


func _finish() -> void:
	if _failures == 0:
		print("=== ALL TESTS PASSED ===")
		get_tree().quit(0)
	else:
		print("=== TESTS FAILED: %d ===" % _failures)
		get_tree().quit(1)


## Mulligan: worst-category selection over crafted scorecard dicts.
func _test_mulligan_selection() -> void:
	print("--- Mulligan worst-category selection ---")

	# No placed scores -> empty result
	var all_null_upper := {"ones": null, "twos": null}
	var all_null_lower := {"yahtzee": null, "chance": null}
	_ok(MulliganConsumable.find_worst_placed_score(all_null_upper, all_null_lower).is_empty(),
		"mulligan: no placed scores returns empty")

	# A scored 0 counts and is always the worst
	var upper_zero := {"ones": null, "twos": 0}
	var lower_high := {"yahtzee": 50, "chance": 22}
	var worst := MulliganConsumable.find_worst_placed_score(upper_zero, lower_high)
	_ok(worst.get("category", "") == "twos", "mulligan: scored zero is the worst")
	_ok(worst.get("section", -1) == Scorecard.Section.UPPER, "mulligan: zero found in upper section")
	_ok(worst.get("score", -1) == 0, "mulligan: zero score value returned")

	# Minimum across both sections
	var upper_mid := {"ones": 3, "fives": 15}
	var lower_min := {"three_of_a_kind": null, "chance": 2, "yahtzee": 50}
	worst = MulliganConsumable.find_worst_placed_score(upper_mid, lower_min)
	_ok(worst.get("category", "") == "chance", "mulligan: lower section minimum wins")
	_ok(worst.get("section", -1) == Scorecard.Section.LOWER, "mulligan: lower section reported")
	_ok(worst.get("score", -1) == 2, "mulligan: minimum score value returned")

	# Unscored (null) never beats a placed score
	var upper_null_low := {"ones": null}
	var lower_placed := {"chance": 1}
	worst = MulliganConsumable.find_worst_placed_score(upper_null_low, lower_placed)
	_ok(worst.get("category", "") == "chance", "mulligan: null is skipped, placed score wins")


## Scratch Ticket: true-zero gate plus arm/disarm against a real Scorecard.
func _test_scratch_ticket() -> void:
	print("--- Scratch Ticket arm/disarm ---")

	var scorecard := Scorecard.new()
	add_child(scorecard)
	var ticket := ScratchTicketConsumable.new()
	add_child(ticket)

	# last_base_score starts at 0, but no score placed yet -> refuse
	_ok(not ScratchTicketConsumable.can_arm(scorecard),
		"scratch ticket: refuses with no placed scores")

	# Non-zero last base score -> refuse
	scorecard.set_score(Scorecard.Section.UPPER, "ones", 3)
	scorecard.last_base_score = 3
	_ok(not ScratchTicketConsumable.can_arm(scorecard),
		"scratch ticket: refuses when last base score is non-zero")

	# True zero last base score -> arm
	scorecard.set_score(Scorecard.Section.LOWER, "yahtzee", 0)
	scorecard.last_base_score = 0
	_ok(ScratchTicketConsumable.can_arm(scorecard),
		"scratch ticket: arms when last base score is a true zero")

	ticket.arm(scorecard)
	_ok(ticket.is_active, "scratch ticket: active after arm")
	_ok(ScoreModifierManager.has_multiplier("scratch_ticket"),
		"scratch ticket: multiplier registered")

	# Next score disarms the one-shot
	scorecard.set_score(Scorecard.Section.UPPER, "twos", 4)
	_ok(not ticket.is_active, "scratch ticket: disarmed after next score")
	_ok(not ScoreModifierManager.has_multiplier("scratch_ticket"),
		"scratch ticket: multiplier removed after next score")

	ticket.queue_free()
	scorecard.queue_free()


## Comeback Kid: zero-count logic and additive register/unregister lifecycle.
func _test_comeback_kid() -> void:
	print("--- Comeback Kid zero-count and lifecycle ---")

	# Static zero-count logic on crafted dicts
	var empty_upper := {"ones": null, "twos": null}
	var empty_lower := {"chance": null}
	_ok(ComebackKidPowerUp.count_zero_scores(empty_upper, empty_lower) == 0,
		"comeback kid: 0 zeros when nothing scored")

	var mixed_upper := {"ones": 0, "twos": 4, "threes": null}
	var mixed_lower := {"chance": 0, "yahtzee": 0, "full_house": 25}
	_ok(ComebackKidPowerUp.count_zero_scores(mixed_upper, mixed_lower) == 3,
		"comeback kid: counts exactly the 0-scored categories")

	# Lifecycle against a real Scorecard (2 zero-scored categories)
	var scorecard := Scorecard.new()
	add_child(scorecard)
	scorecard.set_score(Scorecard.Section.UPPER, "ones", 0)
	scorecard.set_score(Scorecard.Section.LOWER, "yahtzee", 0)

	var power_up := ComebackKidPowerUp.new()
	add_child(power_up)
	power_up.scorecard_ref = scorecard

	var dice_values: Array[int] = [1, 2, 3, 4, 5]
	power_up._on_about_to_score(Scorecard.Section.LOWER, "chance", dice_values)
	_ok(ScoreModifierManager.has_additive("comeback_kid"),
		"comeback kid: additive registered on about_to_score")
	_ok(ScoreModifierManager.get_additive("comeback_kid") == 2 * ComebackKidPowerUp.BONUS_PER_ZERO,
		"comeback kid: additive equals zeros x per-zero value")

	power_up._on_score_assigned(Scorecard.Section.LOWER, "chance", 10)
	_ok(not ScoreModifierManager.has_additive("comeback_kid"),
		"comeback kid: additive removed after score_assigned")

	# No zeros remaining relevant check: fresh card with a non-zero score
	var scorecard2 := Scorecard.new()
	add_child(scorecard2)
	scorecard2.set_score(Scorecard.Section.UPPER, "ones", 3)
	power_up.scorecard_ref = scorecard2
	power_up._on_about_to_score(Scorecard.Section.LOWER, "chance", dice_values)
	_ok(not ScoreModifierManager.has_additive("comeback_kid"),
		"comeback kid: no additive when nothing is 0-scored")

	power_up.queue_free()
	scorecard.queue_free()
	scorecard2.queue_free()
