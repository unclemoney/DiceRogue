extends Control
class_name ShopUI

signal item_purchased(item_id: String, item_type: String)
signal shop_button_opened

@export var power_up_manager_path: NodePath
@export var consumable_manager_path: NodePath
@export var mod_manager_path: NodePath

@onready var power_up_container: GridContainer = $TabContainer/PowerUps/GridContainer
@onready var consumable_container: GridContainer = $TabContainer/Consumables/GridContainer
@onready var mod_container: GridContainer = $TabContainer/Mods/GridContainer
@onready var power_up_manager: PowerUpManager = get_node_or_null(power_up_manager_path)
@onready var consumable_manager: ConsumableManager = get_node_or_null(consumable_manager_path)
@onready var mod_manager: ModManager = get_node_or_null(mod_manager_path)
@onready var shop_label: RichTextLabel = $MarginContainer/ShopLabel

var _managers_ready := 0
const REQUIRED_MANAGERS := 3
var _time: float = 0.0
const RAINBOW_SPEED := 0.9
const RAINBOW_COLORS := [
	Color(1, 0, 0),    # Red
	Color(1, 0.5, 0),  # Orange
	Color(1, 1, 0),    # Yellow
	Color(0, 1, 0),    # Green
	Color(0, 0, 1),    # Blue
	Color(0.5, 0, 1),  # Purple
]

const ShopItemScene := preload("res://Scenes/Shop/shop_item.tscn")

var items_per_section := 2  # Number of items to display per section
var power_up_items := 2     # Specific count for power-ups
var consumable_items := 2   # Specific count for consumables  
var mod_items := 2          # Specific count for mods

var purchased_items := {}  # Track purchased items by type: {"power_up": [], "consumable": [], "mod": []}

func _ready() -> void:
	print("[ShopUI] Initializing...")
	print("PowerUpManager path:", power_up_manager_path)
	print("ConsumableManager path:", consumable_manager_path)
	print("ModManager path:", mod_manager_path)

	# Initialize purchased items tracking
	purchased_items = {
		"power_up": [],
		"consumable": [],
		"mod": []
	}
	
	if not shop_label:
		push_error("[ShopUI] ShopLabel not found!")
		return

	if not power_up_manager:
		push_error("[ShopUI] PowerUpManager not found at path:", power_up_manager_path)
	if not consumable_manager:
		push_error("[ShopUI] ConsumableManager not found at path:", consumable_manager_path)
	if not mod_manager:
		push_error("[ShopUI] ModManager not found at path:", mod_manager_path)
		return
		
	# Set up shop label
	shop_label.bbcode_enabled = true
	shop_label.fit_content = true
	shop_label.custom_minimum_size = Vector2(0, 24)
		
	# Connect to manager ready signals
	power_up_manager.definitions_loaded.connect(_on_manager_ready)
	consumable_manager.definitions_loaded.connect(_on_manager_ready)
	mod_manager.definitions_loaded.connect(_on_manager_ready)
	PlayerEconomy.money_changed.connect(_on_money_changed)
	hide()
	#buy_button.pressed.connect(_on_buy_button_pressed)

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
	shop_label.add_theme_font_size_override("normal_font_size", 45)
	shop_label.text = "[center][color=#%s][wave amp=50 freq=2]SHOP[/wave][/color][/center]" % hex_color
	
func _on_manager_ready() -> void:
	_managers_ready += 1
	print("[ShopUI] Manager ready. Waiting for", REQUIRED_MANAGERS - _managers_ready, "more")
	
	if _managers_ready == REQUIRED_MANAGERS:
		print("[ShopUI] All managers ready - populating shop")
		_populate_shop_items()

func _populate_shop_items() -> void:
	print("\n=== Populating Shop Items ===")
	
	# Clear existing containers
	_clear_shop_containers()
	
	# Populate PowerUps
	var power_ups = power_up_manager.get_available_power_ups()
	var filtered_power_ups = _filter_out_purchased_items(power_ups, "power_up")
	# Also filter out already owned power-ups
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		filtered_power_ups = filtered_power_ups.filter(func(id): return not game_controller.active_power_ups.has(id))
	var selected_power_ups = _select_random_items(filtered_power_ups, power_up_items)
	
	for id in selected_power_ups:
		var data = power_up_manager.get_def(id)
		if data:
			_add_shop_item(data, "power_up")
		else:
			push_error("[ShopUI] Failed to get PowerUpData for:", id)
	
	# Populate Consumables
	var consumables = consumable_manager._defs_by_id.keys()
	var filtered_consumables = _filter_out_purchased_items(consumables, "consumable")
	var selected_consumables = _select_random_items(filtered_consumables, consumable_items)
	
	for id in selected_consumables:
		var data = consumable_manager.get_def(id)
		if data:
			_add_shop_item(data, "consumable")
		else:
			push_error("[ShopUI] Failed to get ConsumableData for:", id)
			
	# Populate Mods
	var mods = mod_manager._defs_by_id.keys()
	var filtered_mods = _filter_out_purchased_items(mods, "mod")
	var selected_mods = _select_random_items(filtered_mods, mod_items)
	
	for id in selected_mods:
		var data = mod_manager.get_def(id)
		if data:
			_add_shop_item(data, "mod")
		else:
			push_error("[ShopUI] Failed to get ModData for:", id)

# Helper function to filter out already purchased items
func _filter_out_purchased_items(items: Array, type: String) -> Array:
	var result = []
	for item in items:
		if not purchased_items[type].has(item):
			result.append(item)
	return result

# Helper function to select random items from an array with weighted selection for power-ups
func _select_random_items(items: Array, count: int) -> Array:
	var result = []
	
	# For power-ups, use weighted selection based on rarity
	if items.size() > 0:
		var first_item_id = items[0] if items.size() > 0 else ""
		var first_data = power_up_manager.get_def(first_item_id) if first_item_id else null
		
		if first_data and first_data is PowerUpData:
			result = _select_weighted_power_ups(items, count)
		else:
			# For non-power-ups, use original random selection
			var available = items.duplicate()
			available.shuffle()
			var items_to_take = min(count, available.size())
			for i in range(items_to_take):
				result.append(available[i])
	
	return result

# Weighted selection for power-ups based on rarity
func _select_weighted_power_ups(power_up_ids: Array, count: int) -> Array:
	var result = []
	var available_items = []
	
	# Build weighted array with debugging
	print("\n[ShopUI] Building weighted power-up selection:")
	for id in power_up_ids:
		var data = power_up_manager.get_def(id)
		if data and data is PowerUpData:
			var weight = PowerUpData.get_rarity_weight(data.rarity)
			var rarity_char = PowerUpData.get_rarity_display_char(data.rarity)
			print("  - %s (%s): %s%% chance" % [data.display_name, rarity_char, str(weight)])
			
			# Add this item multiple times based on its weight
			for i in range(weight):
				available_items.append(id)
	
	# Select random items from weighted array
	available_items.shuffle()
	var items_to_take = min(count, power_up_ids.size())  # Don't exceed available unique items
	var selected_unique = {}
	
	print("[ShopUI] Selecting %d power-ups from weighted pool of %d entries" % [items_to_take, available_items.size()])
	
	for i in range(available_items.size()):
		if result.size() >= items_to_take:
			break
		
		var item_id = available_items[i]
		if not selected_unique.has(item_id):
			selected_unique[item_id] = true
			result.append(item_id)
			
			var data = power_up_manager.get_def(item_id)
			if data:
				var rarity_char = PowerUpData.get_rarity_display_char(data.rarity)
				print("  ✓ Selected: %s (%s)" % [data.display_name, rarity_char])
	
	print("[ShopUI] Final selection: %d power-ups" % result.size())
	return result

# Helper function to clear all shop containers
func _clear_shop_containers() -> void:
	if power_up_container:
		for child in power_up_container.get_children():
			child.queue_free()
	
	if consumable_container:
		for child in consumable_container.get_children():
			child.queue_free()
	
	if mod_container:
		for child in mod_container.get_children():
			child.queue_free()

# Add this function to reset purchased items for a new round
func reset_for_new_round() -> void:
	print("[ShopUI] Resetting shop for new round")
	purchased_items = {
		"power_up": [],
		"consumable": [],
		"mod": []
	}
	_populate_shop_items()

func _add_shop_item(data: Resource, type: String) -> void:
	var container = _get_container_for_type(type)
	if not container:
		push_error("[ShopUI] No container found for type:", type)
		return
		
	var item = ShopItemScene.instantiate()
	container.add_child(item)
	print("[ShopUI] Created shop item instance for:", data.id)
	
	# Connect the signal before setup
	item.purchased.connect(
		func(id: String, itype: String):
			print("[ShopUI] Purchase signal received from item:", id)
			_on_item_purchased(id, itype)
	)
	
	item.setup(data, type)
	print("[ShopUI] Added and connected item:", data.id, "type:", type)

func _on_item_purchased(item_id: String, item_type: String) -> void:
	print("[ShopUI] Processing purchase:", item_id, "type:", item_type)
	
	# Check if it's a power-up and if we're already at max
	if item_type == "power_up":
		# Find PowerUpUI to check max status
		var power_up_ui = _find_power_up_ui()
		if power_up_ui and power_up_ui.has_max_power_ups():
			print("[ShopUI] Maximum power-ups reached, purchase blocked")
			# Could show a notification here
			return
	# Check if it's a consumable and if we're already at max
	elif item_type == "consumable":
		# Find ConsumableUI to check max status
		var consumable_ui = _find_consumable_ui()
		if consumable_ui and consumable_ui.has_max_consumables():
			print("[ShopUI] Maximum consumables reached, purchase blocked")
			return
	
	# Record that this item was purchased
	if not purchased_items[item_type].has(item_id):
		purchased_items[item_type].append(item_id)
	
	# Remove the item from the shop
	_remove_shop_item(item_id, item_type)
	
	# If we got here, proceed with purchase
	emit_signal("item_purchased", item_id, item_type)

# Add function to remove a shop item after purchase
func _remove_shop_item(item_id: String, item_type: String) -> void:
	var container = _get_container_for_type(item_type)
	if not container:
		push_error("[ShopUI] No container found for type:", item_type)
		return
		
	# Find and remove the shop item with matching ID
	for child in container.get_children():
		if child is ShopItem and child.item_id == item_id:
			child.queue_free()
			print("[ShopUI] Removed shop item:", item_id, "from shop")
			break

# Helper function to find PowerUpUI
func _find_power_up_ui() -> PowerUpUI:
	# Try direct path first
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		var power_up_ui = game_controller.get_node_or_null("../PowerUpUI")
		if power_up_ui:
			return power_up_ui
	
	# Fall back to searching the tree
	return get_tree().get_first_node_in_group("power_up_ui")

# Add helper function to find ConsumableUI
func _find_consumable_ui() -> ConsumableUI:
	# Try direct path first
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		var consumable_ui = game_controller.get_node_or_null("../ConsumableUI") as ConsumableUI
		if consumable_ui:
			return consumable_ui
	
	# Fall back to searching the tree
	return get_tree().get_first_node_in_group("consumable_ui") as ConsumableUI

func _on_close_button_pressed() -> void:
	hide()

func _get_container_for_type(type: String) -> Node:
	match type:
		"power_up": 
			print("[ShopUI] Getting power-up container")
			return power_up_container
		"consumable": 
			print("[ShopUI] Getting consumable container")
			return consumable_container
		"mod": 
			print("[ShopUI] Getting mod container")
			return mod_container
		_:
			push_error("[ShopUI] Unknown item type:", type)
			return null

func _on_money_changed(new_amount: int) -> void:
	# Update all shop item buttons in all containers
	for container in [power_up_container, consumable_container, mod_container]:
		if container:
			for child in container.get_children():
				if child is ShopItem:
					child._update_button_state()

# Add method to increase the number of power-ups displayed in shop
func increase_power_up_items(amount: int) -> void:
	power_up_items += amount
	print("[ShopUI] Increased power-up items by", amount, "- new value:", power_up_items)
	# Refresh the shop to show the new items
	_populate_shop_items()

# Add method to increase consumable items (for future use)
func increase_consumable_items(amount: int) -> void:
	consumable_items += amount
	print("[ShopUI] Increased consumable items by", amount, "- new value:", consumable_items)
	_populate_shop_items()

# Add method to increase mod items (for future use)  
func increase_mod_items(amount: int) -> void:
	mod_items += amount
	print("[ShopUI] Increased mod items by", amount, "- new value:", mod_items)
	_populate_shop_items()

# Keep old method for backward compatibility but mark as deprecated
func increase_items_per_section(amount: int) -> void:
	items_per_section += amount
	power_up_items = items_per_section
	consumable_items = items_per_section
	mod_items = items_per_section
	print("[ShopUI] [DEPRECATED] Increased all section items by", amount)
	_populate_shop_items()