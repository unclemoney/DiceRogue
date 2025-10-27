extends PanelContainer
class_name ShopItem

signal purchased(item_id: String, item_type: String)

@onready var icon: TextureRect = $MarginContainer/VBoxContainer/Icon
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var price_label: Label = $MarginContainer/VBoxContainer/PriceLabel
@onready var buy_button: Button = $MarginContainer/VBoxContainer/BuyButton
@onready var shop_label: Label = $MarginContainer/ShopLabel

var item_id: String
var item_type: String
var price: int
var item_data: Resource  # Store the data resource for tooltip access

# Hover tooltip variables
var hover_tooltip: PanelContainer
var hover_tooltip_label: Label
var is_hovered: bool = false
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
	icon.texture = data.icon
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	name_label.text = data.display_name
	price_label.text = "$%d" % price
	
	_setup_hover_tooltip()
	
	_update_button_state()
	if not PlayerEconomy.is_connected("money_changed", _update_button_state):
		PlayerEconomy.money_changed.connect(_update_button_state)
	#print("[ShopItem] Connected to PlayerEconomy.money_changed, Instance ID:", PlayerEconomy.get_instance_id())
	#print("[ShopItem] Setup complete for:", data.id)

func _update_button_state(_new_amount := 0) -> void:
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

# Helper function to find the ConsumableUI node
func _find_consumable_ui() -> ConsumableUI:
	# Try to find it in the scene tree
	var candidates = get_tree().get_nodes_in_group("consumable_ui")
	if candidates.size() > 0:
		return candidates[0]
		
	# Or navigate up to GameController and then down
	var root = get_tree().get_root()
	var game_controller = root.find_child("GameController", true, false)
	if game_controller:
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
	hover_tooltip.z_index = 1000
	
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
	get_parent().add_child(hover_tooltip)
	
	# Connect hover signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	print("[ShopItem] Tooltip created with direct styling")

## _on_mouse_entered()
## Shows the hover tooltip when mouse enters the shop item
func _on_mouse_entered() -> void:
	if not hover_tooltip or not item_data:
		return
		
	is_hovered = true
	hover_tooltip.visible = true
	_update_tooltip_position()

## _on_mouse_exited()
## Hides the hover tooltip when mouse exits the shop item
func _on_mouse_exited() -> void:
	if not hover_tooltip:
		return
		
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
