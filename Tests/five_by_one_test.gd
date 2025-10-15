extends Control

@onready var dice_scene = preload("res://Scenes/Dice/dice.tscn")
@onready var mod_scene = preload("res://Scenes/Mods/FiveByOneMod.tscn")

var test_dice: Dice
var test_mod: Mod

func _ready() -> void:
	print("[FiveByOneTest] Starting Five By One Mod test")
	setup_test()

func setup_test() -> void:
	# Create a test dice
	test_dice = dice_scene.instantiate()
	add_child(test_dice)
	test_dice.position = Vector2(200, 200)
	
	# Create the mod
	test_mod = mod_scene.instantiate()
	add_child(test_mod)
	
	# Apply the mod to the dice
	test_mod.apply(test_dice)
	
	print("[FiveByOneTest] Mod applied to dice")
	
	# Wait a moment then start rolling tests
	await get_tree().create_timer(1.0).timeout
	test_rolls()

func test_rolls() -> void:
	print("[FiveByOneTest] Starting roll tests...")
	
	# Test multiple rolls to verify the mod behavior
	for i in range(5):
		print("\n--- Roll %d ---" % (i + 1))
		print("Roll count before roll: %d" % test_mod.get_roll_count())
		
		# Roll the dice
		test_dice.roll()
		
		# Wait for roll to complete
		await test_dice.rolled
		
		print("Dice value after roll: %d" % test_dice.value)
		print("Roll count after roll: %d" % test_mod.get_roll_count())
		
		# Check if score modifier is correctly set
		if ScoreModifierManager.has_additive("five_by_one"):
			var additive = ScoreModifierManager.get_additive("five_by_one")
			print("Score additive: +%d" % additive)
		else:
			print("No score additive found")
		
		# Wait before next roll
		await get_tree().create_timer(1.0).timeout
	
	print("\n[FiveByOneTest] Testing mod removal...")
	test_mod.remove()
	
	print("Roll count after removal: %d" % test_mod.get_roll_count())
	
	if ScoreModifierManager.has_additive("five_by_one"):
		print("ERROR: Score additive still exists after removal!")
	else:
		print("SUCCESS: Score additive properly removed")
	
	print("\n[FiveByOneTest] Test completed!")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		print("[FiveByOneTest] Restarting test...")
		test_rolls()