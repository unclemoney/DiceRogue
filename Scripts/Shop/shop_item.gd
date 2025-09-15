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
	
	# Interpolate between colors
	var current_color: Color = RAINBOW_COLORS[index1].lerp(RAINBOW_COLORS[index2], t)
	
	# Format BBCode with hex color
	var hex_color: String = current_color.to_html(false)
	#shop_label.text = "[center][color=#%s][wave amp=50 freq=2]SHOP[/wave][/color][/center]" % hex_color
	# Check if this is a power-up item and if there's a maximum reached
	if item_type == "power_up":
		# Find the PowerUpUI node to check if maximum reached
		var power_up_ui = _find_power_up_ui()
		if power_up_ui and power_up_ui.has_max_power_ups():
			# Disable the buy button and show "MAX REACHED" text
			buy_button.disabled = true
			buy_button.text = "MAX REACHED"
		else:
			# Re-enable the button if previously disabled
			if buy_button.disabled and buy_button.text == "MAX REACHED":
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

func setup(data: Resource, type: String) -> void:
	print("[ShopItem] Setting up item:", data.id)
	item_id = data.id
	item_type = type
	price = data.price
	
	if not icon or not name_label or not price_label:
		push_error("[ShopItem] One or more required nodes not found!")
		return
	
	# Explicitly set icon size and expansion
	icon.custom_minimum_size = Vector2(48, 48)
	icon.texture = data.icon
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	name_label.text = data.display_name
	price_label.text = "$%d" % price
	
	_update_button_state()
	if not PlayerEconomy.is_connected("money_changed", _update_button_state):
		PlayerEconomy.money_changed.connect(_update_button_state)
	print("[ShopItem] Connected to PlayerEconomy.money_changed, Instance ID:", PlayerEconomy.get_instance_id())
	print("[ShopItem] Setup complete for:", data.id)

func _update_button_state(_new_amount := 0) -> void:
	print("[ShopItem] _update_button_state called")
	print("[ShopItem] Updating button state for", item_id, "- Player money:", PlayerEconomy.money, ", Price:", price)
	if buy_button:
		buy_button.disabled = not PlayerEconomy.can_afford(price)
		print("[ShopItem] Buy button state updated - disabled:", buy_button.disabled)

func _on_buy_button_pressed() -> void:
	print("[ShopItem] Buy button pressed for", item_id)
	if PlayerEconomy.can_afford(price):
		if PlayerEconomy.remove_money(price):
			print("[ShopItem] Successfully purchased", item_id, "for", price)
			emit_signal("purchased", item_id, item_type)
			print("[ShopItem] Purchase signal emitted")
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
