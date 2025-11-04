extends Control
class_name ShopUI

signal item_purchased(item_id: String, item_type: String)
signal shop_button_opened

@export var power_up_manager_path: NodePath
@export var consumable_manager_path: NodePath
@export var mod_manager_path: NodePath

@onready var tab_container: TabContainer = $TabContainer
@onready var power_up_container: Container = $TabContainer/PowerUps/GridContainer
@onready var consumable_container: Container = $TabContainer/Consumables/GridContainer
@onready var mod_container: Container = $TabContainer/Mods/GridContainer
@onready var colored_dice_container: Container = get_node_or_null("TabContainer/Colors/GridContainer")
@onready var locked_container: Container = $TabContainer/Locked/ScrollContainer/GridContainer
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
var colored_dice_items := 2 # Specific count for colored dice

var purchased_items := {}  # Track purchased items by type: {"power_up": [], "consumable": [], "mod": [], "colored_dice": []}

func _ready() -> void:
	print("[ShopUI] Initializing...")
	print("PowerUpManager path:", power_up_manager_path)
	print("ConsumableManager path:", consumable_manager_path)
	print("ModManager path:", mod_manager_path)

	# Initialize purchased items tracking
	purchased_items = {
		"power_up": [],
		"consumable": [],
		"mod": [],
		"colored_dice": []
	}
	
	if not shop_label:
		push_error("[ShopUI] ShopLabel not found!")
		return

	# Set up and style shop label
	_style_shop_title()
	
	# Fix mouse input for background elements (do this early, before manager checks)
	_configure_mouse_input()

	if not colored_dice_container:
		print("[ShopUI] ColoredDiceContainer not found - creating programmatically")
		_create_colors_tab()
	if not power_up_manager:
		push_error("[ShopUI] PowerUpManager not found at path:", power_up_manager_path)
	if not consumable_manager:
		push_error("[ShopUI] ConsumableManager not found at path:", consumable_manager_path)
	if not mod_manager:
		push_error("[ShopUI] ModManager not found at path:", mod_manager_path)
		return
		
	# Style the tab container with VCR font and larger tabs
	_style_tab_container()
		
	# Connect to manager ready signals
	power_up_manager.definitions_loaded.connect(_on_manager_ready)
	consumable_manager.definitions_loaded.connect(_on_manager_ready)
	mod_manager.definitions_loaded.connect(_on_manager_ready)
	PlayerEconomy.money_changed.connect(_on_money_changed)
	
	# Connect to ProgressManager to refresh shop when items are unlocked/locked
	var progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		if progress_manager.has_signal("item_unlocked"):
			progress_manager.item_unlocked.connect(func(_item_id: String, _item_type: String): _on_progress_changed())
		if progress_manager.has_signal("item_locked"):
			progress_manager.item_locked.connect(func(_item_id: String, _item_type: String): _on_progress_changed())
		if progress_manager.has_signal("progress_saved"):
			progress_manager.progress_saved.connect(_on_progress_changed)
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
		populate_locked_items()  # Add locked items population

## _on_progress_changed()
##
## Called when progress is updated (items unlocked/locked) to refresh shop display
func _on_progress_changed() -> void:
	print("[ShopUI] Progress changed - refreshing shop")
	if _managers_ready == REQUIRED_MANAGERS:
		_populate_shop_items()
		populate_locked_items()

func _populate_shop_items() -> void:
	print("\n=== Populating Shop Items ===")
	
	# Clear existing containers
	_clear_shop_containers()
	
	# Populate PowerUps
	var power_ups = power_up_manager.get_available_power_ups()
	var filtered_power_ups = _filter_out_purchased_items(power_ups, "power_up")
	# Filter out locked items
	filtered_power_ups = _filter_unlocked_items(filtered_power_ups, "power_up")
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
	# Filter out locked items
	filtered_consumables = _filter_unlocked_items(filtered_consumables, "consumable")
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
	# Filter out locked items
	filtered_mods = _filter_unlocked_items(filtered_mods, "mod")
	var selected_mods = _select_random_items(filtered_mods, mod_items)
	
	for id in selected_mods:
		var data = mod_manager.get_def(id)
		if data:
			_add_shop_item(data, "mod")
		else:
			push_error("[ShopUI] Failed to get ModData for:", id)
	
	# Populate Colored Dice
	var colored_dice = DiceColorManager.get_available_colored_dice()
	var colored_dice_ids = []
	for data in colored_dice:
		colored_dice_ids.append(data.id)
	var filtered_colored_dice = _filter_out_purchased_items(colored_dice_ids, "colored_dice")
	# Filter out locked items
	filtered_colored_dice = _filter_unlocked_items(filtered_colored_dice, "colored_dice")
	var selected_colored_dice = _select_random_items(filtered_colored_dice, colored_dice_items)
	
	for id in selected_colored_dice:
		var data = DiceColorManager.get_colored_dice_data(id)
		if data:
			_add_shop_item(data, "colored_dice")
		else:
			push_error("[ShopUI] Failed to get ColoredDiceData for:", id)

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
	
	if colored_dice_container:
		for child in colored_dice_container.get_children():
			child.queue_free()

# Add this function to reset purchased items for a new round
func reset_for_new_round() -> void:
	print("[ShopUI] Resetting shop for new round")
	purchased_items = {
		"power_up": [],
		"consumable": [], 
		"mod": [],
		"colored_dice": []
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
	# Check if it's a mod and if we're already at dice limit
	elif item_type == "mod":
		# Find GameController to check mod vs dice count limit
		var game_controller = _find_game_controller()
		if game_controller and _has_reached_mod_limit(game_controller):
			print("[ShopUI] Mod limit reached (all dice have mods), purchase blocked")
			return
		else:
			print("[ShopUI] Mod purchase allowed - limit not reached")
	# Check if it's a colored dice purchase
	elif item_type == "colored_dice":
		# Get the colored dice data to determine color type
		var colored_dice_data = DiceColorManager.get_colored_dice_data(item_id)
		if not colored_dice_data:
			print("[ShopUI] Invalid colored dice ID:", item_id)
			return
		
		# Check if this color type is already purchased
		if DiceColorManager.is_color_purchased(colored_dice_data.color_type):
			print("[ShopUI] Color type already purchased:", colored_dice_data.get_color_name())
			return
		
		print("[ShopUI] Colored dice purchase validation passed for:", colored_dice_data.get_color_name())
	
	print("[ShopUI] Purchase validation passed, proceeding with purchase")
	
	# Record that this item was purchased
	if not purchased_items[item_type].has(item_id):
		purchased_items[item_type].append(item_id)
		print("[ShopUI] Added", item_id, "to purchased items list")
	
	# Remove the item from the shop
	print("[ShopUI] Calling _remove_shop_item for:", item_id, "type:", item_type)
	_remove_shop_item(item_id, item_type)
	
	# If we got here, proceed with purchase
	print("[ShopUI] Emitting item_purchased signal for:", item_id, "type:", item_type)
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
			# Hide immediately and disable the button to prevent multiple purchases
			child.visible = false
			if child.buy_button:
				child.buy_button.disabled = true
			# Then queue for deletion
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

# Helper function to find GameController
func _find_game_controller() -> GameController:
	return get_tree().get_first_node_in_group("game_controller") as GameController

# Helper function to check if mod limit has been reached
func _has_reached_mod_limit(game_controller: GameController) -> bool:
	if not game_controller:
		return false
	
	var current_mod_count = game_controller._get_total_active_mod_count()
	# Use expected dice count instead of current dice list size to handle pre-spawn scenario
	var expected_dice_count = game_controller._get_expected_dice_count()
	
	return current_mod_count >= expected_dice_count

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
		"colored_dice":
			print("[ShopUI] Getting colored dice container")
			return colored_dice_container
		_:
			push_error("[ShopUI] Unknown item type:", type)
			return null

func _on_money_changed(_new_amount: int, _change: int = 0) -> void:
	# Update all shop item buttons in all containers
	for container in [power_up_container, consumable_container, mod_container, colored_dice_container]:
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

# Add method to increase colored dice items
func increase_colored_dice_items(amount: int) -> void:
	colored_dice_items += amount
	print("[ShopUI] Increased colored dice items by", amount, "- new value:", colored_dice_items)
	_populate_shop_items()

# Keep old method for backward compatibility but mark as deprecated
func increase_items_per_section(amount: int) -> void:
	items_per_section += amount
	power_up_items = items_per_section
	consumable_items = items_per_section
	mod_items = items_per_section
	colored_dice_items = items_per_section
	print("[ShopUI] [DEPRECATED] Increased all section items by", amount)
	_populate_shop_items()

## _style_tab_container()
## Applies VCR font and larger styling to the shop tabs
func _style_tab_container() -> void:
	if not tab_container:
		print("[ShopUI] TabContainer not found, skipping styling")
		return
	
	print("[ShopUI] Applying VCR font and styling to shop tabs")
	
	# Load VCR font
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font:
		tab_container.add_theme_font_override("font", vcr_font)
		tab_container.add_theme_font_size_override("font_size", 20)  # Larger font size
		tab_container.add_theme_color_override("font_selected_color", Color(1, 0.8, 0.2, 1))  # Golden selected
		tab_container.add_theme_color_override("font_unselected_color", Color(0.9, 0.9, 0.9, 1))  # Light gray unselected
		tab_container.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		tab_container.add_theme_constant_override("font_outline_size", 1)
	
	# Make tabs taller
	tab_container.add_theme_constant_override("tab_height", 40)
	
	# Style the grid containers for better centering and spacing
	_style_grid_containers()
	
	# Apply better background styling
	_style_shop_background()
	
	print("[ShopUI] Tab container styling applied")

## _style_grid_containers()
## Improves the layout and centering of shop item grids
func _style_grid_containers() -> void:
	print("[ShopUI] Styling containers for better centered layout")
	
	# First try programmatic approach - replace grid containers with centered layout
	_replace_grid_with_centered_layout()
	
	# Apply styling to any remaining grid containers
	var containers = [power_up_container, consumable_container, mod_container]
	
	for container in containers:
		if container:
			# Set columns to create more centered layout (only for GridContainer)
			if container is GridContainer:
				container.columns = 2
			
			# Center the container content
			container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			# Add spacing between items
			container.add_theme_constant_override("h_separation", 30)
			container.add_theme_constant_override("v_separation", 25)
			
			print("[ShopUI] Styled grid container:", container.name)

## _replace_grid_with_centered_layout()
## Replaces GridContainers with centered VBox/HBox layout for better positioning
func _replace_grid_with_centered_layout() -> void:
	print("[ShopUI] Attempting to improve container layout for centering")
	
	var tab_nodes = [
		tab_container.get_node_or_null("PowerUps"),
		tab_container.get_node_or_null("Consumables"), 
		tab_container.get_node_or_null("Mods")
	]
	
	for i in range(tab_nodes.size()):
		var tab_node = tab_nodes[i]
		if not tab_node:
			continue
			
		var grid = tab_node.get_node_or_null("GridContainer")
		if not grid:
			continue
		
		print("[ShopUI] Creating centered layout for tab:", tab_node.name)
		
		# Create a centered VBox container
		var main_vbox = VBoxContainer.new()
		main_vbox.name = "CenteredContainer"
		main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Create margin container for padding from edges
		var margin_container = MarginContainer.new()
		margin_container.name = "MarginContainer"
		margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin_container.add_theme_constant_override("margin_left", 50)
		margin_container.add_theme_constant_override("margin_right", 50)
		margin_container.add_theme_constant_override("margin_top", 30)
		margin_container.add_theme_constant_override("margin_bottom", 30)
		
		# Create inner HBox for horizontal centering
		var hbox = HBoxContainer.new()
		hbox.name = "ItemContainer"
		hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 40)
		
		# Move children from grid to hbox
		var children_to_move = []
		for child in grid.get_children():
			children_to_move.append(child)
		
		for child in children_to_move:
			grid.remove_child(child)
			hbox.add_child(child)
		
		# Build the hierarchy: tab -> margin -> main_vbox -> hbox -> items
		margin_container.add_child(main_vbox)
		main_vbox.add_child(hbox)
		tab_node.add_child(margin_container)
		
		# Hide the old grid (keep it for fallback)
		grid.visible = false
		
		# Update container references
		if tab_node.name == "PowerUps":
			power_up_container = hbox
		elif tab_node.name == "Consumables":
			consumable_container = hbox
		elif tab_node.name == "Mods":
			mod_container = hbox
		
		print("[ShopUI] Created centered layout for:", tab_node.name)

## _style_shop_background()
## Applies an improved background to the shop UI
func _style_shop_background() -> void:
	print("[ShopUI] Applying improved shop background styling")
	
	# Apply background styling to the main shop control
	var style_box = StyleBoxFlat.new()
	
	# Create a dark gradient background instead of solid blue
	style_box.bg_color = Color(0.08, 0.05, 0.15, 0.98)  # Dark purple base
	
	# Add a subtle border
	style_box.border_color = Color(1, 0.8, 0.2, 0.6)    # Semi-transparent golden border
	style_box.set_border_width_all(2)
	
	# Rounded corners for modern look
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_right = 12
	style_box.corner_radius_bottom_left = 12
	
	# Add shadow for depth
	style_box.shadow_color = Color(0, 0, 0, 0.5)
	style_box.shadow_size = 4
	style_box.shadow_offset = Vector2(2, 2)
	
	# Create a background panel if one doesn't exist
	var bg_panel = get_node_or_null("BackgroundPanel")
	if not bg_panel:
		bg_panel = Panel.new()
		bg_panel.name = "BackgroundPanel" 
		bg_panel.z_index = -10  # Behind everything else
		bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg_panel)
		move_child(bg_panel, 0)  # Move to back
	
	# Apply the background style to the panel
	bg_panel.add_theme_stylebox_override("panel", style_box)
	
	# Also style the tab container background
	if tab_container:
		var tab_style = StyleBoxFlat.new()
		tab_style.bg_color = Color(0.12, 0.08, 0.18, 0.95)  # Slightly lighter for tabs
		tab_style.corner_radius_top_left = 8
		tab_style.corner_radius_top_right = 8
		tab_style.corner_radius_bottom_right = 8
		tab_style.corner_radius_bottom_left = 8
		tab_container.add_theme_stylebox_override("panel", tab_style)
	
	print("[ShopUI] Shop background styling applied")

## _style_shop_title()
## Styles the shop title with better positioning and fonts
func _style_shop_title() -> void:
	if not shop_label:
		print("[ShopUI] Shop label not found, skipping title styling")
		return
	
	print("[ShopUI] Styling shop title")
	
	# Configure basic properties
	shop_label.bbcode_enabled = true
	shop_label.fit_content = true
	shop_label.custom_minimum_size = Vector2(0, 40)  # Taller for better presence
	
	# Apply VCR font and styling
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font:
		shop_label.add_theme_font_override("normal_font", vcr_font)
		shop_label.add_theme_font_size_override("normal_font_size", 28)  # Large title font
		shop_label.add_theme_color_override("default_color", Color(1, 0.8, 0.2, 1))  # Golden color
	
	# Center alignment
	shop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Add background to the title
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.1, 0.08, 0.15, 0.8)  # Semi-transparent dark background
	title_style.border_color = Color(1, 0.8, 0.2, 0.4)  # Subtle golden border
	title_style.set_border_width_all(1)
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_style.corner_radius_bottom_right = 8  
	title_style.corner_radius_bottom_left = 8
	title_style.content_margin_left = 20.0
	title_style.content_margin_top = 10.0
	title_style.content_margin_right = 20.0
	title_style.content_margin_bottom = 10.0
	
	shop_label.add_theme_stylebox_override("normal", title_style)
	
	# Set the shop title text with BBCode formatting
	shop_label.text = "[center][color=gold]✦ MERCHANT'S SHOP ✦[/color][/center]"
	
	print("[ShopUI] Shop title styling applied")

## _create_colors_tab()
## Creates the COLORS tab programmatically if it doesn't exist in the scene
func _create_colors_tab() -> void:
	print("[ShopUI] Creating COLORS tab programmatically")
	
	if not tab_container:
		push_error("[ShopUI] TabContainer not found - cannot create COLORS tab")
		return
	
	# Create the Colors tab
	var colors_tab = Control.new()
	colors_tab.name = "Colors"
	tab_container.add_child(colors_tab)
	
	# Create GridContainer for the colored dice items
	var grid_container = GridContainer.new()
	grid_container.name = "GridContainer"
	grid_container.columns = 2  # Match other tabs
	colors_tab.add_child(grid_container)
	
	# Set up the container reference
	colored_dice_container = grid_container
	
	print("[ShopUI] COLORS tab created successfully")

## _configure_mouse_input()
## Configures mouse input filters to prevent background elements from blocking shop items
func _configure_mouse_input() -> void:
	print("[ShopUI] Configuring mouse input for background elements...")
	
	# Find and configure the background PanelContainer and TextureRect
	var panel_container = get_node_or_null("PanelContainer")
	if panel_container:
		panel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		print("[ShopUI] Set PanelContainer mouse filter to IGNORE")
		
		# Also set the TextureRect inside to ignore mouse
		var texture_rect = panel_container.get_node_or_null("TextureRect")
		if texture_rect:
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			print("[ShopUI] Set TextureRect mouse filter to IGNORE")
	
	# Ensure TabContainer allows mouse passthrough to children
	var tab_cont = get_node_or_null("TabContainer")
	if tab_cont:
		tab_cont.mouse_filter = Control.MOUSE_FILTER_PASS
		print("[ShopUI] Set TabContainer mouse filter to PASS")
	
	print("[ShopUI] Mouse input configuration complete")

## populate_locked_items()
## 
## Populates the LOCKED tab with items that haven't been unlocked yet
func populate_locked_items() -> void:
	if not locked_container:
		print("[ShopUI] No locked container found")
		return
	
	# Clear existing locked items
	for child in locked_container.get_children():
		child.queue_free()
	
	# Get the ProgressManager autoload
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("[ShopUI] ProgressManager not available")
		return
	
	print("[ShopUI] Populating locked items...")
	
	# Load the UnlockableItem class to access ItemType enum
	const UnlockableItemClass = preload("res://Scripts/Core/unlockable_item.gd")
	
	# Get locked PowerUps
	var locked_power_ups = progress_manager.get_locked_items(UnlockableItemClass.ItemType.POWER_UP)
	for item in locked_power_ups:
		_create_locked_item_display(item)
	
	# Get locked Consumables
	var locked_consumables = progress_manager.get_locked_items(UnlockableItemClass.ItemType.CONSUMABLE)
	for item in locked_consumables:
		_create_locked_item_display(item)
	
	# Get locked Mods
	var locked_mods = progress_manager.get_locked_items(UnlockableItemClass.ItemType.MOD)
	for item in locked_mods:
		_create_locked_item_display(item)
	
	# Get locked Colored Dice features
	var locked_dice_features = progress_manager.get_locked_items(UnlockableItemClass.ItemType.COLORED_DICE_FEATURE)
	for item in locked_dice_features:
		_create_locked_item_display(item)
	
	print("[ShopUI] Locked items populated")

## _create_locked_item_display(item)
##
## Creates a display for a locked item showing what it is and unlock requirements
func _create_locked_item_display(item) -> void:
	if not item or not locked_container:
		return
	
	# Create a panel for the locked item
	var locked_panel = PanelContainer.new()
	locked_panel.custom_minimum_size = Vector2(200, 150)
	
	# Add a background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.4, 0.4, 1.0)  # Red border for locked items
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	locked_panel.add_theme_stylebox_override("panel", style)
	
	# Create content container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	locked_panel.add_child(vbox)
	
	# Add item name with lock icon
	var name_label = RichTextLabel.new()
	name_label.custom_minimum_size = Vector2(180, 30)
	name_label.fit_content = true
	name_label.scroll_active = false
	name_label.bbcode_enabled = true  # Enable BBCode
	name_label.text = "[center]🔒 %s[/center]" % item.display_name
	name_label.add_theme_font_size_override("normal_font_size", 11)
	vbox.add_child(name_label)
	
	# Add item type
	var type_label = Label.new()
	type_label.text = "Type: %s" % item.get_type_string()
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)
	
	# Add description
	var desc_label = RichTextLabel.new()
	desc_label.custom_minimum_size = Vector2(180, 40)
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.bbcode_enabled = true  # Enable BBCode
	desc_label.add_theme_font_size_override("normal_font_size", 9)
	desc_label.text = "[center]%s[/center]" % item.description
	vbox.add_child(desc_label)
	
	# Add unlock requirement
	var unlock_label = RichTextLabel.new()
	unlock_label.custom_minimum_size = Vector2(180, 35)
	unlock_label.fit_content = true
	unlock_label.scroll_active = false
	unlock_label.bbcode_enabled = true  # Enable BBCode
	unlock_label.add_theme_font_size_override("normal_font_size", 9)
	unlock_label.text = "[center][color=yellow]Unlock: %s[/color][/center]" % item.get_unlock_description()
	vbox.add_child(unlock_label)
	
	locked_container.add_child(locked_panel)

func _filter_unlocked_items(items: Array, item_type: String) -> Array:
	# Get the ProgressManager autoload
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("[ShopUI] ProgressManager not available for filtering")
		return items
	
	var filtered_items: Array = []
	
	for item_id in items:
		# Check if this item is tracked by the progress system
		if progress_manager.is_item_unlocked(item_id):
			filtered_items.append(item_id)
		else:
			print("[ShopUI] Filtering out locked %s: %s" % [item_type, item_id])
	
	return filtered_items
