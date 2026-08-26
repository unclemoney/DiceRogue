extends Node

## Throwaway test for the ChallengeUI store API (challenges deprecated).
## Exercises show_store / set_store_progress / fan-out / complete / clear.

var _failures: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		_failures += 1
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var ui := ChallengeUI.new()
	add_child(ui)
	await get_tree().process_frame

	# show_store adds one icon with the store name and target
	var icon := ui.show_store("Food Court", 150, 25, 1)
	_check(icon != null, "show_store returns an icon")
	_check(ui._challenges.has("Food Court"), "store id registered in _challenges")
	_check(icon.data.display_name == "Food Court", "icon title is the store name")
	_check(icon.data.target_score == 150, "icon target score set")
	_check(icon.data.reward_money == 25, "icon reward set")
	_check(icon.data.difficulty == 1, "icon difficulty set")

	# progress updates the icon bar
	ui.set_store_progress(0.5)
	await get_tree().process_frame
	_check(is_equal_approx(ui._progress["Food Court"], 0.5), "progress tracked at 0.5")
	ui.set_store_progress(2.0)
	_check(is_equal_approx(ui._progress["Food Court"], 1.0), "progress clamps to 1.0")

	# debuff tags land on the icon data
	ui.set_store_debuffs(["one_shot", "docked_allowance"])
	_check(icon.data.debuff_ids == (["one_shot", "docked_allowance"] as Array[String]), "debuff tags set on icon data")

	# fan-out creates a detail card; clicking folds back
	ui._fan_out_challenges()
	await get_tree().process_frame
	_check(ui._current_state == ChallengeUI.State.FANNED_OUT, "fan-out state entered")
	_check(ui._detail_cards.has("Food Court"), "detail card created for store")
	var card: ChallengeDetailCard = ui._detail_cards["Food Court"]
	_check(is_equal_approx(card._progress, 1.0), "detail card got current progress")
	ui._fold_back_challenges()
	await get_tree().process_frame
	_check(ui._current_state == ChallengeUI.State.NORMAL, "fold-back returns to normal")
	_check(icon.visible, "icon visible again after fold-back")

	# complete/fail effects don't error and set progress to full
	ui.notify_store_completed()
	_check(is_equal_approx(ui._progress.get("Food Court", 0.0), 1.0), "completion leaves progress at 1.0")

	# clear removes everything; a second store replaces the first
	ui.show_store("Comic Book Store", 75, 10, 2)
	_check(not ui._challenges.has("Food Court"), "previous store cleared")
	_check(ui._challenges.has("Comic Book Store"), "new store shown")
	_check(ui._challenges.size() == 1, "exactly one store icon at a time")

	ui.clear_all_challenges()
	_check(ui._challenges.is_empty(), "clear_all_challenges empties icons")

	# Safe no-ops with nothing shown
	ui.set_store_progress(0.5)
	ui.notify_store_failed()
	_check(true, "no-op calls safe with no store")

	print("StoreChallengeUITest done. failures=%d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
