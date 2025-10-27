extends Control

func _ready():
	# Create several colored dice to test hover functionality
	var colors = [DiceColor.Type.GREEN, DiceColor.Type.RED, DiceColor.Type.PURPLE, DiceColor.Type.BLUE]
	var positions = [Vector2(200, 200), Vector2(300, 200), Vector2(400, 200), Vector2(500, 200)]
	
	for i in range(colors.size()):
		var dice = preload("res://Scenes/Dice/dice.tscn").instantiate()
		add_child(dice)
		dice.position = positions[i]
		dice.value = i + 2  # Values 2-5
		dice.force_color(colors[i])
		
		print("Created %s dice with value %d at position %s" % [DiceColor.get_color_name(colors[i]), dice.value, str(positions[i])])
	
	print("Hover over the colored dice to see their tooltips!")