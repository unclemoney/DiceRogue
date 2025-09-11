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

func _ready() -> void:
	print("[ShopUI] Initializing...")
	print("PowerUpManager path:", power_up_manager_path)
	print("ConsumableManager path:", consumable_manager_path)
	print("ModManager path:", mod_manager_path)

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
	
	# Populate PowerUps
	var power_ups = power_up_manager.get_available_power_ups()
	#print("[ShopUI] Power-ups found:", power_ups)
	for id in power_ups:
		#print("[ShopUI] Adding power-up:", id)
		var data = power_up_manager.get_def(id)
		if data:
			_add_shop_item(data, "power_up")
		else:
			push_error("[ShopUI] Failed to get PowerUpData for:", id)
	
	# Populate Consumables
	var consumables = consumable_manager._defs_by_id.keys()
	#print("[ShopUI] Consumables found:", consumables)
	for id in consumables:
		#print("[ShopUI] Adding consumable:", id)
		var data = consumable_manager.get_def(id)
		if data:
			_add_shop_item(data, "consumable")
		else:
			push_error("[ShopUI] Failed to get ConsumableData for:", id)
			
	# Populate Mods
	var mods = mod_manager._defs_by_id.keys()
	#print("[ShopUI] Mods found:", mods)
	for id in mods:
		#print("[ShopUI] Adding mod:", id)
		var data = mod_manager.get_def(id)
		if data:
			_add_shop_item(data, "mod")
		else:
			push_error("[ShopUI] Failed to get ModData for:", id)

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
	
	# If we got here, proceed with purchase
	emit_signal("item_purchased", item_id, item_type)

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
