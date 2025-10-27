extends Control

func _ready():
	# Create a PowerUpIcon from scratch (simulating the programmatic creation)
	var power_up_icon = PowerUpIcon.new()
	add_child(power_up_icon)
	
	# Position it in the center
	power_up_icon.position = Vector2(400, 300)
	power_up_icon.size = Vector2(80, 120)
	
	# Load some test data
	var test_data = load("res://Scripts/PowerUps/ExtraDice.tres")
	if test_data:
		power_up_icon.set_data(test_data)
	
	# Test the hover label immediately
	await get_tree().process_frame
	
	print("Created PowerUpIcon programmatically")
	print("LabelBg theme: ", power_up_icon.label_bg.theme if power_up_icon.label_bg else "null")
	print("HoverLabel parent theme: ", power_up_icon.hover_label.get_parent().theme if power_up_icon.hover_label else "null")
	
	# Show the label for testing
	if power_up_icon.hover_label and power_up_icon.label_bg:
		power_up_icon.hover_label.text = "PROGRAMMATIC TEST"
		power_up_icon.label_bg.visible = true