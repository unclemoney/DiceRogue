extends Node
class_name BonusMoneyTest

## BonusMoneyTest
##
## Test script for BonusMoneyPowerUp functionality.
## Verifies that the PowerUp correctly grants money for bonuses achieved.

const BonusMoneyPowerUpScript = preload("res://Scripts/PowerUps/bonus_money_power_up.gd")

@onready var game_controller: GameController
@onready var scorecard: Scorecard
@onready var bonus_money_power_up: PowerUp

func _ready() -> void:
	print("\n=== BonusMoneyPowerUp Test Starting ===")
	_setup_test_environment()
	await get_tree().create_timer(1.0).timeout
	_run_all_tests()

func _setup_test_environment() -> void:
	print("\n--- Setting up test environment ---")
	
	# Create required components
	game_controller = GameController.new()
	scorecard = Scorecard.new()
	
	add_child(game_controller)
	add_child(scorecard)
	
	# Initialize PlayerEconomy
	if PlayerEconomy:
		PlayerEconomy.money = 100  # Start with $100
		print("[BonusMoneyTest] Player money set to $100")

func _run_all_tests() -> void:
	print("\n=== Running All Tests ===")
	
	_test_power_up_creation()
	_test_upper_bonus_money_grant()
	_test_yahtzee_bonus_money_grant()
	_test_multiple_bonuses()
	_test_description_updates()
	_test_cleanup()
	
	print("\n=== All Tests Completed ===")

func _test_power_up_creation() -> void:
	print("\n--- Test: PowerUp Creation ---")
	
	# Create the PowerUp instance
	var bonus_money_scene = preload("res://Scenes/PowerUp/BonusMoneyPowerUp.tscn")
	bonus_money_power_up = bonus_money_scene.instantiate() as PowerUp
	
	assert(bonus_money_power_up != null, "BonusMoneyPowerUp should be created successfully")
	assert(bonus_money_power_up.id == "bonus_money", "PowerUp should have correct id")
	assert(bonus_money_power_up.get("total_bonuses_earned") == 0, "Initial bonus count should be 0")
	assert(bonus_money_power_up.get("money_per_bonus") == 50, "Money per bonus should be $50")
	
	add_child(bonus_money_power_up)
	print("[BonusMoneyTest] ✓ PowerUp creation test passed")

func _test_upper_bonus_money_grant() -> void:
	print("\n--- Test: Upper Bonus Money Grant ---")
	
	var initial_money = PlayerEconomy.money
	print("[BonusMoneyTest] Initial money: $", initial_money)
	
	# Apply PowerUp to scorecard
	bonus_money_power_up.apply(scorecard)
	
	# Trigger upper bonus
	scorecard.emit_signal("upper_bonus_achieved", 35)
	
	# Check results
	var expected_money = initial_money + 50
	var actual_money = PlayerEconomy.money
	
	assert(actual_money == expected_money, "Money should increase by $50. Expected: $" + str(expected_money) + ", Got: $" + str(actual_money))
	assert(bonus_money_power_up.get("total_bonuses_earned") == 1, "Bonus count should be 1")
	
	print("[BonusMoneyTest] ✓ Upper bonus money grant test passed")

func _test_yahtzee_bonus_money_grant() -> void:
	print("\n--- Test: Yahtzee Bonus Money Grant ---")
	
	var initial_money = PlayerEconomy.money
	print("[BonusMoneyTest] Money before yahtzee bonus: $", initial_money)
	
	# Trigger yahtzee bonus
	scorecard.emit_signal("yahtzee_bonus_achieved", 100)
	
	# Check results
	var expected_money = initial_money + 50
	var actual_money = PlayerEconomy.money
	
	assert(actual_money == expected_money, "Money should increase by $50. Expected: $" + str(expected_money) + ", Got: $" + str(actual_money))
	assert(bonus_money_power_up.get("total_bonuses_earned") == 2, "Bonus count should be 2 (1 upper + 1 yahtzee)")
	
	print("[BonusMoneyTest] ✓ Yahtzee bonus money grant test passed")

func _test_multiple_bonuses() -> void:
	print("\n--- Test: Multiple Bonuses ---")
	
	var initial_money = PlayerEconomy.money
	var initial_bonuses = bonus_money_power_up.get("total_bonuses_earned")
	
	# Trigger multiple yahtzee bonuses
	scorecard.emit_signal("yahtzee_bonus_achieved", 100)
	scorecard.emit_signal("yahtzee_bonus_achieved", 100)
	scorecard.emit_signal("yahtzee_bonus_achieved", 100)
	
	# Check results
	var expected_money = initial_money + (3 * 50)  # 3 bonuses * $50 each
	var actual_money = PlayerEconomy.money
	var expected_bonuses = initial_bonuses + 3
	
	assert(actual_money == expected_money, "Money should increase by $150. Expected: $" + str(expected_money) + ", Got: $" + str(actual_money))
	assert(bonus_money_power_up.get("total_bonuses_earned") == expected_bonuses, "Bonus count should be " + str(expected_bonuses))
	
	print("[BonusMoneyTest] ✓ Multiple bonuses test passed")

func _test_description_updates() -> void:
	print("\n--- Test: Description Updates ---")
	
	var description = bonus_money_power_up.call("get_current_description")
	var bonuses = bonus_money_power_up.get("total_bonuses_earned")
	var total_money = bonuses * 50
	
	assert(description.contains("+$50 for each bonus achieved"), "Description should contain base text")
	if bonuses > 0:
		assert(description.contains("Bonuses earned: " + str(bonuses)), "Description should show bonus count")
		assert(description.contains("$" + str(total_money) + " total"), "Description should show total money earned")
	
	print("[BonusMoneyTest] ✓ Description updates test passed")

func _test_cleanup() -> void:
	print("\n--- Test: Cleanup ---")
	
	# Test remove functionality
	bonus_money_power_up.remove(scorecard)
	
	# Verify signals are disconnected by trying to trigger them
	var money_before = PlayerEconomy.money
	scorecard.emit_signal("upper_bonus_achieved", 35)
	scorecard.emit_signal("yahtzee_bonus_achieved", 100)
	var money_after = PlayerEconomy.money
	
	assert(money_before == money_after, "Money should not change after cleanup. Before: $" + str(money_before) + ", After: $" + str(money_after))
	assert(bonus_money_power_up.get("scorecard_ref") == null, "Scorecard reference should be null after removal")
	
	print("[BonusMoneyTest] ✓ Cleanup test passed")

func _on_test_completed() -> void:
	print("\n[BonusMoneyTest] All tests completed successfully!")
	print("[BonusMoneyTest] Final player money: $", PlayerEconomy.money)
	print("[BonusMoneyTest] Total bonuses earned: ", bonus_money_power_up.get("total_bonuses_earned") if bonus_money_power_up else "N/A")