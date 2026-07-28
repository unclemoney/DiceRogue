extends Node

## rep_round_transition_test.gd
##
## Regression test for the playtest bug "REP is 0 at the round-1 -> round-2
## transition and the round-2 REP meter never moves". Drives the REAL game
## scene (Tests/DebuffTest.tscn is the shipped main game scene, see
## main_menu.gd) and the REAL transition functions:
##   1. A rep gain from a real Mom dialog sass (real
##      GameController._run_mom_dialog_session + real response picking)
##      survives the real round-end calls: ProgressManager.end_game_tracking()
##      (from _on_shop_button_pressed), RoundManager.complete_round() (from
##      _on_stats_panel_continue) and RoundManager.start_round(n+1) (from
##      _continue_round_start).
##   2. In "round 2", adjust_rep() still fires rep_changed and the signal
##      reaches a connected listener (the MomCharacter meter connects the
##      same way).
##   3. The same holds across a mall-zone change via the real channel-win
##      path (_on_next_channel_pressed -> carry-over confirm ->
##      _proceed_to_next_channel_with_carryovers ->
##      _restart_game_for_new_channel).
##   4. A mid-run profile reload that changes rep (e.g. the slot-mismatch
##      guard in save_current_profile()) MUST emit rep_changed so meters
##      refresh instead of silently showing a stale value.
##
## All profile slots and Rep values touched are restored afterwards.
##
## Scene-based test (autoloads must be compiled first).
## Run headless (do NOT pass --quit-after: the child game scene honors it
## and would quit early; this test always exits by itself with 0/1):
##   godot --headless --path . Tests/RepRoundTransitionTest.tscn
## Exit code 0 = all checks passed, 1 = at least one failure.

const GAME_SCENE := "res://Tests/DebuffTest.tscn"
const SASS_ATTEMPTS := 12  # checkin_neutral sassy is ~60% punished by design

var _failures: int = 0
var _profile_reloads: int = 0
var _pm
var _gc


func _ready() -> void:
	print("[RepRoundTransitionTest] Starting")
	var game = load(GAME_SCENE).instantiate()
	add_child(game)

	_pm = get_node_or_null("/root/ProgressManager")
	if _pm == null:
		_fail("ProgressManager autoload missing")
		_finish(-1, -1)
		return
	_pm.profile_loaded.connect(func(_slot): _profile_reloads += 1)

	# Wait for game boot + channel selector
	await get_tree().create_timer(4.0).timeout

	_gc = get_tree().get_first_node_in_group("game_controller")
	if _gc == null:
		_fail("GameController not found in game scene")
		_finish(-1, -1)
		return

	# Preserve original state (restored at the end)
	var orig_slot: int = _pm.current_profile_slot
	var orig_rep: int = _pm.get_rep()

	# Normalize rep to 0 so gains are observable
	_pm.cumulative_stats["rep"] = 0
	_pm.save_progress()
	_profile_reloads = 0

	# Start the game on channel 1 via the real signal path
	_gc.channel_manager.set_channel(1)
	_gc.channel_manager.select_channel()
	await get_tree().create_timer(2.0).timeout

	await _test_rep_survives_round_transition()
	await _test_rep_survives_zone_change()
	_test_profile_reload_notifies_rep_listeners()

	_finish(orig_rep, orig_slot)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[RepRoundTransitionTest] OK: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	push_error("[RepRoundTransitionTest] FAILED: " + label)
	_failures += 1


func _finish(orig_rep: int, orig_slot: int) -> void:
	# Restore original profile state
	if _pm:
		if orig_slot >= 1:
			_pm.load_profile(orig_slot)
		if orig_rep >= 0 and _pm.get_rep() != orig_rep:
			_pm.cumulative_stats["rep"] = orig_rep
			_pm.save_progress()

	if _failures == 0:
		print("[RepRoundTransitionTest] PASS - all checks passed")
	else:
		print("[RepRoundTransitionTest] FAIL - %d check(s) failed" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


## _test_rep_survives_round_transition()
##
## Round-1 sass gain must survive the real round-end function chain, and a
## round-2 sass must still raise rep and emit rep_changed to a listener.
func _test_rep_survives_round_transition() -> void:
	var gained := await _sass_until_gain()
	if not gained:
		_fail("could not gain rep from a round-1 sass (real dialog session)")
		return
	var rep_after_round1: int = _pm.get_rep()
	_check("round-1 sass raises rep above 0", rep_after_round1 > 0)

	# Real round-end chain, in real call order
	var score: int = _gc.scorecard.get_total_score() if _gc.scorecard else 0
	_pm.end_game_tracking(score, true)  # _on_shop_button_pressed
	_gc.round_manager.complete_round()  # _on_stats_panel_continue
	await get_tree().process_frame
	var next_round: int = _gc.round_manager.get_current_round_number() + 1
	_gc.round_manager.start_round(next_round)  # _continue_round_start
	await get_tree().create_timer(1.0).timeout

	_check("rep survives the round-end transition", _pm.get_rep() == rep_after_round1)
	_check("no profile reload during round transition", _profile_reloads == 0)

	# Round-2 sass: a probe listener stands in for the MomCharacter meter
	var heard: Array = []
	var listener := func(v): heard.append(v)
	_pm.rep_changed.connect(listener)
	var gained2 := await _sass_until_gain()
	_pm.rep_changed.disconnect(listener)
	_check("rep rises again in round 2", gained2)
	_check("rep_changed reaches a listener in round 2", not heard.is_empty())
	_check("no profile reload during round-2 sass", _profile_reloads == 0)


## _test_rep_survives_zone_change()
##
## The real channel-win path (next channel -> carry-over confirm ->
## _restart_game_for_new_channel) must keep rep, and sass must still work
## in the new zone.
func _test_rep_survives_zone_change() -> void:
	var rep_before_zone: int = _pm.get_rep()
	_gc._on_next_channel_pressed()
	var advanced := await _wait_for("zone advance", func():
		# Drive the panels the real flow may show
		if _gc._pending_unlocked_items.size() > 0 and _gc.unlocked_item_panel \
				and _gc.unlocked_item_panel.has_signal("all_items_acknowledged"):
			_gc.unlocked_item_panel.all_items_acknowledged.emit()
		if _gc.carry_over_panel and is_instance_valid(_gc.carry_over_panel) \
				and _gc.carry_over_panel.visible:
			_gc.carry_over_panel._on_confirm_pressed()
		return _gc.channel_manager.current_channel >= 2, 20.0)
	if not advanced:
		_fail("zone advance did not complete")
		return
	await get_tree().create_timer(2.0).timeout

	_check("rep survives mall-zone change", _pm.get_rep() == rep_before_zone)
	_check("no profile reload during zone change", _profile_reloads == 0)

	var heard: Array = []
	var listener := func(v): heard.append(v)
	_pm.rep_changed.connect(listener)
	var gained := await _sass_until_gain()
	_pm.rep_changed.disconnect(listener)
	_check("rep rises again in the new zone", gained)
	_check("rep_changed reaches a listener in the new zone", not heard.is_empty())


## _test_profile_reload_notifies_rep_listeners()
##
## load_profile() replaces cumulative_stats wholesale. If a mid-run reload
## (e.g. the slot-mismatch guard in save_current_profile()) changes rep,
## listeners must be told - otherwise every rep meter silently goes stale.
func _test_profile_reload_notifies_rep_listeners() -> void:
	var disk_rep: int = _pm.get_rep()
	# Diverge in-memory rep from the on-disk value without saving
	_pm.cumulative_stats["rep"] = mini(disk_rep + 5, _pm.MAX_REP)
	var heard: Array = []
	var listener := func(v): heard.append(v)
	_pm.rep_changed.connect(listener)
	_pm.load_profile(_pm.current_profile_slot)
	_pm.rep_changed.disconnect(listener)
	_check("reload reverts rep to the on-disk value", _pm.get_rep() == disk_rep)
	_check("profile reload emits rep_changed when rep changes", heard.has(disk_rep))
	_profile_reloads = 0  # reset the counter for this intentional reload


## _sass_until_gain()
##
## Runs real Mom dialog sessions (checkin_neutral, severity 0 - the real
## _on_mom_checkin entry point) with sassy answers until a rep gain lands.
## Sassy check-in outcomes are ~60% punished by design (0 rep), so retry.
func _sass_until_gain() -> bool:
	for attempt in range(SASS_ATTEMPTS):
		var before: int = _pm.get_rep()
		_gc._run_mom_dialog_session("checkin_neutral", 0, false)
		await _drive_dialog()
		await get_tree().create_timer(0.5).timeout
		if _pm.get_rep() > before:
			return true
	return false


## _drive_dialog()
##
## Auto-answers the Mom dialog: picks sassy responses, closes when the
## visit ends. Same driving the bot uses (choose_response_by_tone).
func _drive_dialog() -> void:
	var dialog = _gc._mom_dialog
	var safety := 0
	while safety < 600:
		safety += 1
		await get_tree().process_frame
		if not is_instance_valid(dialog):
			return
		if dialog.visible and dialog.has_pending_responses():
			if not dialog.choose_response_by_tone("sassy"):
				dialog.choose_response_by_tone("polite")
		elif not dialog.visible:
			if safety > 5:
				return  # Dialog closed -> session over
		else:
			dialog.close_dialog()  # Outcome reply showing -> close


func _wait_for(label: String, predicate: Callable, timeout_sec: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		if predicate.call():
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	print("[RepRoundTransitionTest] TIMEOUT waiting for: " + label)
	return false
