extends Node
class_name DebugTestScene

## DebugTestScene
##
## Simple test scene to validate debug panel lock/unlock functionality with shop refresh

var progress_manager: Node

func _ready() -> void:
	print("=== Debug Test Scene Ready ===")
	print("Press F12 to open debug panel")
	print("Use 'Lock All Items' and 'Unlock All Items' to test shop refresh")
	print("Press 'Print All Item Status' to see current state")
	print("================================")
	
	# Connect to ProgressManager signals to verify they're working
	progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		if progress_manager.has_signal("item_unlocked"):
			progress_manager.item_unlocked.connect(_on_item_unlocked)
			print("[DEBUG] Connected to item_unlocked signal")
		if progress_manager.has_signal("item_locked"):
			progress_manager.item_locked.connect(_on_item_locked)
			print("[DEBUG] Connected to item_locked signal")
		if progress_manager.has_signal("progress_saved"):
			progress_manager.progress_saved.connect(_on_progress_saved)
			print("[DEBUG] Connected to progress_saved signal")
	
	# Auto-test the fixes after a short delay
	await get_tree().create_timer(1.0).timeout
	_run_auto_test()

func _run_auto_test() -> void:
	print("\n=== RUNNING AUTO-TEST ===")
	
	# Test 1: Check default unlock status
	print("Test 1: Checking default unlock status...")
	var test_items = ["extra_dice", "wild_dots", "randomizer", "step_by_step", "chance520"]
	for item_id in test_items:
		var is_unlocked = progress_manager.is_item_unlocked(item_id)
		print("  %s: %s" % [item_id, "UNLOCKED" if is_unlocked else "LOCKED"])
	
	# Test 2: Try unlocking multiple items to test notifications
	print("\nTest 2: Unlocking multiple items to test notifications...")
	progress_manager.debug_unlock_item("step_by_step")
	await get_tree().create_timer(0.5).timeout  # Small delay
	progress_manager.debug_unlock_item("extra_dice")
	await get_tree().create_timer(0.5).timeout  # Small delay
	progress_manager.debug_unlock_item("foursome")
	
	# Test 3: Check save file generation
	print("\nTest 3: Testing save functionality...")
	progress_manager.save_progress()
	print("  Progress saved - check progress.save file")
	
	print("\n=== AUTO-TEST COMPLETE ===")
	print("Watch for unlock notifications appearing on screen!")
	print("If step_by_step, extra_dice, and foursome show UNLOCKED, the fix worked!")

func _on_item_unlocked(item_id: String, item_type: String) -> void:
	print("[DEBUG] Signal received - Item unlocked: %s (%s)" % [item_id, item_type])

func _on_item_locked(item_id: String, item_type: String) -> void:
	print("[DEBUG] Signal received - Item locked: %s (%s)" % [item_id, item_type])

func _on_progress_saved() -> void:
	print("[DEBUG] Signal received - Progress saved")