extends Control
class_name ShopUI

signal item_purchased(item_id: String, item_type: String)
signal shop_button_opened  # May be used by external listeners
signal shop_closed

@export var power_up_manager_path: NodePath
@export var consumable_manager_path: NodePath
@export var mod_manager_path: NodePath
@export var gaming_console_manager_path: NodePath

@onready var tab_container: TabContainer = $TabContainer
@onready var power_up_container: Container = $TabContainer/PowerUps/GridContainer
@onready var consumable_container: Container = $TabContainer/Consumables/GridContainer
@onready var mod_container: Container = $TabContainer/Mods/GridContainer
@onready var colored_dice_container: Container = get_node_or_null("TabContainer/Colors/GridContainer")
@onready var gaming_console_container: Container = get_node_or_null("TabContainer/Consoles/GridContainer")
@onready var locked_container: Container = $TabContainer/Locked/ScrollContainer/GridContainer
@onready var unlocked_container: Container = get_node_or_null("TabContainer/Unlocked/ScrollContainer/GridContainer")
@onready var power_up_manager: PowerUpManager = get_node_or_null(power_up_manager_path)
@onready var consumable_manager: ConsumableManager = get_node_or_null(consumable_manager_path)
@onready var mod_manager: ModManager = get_node_or_null(mod_manager_path)
@onready var gaming_console_manager: GamingConsoleManager = get_node_or_null(gaming_console_manager_path)
@onready var shop_label: RichTextLabel = $MarginContainer/ShopLabel
@onready var close_button: Button = $CloseButton
@onready var backdrop: ColorRect = $Backdrop
@onready var _tfx := get_node("/root/TweenFXHelper")

# Reroll system
var reroll_button: Button
var reroll_cost_label: Label
var reroll_cost: int = 25
var reroll_cooldown: float = 0.0
const REROLL_BASE_COST: int = 25
const REROLL_COST_INCREMENT: int = 5
const REROLL_COOLDOWN_TIME: float = 0.5
const REROLL_SHADER_PATH := "res://Scripts/Shaders/shop_reroll_button_glass.gdshader"

var _managers_ready := 0
const REQUIRED_MANAGERS := 3

# Title animation
const TITLE_FLOAT_AMOUNT := 8.0

const ShopItemScene := preload("res://Scenes/Shop/shop_item.tscn")

var items_per_section := 2  # Number of items to display per section
var power_up_items := 2     # Specific count for power-ups
var consumable_items := 2   # Specific count for consumables
var mod_items := 2          # Specific count for mods
var colored_dice_items := 2 # Specific count for colored dice

var purchased_items := {}  # Track purchased items by type: {"power_up": [], "consumable": [], "mod": [], "colored_dice": []}
var _tab_item_pools := {}
var _tab_page_indices := {}
var _footer_controls := {}
var _page_transitioning := {}
var _reroll_shells := {}
var _reroll_shader_materials := {}
var _reroll_title_labels := {}
var _reroll_price_labels := {}

const PAGE_SIZE := 3
const PAGED_ITEM_TYPES := ["power_up", "consumable", "mod", "colored_dice", "gaming_console"]
const FOOTER_REROLL_TYPES := ["power_up", "consumable"]

func _ready() -> void:
	print("[ShopUI] Initializing...")
	print("PowerUpManager path:", power_up_manager_path)
	print("ConsumableManager path:", consumable_manager_path)
	print("ModManager path:", mod_manager_path)
	
	# Set z_index so shop is above base UI but below fan-outs and pause menu
	z_index = 100

	# Initialize purchased items tracking
	purchased_items = {
		"power_up": [],
		"consumable": [],
		"mod": [],
		"colored_dice": [],
		"gaming_console": []
	}
	_initialize_page_state()
	
	if not shop_label:
		push_error("[ShopUI] ShopLabel not found!")
		return

	# Set up and style shop label with BRICK_SANS font
	_style_shop_title()
	
	# Start floating animation
	_start_title_animation()
	
	# Fix mouse input for background elements (do this early, before manager checks)
	_configure_mouse_input()

	if not colored_dice_container:
		print("[ShopUI] ColoredDiceContainer not found - creating programmatically")
		_create_colors_tab()
	if not gaming_console_container:
		print("[ShopUI] GamingConsoleContainer not found - creating programmatically")
		_create_consoles_tab()
	if not power_up_manager:
		push_error("[ShopUI] PowerUpManager not found at path:", power_up_manager_path)
	if not consumable_manager:
		push_error("[ShopUI] ConsumableManager not found at path:", consumable_manager_path)
	if not mod_manager:
		push_error("[ShopUI] ModManager not found at path:", mod_manager_path)
		return
		
	# Set up reroll footer state
	_setup_reroll_ui()
	
	# Style the tab container with VCR font and larger tabs
	_style_tab_container()
	
	_update_reroll_cost_display()
	_update_reroll_button_state()
	
	# Connect to tab changed signal for showing/hiding reroll button
	if tab_container:
		tab_container.tab_changed.connect(_on_tab_changed)
	
	# Set up backdrop click-to-close
	_setup_backdrop()
	
	# Style the close button
	_style_close_button()
		
	# Connect to manager ready signals
	power_up_manager.definitions_loaded.connect(_on_manager_ready)
	consumable_manager.definitions_loaded.connect(_on_manager_ready)
	mod_manager.definitions_loaded.connect(_on_manager_ready)
	PlayerEconomy.money_changed.connect(_on_money_changed)
	
	# Connect to GamingConsoleManager separately (it may load after other managers)
	if gaming_console_manager:
		gaming_console_manager.definitions_loaded.connect(_on_gaming_console_manager_ready)
	
	# Connect to ProgressManager to refresh shop when items are unlocked/locked
	var progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		if progress_manager.has_signal("item_unlocked"):
			progress_manager.item_unlocked.connect(func(_item_id: String, _item_type: String): _on_progress_changed())
		if progress_manager.has_signal("item_locked"):
			progress_manager.item_locked.connect(func(_item_id: String, _item_type: String): _on_progress_changed())
		if progress_manager.has_signal("progress_saved"):
			progress_manager.progress_saved.connect(_on_progress_changed)
	# Connect visibility for open animation
	visibility_changed.connect(_on_visibility_changed)
	hide()

func _on_visibility_changed() -> void:
	if visible:
		shop_button_opened.emit()
		_animate_shop_open()

## _animate_shop_open()
##
## Plays drop-in entrance animation for the shop panel, backdrop, label and close button.
func _animate_shop_open() -> void:
	if backdrop:
		backdrop.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(backdrop, "modulate:a", 0.75, 0.2)
	
	if tab_container:
		TweenFX.fly_in(tab_container, Vector2.DOWN, 150.0, 0.4)
	
	if shop_label:
		TweenFX.fly_in(shop_label, Vector2.DOWN, 80.0, 0.35, 0.15)
	
	if close_button:
		TweenFX.fly_in(close_button, Vector2.DOWN, 60.0, 0.3, 0.25)

func _exit_tree() -> void:
	if shop_label:
		_tfx.stop_effect(shop_label)

func _process(delta: float) -> void:
	# Handle reroll cooldown
	if reroll_cooldown > 0:
		reroll_cooldown -= delta
		if reroll_cooldown <= 0:
			reroll_cooldown = 0
			_update_reroll_button_state()

## _start_title_animation()
##
## Starts the floating animation for the shop title using TweenFXHelper.
func _start_title_animation() -> void:
	if not shop_label:
		return
	_tfx.idle_float(shop_label, TITLE_FLOAT_AMOUNT)

func _on_manager_ready() -> void:
	_managers_ready += 1
	print("[ShopUI] Manager ready. Waiting for", REQUIRED_MANAGERS - _managers_ready, "more")
	
	if _managers_ready == REQUIRED_MANAGERS:
		print("[ShopUI] All managers ready - populating shop")
		_populate_shop_items()
		populate_locked_items()
		populate_unlocked_items()

## _on_gaming_console_manager_ready()
##
## Called when GamingConsoleManager finishes loading definitions.
## If the other managers are already ready, repopulate to include consoles.
func _on_gaming_console_manager_ready() -> void:
	print("[ShopUI] GamingConsoleManager ready")
	if _managers_ready >= REQUIRED_MANAGERS:
		print("[ShopUI] Other managers already ready - repopulating to include consoles")
		_populate_shop_items()
		populate_locked_items()
		populate_unlocked_items()

## _on_progress_changed()
##
## Called when progress is updated (items unlocked/locked) to refresh shop display
func _on_progress_changed() -> void:
	print("[ShopUI] Progress changed - refreshing shop")
	if _managers_ready == REQUIRED_MANAGERS:
		_populate_shop_items()
		populate_locked_items()
		populate_unlocked_items()

func _populate_shop_items() -> void:
	print("\n=== Populating Shop Items ===")
	
	# Clear existing containers
	_clear_shop_containers()
	_reset_page_indices()

	_set_tab_item_pool("power_up", _build_power_up_pool())
	_set_tab_item_pool("consumable", _build_consumable_pool())
	_set_tab_item_pool("mod", _build_mod_pool())
	_set_tab_item_pool("colored_dice", _build_colored_dice_pool())
	_set_tab_item_pool("gaming_console", _build_gaming_console_pool())

	for item_type in PAGED_ITEM_TYPES:
		_render_current_page(item_type)

func _build_power_up_pool() -> Array:
	var power_up_page_items: Array = []
	var power_ups = power_up_manager.get_available_power_ups()
	var filtered_power_ups = _filter_out_purchased_items(power_ups, "power_up")
	filtered_power_ups = _filter_unlocked_items(filtered_power_ups, "power_up")
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		filtered_power_ups = filtered_power_ups.filter(func(id): return not game_controller.active_power_ups.has(id))
	var selected_power_ups = _select_random_items(filtered_power_ups, power_up_items)
	for id in selected_power_ups:
		var data = power_up_manager.get_def(id)
		if data:
			power_up_page_items.append(data)
		else:
			push_error("[ShopUI] Failed to get PowerUpData for:", id)
	return power_up_page_items

func _build_consumable_pool() -> Array:
	var consumable_page_items: Array = []
	var consumables = consumable_manager._defs_by_id.keys()
	var filtered_consumables = _filter_out_purchased_items(consumables, "consumable")
	filtered_consumables = _filter_unlocked_items(filtered_consumables, "consumable")
	var selected_consumables = _select_random_items(filtered_consumables, consumable_items)
	for id in selected_consumables:
		var data = consumable_manager.get_def(id)
		if data:
			consumable_page_items.append(data)
		else:
			push_error("[ShopUI] Failed to get ConsumableData for:", id)
	return consumable_page_items

func _build_mod_pool() -> Array:
	var mod_page_items: Array = []
	var mods = mod_manager._defs_by_id.keys()
	var filtered_mods = _filter_out_purchased_items(mods, "mod")
	filtered_mods = _filter_unlocked_items(filtered_mods, "mod")
	var selected_mods = _select_random_items(filtered_mods, mod_items)
	for id in selected_mods:
		var data = mod_manager.get_def(id)
		if data:
			mod_page_items.append(data)
		else:
			push_error("[ShopUI] Failed to get ModData for:", id)
	return mod_page_items

func _build_colored_dice_pool() -> Array:
	var colored_dice_page_items: Array = []
	var colored_dice = DiceColorManager.get_available_colored_dice()
	var colored_dice_ids: Array = []
	for data in colored_dice:
		colored_dice_ids.append(data.id)
	var filtered_colored_dice = _filter_out_max_odds_colored_dice(colored_dice_ids)
	filtered_colored_dice = _filter_unlocked_items(filtered_colored_dice, "colored_dice")
	var selected_colored_dice = _select_random_items(filtered_colored_dice, colored_dice_items)
	for id in selected_colored_dice:
		var data = DiceColorManager.get_colored_dice_data(id)
		if data:
			colored_dice_page_items.append(data)
		else:
			push_error("[ShopUI] Failed to get ColoredDiceData for:", id)
	return colored_dice_page_items

func _build_gaming_console_pool() -> Array:
	var gaming_console_page_items: Array = []
	if not gaming_console_manager:
		return gaming_console_page_items
	var consoles = gaming_console_manager.get_available_consoles()
	var filtered_consoles = _filter_out_purchased_items(consoles, "gaming_console")
	filtered_consoles = _filter_unlocked_items(filtered_consoles, "gaming_console")
	for id in filtered_consoles:
		var data = gaming_console_manager.get_def(id)
		if data:
			gaming_console_page_items.append(data)
		else:
			push_error("[ShopUI] Failed to get GamingConsoleData for:", id)
	return gaming_console_page_items

# Helper function to filter out already purchased items
func _filter_out_purchased_items(items: Array, type: String) -> Array:
	var result = []
	for item in items:
		if not purchased_items[type].has(item):
			result.append(item)
	return result

## _filter_out_max_odds_colored_dice()
##
## Filters out colored dice that have reached their maximum odds (1:1).
## Unlike other item types, colored dice can be purchased multiple times
## until they reach MAX odds.
func _filter_out_max_odds_colored_dice(dice_ids: Array) -> Array:
	var result = []
	for id in dice_ids:
		var data = DiceColorManager.get_colored_dice_data(id)
		if data and not DiceColorManager.is_color_at_max_odds(data.color_type):
			result.append(id)
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
		_clear_item_container(power_up_container)
	
	if consumable_container:
		_clear_item_container(consumable_container)
	
	if mod_container:
		_clear_item_container(mod_container)
	
	if colored_dice_container:
		_clear_item_container(colored_dice_container)
	
	if gaming_console_container:
		_clear_item_container(gaming_console_container)

func _clear_item_container(container: Container) -> void:
	if not container:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _initialize_page_state() -> void:
	for item_type in PAGED_ITEM_TYPES:
		_tab_item_pools[item_type] = []
		_tab_page_indices[item_type] = 0
		_page_transitioning[item_type] = false
		_footer_controls[item_type] = {}

func _reset_page_indices() -> void:
	for item_type in PAGED_ITEM_TYPES:
		_tab_page_indices[item_type] = 0

func _set_tab_item_pool(item_type: String, items: Array) -> void:
	_tab_item_pools[item_type] = items.duplicate()
	_tab_page_indices[item_type] = clampi(_tab_page_indices.get(item_type, 0), 0, _get_max_page_index(item_type))

func _get_tab_item_pool(item_type: String) -> Array:
	return _tab_item_pools.get(item_type, [])

func _get_page_count(item_type: String) -> int:
	var items = _get_tab_item_pool(item_type)
	if items.is_empty():
		return 0
	return int(ceil(float(items.size()) / float(PAGE_SIZE)))

func _get_max_page_index(item_type: String) -> int:
	return maxi(0, _get_page_count(item_type) - 1)

func _get_page_items(item_type: String) -> Array:
	var items = _get_tab_item_pool(item_type)
	if items.is_empty():
		return []
	var page_index = clampi(_tab_page_indices.get(item_type, 0), 0, _get_max_page_index(item_type))
	var start_index = page_index * PAGE_SIZE
	var end_index = min(start_index + PAGE_SIZE, items.size())
	var page_items: Array = []
	for i in range(start_index, end_index):
		page_items.append(items[i])
	return page_items

func _get_tab_name_for_type(item_type: String) -> String:
	match item_type:
		"power_up":
			return "PowerUps"
		"consumable":
			return "Consumables"
		"mod":
			return "Mods"
		"colored_dice":
			return "Colors"
		"gaming_console":
			return "Consoles"
	return ""

func _get_type_for_tab_name(tab_name: String) -> String:
	match tab_name:
		"PowerUps":
			return "power_up"
		"Consumables":
			return "consumable"
		"Mods":
			return "mod"
		"Colors":
			return "colored_dice"
		"Consoles":
			return "gaming_console"
	return ""

func _get_type_for_tab_index(tab_index: int) -> String:
	match tab_index:
		0:
			return "power_up"
		1:
			return "consumable"
		2:
			return "mod"
		3:
			return "colored_dice"
		4:
			return "gaming_console"
	return ""

func _has_multiple_pages(item_type: String) -> bool:
	return _get_page_count(item_type) > 1

func _get_page_motion_vector(step: int) -> Vector2:
	return Vector2.LEFT if step > 0 else Vector2.RIGHT

func _set_page_index(item_type: String, page_index: int) -> void:
	_tab_page_indices[item_type] = clampi(page_index, 0, _get_max_page_index(item_type))

func _render_current_page(item_type: String) -> void:
	var container = _get_container_for_type(item_type)
	if not container:
		return
	_set_page_index(item_type, _tab_page_indices.get(item_type, 0))
	_clear_item_container(container)
	for data in _get_page_items(item_type):
		_add_shop_item(data, item_type)
	_update_footer_state(item_type)

func _change_page(item_type: String, step: int) -> void:
	if not PAGED_ITEM_TYPES.has(item_type):
		return
	if _page_transitioning.get(item_type, false):
		return
	var current_index = _tab_page_indices.get(item_type, 0)
	var target_index = clampi(current_index + step, 0, _get_max_page_index(item_type))
	if target_index == current_index:
		return

	_page_transitioning[item_type] = true
	_update_footer_state(item_type)

	var container := _get_container_for_type(item_type) as Container
	var motion_vector := _get_page_motion_vector(step)
	var items := _get_shop_items(container)
	var last_tween := _animate_items_out(items, motion_vector)
	if last_tween:
		await last_tween.finished

	_clear_item_container(container)
	await get_tree().process_frame

	_set_page_index(item_type, target_index)
	_render_current_page(item_type)
	await get_tree().process_frame

	items = _get_shop_items(container)
	_animate_items_in(items, motion_vector)
	_page_transitioning[item_type] = false
	_update_footer_state(item_type)

func _on_page_arrow_pressed(item_type: String, step: int) -> void:
	_change_page(item_type, step)

func _remove_item_from_pool(item_id: String, item_type: String) -> void:
	var filtered_items: Array = []
	for data in _get_tab_item_pool(item_type):
		if data and data.id != item_id:
			filtered_items.append(data)
	_set_tab_item_pool(item_type, filtered_items)

func _refresh_page_after_purchase(item_type: String) -> void:
	_set_page_index(item_type, _tab_page_indices.get(item_type, 0))
	_render_current_page(item_type)
	_update_reroll_button_state()

# Add this function to reset purchased items for a new round
func reset_for_new_round() -> void:
	print("[ShopUI] Resetting shop for new round")
	purchased_items = {
		"power_up": [],
		"consumable": [], 
		"mod": [],
		"colored_dice": [],
		"gaming_console": []
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
		
		# Check if this color type is at max odds (1:1) - no more purchases allowed
		if DiceColorManager.is_color_at_max_odds(colored_dice_data.color_type):
			print("[ShopUI] Color type at MAX odds, cannot purchase more:", colored_dice_data.get_color_name())
			return
		
		print("[ShopUI] Colored dice purchase validation passed for:", colored_dice_data.get_color_name())
	# Check if it's a gaming console purchase
	elif item_type == "gaming_console":
		# Only one console allowed at a time — check if player already has one
		var gc = _find_game_controller()
		if gc and gc.has_method("has_gaming_console"):
			if gc.has_gaming_console():
				print("[ShopUI] Player already has a gaming console, purchase blocked")
				return
	
	print("[ShopUI] Purchase validation passed, proceeding with purchase")

	# Record that this item was purchased (for statistics)
	if not purchased_items[item_type].has(item_id):
		purchased_items[item_type].append(item_id)
		print("[ShopUI] Added", item_id, "to purchased items list")

	# Grant the purchase immediately. The removal animation runs independently
	# so a killed tween cannot block the grant (see _remove_shop_item).
	print("[ShopUI] Emitting item_purchased signal for:", item_id, "type:", item_type)
	emit_signal("item_purchased", item_id, item_type)
	_remove_item_from_pool(item_id, item_type)

	# Remove the item from the shop after purchase.
	# For colored dice: removed this turn, but available again next turn (not tracked in purchased_items for filtering)
	print("[ShopUI] Removing shop item:", item_id, "type:", item_type)
	_remove_shop_item(item_id, item_type)

## _remove_shop_item(item_id, item_type)
##
## Finds the matching ShopItem and starts a purchase-out animation.
## The animation is fire-and-forget; the caller must already have emitted
## item_purchased so the grant cannot be blocked by the tween.
func _remove_shop_item(item_id: String, item_type: String) -> void:
	var container = _get_container_for_type(item_type)
	if not container:
		push_error("[ShopUI] No container found for type:", item_type)
		return

	# Find and remove the shop item with matching ID
	for child in container.get_children():
		if child is ShopItem and child.item_id == item_id:
			_animate_purchase_out(child)
			var refresh_timer := get_tree().create_timer(0.34)
			refresh_timer.timeout.connect(func(): _refresh_page_after_purchase(item_type))
			print("[ShopUI] Started removal for shop item:", item_id)
			break

## _animate_purchase_out(item)
##
## Flashes the item border gold, then slides it up and fades it out before freeing.
## Uses a local tween (not TweenFX) so hover effects on the dying card cannot
## kill the removal tween and leave an invisible, input-blocking node behind.
func _animate_purchase_out(item: ShopItem) -> void:
	if not is_instance_valid(item):
		return

	# Tell the card it is being removed: stops hover juice, hides tooltip, and
	# blocks all mouse input on the card and its children.
	item.mark_for_removal()

	# Flash the hanging panel briefly before it slides away.
	if item.card_panel:
		item.card_panel.self_modulate = Color.WHITE
		var flash_tween := create_tween()
		flash_tween.tween_property(item.card_panel, "self_modulate", Color(1.0, 0.92, 0.72, 1.0), 0.08)
		flash_tween.tween_property(item.card_panel, "self_modulate", Color.WHITE, 0.12)

	# Use a local tween so TweenFXHelper.stop_effect() cannot kill it.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(item, "position", item.position + Vector2.UP * 40.0, 0.25)
	tween.parallel().tween_property(item, "modulate:a", 0.0, 0.25)

	# Capture the item ID and a weak reference before the tween starts so the
	# finished callback never accesses a freed node.
	var weak_item: WeakRef = weakref(item)
	var captured_id: String = item.item_id

	tween.finished.connect(func():
		var target = weak_item.get_ref()
		if is_instance_valid(target):
			print("[ShopUI] Freed shop item:", captured_id)
			target.queue_free()
	)

	# Safety timer: if the tween fails to finish, free the node anyway.
	var fallback_timer := get_tree().create_timer(0.5)
	fallback_timer.timeout.connect(func():
		var target = weak_item.get_ref()
		if is_instance_valid(target):
			print("[ShopUI] Fallback free for shop item:", captured_id)
			target.queue_free()
	)

# Helper function to find PowerUpUI
func _find_power_up_ui() -> PowerUpUI:
	# Try direct path first via GameUI
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		var power_up_ui = game_controller.get_node_or_null("../GameUI/MarginContainer/MainVBox/UpperSection/PowerUpContainer/ContentVBox/PowerUpUI")
		if power_up_ui:
			return power_up_ui
	
	# Fall back to searching the tree
	return get_tree().get_first_node_in_group("power_up_ui")

# Add helper function to find ConsumableUI
func _find_consumable_ui() -> ConsumableUI:
	# Try direct path first via GameUI
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		var consumable_ui = game_controller.get_node_or_null("../GameUI/MarginContainer/MainVBox/MiddleSection/LeftColumn/ConsumableContainer/ContentVBox/ConsumableUI") as ConsumableUI
		if consumable_ui:
			return consumable_ui
	
	# Fall back to searching the tree
	return get_tree().get_first_node_in_group("consumable_ui") as ConsumableUI

# Helper function to find GameController
func _find_game_controller() -> GameController:
	return get_tree().get_first_node_in_group("game_controller") as GameController


## on_shop_opened()
##
## Called by GameController when the shop is opened.
## Refreshes all item prices and reroll display to reflect current discount state.
func on_shop_opened() -> void:
	refresh_all_prices()
	_update_reroll_cost_display()
	_update_reroll_button_state()
	tab_container.current_tab = 0  # Default to first tab

## refresh_all_prices()
##
## Iterates all ShopItem children in power_up and consumable containers
## and calls refresh_price() on each. Called when discount state changes.
func refresh_all_prices() -> void:
	for container in [power_up_container, consumable_container, gaming_console_container]:
		if not container:
			continue
		for child in container.get_children():
			if child is ShopItem:
				child.refresh_price()

# Helper function to check if mod limit has been reached
func _has_reached_mod_limit(game_controller: GameController) -> bool:
	if not game_controller:
		return false
	
	var current_mod_count = game_controller._get_total_active_mod_count()
	# Use expected dice count instead of current dice list size to handle pre-spawn scenario
	var expected_dice_count = game_controller._get_expected_dice_count()
	
	return current_mod_count >= expected_dice_count

func _on_close_button_pressed() -> void:
	# Reset Clearance Rack on shop close
	var game_controller = _find_game_controller()
	if game_controller and game_controller.clearance_rack_active:
		game_controller.clearance_rack_active = false
		print("[ShopUI] Clearance Rack expired on shop close")
	
	shop_closed.emit()
	# Notify tutorial system about shop being closed
	var tutorial_manager = get_node_or_null("/root/TutorialManager")
	if tutorial_manager and tutorial_manager.is_active:
		tutorial_manager.action_completed("close_shop")
	hide()

## _setup_reroll_ui()
## Prepares the state dictionaries used by the footer reroll shells.
func _setup_reroll_ui() -> void:
	print("[ShopUI] Preparing reroll footer state")
	reroll_button = null
	reroll_cost_label = null
	_reroll_shells.clear()
	_reroll_shader_materials.clear()
	_reroll_title_labels.clear()
	_reroll_price_labels.clear()

## _apply_footer_arrow_button_styling(button)
## Applies themed styling to the footer pagination arrows.
func _apply_footer_arrow_button_styling(button: Button) -> void:
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font:
		button.add_theme_font_override("font", vcr_font)
		button.add_theme_font_size_override("font_size", 22)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.16, 0.28, 0.95)
	style_normal.border_color = Color(0.85, 0.75, 0.28, 0.95)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(12)
	style_normal.content_margin_left = 10.0
	style_normal.content_margin_top = 8.0
	style_normal.content_margin_right = 10.0
	style_normal.content_margin_bottom = 8.0
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.14, 0.24, 0.38, 0.98)
	style_hover.border_color = Color(1.0, 0.86, 0.38, 1.0)
	style_hover.set_border_width_all(3)
	style_hover.set_corner_radius_all(12)
	style_hover.content_margin_left = 10.0
	style_hover.content_margin_top = 8.0
	style_hover.content_margin_right = 10.0
	style_hover.content_margin_bottom = 8.0
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.2, 0.28, 0.45, 1.0)
	style_pressed.border_color = Color(1.0, 0.92, 0.55, 1.0)
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(12)
	style_pressed.content_margin_left = 10.0
	style_pressed.content_margin_top = 6.0
	style_pressed.content_margin_right = 10.0
	style_pressed.content_margin_bottom = 6.0
	
	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.12, 0.12, 0.16, 0.72)
	style_disabled.border_color = Color(0.34, 0.34, 0.42, 0.72)
	style_disabled.set_border_width_all(2)
	style_disabled.set_corner_radius_all(12)
	style_disabled.content_margin_left = 10.0
	style_disabled.content_margin_top = 8.0
	style_disabled.content_margin_right = 10.0
	style_disabled.content_margin_bottom = 8.0
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_disabled)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.58, 0.66, 1))
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	button.add_theme_constant_override("outline_size", 1)

func _update_footer_state(item_type: String) -> void:
	var controls: Dictionary = _footer_controls.get(item_type, {})
	if controls.is_empty():
		return
	var left_button = controls.get("left_button") as Button
	var right_button = controls.get("right_button") as Button
	var show_arrows = _has_multiple_pages(item_type)
	var page_index = _tab_page_indices.get(item_type, 0)
	var is_transitioning = _page_transitioning.get(item_type, false)
	if left_button:
		left_button.visible = show_arrows
		left_button.disabled = not show_arrows or is_transitioning or page_index <= 0
	if right_button:
		right_button.visible = show_arrows
		right_button.disabled = not show_arrows or is_transitioning or page_index >= _get_max_page_index(item_type)

## _update_reroll_cost_display()
## Updates the inline reroll footer labels for the PowerUps and Consumables tabs.
func _update_reroll_cost_display() -> void:
	var game_controller = _find_game_controller()
	var free_reroll = game_controller and game_controller.clearance_rack_active
	for item_type in FOOTER_REROLL_TYPES:
		var title_label = _reroll_title_labels.get(item_type) as Label
		var price_label = _reroll_price_labels.get(item_type) as Label
		if title_label:
			title_label.text = "REROLL"
		if price_label:
			if free_reroll:
				price_label.text = "FREE"
				price_label.modulate = Color(0.92, 1.0, 0.64, 1.0)
			else:
				price_label.text = "$%s" % NumberFormatter.format_int(reroll_cost)
				price_label.modulate = Color(0.56, 1.0, 0.7, 1.0)

## _animate_reroll_cost_bounce()
## Animates the inline cost label and shader flash for the currently selected reroll tab.
func _animate_reroll_cost_bounce() -> void:
	var item_type = _get_type_for_tab_index(tab_container.current_tab if tab_container else -1)
	if not FOOTER_REROLL_TYPES.has(item_type):
		return
	var price_label = _reroll_price_labels.get(item_type) as Label
	if not price_label:
		return
	var original_scale = price_label.scale
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(price_label, "scale", original_scale * Vector2(1.18, 1.18), 0.12)
	tween.tween_property(price_label, "scale", original_scale, 0.18)
	_flash_reroll_shader(item_type, 0.95)

## _on_reroll_button_pressed()
## Handles reroll button press - rerolls items in current tab
func _on_reroll_button_pressed() -> void:
	# Check cooldown
	if reroll_cooldown > 0:
		print("[ShopUI] Reroll on cooldown")
		return
	
	# Check if Clearance Rack is active (free rerolls)
	var game_controller = _find_game_controller()
	var free_reroll = game_controller and game_controller.clearance_rack_active
	
	# Check if player can afford (skip if free reroll)
	if not free_reroll and not PlayerEconomy.can_afford(reroll_cost):
		print("[ShopUI] Cannot afford reroll - cost:", reroll_cost)
		return
	
	# Check current tab
	var current_tab = tab_container.current_tab if tab_container else -1
	if current_tab != 0 and current_tab != 1:
		print("[ShopUI] Reroll not available on this tab")
		return
	
	# Deduct money (skip if free reroll)
	var item_type = "power_up" if current_tab == 0 else "consumable"
	if free_reroll:
		print("[ShopUI] Free reroll (Clearance Rack) for %s items" % item_type)
	else:
		PlayerEconomy.remove_money(reroll_cost, "reroll_" + item_type)
		print("[ShopUI] Rerolling %s items for $%d" % [item_type, reroll_cost])
	
	# Set cooldown
	reroll_cooldown = REROLL_COOLDOWN_TIME
	_update_reroll_button_state()
	
	# Increment cost for next reroll
	reroll_cost += REROLL_COST_INCREMENT
	_update_reroll_cost_display()
	_animate_reroll_cost_bounce()
	
	# Reroll the appropriate items
	if current_tab == 0:
		_reroll_power_ups()
	else:
		_reroll_consumables()

## _reroll_power_ups()
## Clears and repopulates power-up items
func _reroll_power_ups() -> void:
	print("[ShopUI] Rerolling power-up items")
	
	var items := _get_shop_items(power_up_container)
	var last_tween := _animate_items_out(items, Vector2.LEFT)
	if last_tween:
		await last_tween.finished
	
	_clear_item_container(power_up_container)
	await get_tree().process_frame
	
	_set_page_index("power_up", 0)
	_set_tab_item_pool("power_up", _build_power_up_pool())
	_render_current_page("power_up")
	await get_tree().process_frame
	items = _get_shop_items(power_up_container)
	_animate_items_in(items, Vector2.RIGHT)
	
	_update_reroll_button_state()

## _reroll_consumables()
## Clears and repopulates consumable items with fly-out / fly-in animation.
func _reroll_consumables() -> void:
	print("[ShopUI] Rerolling consumable items")
	
	var items := _get_shop_items(consumable_container)
	var last_tween := _animate_items_out(items, Vector2.LEFT)
	if last_tween:
		await last_tween.finished
	
	_clear_item_container(consumable_container)
	await get_tree().process_frame
	
	_set_page_index("consumable", 0)
	_set_tab_item_pool("consumable", _build_consumable_pool())
	_render_current_page("consumable")
	await get_tree().process_frame
	items = _get_shop_items(consumable_container)
	_animate_items_in(items, Vector2.RIGHT)
	
	_update_reroll_button_state()

func _has_available_reroll_items(item_type: String) -> bool:
	if item_type == "power_up":
		var filtered = _filter_out_purchased_items(power_up_manager.get_available_power_ups(), "power_up")
		filtered = _filter_unlocked_items(filtered, "power_up")
		var game_controller = get_tree().get_first_node_in_group("game_controller")
		if game_controller:
			filtered = filtered.filter(func(id): return not game_controller.active_power_ups.has(id))
		return filtered.size() > 0
	if item_type == "consumable":
		var filtered = _filter_out_purchased_items(consumable_manager._defs_by_id.keys(), "consumable")
		filtered = _filter_unlocked_items(filtered, "consumable")
		return filtered.size() > 0
	return false

## _update_reroll_button_state()
## Updates the reroll button enabled/disabled state based on available items and money
## Now updates all reroll buttons across tabs
func _update_reroll_button_state() -> void:
	_update_reroll_cost_display()
	var game_controller_ref = _find_game_controller()
	var free_reroll = game_controller_ref and game_controller_ref.clearance_rack_active
	for item_type in FOOTER_REROLL_TYPES:
		var controls: Dictionary = _footer_controls.get(item_type, {})
		var center_control = controls.get("center_control") as Control
		if not center_control:
			continue
		var tab_button = center_control.get_node_or_null("RerollButton") as Button
		if not tab_button:
			continue
		var disabled = false
		if reroll_cooldown > 0:
			disabled = true
		elif not free_reroll and not PlayerEconomy.can_afford(reroll_cost):
			disabled = true
		else:
			disabled = not _has_available_reroll_items(item_type)
		tab_button.disabled = disabled
		_set_reroll_disabled_visual(item_type, disabled)

	for item_type in PAGED_ITEM_TYPES:
		_update_footer_state(item_type)

## _on_tab_changed(tab_index: int)
## Called when the shop tab changes - shows/hides reroll button accordingly
func _on_tab_changed(tab_index: int) -> void:
	print("[ShopUI] Tab changed to index:", tab_index)
	
	# Play tab switch sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_tab_switch()
	
	_update_reroll_button_state()
	var item_type = _get_type_for_tab_index(tab_index)
	if item_type != "":
		_update_footer_state(item_type)
	
	# Animate items in the newly selected purchasable tab.
	var container := _get_container_for_tab_index(tab_index)
	if container and item_type != "":
		# Wait one frame so the container finishes its sort pass
		# (items in a freshly-visible tab share the same uncalculated position until sorted)
		await get_tree().process_frame
		var direction := Vector2.RIGHT if tab_index % 2 == 0 else Vector2.LEFT
		var items := _get_shop_items(container)
		_animate_items_in(items, direction)

## reset_reroll_cost()
## Resets the reroll cost to base value - called on new game
func reset_reroll_cost() -> void:
	reroll_cost = REROLL_BASE_COST
	reroll_cooldown = 0
	_update_reroll_cost_display()
	_update_reroll_button_state()
	print("[ShopUI] Reroll cost reset to $%d" % reroll_cost)


## reset_shop_expansions()
## Resets all shop expansion counts back to default values - called on new game/channel
func reset_shop_expansions() -> void:
	items_per_section = 2
	power_up_items = 2
	consumable_items = 2
	mod_items = 2
	colored_dice_items = 2
	print("[ShopUI] Shop expansions reset to default (2 items per section)")

## _setup_backdrop()
## Sets up the backdrop for click-to-close functionality
func _setup_backdrop() -> void:
	if backdrop:
		backdrop.gui_input.connect(_on_backdrop_gui_input)
		print("[ShopUI] Backdrop click-to-close connected")

## _on_backdrop_gui_input(event: InputEvent)
## Handles clicks on the backdrop to close the shop
func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			print("[ShopUI] Backdrop clicked - closing shop")
			_on_close_button_pressed()

## _style_close_button()
## Styles the close button to match tab container size
func _style_close_button() -> void:
	if not close_button:
		return
	
	print("[ShopUI] Styling close button")
	
	# Set size to match tab height (40px)
	close_button.custom_minimum_size = Vector2(20, 20)
	
	# Load VCR font
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font:
		close_button.add_theme_font_override("font", vcr_font)
		close_button.add_theme_font_size_override("font_size", 14)
	
	# Style the button
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.5, 0.15, 0.15, 0.95)  # Dark red
	style_normal.border_color = Color(1, 0.4, 0.4, 1)     # Red border
	style_normal.set_border_width_all(2)
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.corner_radius_bottom_left = 6
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.6, 0.2, 0.2, 0.98)
	style_hover.border_color = Color(1, 0.5, 0.5, 1)
	style_hover.set_border_width_all(3)
	style_hover.corner_radius_top_left = 6
	style_hover.corner_radius_top_right = 6
	style_hover.corner_radius_bottom_right = 6
	style_hover.corner_radius_bottom_left = 6
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.7, 0.25, 0.25, 1)
	style_pressed.border_color = Color(1, 0.6, 0.6, 1)
	style_pressed.set_border_width_all(2)
	style_pressed.corner_radius_top_left = 6
	style_pressed.corner_radius_top_right = 6
	style_pressed.corner_radius_bottom_right = 6
	style_pressed.corner_radius_bottom_left = 6
	
	close_button.add_theme_stylebox_override("normal", style_normal)
	close_button.add_theme_stylebox_override("hover", style_hover)
	close_button.add_theme_stylebox_override("pressed", style_pressed)
	close_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	close_button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	close_button.add_theme_constant_override("outline_size", 1)
	
	# TweenFX hover/press feedback
	close_button.mouse_entered.connect(_tfx.button_hover.bind(close_button))
	close_button.mouse_exited.connect(_tfx.button_unhover.bind(close_button))
	close_button.pressed.connect(_tfx.button_press.bind(close_button))
	close_button.text = "X"

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
		"gaming_console":
			print("[ShopUI] Getting gaming console container")
			return gaming_console_container
		_:
			push_error("[ShopUI] Unknown item type:", type)
			return null

## _get_container_for_tab_index(tab_index)
##
## Returns the item container for the given TabContainer tab index.
func _get_container_for_tab_index(tab_index: int) -> Container:
	match tab_index:
		0: return power_up_container
		1: return consumable_container
		2: return mod_container
		3: return colored_dice_container
		4: return gaming_console_container
		5: return locked_container
		6: return unlocked_container
	return null

## _get_shop_items(container)
##
## Collects all ShopItem instances inside a container.
func _get_shop_items(container: Container) -> Array[ShopItem]:
	var items: Array[ShopItem] = []
	if not container:
		return items
	for child in container.get_children():
		if child is ShopItem:
			items.append(child)
	return items

## _animate_items_in(items, direction)
##
## Plays a staggered fly-in entrance on an array of shop items.
func _animate_items_in(items: Array[ShopItem], direction: Vector2 = Vector2.RIGHT) -> void:
	for i in range(items.size()):
		var item := items[i]
		var delay := i * 0.06
		TweenFX.fly_in(item, direction, 120.0, 0.35, delay)

## _animate_items_out(items, direction)
##
## Plays a staggered fly-out exit on an array of shop items.
## Returns the last Tween so callers can await completion.
func _animate_items_out(items: Array[ShopItem], direction: Vector2 = Vector2.LEFT) -> Tween:
	var last_tween: Tween = null
	for i in range(items.size()):
		var item := items[i]
		var delay := i * 0.04
		last_tween = TweenFX.fly_out(item, direction, 80.0, 0.3, delay)
	return last_tween

func _on_money_changed(_new_amount: int, _change: int = 0) -> void:
	# Update all shop item buttons in all containers
	for container in [power_up_container, consumable_container, mod_container, colored_dice_container, gaming_console_container]:
		if container:
			for child in container.get_children():
				if child is ShopItem:
					child._update_button_state()
	_update_reroll_button_state()

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
		tab_container.add_theme_font_size_override("font_size", 22)  # Larger font size
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
	var containers = [power_up_container, consumable_container, mod_container, colored_dice_container, gaming_console_container]
	
	for container in containers:
		if container:
			# Set columns to create more centered layout (only for GridContainer)
			# Skip gaming_console_container — it uses 3 columns set in _replace_grid_with_centered_layout
			if container is GridContainer and container != gaming_console_container:
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
## Items will remain centered regardless of how many items are in the shop
## Also adds shelf background and reroll UI to PowerUps and Consumables tabs
func _replace_grid_with_centered_layout() -> void:
	print("[ShopUI] Attempting to improve container layout for centering")
	
	var tab_nodes = [
		tab_container.get_node_or_null("PowerUps"),
		tab_container.get_node_or_null("Consumables"), 
		tab_container.get_node_or_null("Mods"),
		tab_container.get_node_or_null("Colors"),
		tab_container.get_node_or_null("Consoles")
	]
	
	for i in range(tab_nodes.size()):
		var tab_node = tab_nodes[i]
		if not tab_node:
			continue
		if tab_node.get_node_or_null("MarginContainer"):
			continue
			
		var grid = tab_node.get_node_or_null("GridContainer")
		if not grid:
			continue
		
		print("[ShopUI] Creating centered layout for tab:", tab_node.name)
		
		# For PowerUps, Consumables, and Consoles tabs, add shelf background
		var is_reroll_tab = tab_node.name == "PowerUps" or tab_node.name == "Consumables"
		var needs_shelf = is_reroll_tab or tab_node.name == "Consoles"
		if needs_shelf:
			_add_shelf_background_to_tab(tab_node)
		
		# Create margin container for padding from edges - this fills the tab
		var margin_container = MarginContainer.new()
		margin_container.name = "MarginContainer"
		margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin_container.add_theme_constant_override("margin_left", 50)
		margin_container.add_theme_constant_override("margin_right", 50)
		margin_container.add_theme_constant_override("margin_top", 30)
		# Reserve footer space for all paged tabs.
		var item_type = _get_type_for_tab_name(tab_node.name)
		var bottom_margin = 100 if item_type != "" else 30
		margin_container.add_theme_constant_override("margin_bottom", bottom_margin)
		
		# Create a centered VBox container that centers content vertically
		var main_vbox = VBoxContainer.new()
		main_vbox.name = "CenteredContainer"
		main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Create a single-row container for the current page slice.
		var item_container := HBoxContainer.new()
		item_container.name = "ItemContainer"
		item_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		item_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item_container.alignment = BoxContainer.ALIGNMENT_CENTER
		item_container.add_theme_constant_override("separation", 40)
		
		# Move children from grid to item_container
		var children_to_move = []
		for child in grid.get_children():
			children_to_move.append(child)
		
		for child in children_to_move:
			grid.remove_child(child)
			item_container.add_child(child)
		
		# Build the hierarchy: tab -> margin -> main_vbox -> item_container -> items
		main_vbox.add_child(item_container)
		margin_container.add_child(main_vbox)
		tab_node.add_child(margin_container)
		
		# Hide the old grid (keep it for fallback)
		grid.visible = false
		
		# Update container references
		if tab_node.name == "PowerUps":
			power_up_container = item_container
		elif tab_node.name == "Consumables":
			consumable_container = item_container
		elif tab_node.name == "Mods":
			mod_container = item_container
		elif tab_node.name == "Colors":
			colored_dice_container = item_container
		elif tab_node.name == "Consoles":
			gaming_console_container = item_container

		if item_type != "":
			_add_footer_ui_to_tab(tab_node, item_type)
		
		print("[ShopUI] Created centered layout for:", tab_node.name)

## _add_shelf_background_to_tab(tab_node)
## Adds the Blockbuster shelf background to a tab
func _add_shelf_background_to_tab(tab_node: Control) -> void:
	print("[ShopUI] Adding shelf background to tab:", tab_node.name)
	
	# Create a TextureRect for the shelf background
	var shelf_bg = TextureRect.new()
	shelf_bg.name = "ShelfBackground"
	
	# Load the shelf texture
	var shelf_texture = load("res://Resources/Art/UI/blockbuster_shelf.png")
	if shelf_texture:
		shelf_bg.texture = shelf_texture
		shelf_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shelf_bg.stretch_mode = TextureRect.STRETCH_TILE  # Tile the texture
		shelf_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		shelf_bg.modulate = Color(1, 1, 1, 0.3)  # Semi-transparent
		shelf_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shelf_bg.z_index = -1  # Behind items
		
		# Add as first child so it's behind everything else
		tab_node.add_child(shelf_bg)
		tab_node.move_child(shelf_bg, 0)
		
		print("[ShopUI] Shelf background added to:", tab_node.name)
	else:
		print("[ShopUI] WARNING: Could not load shelf texture")

## _add_footer_ui_to_tab(tab_node, item_type)
## Adds the bottom footer row with pagination arrows and reroll shell when applicable.
func _add_footer_ui_to_tab(tab_node: Control, item_type: String) -> void:
	print("[ShopUI] Adding footer UI to tab:", tab_node.name)
	var footer_container = MarginContainer.new()
	footer_container.name = "Footer_" + tab_node.name
	footer_container.anchor_left = 0.0
	footer_container.anchor_right = 1.0
	footer_container.anchor_top = 1.0
	footer_container.anchor_bottom = 1.0
	footer_container.offset_left = 44.0
	footer_container.offset_right = -44.0
	footer_container.offset_top = -86.0
	footer_container.offset_bottom = -10.0
	footer_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var footer_row = HBoxContainer.new()
	footer_row.name = "FooterRow"
	footer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_row.add_theme_constant_override("separation", 18)
	footer_container.add_child(footer_row)
	
	var left_button = _create_footer_arrow_button(item_type, -1, "LeftArrow", "<")
	var right_button = _create_footer_arrow_button(item_type, 1, "RightArrow", ">")
	footer_row.add_child(left_button)
	
	var center_control: Control
	if FOOTER_REROLL_TYPES.has(item_type):
		center_control = _create_reroll_center_control(item_type)
	else:
		var spacer = Control.new()
		spacer.name = "FooterSpacer"
		spacer.custom_minimum_size = Vector2(172, 64)
		center_control = spacer
	footer_row.add_child(center_control)
	footer_row.add_child(right_button)
	
	tab_node.add_child(footer_container)
	_footer_controls[item_type] = {
		"footer_container": footer_container,
		"left_button": left_button,
		"right_button": right_button,
		"center_control": center_control,
	}
	_update_footer_state(item_type)

func _create_footer_arrow_button(item_type: String, step: int, button_name: String, button_text: String) -> Button:
	var button = Button.new()
	button.name = button_name
	button.text = button_text
	button.custom_minimum_size = Vector2(52, 52)
	button.focus_mode = Control.FOCUS_NONE
	_apply_footer_arrow_button_styling(button)
	button.pressed.connect(_on_page_arrow_pressed.bind(item_type, step))
	button.mouse_entered.connect(_tfx.button_hover.bind(button))
	button.mouse_exited.connect(_tfx.button_unhover.bind(button))
	button.pressed.connect(_tfx.button_press.bind(button))
	return button

func _create_reroll_center_control(item_type: String) -> Control:
	var shell = Control.new()
	shell.name = "RerollShell_" + _get_tab_name_for_type(item_type)
	shell.custom_minimum_size = Vector2(172, 64)
	shell.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var shader_rect = ColorRect.new()
	shader_rect.name = "ShaderRect"
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_rect.color = Color.WHITE
	shell.add_child(shader_rect)
	
	var shader = load(REROLL_SHADER_PATH) as Shader
	if shader:
		var shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		shader_material.set_shader_parameter("aspect_ratio", 172.0 / 64.0)
		shader_material.set_shader_parameter("hover_strength", 0.0)
		shader_material.set_shader_parameter("pulse_strength", 0.0)
		shader_material.set_shader_parameter("press_flash", 0.0)
		shader_material.set_shader_parameter("disabled_factor", 0.0)
		shader_material.set_shader_parameter("accent_color", Color(0.16, 0.82, 0.48, 1.0))
		shader_material.set_shader_parameter("glow_color", Color(0.95, 0.88, 0.34, 1.0))
		shader_material.set_shader_parameter("base_color", Color(0.10, 0.22, 0.18, 0.98))
		shader_material.set_shader_parameter("mid_color", Color(0.16, 0.32, 0.26, 0.98))
		shader_material.set_shader_parameter("rim_color", Color(0.96, 0.97, 0.88, 1.0))
		shader_rect.material = shader_material
		_reroll_shader_materials[item_type] = shader_material
	
	var content_margin = MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 16)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_right", 16)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	shell.add_child(content_margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_theme_constant_override("separation", 1)
	content_margin.add_child(content_vbox)
	
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	var title_label = Label.new()
	title_label.name = "RerollTitle"
	title_label.text = "REROLL"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		title_label.add_theme_font_override("font", vcr_font)
		title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.08, 1.0))
	title_label.add_theme_constant_override("outline_size", 1)
	content_vbox.add_child(title_label)
	
	var price_label = Label.new()
	price_label.name = "RerollPrice"
	price_label.text = "$%s" % NumberFormatter.format_int(reroll_cost)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		price_label.add_theme_font_override("font", vcr_font)
		price_label.add_theme_font_size_override("font_size", 16)
	price_label.add_theme_color_override("font_color", Color(0.56, 1.0, 0.7, 1.0))
	price_label.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.06, 1.0))
	price_label.add_theme_constant_override("outline_size", 1)
	content_vbox.add_child(price_label)
	
	var overlay_button = Button.new()
	overlay_button.name = "RerollButton"
	overlay_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_button.flat = true
	overlay_button.text = ""
	overlay_button.focus_mode = Control.FOCUS_NONE
	overlay_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style = StyleBoxEmpty.new()
	overlay_button.add_theme_stylebox_override("normal", empty_style)
	overlay_button.add_theme_stylebox_override("hover", empty_style)
	overlay_button.add_theme_stylebox_override("pressed", empty_style)
	overlay_button.add_theme_stylebox_override("disabled", empty_style)
	overlay_button.add_theme_stylebox_override("focus", empty_style)
	overlay_button.pressed.connect(_on_reroll_button_pressed)
	overlay_button.mouse_entered.connect(func(): _on_reroll_hover_changed(item_type, true))
	overlay_button.mouse_exited.connect(func(): _on_reroll_hover_changed(item_type, false))
	overlay_button.pressed.connect(func(): _on_reroll_pressed_visual(item_type))
	shell.add_child(overlay_button)
	
	_reroll_shells[item_type] = shell
	_reroll_title_labels[item_type] = title_label
	_reroll_price_labels[item_type] = price_label
	if item_type == "power_up":
		reroll_button = overlay_button
		reroll_cost_label = price_label
	return shell

func _on_reroll_hover_changed(item_type: String, hovered: bool) -> void:
	var shell = _reroll_shells.get(item_type) as Control
	var shader_material = _reroll_shader_materials.get(item_type) as ShaderMaterial
	if shell:
		if hovered:
			_tfx.button_hover(shell)
		else:
			_tfx.button_unhover(shell)
	if shader_material:
		shader_material.set_shader_parameter("hover_strength", 1.0 if hovered else 0.0)
		shader_material.set_shader_parameter("pulse_strength", 0.3 if hovered else 0.0)

func _on_reroll_pressed_visual(item_type: String) -> void:
	var shell = _reroll_shells.get(item_type) as Control
	if shell:
		_tfx.button_press(shell)
	_flash_reroll_shader(item_type, 1.15)

func _set_reroll_disabled_visual(item_type: String, disabled: bool) -> void:
	var shell = _reroll_shells.get(item_type) as Control
	var shader_material = _reroll_shader_materials.get(item_type) as ShaderMaterial
	var title_label = _reroll_title_labels.get(item_type) as Label
	var price_label = _reroll_price_labels.get(item_type) as Label
	if shell:
		shell.modulate = Color(1.0, 1.0, 1.0, 0.78) if disabled else Color.WHITE
	if title_label:
		title_label.modulate = Color(0.76, 0.76, 0.82, 0.92) if disabled else Color.WHITE
	if price_label:
		price_label.modulate = Color(0.58, 0.58, 0.64, 0.92) if disabled else price_label.modulate
	if shader_material:
		shader_material.set_shader_parameter("disabled_factor", 1.0 if disabled else 0.0)
		if disabled:
			shader_material.set_shader_parameter("hover_strength", 0.0)
			shader_material.set_shader_parameter("pulse_strength", 0.0)

func _flash_reroll_shader(item_type: String, flash_strength: float) -> void:
	var shader_material = _reroll_shader_materials.get(item_type) as ShaderMaterial
	if not shader_material:
		return
	shader_material.set_shader_parameter("press_flash", flash_strength)
	var tween = create_tween()
	tween.tween_method(func(value: float): shader_material.set_shader_parameter("press_flash", value), flash_strength, 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
## Styles the shop title with BRICK_SANS font (no BBCode or rainbow colors)
func _style_shop_title() -> void:
	if not shop_label:
		print("[ShopUI] Shop label not found, skipping title styling")
		return
	
	print("[ShopUI] Styling shop title")
	
	# Configure basic properties
	shop_label.bbcode_enabled = false  # No BBCode needed
	shop_label.fit_content = true
	shop_label.custom_minimum_size = Vector2(0, 60)  # Taller for BRICK_SANS
	
	# Apply BRICK_SANS font with golden yellow color
	var brick_font = load("res://Resources/Font/BRICK_SANS.ttf")
	if brick_font:
		shop_label.add_theme_font_override("normal_font", brick_font)
		shop_label.add_theme_font_size_override("normal_font_size", 40)  # Large title
		shop_label.add_theme_color_override("default_color", Color(1.0, 0.85, 0.3, 1.0))  # Golden yellow
		# Add shadow for depth
		shop_label.add_theme_color_override("font_shadow_color", Color(0.6, 0.3, 0.0, 0.8))
		shop_label.add_theme_constant_override("shadow_offset_x", 4)
		shop_label.add_theme_constant_override("shadow_offset_y", 4)
	
	# Center alignment
	shop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Set simple text (no BBCode)
	shop_label.text = "SHOP"
	
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

## _create_consoles_tab()
## Creates the CONSOLES tab programmatically if it doesn't exist in the scene
func _create_consoles_tab() -> void:
	print("[ShopUI] Creating CONSOLES tab programmatically")
	
	if not tab_container:
		push_error("[ShopUI] TabContainer not found - cannot create CONSOLES tab")
		return
	
	# Create the Consoles tab
	var consoles_tab = Control.new()
	consoles_tab.name = "Consoles"
	tab_container.add_child(consoles_tab)
	
	# Create GridContainer for the gaming console items
	var grid_container = GridContainer.new()
	grid_container.name = "GridContainer"
	grid_container.columns = 3  # Show consoles in a 3-column grid
	consoles_tab.add_child(grid_container)
	
	# Set up the container reference
	gaming_console_container = grid_container
	
	print("[ShopUI] CONSOLES tab created successfully")

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
	
	_clear_item_container(locked_container)
	
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
	
	# Get locked Gaming Consoles
	var locked_consoles = progress_manager.get_locked_items(UnlockableItemClass.ItemType.GAMING_CONSOLE)
	for item in locked_consoles:
		_create_locked_item_display(item)
	
	print("[ShopUI] Locked items populated")

## populate_unlocked_items()
##
## Populates the UNLOCKED tab with items already unlocked in ProgressManager.
func populate_unlocked_items() -> void:
	if not unlocked_container:
		print("[ShopUI] No unlocked container found")
		return
	_clear_item_container(unlocked_container)
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("[ShopUI] ProgressManager not available")
		return
	print("[ShopUI] Populating unlocked items...")
	const UnlockableItemClass = preload("res://Scripts/Core/unlockable_item.gd")
	var item_types = [
		UnlockableItemClass.ItemType.POWER_UP,
		UnlockableItemClass.ItemType.CONSUMABLE,
		UnlockableItemClass.ItemType.MOD,
		UnlockableItemClass.ItemType.COLORED_DICE_FEATURE,
		UnlockableItemClass.ItemType.GAMING_CONSOLE,
	]
	for item_type in item_types:
		var unlocked_ids = progress_manager.get_unlocked_items(item_type)
		for item_id in unlocked_ids:
			var item = progress_manager.get_unlockable_item(item_id)
			if item:
				_create_unlocked_item_display(item)
	print("[ShopUI] Unlocked items populated")

## _create_locked_item_display(item)
##
## Creates a display for a locked item showing what it is, unlock requirements,
## and current progress toward unlocking (for cumulative conditions).
func _create_locked_item_display(item) -> void:
	_create_archive_item_display(item, locked_container, true)

func _create_unlocked_item_display(item) -> void:
	_create_archive_item_display(item, unlocked_container, false)

func _create_archive_item_display(item, target_container: Container, is_locked: bool) -> void:
	if not item or not target_container:
		return
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	var brick_font = load("res://Resources/Font/BRICK_SANS.ttf")
	var progress_manager = get_node("/root/ProgressManager")
	var progress_data = {"current": 0, "target": 0, "percentage": 0.0}
	if is_locked and progress_manager and progress_manager.has_method("get_condition_progress"):
		progress_data = progress_manager.get_condition_progress(item.id)
	var is_close_to_unlock = is_locked and progress_data["percentage"] >= 80.0
	var archive_panel = PanelContainer.new()
	var panel_theme = load("res://Resources/UI/powerup_hover_theme.tres") as Theme
	if panel_theme:
		archive_panel.theme = panel_theme
	archive_panel.custom_minimum_size = Vector2(200, 170)
	var shader_bg = ColorRect.new()
	shader_bg.color = Color.WHITE
	shader_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = load("res://Scripts/Shaders/marquee_lights.gdshader")
	if shader:
		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = shader
		if is_locked:
			shader_mat.set_shader_parameter("color_A", Vector3(0.0, 0.0, 0.0))
			shader_mat.set_shader_parameter("color_B", Vector3(0.4, 0.4, 0.4))
		else:
			shader_mat.set_shader_parameter("color_A", Vector3(0.0, 0.25, 0.18))
			shader_mat.set_shader_parameter("color_B", Vector3(0.15, 0.45, 0.34))
		shader_bg.material = shader_mat
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	if is_locked:
		style.border_color = Color(1.0, 0.85, 0.0, 1.0) if is_close_to_unlock else Color(0.8, 0.4, 0.4, 1.0)
	else:
		style.border_color = Color(0.45, 0.92, 0.62, 1.0)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	archive_panel.add_theme_stylebox_override("panel", style)
	archive_panel.add_child(shader_bg)
	shader_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	archive_panel.mouse_entered.connect(_on_locked_item_mouse_entered.bind(shader_bg))
	archive_panel.mouse_exited.connect(_on_locked_item_mouse_exited.bind(shader_bg))
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	archive_panel.add_child(vbox)
	var name_label = RichTextLabel.new()
	name_label.custom_minimum_size = Vector2(180, 30)
	name_label.fit_content = true
	name_label.scroll_active = false
	name_label.bbcode_enabled = true
	name_label.add_theme_font_override("normal_font", brick_font)
	if is_locked:
		if is_close_to_unlock:
			name_label.text = "[center]⭐ %s[/center]" % item.display_name
		else:
			name_label.text = "[center]🔒 %s[/center]" % item.display_name
	else:
		name_label.text = "[center]🔓 %s[/center]" % item.display_name
	name_label.add_theme_font_size_override("normal_font_size", 11)
	vbox.add_child(name_label)
	var type_label = Label.new()
	type_label.text = "Type: %s" % item.get_type_string()
	type_label.add_theme_font_override("font", vcr_font)
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)
	var desc_label = RichTextLabel.new()
	desc_label.custom_minimum_size = Vector2(180, 40)
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.bbcode_enabled = true
	desc_label.add_theme_font_override("normal_font", vcr_font)
	desc_label.add_theme_font_size_override("normal_font_size", 9)
	desc_label.text = "[center]%s[/center]" % item.description
	vbox.add_child(desc_label)
	var status_label = RichTextLabel.new()
	status_label.custom_minimum_size = Vector2(180, 35)
	status_label.fit_content = true
	status_label.scroll_active = false
	status_label.bbcode_enabled = true
	status_label.add_theme_font_override("normal_font", vcr_font)
	status_label.add_theme_font_size_override("normal_font_size", 9)
	if is_locked:
		status_label.text = "[center][color=yellow]Unlock: %s[/color][/center]" % item.get_unlock_description()
	else:
		status_label.text = "[center][color=#8dff8d]Status: Unlocked[/color][/center]"
	vbox.add_child(status_label)
	if is_locked and progress_data["target"] > 0 and progress_data["current"] > 0:
		var progress_container = HBoxContainer.new()
		progress_container.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(progress_container)
		var progress_bar = ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(120, 12)
		progress_bar.max_value = 100.0
		progress_bar.value = progress_data["percentage"]
		progress_bar.show_percentage = false
		var bar_style = StyleBoxFlat.new()
		bar_style.bg_color = Color(0.3, 0.3, 0.3, 1.0)
		bar_style.corner_radius_top_left = 3
		bar_style.corner_radius_top_right = 3
		bar_style.corner_radius_bottom_left = 3
		bar_style.corner_radius_bottom_right = 3
		progress_bar.add_theme_stylebox_override("background", bar_style)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(1.0, 0.85, 0.0, 1.0) if is_close_to_unlock else Color(0.3, 0.7, 0.3, 1.0)
		fill_style.corner_radius_top_left = 3
		fill_style.corner_radius_top_right = 3
		fill_style.corner_radius_bottom_left = 3
		fill_style.corner_radius_bottom_right = 3
		progress_bar.add_theme_stylebox_override("fill", fill_style)
		progress_container.add_child(progress_bar)
		var progress_text = Label.new()
		progress_text.text = " %d/%d" % [progress_data["current"], progress_data["target"]]
		progress_text.add_theme_font_override("font", vcr_font)
		progress_text.add_theme_font_size_override("font_size", 9)
		progress_text.modulate = Color(0.8, 0.8, 0.8, 1.0)
		progress_container.add_child(progress_text)
	target_container.add_child(archive_panel)

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

## _on_locked_item_mouse_entered(shader_bg)
##
## Called when mouse enters a locked item - changes shader colors to teal and purple
func _on_locked_item_mouse_entered(shader_bg: ColorRect) -> void:
	if not shader_bg or not shader_bg.material:
		return
	
	var shader_mat = shader_bg.material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("color_A", Vector3(0.0, 0.8, 0.8))  # Teal
		shader_mat.set_shader_parameter("color_B", Vector3(0.5, 0.0, 0.5))  # Purple

## _on_locked_item_mouse_exited(shader_bg)
##
## Called when mouse exits a locked item - returns shader colors to black and grey
func _on_locked_item_mouse_exited(shader_bg: ColorRect) -> void:
	if not shader_bg or not shader_bg.material:
		return
	
	var shader_mat = shader_bg.material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("color_A", Vector3(0.0, 0.0, 0.0))  # Black
		shader_mat.set_shader_parameter("color_B", Vector3(0.4, 0.4, 0.4))  # Grey


## temporarily_minimize()
##
## Hides the shop UI while preserving all internal state (current tab, scroll, items).
## Used when fan-out UIs (PowerUpUI, CorkboardUI) need to be interactive above the shop.
## Call restore_from_minimize() to bring the shop back.
func temporarily_minimize() -> void:
	if visible:
		visible = false
		print("[ShopUI] Temporarily minimized for fan-out overlay")


## restore_from_minimize()
##
## Restores the shop UI that was temporarily minimized by a fan-out overlay.
## All shop state (tab, items, scroll) is preserved from before minimization.
func restore_from_minimize() -> void:
	if not visible:
		visible = true
		print("[ShopUI] Restored from minimize")
