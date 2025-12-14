extends Node

## SynergyTest
##
## Test scene to validate SynergyManager functionality.
## Tests rating tracking, matching set bonuses (+50 per 5), and rainbow multiplier (5x).
## 
## Run with: & "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --path "c:\Users\danie\Documents\dicerogue\DiceRogue" Tests/SynergyTest.tscn

var synergy_manager
var power_up_manager: PowerUpManager
var game_controller: GameController
var score_modifier_manager

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
		print("\n[ABORT] Cannot run tests without required managers")
		return
	
	# Test 2: Check initial state
	print("\n[TEST 2] Initial state check...")
	var initial_counts = synergy_manager.get_rating_counts()
	var all_zero := true
	for rating in ["G", "PG", "PG-13", "R", "NC-17"]:
		if initial_counts.get(rating, 0) != 0:
			all_zero = false
			break
	
	if all_zero:
		print("  ✓ All rating counts start at 0")
	else:
		print("  ⚠ Warning: Rating counts not all zero: %s" % str(initial_counts))
	
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
	for rating in ["G", "PG", "PG-13", "R", "NC-17"]:
		by_rating[rating] = []
	
	for pu_id in available:
		var data = power_up_manager.get_def(pu_id)
		if data:
			var rating = data.rating
			if by_rating.has(rating):
				by_rating[rating].append(pu_id)
	
	for rating in ["G", "PG", "PG-13", "R", "NC-17"]:
		var count = by_rating[rating].size()
		print("  %s: %d PowerUps %s" % [rating, count, by_rating[rating]])
	
	# Test 6: Check ScoreModifierManager integration
	print("\n[TEST 6] ScoreModifierManager integration...")
	var total_additive = score_modifier_manager.get_total_additive()
	var total_mult = score_modifier_manager.get_total_multiplier()
	print("  Current additive: %d" % total_additive)
	print("  Current multiplier: %.2fx" % total_mult)
	
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
	
	# Final status
	synergy_manager.debug_print_status()
