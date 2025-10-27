extends TextureRect
class_name ModIcon

signal mod_sell_requested(mod_id: String)

@export var data: ModData
@export var tooltip_offset := Vector2(-50, -80)
@export var icon_size := Vector2(50, 60)  # Add size control (expanded for sell button)

@onready var tooltip: Label = $TooltipBg/Tooltip
@onready var tooltip_bg: PanelContainer = $TooltipBg
@onready var modicon: Sprite2D = $Sprite2D
@onready var sell_button: Button

var _sell_button_visible := false

func _ready() -> void:
	if not tooltip or not tooltip_bg or not modicon:
		push_error("[ModIcon] Required nodes not found")
		return
	
	# Create sell button and add it to scene root to bypass UI layer blocking
	sell_button = Button.new()
	sell_button.name = "SellButton_" + str(get_instance_id())
	sell_button.text = "SELL"
	sell_button.visible = false  # Hidden by default
	sell_button.z_index = 1000  # Very high z-index above all UI
	sell_button.size = Vector2(44, 20)
	sell_button.mouse_filter = Control.MOUSE_FILTER_STOP
	sell_button.clip_contents = false
	
	# Apply button styling directly
	_apply_action_button_style(sell_button)
	
	# Connect the signal with debugging
	if not sell_button.pressed.is_connected(_on_sell_button_pressed):
		sell_button.pressed.connect(_on_sell_button_pressed)
		print("[ModIcon] Sell button signal connected")
	
	# Add additional debugging for mouse events on the button
	sell_button.gui_input.connect(_on_sell_button_input)
	sell_button.mouse_entered.connect(_on_sell_button_mouse_entered)
	sell_button.mouse_exited.connect(_on_sell_button_mouse_exited)
	
	# Add to scene root instead of ModIcon to bypass UI layer blocking
	var scene_root = get_tree().current_scene
	scene_root.add_child(sell_button)
	print("[ModIcon] Sell button created and added to scene root:", scene_root.name)
	print("[ModIcon] Button mouse_filter:", sell_button.mouse_filter)
	print("[ModIcon] Button z_index:", sell_button.z_index)
		
	if data:
		# Set up the Sprite2D
		modicon.texture = data.icon
		modicon.scale = Vector2(32, 32) / data.icon.get_size()  # Keep icon at 32x32 
		modicon.position = Vector2(25, 45)  # Position in lower part of expanded area
		
		# Clear the TextureRect texture since we're using Sprite2D
		texture = null
		
		# Set up tooltip
		tooltip.text = data.display_name
		tooltip_bg.visible = false
		
		# Apply direct styling to tooltip
		_apply_hover_tooltip_style(tooltip_bg)
		_apply_hover_label_style(tooltip)
		
		# Set control size to match icon
		custom_minimum_size = icon_size
		size = icon_size
	else:
		push_error("[ModIcon] No ModData assigned")
		return
	
	# Set up mouse interactions - only connect if not already connected from scene  
	mouse_filter = Control.MOUSE_FILTER_PASS  # Allow clicks to pass through to children
	
	print("[ModIcon] ModIcon mouse_filter set to PASS")
	print("[ModIcon] ModIcon z_index:", z_index)
	
	print("[ModIcon] Setup complete for mod: ", data.id if data else "no data")

func _on_mouse_entered() -> void:
	if tooltip_bg and data:
		tooltip_bg.visible = true
		tooltip_bg.global_position = get_global_mouse_position() + tooltip_offset

func _on_mouse_exited() -> void:
	if tooltip_bg:
		tooltip_bg.visible = false

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("[ModIcon] Click detected on mod icon:", data.id if data else "no data")
		# Toggle sell button visibility
		_sell_button_visible = !_sell_button_visible
		if sell_button:
			sell_button.visible = _sell_button_visible
			print("[ModIcon] Sell button visibility set to:", _sell_button_visible)
			if _sell_button_visible:
				# Position button above the mod icon using global coordinates
				var my_global_rect = get_global_rect()
				sell_button.position = Vector2(my_global_rect.position.x + 3, my_global_rect.position.y - 10)
				print("[ModIcon] Button positioned at global:", sell_button.position)
				print("[ModIcon] ModIcon global rect:", my_global_rect)
				print("[ModIcon] Button global rect:", sell_button.get_global_rect())
				_debug_ui_layers_blocking_button()

func _debug_ui_layers_blocking_button() -> void:
	print("[ModIcon] ===== DEBUGGING UI LAYERS =====")
	var root = get_tree().current_scene
	_check_node_for_blocking(root, 0)
	print("[ModIcon] ===== END UI LAYER DEBUG =====")

func _check_node_for_blocking(node: Node, depth: int) -> void:
	var indent = "  ".repeat(depth)
	if node is Control:
		var ctrl = node as Control
		if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP and ctrl.visible:
			var global_rect = ctrl.get_global_rect()
			var button_rect = sell_button.get_global_rect()
			var overlaps = global_rect.intersects(button_rect)
			print(indent, "[BLOCKING?] ", ctrl.name, " z:", ctrl.z_index, " rect:", global_rect, " overlaps:", overlaps)
		elif ctrl.mouse_filter == Control.MOUSE_FILTER_PASS and ctrl.z_index > 5:
			print(indent, "[PASSTHROUGH] ", ctrl.name, " z:", ctrl.z_index)
	
	for child in node.get_children():
		_check_node_for_blocking(child, depth + 1)

func _on_sell_button_pressed() -> void:
	print("[ModIcon] ===== SELL BUTTON PRESSED =====")
	print("[ModIcon] Sell button pressed for mod:", data.id if data else "unknown")
	print("[ModIcon] Button exists:", sell_button != null)
	if sell_button:
		print("[ModIcon] Button visible:", sell_button.visible)
	else:
		print("[ModIcon] Button visible: no button")
	
	if data:
		print("[ModIcon] Emitting mod_sell_requested signal for:", data.id)
		emit_signal("mod_sell_requested", data.id)
	else:
		print("[ModIcon] No data available to sell")
	
	# Hide the sell button after selling
	_sell_button_visible = false
	if sell_button:
		sell_button.visible = false
		print("[ModIcon] Sell button hidden after sale")
	print("[ModIcon] ===== SELL BUTTON PRESS COMPLETE =====")

func _on_sell_button_input(event: InputEvent) -> void:
	print("[ModIcon] Sell button received input event:", event)
	if event is InputEventMouseButton:
		print("[ModIcon] Mouse button event - button:", event.button_index, "pressed:", event.pressed)

func _on_sell_button_mouse_entered() -> void:
	print("[ModIcon] Mouse ENTERED sell button")

func _on_sell_button_mouse_exited() -> void:
	print("[ModIcon] Mouse EXITED sell button")

func _exit_tree() -> void:
	# Clean up the sell button when ModIcon is removed
	if sell_button and is_instance_valid(sell_button):
		print("[ModIcon] Cleaning up sell button on exit")
		sell_button.queue_free()

## check_outside_click(event_position)
##
## Checks if a click occurred outside both the icon and sell button.
## Returns true if the sell button should be hidden.
func check_outside_click(event_position: Vector2) -> bool:
	if not _sell_button_visible:
		return false
	
	# Get global rectangles for both icon and button
	var icon_rect = get_global_rect()
	var button_rect = Rect2()
	
	if sell_button and sell_button.visible:
		button_rect = sell_button.get_global_rect()
	
	if not icon_rect.has_point(event_position) and not button_rect.has_point(event_position):
		# Click outside both icon and button, hide the sell button
		_sell_button_visible = false
		if sell_button:
			sell_button.visible = false
		return true
	
	return false

## _apply_action_button_style(button)
## Applies the action button styling directly to a button
func _apply_action_button_style(button: Button) -> void:
	# Load VCR font
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile
	if vcr_font:
		button.add_theme_font_override("font", vcr_font)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", Color(1, 0.98, 0.9, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 0.95, 1))
		button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		button.add_theme_constant_override("outline_size", 1)
	
	# Create style boxes for different states
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.95)
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = Color(1, 0.8, 0.2, 1)
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.content_margin_left = 8.0
	style_normal.content_margin_top = 6.0
	style_normal.content_margin_right = 8.0
	style_normal.content_margin_bottom = 6.0
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.18, 0.25, 0.98)
	style_hover.border_width_left = 3
	style_hover.border_width_top = 3
	style_hover.border_width_right = 3
	style_hover.border_width_bottom = 3
	style_hover.border_color = Color(1, 0.9, 0.3, 1)
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.content_margin_left = 8.0
	style_hover.content_margin_top = 6.0
	style_hover.content_margin_right = 8.0
	style_hover.content_margin_bottom = 6.0
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.25, 0.22, 0.3, 1)
	style_pressed.border_width_left = 3
	style_pressed.border_width_top = 3
	style_pressed.border_width_right = 3
	style_pressed.border_width_bottom = 3
	style_pressed.border_color = Color(1, 1, 0.4, 1)
	style_pressed.corner_radius_top_left = 4
	style_pressed.corner_radius_top_right = 4
	style_pressed.corner_radius_bottom_right = 4
	style_pressed.corner_radius_bottom_left = 4
	style_pressed.content_margin_left = 8.0
	style_pressed.content_margin_top = 6.0
	style_pressed.content_margin_right = 8.0
	style_pressed.content_margin_bottom = 6.0
	
	# Apply styles to button
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	print("[ModIcon] Direct button styling applied")

## Helper functions for consistent styling
func _apply_hover_tooltip_style(panel: PanelContainer) -> void:
	print("[ModIcon] Applying direct hover tooltip style")
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.95)  # Dark background
	style_box.border_color = Color(1, 0.8, 0.2, 1)   # Golden border
	style_box.set_border_width_all(4)                # 4px border
	style_box.content_margin_left = 16
	style_box.content_margin_right = 16
	style_box.content_margin_top = 16
	style_box.content_margin_bottom = 16
	style_box.shadow_color = Color(0, 0, 0, 0.5)
	style_box.shadow_size = 2
	panel.add_theme_stylebox_override("panel", style_box)

func _apply_hover_label_style(label: Label) -> void:
	print("[ModIcon] Applying direct hover label style")
	# Load and apply VCR font
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font:
		label.add_theme_font_override("font", vcr_font)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))  # White text
