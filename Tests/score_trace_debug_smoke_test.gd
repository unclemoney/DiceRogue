extends Node

const ScorecardScript := preload("res://Scenes/ScoreCard/score_card.gd")
const DebugPanelScript := preload("res://Scripts/UI/debug_panel.gd")
const DiceColorClass := preload("res://Scripts/Core/dice_color.gd")

var _failures := 0
var _scorecard: Scorecard
var _debug_panel: DebugPanel
var _dice_hand: FakeDiceHand
var _turn_tracker: FakeTurnTracker
var _game_controller: FakeGameController


class FakeTurnTracker extends Node:
	signal turn_started(turn: int)

	var current_turn: int = 7

	func _ready() -> void:
		add_to_group("turn_tracker")
		if not turn_started.is_connected(_on_turn_started):
			turn_started.connect(_on_turn_started)

	func _on_turn_started(_turn: int) -> void:
		pass


class FakeDiceHand extends Node:
	var current_dice_type: String = "d6"
	var dice_list: Array[Dice] = []

	func _ready() -> void:
		add_to_group("dice_hand")

	func get_current_dice_values() -> Array[int]:
		var values: Array[int] = []
		for die in dice_list:
			if is_instance_valid(die):
				values.append(die.value)
		return values

	func get_color_effects() -> Dictionary:
		return DiceColorManager.calculate_color_effects(dice_list)

	func get_all_dice() -> Array[Dice]:
		return dice_list


class FakeGameController extends Node:
	signal consumable_used(id: String, consumable)

	var scorecard: Scorecard
	var turn_tracker: FakeTurnTracker
	var active_debuffs: Dictionary = {"debug_debuff": true}
	var active_challenges: Dictionary = {"debug_challenge": true}

	func _ready() -> void:
		add_to_group("game_controller")
		if not consumable_used.is_connected(_on_consumable_used):
			consumable_used.connect(_on_consumable_used)

	func _create_manual_breakdown_info(_category: String = "") -> Dictionary:
		return {}

	func _on_consumable_used(_id: String, _consumable) -> void:
		pass


func _ready() -> void:
	print("[ScoreTraceDebugSmokeTest] Starting")
	_check("ScoreModifierManager autoload available", ScoreModifierManager != null)
	_check("DiceColorManager autoload available", DiceColorManager != null)
	_check("Statistics autoload available", Statistics != null)
	if _failures > 0:
		_finish()
		return

	Statistics.reset_statistics()
	ScoreModifierManager.reset()
	ScoreModifierManager.set_division_mode(false)

	_scorecard = ScorecardScript.new()
	add_child(_scorecard)
	DiceResults.set_scorecard(_scorecard)

	_game_controller = FakeGameController.new()
	add_child(_game_controller)

	_turn_tracker = FakeTurnTracker.new()
	_game_controller.add_child(_turn_tracker)
	_game_controller.turn_tracker = _turn_tracker
	_game_controller.scorecard = _scorecard

	_dice_hand = FakeDiceHand.new()
	add_child(_dice_hand)
	_seed_dice_fixture()
	DiceResults.update_from_dice(_dice_hand.dice_list)

	_scorecard.upper_levels["fives"] = 2
	ScoreModifierManager.register_additive("debug_powerup_bonus", 3)
	ScoreModifierManager.register_multiplier("debug_powerup_multiplier", 2.0)

	_scorecard.on_category_selected(Scorecard.Section.UPPER, "fives")
	await get_tree().process_frame

	_debug_panel = DebugPanelScript.new()
	add_child(_debug_panel)
	await get_tree().process_frame

	_run_assertions()
	_cleanup_fixture()
	_finish()


func _seed_dice_fixture() -> void:
	var values: Array[int] = [5, 5, 4, 1, 1]
	var colors = [
		DiceColorClass.Type.PURPLE,
		DiceColorClass.Type.RED,
		DiceColorClass.Type.BLUE,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
	]

	for i in range(values.size()):
		var die := Dice.new()
		die.value = values[i]
		die.color = colors[i]
		die.current_state = Dice.DiceState.ROLLED
		if i == 0:
			die.current_state = Dice.DiceState.LOCKED
			die.is_locked = true
			die.active_mods["odd_only"] = Node.new()
		elif i == 2:
			die.active_mods["wildcard"] = Node.new()
		_dice_hand.dice_list.append(die)


func _run_assertions() -> void:
	var latest_entry = Statistics.get_latest_log_entry()
	_check("latest log entry created", latest_entry != null)
	if latest_entry == null:
		return

	_check("turn number captured from TurnTracker", latest_entry.turn_number == 7)
	_check("final score recorded", latest_entry.final_score == 38)
	_check("latest entry keeps used dice indices", latest_entry.breakdown_info.get("used_dice_indices", []).size() == 2)

	var live_report = _debug_panel._build_live_dice_state_report()
	var score_report = _debug_panel._build_score_trace_report()

	_check("live report shows last scored hand header", live_report.contains("Last scored hand: Fives / upper"))
	_check("live report shows die snapshot comparison", live_report.contains("Last score | value=5 | color=purple | used=true | mods=odd_only"))
	_check("score report shows final score", score_report.contains("Final score: 38"))
	_check("score report shows additive trace", score_report.contains("Additives: regular +3 | red dice +5 => 38"))
	_check("score report shows multiplier source", score_report.contains("debug_powerup_multiplier ×2.00"))
	_check("score report shows recent history", score_report.contains("Recent history:"))


func _cleanup_fixture() -> void:
	ScoreModifierManager.reset()
	ScoreModifierManager.set_division_mode(false)
	DiceResults.reset()
	DiceResults.set_scorecard(null)

	if is_instance_valid(_debug_panel):
		_debug_panel.free()

	if is_instance_valid(_game_controller):
		_game_controller.free()
	if is_instance_valid(_dice_hand):
		for die in _dice_hand.dice_list:
			if is_instance_valid(die):
				for mod in die.active_mods.values():
					if is_instance_valid(mod):
						mod.free()
				die.active_mods.clear()
				die.free()
		_dice_hand.dice_list.clear()
		_dice_hand.free()
	if is_instance_valid(_scorecard):
		_scorecard.free()


func _finish() -> void:
	if _failures == 0:
		print("[ScoreTraceDebugSmokeTest] PASS - all checks passed")
	else:
		print("[ScoreTraceDebugSmokeTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[ScoreTraceDebugSmokeTest] OK: " + label)
	else:
		push_error("[ScoreTraceDebugSmokeTest] FAILED: " + label)
		_failures += 1