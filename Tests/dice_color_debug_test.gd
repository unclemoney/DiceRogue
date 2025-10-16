extends Control
class_name DiceColorDebugTest

## Simple debug test to verify dice color system end-to-end

func _ready():
	print("\n=== DICE COLOR DEBUG TEST ===")
	test_get_all_dice_method()
	test_dice_color_description()
	print("=== DEBUG TEST COMPLETE ===")

func test_get_all_dice_method():
	print("\n--- Testing get_all_dice() Method ---")
	
	# Create a simple DiceHand for testing
	var dice_hand = DiceHand.new()
	add_child(dice_hand)
	
	# Test that get_all_dice() exists and returns correct type
	if dice_hand.has_method("get_all_dice"):
		var all_dice = dice_hand.get_all_dice()
		print("[DebugTest] get_all_dice() method exists and returns:", typeof(all_dice))
		print("[DebugTest] Current dice count:", all_dice.size())
	else:
		print("[DebugTest] ERROR: get_all_dice() method not found!")
	
	dice_hand.queue_free()

func test_dice_color_description():
	print("\n--- Testing Dice Color Description ---")
	
	# Test DiceColorManager exists and has get_current_effects_description method
	if DiceColorManager:
		print("[DebugTest] DiceColorManager found")
		if DiceColorManager.has_method("get_current_effects_description"):
			var empty_description = DiceColorManager.get_current_effects_description([])
			print("[DebugTest] Empty dice description:", empty_description)
		else:
			print("[DebugTest] ERROR: get_current_effects_description method not found!")
	else:
		print("[DebugTest] ERROR: DiceColorManager not found!")