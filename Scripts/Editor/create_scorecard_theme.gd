@tool
extends EditorScript

# This script creates a custom theme resource for the ScoreCard UI
# Run this script in the editor to generate the theme file

func _run():
	print("Creating ScoreCard Theme...")
	
	# Create a new theme
	var theme = Theme.new()
	
	# Load the font using direct path (avoids UID issues)
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile
	if not vcr_font:
		push_error("Could not load VCR font")
		return
	print("✓ VCR font loaded successfully")
	
	# Load button textures using direct paths
	var button_normal = load("res://Resources/Art/UI/button_normal.png") as Texture2D
	var button_hover = load("res://Resources/Art/UI/button_hover.png") as Texture2D
	var button_pressed = load("res://Resources/Art/UI/button_pressed.png") as Texture2D
	var panel_border = load("res://Resources/Art/UI/panel_border.png") as Texture2D
	
	if not button_normal:
		push_error("Could not load button_normal.png")
		return
	if not button_hover:
		push_error("Could not load button_hover.png")
		return
	if not button_pressed:
		push_error("Could not load button_pressed.png")
		return
	if not panel_border:
		push_error("Could not load panel_border.png")
		return
	
	print("✓ All textures loaded successfully")
	
	# Configure Button styles
	print("⚙️ Creating button StyleBox configurations...")
	
	var button_normal_style = StyleBoxTexture.new()
	print("🔧 StyleBoxTexture created")
	button_normal_style.texture = button_normal
	print("🔧 Texture assigned")
	
	# Use Godot 4.4 correct property names
	button_normal_style.texture_margin_left = 4.0
	button_normal_style.texture_margin_right = 4.0
	button_normal_style.texture_margin_top = 4.0
	button_normal_style.texture_margin_bottom = 4.0
	button_normal_style.content_margin_left = 8.0
	button_normal_style.content_margin_right = 8.0
	button_normal_style.content_margin_top = 8.0
	button_normal_style.content_margin_bottom = 8.0
	print("✓ Button normal style created")
	
	var button_hover_style = StyleBoxTexture.new()
	button_hover_style.texture = button_hover
	button_hover_style.texture_margin_left = 4.0
	button_hover_style.texture_margin_right = 4.0
	button_hover_style.texture_margin_top = 4.0
	button_hover_style.texture_margin_bottom = 4.0
	button_hover_style.content_margin_left = 8.0
	button_hover_style.content_margin_right = 8.0
	button_hover_style.content_margin_top = 8.0
	button_hover_style.content_margin_bottom = 8.0
	print("✓ Button hover style created")
	
	var button_pressed_style = StyleBoxTexture.new()
	button_pressed_style.texture = button_pressed
	button_pressed_style.texture_margin_left = 4.0
	button_pressed_style.texture_margin_right = 4.0
	button_pressed_style.texture_margin_top = 4.0
	button_pressed_style.texture_margin_bottom = 4.0
	button_pressed_style.content_margin_left = 8.0
	button_pressed_style.content_margin_right = 8.0
	button_pressed_style.content_margin_top = 8.0
	button_pressed_style.content_margin_bottom = 8.0
	print("✓ Button pressed style created")
	
	# Configure Panel style
	print("⚙️ Creating panel StyleBox configuration...")
	var panel_style = StyleBoxTexture.new()
	panel_style.texture = panel_border
	panel_style.texture_margin_left = 8.0
	panel_style.texture_margin_right = 8.0
	panel_style.texture_margin_top = 8.0
	panel_style.texture_margin_bottom = 8.0
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	print("✓ Panel style created")
	
	print("✓ StyleBox configurations created")
	
	# Apply Button theme
	print("🎨 Applying Button theme properties...")
	theme.set_stylebox("normal", "Button", button_normal_style)
	theme.set_stylebox("hover", "Button", button_hover_style)
	theme.set_stylebox("pressed", "Button", button_pressed_style)
	theme.set_font("font", "Button", vcr_font)
	theme.set_font_size("font_size", "Button", 12)
	theme.set_color("font_color", "Button", Color.BLACK)
	theme.set_color("font_hover_color", "Button", Color.BLACK)
	theme.set_color("font_pressed_color", "Button", Color.BLACK)
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5, 1))
	print("✓ Button theme applied")
	
	# Apply Label theme
	print("🎨 Applying Label theme properties...")
	theme.set_font("font", "Label", vcr_font)
	theme.set_font_size("font_size", "Label", 12)
	theme.set_color("font_color", "Label", Color.BLACK)
	print("✓ Label theme applied")
	
	# Apply RichTextLabel theme
	print("🎨 Applying RichTextLabel theme properties...")
	theme.set_font("normal_font", "RichTextLabel", vcr_font)
	theme.set_font_size("normal_font_size", "RichTextLabel", 14)
	theme.set_color("default_color", "RichTextLabel", Color.BLACK)
	print("✓ RichTextLabel theme applied")
	
	# Apply Panel theme
	print("🎨 Applying Panel theme properties...")
	theme.set_stylebox("panel", "Panel", panel_style)
	print("✓ Panel theme applied")
	
	print("✓ Theme properties applied")
	
	# Save the theme
	print("💾 Attempting to save theme...")
	var save_path = "res://Resources/UI/scorecard_theme.tres"
	print("📁 Save path: ", save_path)
	
	var result = ResourceSaver.save(theme, save_path)
	print("📊 Save result code: ", result)
	
	if result == OK:
		print("✅ Theme saved successfully to: ", save_path)
		# Verify the file was actually created
		if FileAccess.file_exists(save_path):
			print("✅ File verification: Theme file exists on disk")
		else:
			push_error("❌ File verification failed: Theme file was not created")
	else:
		push_error("❌ Failed to save theme. Error code: ", result)
		# Additional error details
		match result:
			ERR_FILE_CANT_WRITE:
				push_error("❌ Cannot write to file - check permissions")
			ERR_FILE_BAD_PATH:
				push_error("❌ Bad file path")
			ERR_INVALID_PARAMETER:
				push_error("❌ Invalid parameter")
			_:
				push_error("❌ Unknown error code: ", result)
