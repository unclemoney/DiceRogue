extends Control

func _ready():
	var power_up_icon = $CenterContainer/PowerUpIcon
	print("PowerUpIcon data: ", power_up_icon.data)
	print("PowerUpIcon hover_label: ", power_up_icon.hover_label)
	print("PowerUpIcon label_bg: ", power_up_icon.label_bg)
	
	# Wait a frame to ensure everything is set up
	await get_tree().process_frame
	
	# Set some test text to verify the theme
	if power_up_icon.hover_label:
		power_up_icon.hover_label.text = "TEST THEME"
		power_up_icon.label_bg.visible = true
		print("Theme applied. Text color should be red, font should be VCR.")
		print("Label text: ", power_up_icon.hover_label.text)
		print("Label theme: ", power_up_icon.hover_label.theme)
		print("Label font color: ", power_up_icon.hover_label.get_theme_color("font_color"))
	else:
		print("Could not find hover_label!")