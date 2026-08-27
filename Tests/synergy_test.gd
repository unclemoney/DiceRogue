extends Node

## SynergyTest
##
## Test scene to validate SynergyManager functionality.
## Tests rating tracking, matching set bonuses (+50 per 5), and rainbow multiplier (5x).
##
## Run headless with `-- --quit-after` to exit with the failure count.
##
## Run with: & "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --path "c:\Users\danie\Documents\dicerogue\DiceRogue" Tests/SynergyTest.tscn

var synergy_manager
var power_up_manager: PowerUpManager
var game_controller: GameController
var score_modifier_manager
var _test_failures: int = 0

const TEST_RATINGS := ["G", "PG", "PG-13", "R", "NC-17"]

func _ready() -> void:
	print("=== Synergy Test Scene Ready ===")
	print("Press F12 to open debug panel and use Synergies tab")
	print("Or wait for auto-tests to complete")
	print("================================")
	
	# Wait for scene to fully load
	await get_tree().create_timer(0.5).timeout
	
	# Find managers
	synergy_manager = get_tree().get_first_node_in_group("synergy_manager")
	game_controller = get_tree().get_first_node_in_group("game_controller")
	
	if game_controller:
		power_up_manager = game_controller.pu_manager
		synergy_manager = game_controller.synergy_manager
	
	# Get ScoreModifierManager
	score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	
	# Run auto tests
	await get_tree().create_timer(1.0).timeout
	_run_synergy_tests()


func _run_synergy_tests() -> void:
	print("\n")
	print("╔══════════════════════════════════════════════════╗")
	print("║          SYNERGY MANAGER TEST SUITE              ║")
	print("╚══════════════════════════════════════════════════╝")
	
	# Test 1: Verify managers exist
	print("\n[TEST 1] Manager availability check...")
	var managers_ok := true
	
	if not synergy_manager:
		print("  ❌ FAIL: SynergyManager not found")
		managers_ok = false
	else:
		print("  ✓ SynergyManager found")
	
	if not power_up_manager:
		print("  ❌ FAIL: PowerUpManager not found")
		managers_ok = false
	else:
		print("  ✓ PowerUpManager found")
	
	if not game_controller:
		print("  ❌ FAIL: GameController not found")
		managers_ok = false
	else:
		print("  ✓ GameController found")
	
	if not score_modifier_manager:
		print("  ❌ FAIL: ScoreModifierManager not found")
		managers_ok = false
	else:
		print("  ✓ ScoreModifierManager found")
	
	if not managers_ok:
		_fail_test("Cannot run tests without required managers")
		print("\n[ABORT] Cannot run tests without required managers")
		_quit_if_requested()
		return

	await _clear_power_ups_for_test()
	
	# Test 2: Check initial state
	print("\n[TEST 2] Initial state check...")
	var initial_counts = synergy_manager.get_rating_counts()
	var all_zero := true
	for rating in TEST_RATINGS:
		if initial_counts.get(rating, 0) != 0:
			all_zero = false
			break
	
	if all_zero:
		print("  ✓ All rating counts start at 0")
	else:
		_fail_test("Rating counts not all zero at test start: %s" % str(initial_counts))
	
	# Test 3: PowerUp rating lookup
	print("\n[TEST 3] PowerUp rating lookup...")
	var test_powerups := ["extra_dice", "extra_rolls", "bonus_money"]
	for pu_id in test_powerups:
		var data = power_up_manager.get_def(pu_id)
		if data:
			print("  ✓ %s -> rating: %s" % [pu_id, data.rating])
		else:
			print("  ❌ FAIL: No data for %s" % pu_id)
	
	# Test 4: Grant PowerUp and check tracking
	print("\n[TEST 4] PowerUp grant tracking...")
	var available = power_up_manager.get_available_power_ups()
	if available.size() > 0:
		var test_id = available[0]
		var test_data = power_up_manager.get_def(test_id)
		var expected_rating = test_data.rating if test_data else "G"
		
		print("  Granting: %s (rating: %s)" % [test_id, expected_rating])
		game_controller.grant_power_up(test_id)
		
		await get_tree().create_timer(0.2).timeout
		
		var counts_after = synergy_manager.get_rating_counts()
		var count_for_rating = counts_after.get(expected_rating, 0)
		
		if count_for_rating >= 1:
			print("  ✓ Rating count increased correctly: %s = %d" % [expected_rating, count_for_rating])
		else:
			print("  ❌ FAIL: Rating count not increased")
	else:
		print("  ⚠ No available PowerUps to test")
	
	# Test 5: Print available PowerUps by rating
	print("\n[TEST 5] Available PowerUps by rating...")
	var by_rating: Dictionary = {}
	for rating in TEST_RATINGS:
		by_rating[rating] = []
	
	for pu_id in available:
		var data = power_up_manager.get_def(pu_id)
		if data:
			var rating = data.rating
			if by_rating.has(rating):
				by_rating[rating].append(pu_id)
	
	for rating in TEST_RATINGS:
		var count = by_rating[rating].size()
		print("  %s: %d PowerUps %s" % [rating, count, by_rating[rating]])
	
	# Test 6: Check ScoreModifierManager integration
	print("\n[TEST 6] ScoreModifierManager integration...")
	var total_additive = score_modifier_manager.get_total_additive()
	var total_mult = score_modifier_manager.get_total_multiplier()
	print("  Current additive: %d" % total_additive)
	print("  Current multiplier: %.2fx" % total_mult)

	# Test 7: Reported mixed-rating regression should not activate a set bonus
	print("\n[TEST 7] Mixed-rating grant does not trigger matching-set bonus...")
	await _clear_power_ups_for_test()
	var regression_ids: Array[String] = _build_mixed_rating_test_ids(by_rating)
	if regression_ids.size() != 5:
		_fail_test("Could not build the 3x G / 2x PG regression set from available PowerUps")
	else:
		for power_up_id in regression_ids:
			game_controller.grant_power_up(power_up_id)
		await get_tree().create_timer(0.2).timeout
		_assert_rating_count("G", 3, "mixed-rating grant")
		_assert_rating_count("PG", 2, "mixed-rating grant")
		if synergy_manager.get_total_matching_bonus() != 0:
			_fail_test("3x G and 2x PG incorrectly produced matching bonus %d" % synergy_manager.get_total_matching_bonus())
		elif _has_matching_set_bonus():
			_fail_test("3x G and 2x PG incorrectly registered a matching-set source")
		else:
			print("  ✓ 3x G and 2x PG produced no matching-set bonus")

	# Test 8: Bulk clear should fully reset synergy tracking
	print("\n[TEST 8] Bulk clear resets synergy counts and bonuses...")
	await _clear_power_ups_for_test()
	_assert_all_rating_counts_zero("bulk clear")
	if not synergy_manager.get_active_synergies().is_empty():
		_fail_test("Bulk clear left active synergies behind: %s" % str(synergy_manager.get_active_synergies()))
	elif _has_matching_set_bonus():
		_fail_test("Bulk clear left matching-set additive sources behind")
	else:
		print("  ✓ Bulk clear removed all synergy state")

	# Test 9: Repeating the same mixed grant after clear should stay clean
	print("\n[TEST 9] Mixed-rating grant stays clean after bulk clear...")
	if regression_ids.size() == 5:
		for power_up_id in regression_ids:
			game_controller.grant_power_up(power_up_id)
		await get_tree().create_timer(0.2).timeout
		if synergy_manager.get_total_matching_bonus() != 0 or _has_matching_set_bonus():
			_fail_test("Repeated 3x G / 2x PG grant still produced a matching-set bonus after clear")
		else:
			print("  ✓ Repeated mixed grant stayed free of matching-set bonuses")

	# Test 10: Replica runtime IDs should resolve to their base rating data
	print("\n[TEST 10] Replica rating lookup normalization...")
	await _clear_power_ups_for_test()
	var replica_base_id := "extra_dice"
	var replica_data: PowerUpData = power_up_manager.get_def(replica_base_id)
	if replica_data == null:
		_fail_test("Replica lookup test could not find PowerUpData for '%s'" % replica_base_id)
	else:
		game_controller.grant_replica_power_up(replica_base_id)
		await get_tree().create_timer(0.2).timeout
		_assert_rating_count(replica_data.rating, 1, "replica grant")
	
	# Final summary
	print("\n")
	print("╔══════════════════════════════════════════════════╗")
	print("║                TEST SUMMARY                      ║")
	print("╠══════════════════════════════════════════════════╣")
	print("║  Use Debug Panel (F12) -> Synergies tab to:      ║")
	print("║  • Grant 5 same-rated PowerUps for +50 bonus     ║")
	print("║  • Grant rainbow set for 5x multiplier           ║")
	print("║  • View current synergy status                   ║")
	print("╚══════════════════════════════════════════════════╝")
	print("")
	if _test_failures == 0:
		print("ALL SYNERGY TESTS PASSED")
	else:
		print("SYNERGY TESTS FAILED: %d" % _test_failures)
	
	# Final status
	synergy_manager.debug_print_status()
	_quit_if_requested()


func _build_mixed_rating_test_ids(by_rating: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var g_ids = by_rating.get("G", [])
	var pg_ids = by_rating.get("PG", [])
	if g_ids.size() < 3 or pg_ids.size() < 2:
		return ids
	for i in range(3):
		ids.append(g_ids[i])
	for i in range(2):
		ids.append(pg_ids[i])
	return ids


func _clear_power_ups_for_test() -> void:
	if not game_controller or not game_controller.has_method("_clear_all_power_ups"):
		return
	game_controller._clear_all_power_ups()
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout


func _has_matching_set_bonus() -> bool:
	if not score_modifier_manager or not score_modifier_manager.has_method("get_active_additive_sources"):
		return false
	for source_name in score_modifier_manager.get_active_additive_sources():
		if source_name.begins_with("synergy_") and source_name.ends_with("_sets"):
			return true
	return false


func _assert_all_rating_counts_zero(context: String) -> void:
	var counts = synergy_manager.get_rating_counts()
	var all_zero := true
	for rating in TEST_RATINGS:
		if counts.get(rating, 0) != 0:
			all_zero = false
			_fail_test("%s left %s count at %d" % [context, rating, counts.get(rating, 0)])
	if all_zero:
		print("  ✓ %s left all rating counts at 0" % context)


func _assert_rating_count(rating: String, expected: int, context: String) -> void:
	var counts = synergy_manager.get_rating_counts()
	var actual: int = counts.get(rating, 0)
	if actual != expected:
		_fail_test("%s expected %s count %d, got %d" % [context, rating, expected, actual])
	else:
		print("  ✓ %s count is %d during %s" % [rating, actual, context])


func _fail_test(message: String) -> void:
	_test_failures += 1
	print("  ❌ FAIL: %s" % message)


func _quit_if_requested() -> void:
	if OS.get_cmdline_user_args().has("--quit-after"):
		print("[SynergyTest] Quitting with %d failure(s)" % _test_failures)
		get_tree().quit(_test_failures)
