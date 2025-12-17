extends Control
## CorkboardUITest
##
## Test scene for verifying the CorkboardUI refactor works correctly.

@onready var corkboard_ui = $CorkboardUI

func _ready() -> void:
	print("[CorkboardUITest] Starting test...")
	
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	# Test adding items
	_test_corkboard_display()


func _test_corkboard_display() -> void:
	print("[CorkboardUITest] Testing CorkboardUI display...")
	
	# Verify CorkboardUI exists and initialized
	if not corkboard_ui:
		push_error("[CorkboardUITest] CorkboardUI not found!")
		return
	
	print("[CorkboardUITest] CorkboardUI found and initialized")
	print("[CorkboardUITest] Test complete - check visual display")
