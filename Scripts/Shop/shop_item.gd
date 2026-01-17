extends PanelContainer
class_name ShopItem

signal purchased(item_id: String, item_type: String)

@onready var icon: TextureRect = $MarginContainer/VBoxContainer/Icon
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var price_label: Label = $MarginContainer/VBoxContainer/PriceLabel
@onready var buy_button: Button = $MarginContainer/VBoxContainer/BuyButton
@onready var shop_label: Label = $MarginContainer/ShopLabel

# Dice texture and shader for colored dice shop cards
const DICE_TEXTURE_PATH := "res://Resources/Art/Dice/dieWhite1.png"
const DICE_SHADER_PATH := "res://Scripts/Shaders/dice_combined_effects.gdshader"

var item_id: String
var item_type: String
var price: int
var item_data: Resource  # Store the data resource for tooltip access
var color_type: DiceColor.Type = DiceColor.Type.NONE  # Track color type for colored dice

# Hover tooltip variables
var hover_tooltip: PanelContainer
var hover_tooltip_label: Label
var is_hovered: bool = false
var is_card_hovered: bool = false
var is_button_hovered: bool = false
var _time: float = 0.0
const RAINBOW_SPEED := 0.5
const RAINBOW_COLORS := [
	Color(1, 0, 0),    # Red
	Color(1, 0.5, 0),  # Orange
	Color(1, 1, 0),    # Yellow
	Color(0, 1, 0),    # Green
	Color(0, 0, 1),    # Blue
	Color(0.5, 0, 1),  # Purple
]

func _ready() -> void:
	print("[ShopItem] Initializing:", name)
	
	if not icon or not name_label or not price_label or not buy_button:
		push_error("[ShopItem] Required nodes not found!")
		for child in get_children():
			print("[ShopItem] Found child:", child.name)
		return
	# Explicitly connect the button signal
	if buy_button:
		buy_button.pressed.connect(_on_buy_button_pressed)
		print("[ShopItem] Connected buy button signal")

func _process(delta: float) -> void:
	if not shop_label:
		return
	
	_time += delta * RAINBOW_SPEED
	
	# Calculate two color indices for interpolation
	var color_count: int = RAINBOW_COLORS.size()
	var index1: int = int(_time) % color_count
	var index2: int = (index1 + 1) % color_count
	var t: float = fmod(_time, 1.0)  # Interpolation factor
	
	# Interpolate between colors (for potential future rainbow effects)
	var _current_color: Color = RAINBOW_COLORS[index1].lerp(RAINBOW_COLORS[index2], t)
	
	# Rainbow effect could be applied to shop_label if needed in the future
	# Check if this is a power-up item and if there's a maximum reached
	if item_type == "power_up":
		# Find the GameController to check ownership directly
		var game_controller = get_tree().get_first_node_in_group("game_controller")
		if game_controller:
			# Check if we already own this power-up
			if game_controller.active_power_ups.has(item_id):
				buy_button.disabled = true
				buy_button.text = "OWNED"
				return
			
		# Check if maximum reached via PowerUpUI
		var power_up_ui = _find_power_up_ui()
		if power_up_ui and power_up_ui.has_max_power_ups():
			buy_button.disabled = true
			buy_button.text = "MAX REACHED"
		else:
			# Re-enable the button if previously disabled
			if buy_button.disabled and (buy_button.text == "MAX REACHED" or buy_button.text == "OWNED"):
				buy_button.disabled = false
				buy_button.text = "BUY"
	
	# Check if this is a consumable item and if there's a maximum reached
	elif item_type == "consumable":
		# Find the ConsumableUI node to check if maximum reached
		var consumable_ui = _find_consumable_ui()
		if consumable_ui and consumable_ui.has_max_consumables():
			# Disable the buy button and show "MAX REACHED" text
			buy_button.disabled = true
			buy_button.text = "MAX REACHED"
		else:
			# Re-enable the button if previously disabled
			if buy_button.disabled and buy_button.text == "MAX REACHED":
				buy_button.disabled = false
				buy_button.text = "BUY"
	
	# Check if this is a mod item and if there's a mod limit reached
	elif item_type == "mod":
		# Find the GameController to check mod vs dice count limit
		var game_controller = get_tree().get_first_node_in_group("game_controller")
		if game_controller and _has_reached_mod_limit(game_controller):
			# Disable the buy button and show "LIMIT REACHED" text
			buy_button.disabled = true
			buy_button.text = "LIMIT REACHED"
		else:
			# Re-enable the button if previously disabled
			if buy_button.disabled and buy_button.text == "LIMIT REACHED":
				buy_button.disabled = false
				buy_button.text = "BUY"
	
	# Check if this is a colored dice item - update price and status dynamically
	elif item_type == "colored_dice":
		_update_colored_dice_display()

func setup(data: Resource, type: String) -> void:
	print("[ShopItem] Setting up item:", data.id)
	item_id = data.id
	item_type = type
	price = data.price
	item_data = data  # Store the data for tooltip access
	
	if not icon or not name_label or not price_label:
		push_error("[ShopItem] One or more required nodes not found!")
		return
	
	# Explicitly set icon size and expansion
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Handle colored dice icons specially - use dice texture with color shader
	if type == "colored_dice" and data is ColoredDiceData:
		color_type = data.color_type
		_setup_colored_dice_icon(data.color_type)
	else:
		icon.texture = data.icon
	
	name_label.text = data.display_name
	price_label.text = "$%d" % price
	
	# Apply shop item styling with border
	_apply_shop_item_styling()
	
	# Apply VCR font to labels and button
	_apply_shop_item_fonts()
	
	_setup_hover_tooltip()
	
	_update_button_state()
	if not PlayerEconomy.is_connected("money_changed", _update_button_state):
		PlayerEconomy.money_changed.connect(_update_button_state)
	#print("[ShopItem] Connected to PlayerEconomy.money_changed, Instance ID:", PlayerEconomy.get_instance_id())
	#print("[ShopItem] Setup complete for:", data.id)

func _update_button_state(_new_amount := 0, _change := 0) -> void:
	#print("[ShopItem] _update_button_state called")
	#print("[ShopItem] Updating button state for", item_id, "- Player money:", PlayerEconomy.money, ", Price:", price)
	if buy_button:
		buy_button.disabled = not PlayerEconomy.can_afford(price)
		#print("[ShopItem] Buy button state updated - disabled:", buy_button.disabled)

func _on_buy_button_pressed() -> void:
	#print("[ShopItem] Buy button pressed for", item_id, "type:", item_type)
	
	# Pre-purchase validation for mods - check if mod limit is reached
	if item_type == "mod":
		var game_controller = get_tree().get_first_node_in_group("game_controller")
		if game_controller and _has_reached_mod_limit(game_controller):
			#print("[ShopItem] Mod purchase blocked - limit reached (all dice have mods)")
			buy_button.disabled = true
			buy_button.text = "LIMIT REACHED"
			return
	
	if PlayerEconomy.can_afford(price):
		if PlayerEconomy.remove_money(price, item_type):
			#print("[ShopItem] Successfully purchased", item_id, "for", price)
			#print("[ShopItem] Emitting purchase signal for:", item_id, "type:", item_type)
			emit_signal("purchased", item_id, item_type)
			#print("[ShopItem] Purchase signal emitted")
			_update_button_state() # <-- Add this line to update button after purchase
		else:
			print("[ShopItem] Failed to remove money for purchase")
	else:
		print("[ShopItem] Cannot afford", item_id, "(cost:", price, ", money:", PlayerEconomy.money, ")")
	_update_button_state()


# Helper function to find the PowerUpUI node
func _find_power_up_ui() -> PowerUpUI:
	# Try to find it in the scene tree
	var candidates = get_tree().get_nodes_in_group("power_up_ui")
	if candidates.size() > 0:
		return candidates[0]
		
	# Or navigate up to GameController and then down
	var root = get_tree().get_root()
	var game_controller = root.find_child("GameController", true, false)
	if game_controller:
		return game_controller.get_node_or_null("PowerUpUI") as PowerUpUI
	
	return null

# Helper function to find the ConsumableUI node (or CorkboardUI which also manages consumables)
func _find_consumable_ui():
	# First try to find CorkboardUI (unified UI that manages consumables)
	var corkboard_candidates = get_tree().get_nodes_in_group("corkboard_ui")
	if corkboard_candidates.size() > 0:
		return corkboard_candidates[0]
	
	# Then try to find legacy ConsumableUI
	var candidates = get_tree().get_nodes_in_group("consumable_ui")
	if candidates.size() > 0:
		return candidates[0]
		
	# Or navigate up to GameController and then down
	var root = get_tree().get_root()
	var game_controller = root.find_child("GameController", true, false)
	if game_controller:
		# Try CorkboardUI first
		var corkboard = game_controller.get_node_or_null("CorkboardUI")
		if corkboard:
			return corkboard
		return game_controller.get_node_or_null("ConsumableUI") as ConsumableUI
	
	return null

# Helper function to check if mod limit has been reached
func _has_reached_mod_limit(game_controller: GameController) -> bool:
	if not game_controller:
		return false
	
	var current_mod_count = game_controller._get_total_active_mod_count()
	# Use expected dice count instead of current dice list size to handle pre-spawn scenario
	var expected_dice_count = game_controller._get_expected_dice_count()
	
	#print("[ShopItem] Mod limit check - Current mods:", current_mod_count, "Expected dice count:", expected_dice_count)
	return current_mod_count >= expected_dice_count

## _setup_hover_tooltip()
## Creates and configures the hover tooltip for shop items
func _setup_hover_tooltip() -> void:
	if not item_data:
		return
		
	# Create hover tooltip container
	hover_tooltip = PanelContainer.new()
	hover_tooltip.visible = false
	hover_tooltip.z_index = 4000  # High z_index within valid range
	
	# Create custom StyleBoxFlat for the tooltip
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.06, 0.12, 0.98)
	style_box.border_width_left = 4
	style_box.border_width_top = 4
	style_box.border_width_right = 4
	style_box.border_width_bottom = 4
	style_box.border_color = Color(1, 0.8, 0.2, 1)
	style_box.corner_radius_top_left = 6
	style_box.corner_radius_top_right = 6
	style_box.corner_radius_bottom_right = 6
	style_box.corner_radius_bottom_left = 6
	style_box.content_margin_left = 16.0
	style_box.content_margin_top = 12.0
	style_box.content_margin_right = 16.0
	style_box.content_margin_bottom = 12.0
	style_box.shadow_color = Color(0, 0, 0, 0.5)
	style_box.shadow_size = 2
	
	# Apply the style directly
	hover_tooltip.add_theme_stylebox_override("panel", style_box)
	
	# Create tooltip label
	hover_tooltip_label = Label.new()
	hover_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_tooltip_label.custom_minimum_size = Vector2(200, 0)
	hover_tooltip_label.text = item_data.description
	
	# Apply font styling to label
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile
	if vcr_font:
		hover_tooltip_label.add_theme_font_override("font", vcr_font)
		hover_tooltip_label.add_theme_font_size_override("font_size", 14)
		hover_tooltip_label.add_theme_color_override("font_color", Color(1, 0.98, 0.9, 1))
		hover_tooltip_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		hover_tooltip_label.add_theme_constant_override("outline_size", 1)
	
	hover_tooltip.add_child(hover_tooltip_label)
	
	# Add tooltip to scene root to avoid grid constraints (deferred to avoid busy parent)
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child.call_deferred(hover_tooltip)
		print("[ShopItem] Added tooltip to scene root (deferred)")
	else:
		get_parent().add_child.call_deferred(hover_tooltip)
		print("[ShopItem] Added tooltip to direct parent (deferred)")
	
	# Connect hover signals for the card itself
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Connect hover signals for the buy button to maintain tooltip visibility
	if buy_button:
		buy_button.mouse_entered.connect(_on_button_mouse_entered)
		buy_button.mouse_exited.connect(_on_button_mouse_exited)
	
	print("[ShopItem] Tooltip created with direct styling")

## _on_mouse_entered()
## Shows the hover tooltip when mouse enters the shop item card
func _on_mouse_entered() -> void:
	if not hover_tooltip or not item_data:
		return
	
	# Update tooltip text - use enhanced version for colored dice
	if hover_tooltip_label:
		if item_type == "colored_dice":
			hover_tooltip_label.text = _get_colored_dice_tooltip_text()
		else:
			hover_tooltip_label.text = item_data.description
	
	is_card_hovered = true
	is_hovered = true
	hover_tooltip.visible = true
	_update_tooltip_position()

## _on_mouse_exited()
## Hides the hover tooltip when mouse exits the shop item card
func _on_mouse_exited() -> void:
	if not hover_tooltip:
		return
	
	is_card_hovered = false
	# Only hide if not hovering over the button either
	if not is_button_hovered:
		is_hovered = false
		hover_tooltip.visible = false

## _on_button_mouse_entered()
## Called when mouse enters the buy button - keeps tooltip visible
func _on_button_mouse_entered() -> void:
	is_button_hovered = true
	# Show tooltip if it exists
	if hover_tooltip and item_data:
		is_hovered = true
		hover_tooltip.visible = true
		_update_tooltip_position()

## _on_button_mouse_exited()
## Called when mouse exits the buy button - hides tooltip if not on card
func _on_button_mouse_exited() -> void:
	is_button_hovered = false
	# Only hide if not hovering over the card either
	if not is_card_hovered and hover_tooltip:
		is_hovered = false
		hover_tooltip.visible = false

## _update_tooltip_position()
## Positions the tooltip relative to the shop item
func _update_tooltip_position() -> void:
	if not hover_tooltip or not hover_tooltip.visible:
		return
		
	# Position tooltip to the right of the shop item
	var shop_item_rect = get_global_rect()
	var tooltip_pos = Vector2(
		shop_item_rect.position.x + shop_item_rect.size.x + 10,
		shop_item_rect.position.y
	)
	
	# Ensure tooltip stays within screen bounds
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_size = hover_tooltip.get_minimum_size()
	
	if tooltip_pos.x + tooltip_size.x > viewport_size.x:
		# Position to the left instead
		tooltip_pos.x = shop_item_rect.position.x - tooltip_size.x - 10
	
	if tooltip_pos.y + tooltip_size.y > viewport_size.y:
		# Adjust vertical position
		tooltip_pos.y = viewport_size.y - tooltip_size.y - 10
	
	hover_tooltip.global_position = tooltip_pos

## _apply_shop_item_styling()
## Applies border and background styling to the shop item panel
func _apply_shop_item_styling() -> void:
	print("[ShopItem] Applying shop item border styling")
	
	# Create shop item style with border
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.2, 0.95)  # Dark background
	style_box.border_color = Color(1, 0.8, 0.2, 1)     # Golden border
	style_box.set_border_width_all(3)                  # 3px border
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.content_margin_left = 12.0
	style_box.content_margin_top = 12.0
	style_box.content_margin_right = 12.0
	style_box.content_margin_bottom = 12.0
	style_box.shadow_color = Color(0, 0, 0, 0.4)
	style_box.shadow_size = 3
	
	# Apply the style to this PanelContainer
	add_theme_stylebox_override("panel", style_box)

## _apply_shop_item_fonts()
## Applies VCR font to shop item labels and button
func _apply_shop_item_fonts() -> void:
	print("[ShopItem] Applying VCR font to shop item elements")
	
	# Load VCR font
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if not vcr_font:
		print("[ShopItem] WARNING: VCR font not found")
		return
	
	# Apply font to name label
	if name_label:
		name_label.add_theme_font_override("font", vcr_font)
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		name_label.add_theme_constant_override("outline_size", 1)
	
	# Apply font to price label
	if price_label:
		price_label.add_theme_font_override("font", vcr_font)
		price_label.add_theme_font_size_override("font_size", 14)
		price_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))  # Green for money
		price_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		price_label.add_theme_constant_override("outline_size", 1)
	
	# Apply styled button
	if buy_button:
		_apply_shop_button_styling(buy_button)

## _apply_shop_button_styling(button)
## Applies themed styling to shop buttons
func _apply_shop_button_styling(button: Button) -> void:
	print("[ShopItem] Applying shop button styling")
	
	# Load VCR font
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font:
		button.add_theme_font_override("font", vcr_font)
		button.add_theme_font_size_override("font_size", 16)
	
	# Normal state style
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.18, 0.25, 0.95)
	style_normal.border_color = Color(1, 0.8, 0.2, 1)
	style_normal.set_border_width_all(2)
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6  
	style_normal.corner_radius_bottom_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.content_margin_left = 12.0
	style_normal.content_margin_top = 8.0
	style_normal.content_margin_right = 12.0
	style_normal.content_margin_bottom = 8.0
	
	# Hover state style
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.22, 0.3, 0.98)
	style_hover.border_color = Color(1, 0.9, 0.3, 1)
	style_hover.set_border_width_all(3)
	style_hover.corner_radius_top_left = 6
	style_hover.corner_radius_top_right = 6
	style_hover.corner_radius_bottom_right = 6
	style_hover.corner_radius_bottom_left = 6
	style_hover.content_margin_left = 12.0
	style_hover.content_margin_top = 8.0
	style_hover.content_margin_right = 12.0
	style_hover.content_margin_bottom = 8.0
	
	# Pressed state style
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.3, 0.27, 0.35, 1)
	style_pressed.border_color = Color(1, 1, 0.4, 1)
	style_pressed.set_border_width_all(2)
	style_pressed.corner_radius_top_left = 6
	style_pressed.corner_radius_top_right = 6
	style_pressed.corner_radius_bottom_right = 6
	style_pressed.corner_radius_bottom_left = 6
	style_pressed.content_margin_left = 10.0
	style_pressed.content_margin_top = 6.0
	style_pressed.content_margin_right = 10.0
	style_pressed.content_margin_bottom = 6.0
	
	# Apply styles to button
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	button.add_theme_constant_override("outline_size", 1)


## _setup_colored_dice_icon()
##
## Sets up the icon for a colored dice shop item.
## Loads the dice texture and applies the color shader to display
## the dice with its characteristic color glow effect.
##
## @param dice_color_type: DiceColor.Type to display
func _setup_colored_dice_icon(dice_color_type: DiceColor.Type) -> void:
	if not icon:
		return
	
	# Load the dice texture
	var dice_texture = load(DICE_TEXTURE_PATH)
	if not dice_texture:
		push_error("[ShopItem] Failed to load dice texture from: " + DICE_TEXTURE_PATH)
		return
	
	icon.texture = dice_texture
	
	# Load and apply the shader
	var shader = load(DICE_SHADER_PATH)
	if not shader:
		push_error("[ShopItem] Failed to load dice shader from: " + DICE_SHADER_PATH)
		return
	
	# Create shader material and apply to icon
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	
	# Reset all color strengths
	shader_material.set_shader_parameter("green_color_strength", 0.0)
	shader_material.set_shader_parameter("red_color_strength", 0.0)
	shader_material.set_shader_parameter("purple_color_strength", 0.0)
	shader_material.set_shader_parameter("blue_color_strength", 0.0)
	shader_material.set_shader_parameter("glow_strength", 0.0)
	shader_material.set_shader_parameter("lock_overlay_strength", 0.0)
	shader_material.set_shader_parameter("disabled", false)
	
	# Set the appropriate color strength based on dice color type
	match dice_color_type:
		DiceColor.Type.GREEN:
			shader_material.set_shader_parameter("green_color_strength", 0.8)
		DiceColor.Type.RED:
			shader_material.set_shader_parameter("red_color_strength", 0.8)
		DiceColor.Type.PURPLE:
			shader_material.set_shader_parameter("purple_color_strength", 0.8)
		DiceColor.Type.BLUE:
			shader_material.set_shader_parameter("blue_color_strength", 0.8)
	
	icon.material = shader_material
	print("[ShopItem] Set up colored dice icon with shader for:", DiceColor.get_color_name(dice_color_type))


## _update_colored_dice_display()
## Updates price, button status, and tooltip for colored dice items dynamically
func _update_colored_dice_display() -> void:
	if item_type != "colored_dice" or not item_data:
		return
	
	# Get color type from the data (use local var to avoid shadowing class var)
	var dice_color = item_data.color_type
	
	# Get current dynamic price from DiceColorManager
	var current_cost = DiceColorManager.get_current_color_cost(dice_color)
	var purchase_count = DiceColorManager.get_color_purchase_count(dice_color)
	var at_max = DiceColorManager.is_color_at_max_odds(dice_color)
	
	# Update price display
	if price_label:
		if at_max:
			price_label.text = "MAX"
			price_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1))  # Red
		else:
			price_label.text = "$%d" % current_cost
			price_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))  # Green
	
	# Update internal price for purchase validation
	price = current_cost
	
	# Update button status
	if buy_button:
		if at_max:
			buy_button.disabled = true
			buy_button.text = "MAX ODDS"
		elif not PlayerEconomy.can_afford(current_cost):
			buy_button.disabled = true
			buy_button.text = "BUY"
		else:
			buy_button.disabled = false
			buy_button.text = "BUY"
	
	# Update name label to show ownership count
	if name_label and purchase_count > 0:
		var base_name = item_data.display_name
		name_label.text = "%s (x%d)" % [base_name, purchase_count]


## _get_colored_dice_tooltip_text()
## Builds enhanced tooltip text for colored dice showing purchase info
func _get_colored_dice_tooltip_text() -> String:
	if item_type != "colored_dice" or not item_data:
		return item_data.description if item_data else ""
	
	var dice_color = item_data.color_type
	var tooltip_lines = []
	
	# Base description
	tooltip_lines.append(item_data.description)
	tooltip_lines.append("")
	
	# Effect description
	if item_data.effect_description and item_data.effect_description != "":
		tooltip_lines.append("Effect: " + item_data.effect_description)
	
	tooltip_lines.append("")
	
	# Purchase info from DiceColorManager
	tooltip_lines.append(DiceColorManager.get_color_shop_tooltip(dice_color))
	
	return "\n".join(tooltip_lines)
