extends Control
class_name DebugPanel

## DebugPanel
##
## Simple debug overlay for rapid testing and verification of DiceRogue features.
## Toggle with F12, provides quick access to test scenarios and system states.
## Singleton pattern ensures only one debug panel exists at a time.

signal debug_command_executed(command: String, result: String)

# Static variable to ensure singleton behavior
static var instance: DebugPanel = null

@onready var background: ColorRect
@onready var main_container: VBoxContainer
@onready var title_label: Label
@onready var system_info_label: Label
@onready var output_text: TextEdit
@onready var button_grid: GridContainer
@onready var close_button: Button

var game_controller: GameController
var is_visible_debug := false
var info_update_timer: Timer

func _ready() -> void:
	# Singleton pattern - if instance already exists, remove this one
	if instance != null and instance != self:
		print("[DebugPanel] Another debug panel already exists (", instance, "), removing duplicate (", self, ")")
		queue_free()
		return
	
	# Set this as the singleton instance
	instance = self
	print("[DebugPanel] Setting as singleton instance: ", self)
	
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000  # Ensure debug panel appears in front of all other UI
	_create_debug_ui()
	hide_debug_panel()
	
	# Try to find GameController
	game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		log_debug("Warning: GameController not found - some debug functions may not work")
	
	# Set up system info timer
	info_update_timer = Timer.new()
	info_update_timer.wait_time = 1.0  # Update every second
	info_update_timer.timeout.connect(_update_system_info)
	info_update_timer.autostart = true
	add_child(info_update_timer)

func _exit_tree() -> void:
	# Clear singleton instance when this panel is destroyed
	if instance == self:
		instance = null

## Static method to get or create debug panel instance
static func get_or_create_instance(parent_node: Node = null) -> DebugPanel:
	if instance == null:
		var debug_scene = preload("res://Scenes/UI/DebugPanel.tscn")
		if debug_scene:
			instance = debug_scene.instantiate()
			if parent_node:
				parent_node.add_child(instance)
				# Move to front (highest index)
				parent_node.move_child(instance, parent_node.get_child_count() - 1)
			else:
				# Add to main scene root if no parent specified
				var main_scene = Engine.get_main_loop().current_scene
				if main_scene:
					main_scene.add_child(instance)
					# Move to front (highest index)
					main_scene.move_child(instance, main_scene.get_child_count() - 1)
	return instance

## Static method to toggle debug panel from anywhere
static func toggle_debug() -> void:
	var panel = get_or_create_instance()
	if panel:
		panel.toggle_debug_panel()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F12 and event.pressed and not event.echo:
		print("[DebugPanel] F12 pressed - instance: ", self)
		toggle_debug_panel()
		get_viewport().set_input_as_handled()

func _create_debug_ui() -> void:
	# Semi-transparent background
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.z_index = 1000  # Very high z-index to appear in front
	add_child(background)
	
	# Solid black panel background for readability
	var panel_background = ColorRect.new()
	panel_background.color = Color(0, 0, 0, 1.0)  # Solid black
	panel_background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel_background.position = Vector2(10, 10)  # Small offset from top-left corner
	panel_background.custom_minimum_size = Vector2(620, 420)
	panel_background.z_index = 1001  # Above the transparent background
	add_child(panel_background)
	
	# Main container
	main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_container.position = Vector2(20, 20)  # Small offset from top-left corner
	main_container.custom_minimum_size = Vector2(600, 400)
	main_container.add_theme_constant_override("separation", 8)
	main_container.z_index = 1002  # Above the panel background
	add_child(main_container)
	
	# Title
	title_label = Label.new()
	title_label.text = "DiceRogue Debug Panel (F12 to toggle)"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	main_container.add_child(title_label)
	
	# System info (FPS, memory, etc.)
	system_info_label = Label.new()
	system_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	system_info_label.add_theme_color_override("font_color", Color.YELLOW)
	system_info_label.add_theme_font_size_override("font_size", 12)
	main_container.add_child(system_info_label)
	
	# Button grid for quick actions
	button_grid = GridContainer.new()
	button_grid.columns = 3
	button_grid.add_theme_constant_override("h_separation", 10)
	button_grid.add_theme_constant_override("v_separation", 5)
	main_container.add_child(button_grid)
	
	_create_debug_buttons()
	
	# Output text area
	var output_label = Label.new()
	output_label.text = "Debug Output:"
	output_label.add_theme_color_override("font_color", Color.WHITE)
	main_container.add_child(output_label)
	
	output_text = TextEdit.new()
	output_text.custom_minimum_size = Vector2(580, 150)
	output_text.editable = false
	output_text.placeholder_text = "Debug output will appear here..."
	output_text.add_theme_color_override("font_color", Color.WHITE)
	output_text.add_theme_color_override("background_color", Color(0.1, 0.1, 0.1, 1.0))
	main_container.add_child(output_text)
	
	# Close button and clear output button
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	
	var clear_output_button = Button.new()
	clear_output_button.text = "Clear Output"
	clear_output_button.pressed.connect(_on_clear_output_pressed)
	button_row.add_child(clear_output_button)
	
	close_button = Button.new()
	close_button.text = "Close (F12)"
	close_button.pressed.connect(_on_close_button_pressed)
	button_row.add_child(close_button)
	
	main_container.add_child(button_row)

func _create_debug_buttons() -> void:
	var buttons = [
		# Power-ups and Items
		{"text": "Grant Random PowerUp", "method": "_debug_grant_powerup"},
		{"text": "Grant Random Consumable", "method": "_debug_grant_consumable"},
		{"text": "Grant AnyScore", "method": "_debug_grant_any_score"},
		{"text": "Grant Random Uncommon PowerUp", "method": "_debug_grant_random_uncommon_powerup"},
		{"text": "Register AnyScore", "method": "_debug_register_any_score"},
		{"text": "Grant Random Mod", "method": "_debug_grant_mod"},
		
		# Economy
		{"text": "Add $100", "method": "_debug_add_money"},
		{"text": "Add $1000", "method": "_debug_add_big_money"},
		{"text": "Reset Money", "method": "_debug_reset_money"},
		
		# Dice Control
		{"text": "Roll All 6s", "method": "_debug_force_dice"},
		{"text": "Roll All 1s", "method": "_debug_force_ones"},
		{"text": "Roll Yahtzee", "method": "_debug_force_yahtzee"},
		{"text": "Roll Large Straight", "method": "_debug_force_large_straight"},
		{"text": "Activate Perfect Strangers", "method": "_debug_activate_perfect_strangers"},
		
		# Debuff Testing
		{"text": "Apply The Division Debuff", "method": "_debug_apply_division_debuff"},
		{"text": "Remove The Division Debuff", "method": "_debug_remove_division_debuff"},
		{"text": "Test Division vs Perfect Strangers", "method": "_debug_test_division_perfect_strangers"},
		
		# Challenge Testing  
		{"text": "Activate The Crossing Challenge", "method": "_debug_activate_crossing_challenge"},
		{"text": "Activate 150pts Roll Minus One", "method": "_debug_activate_pts150_challenge"},
		{"text": "Show Active Challenges", "method": "_debug_show_active_challenges"},
		
		# Mod Limit Testing
		{"text": "Show Mod/Dice Count", "method": "_debug_show_mod_dice_count"},
		{"text": "Fill All Dice w/ Mods", "method": "_debug_fill_dice_with_mods"},
		{"text": "Test Mod Limit Block", "method": "_debug_test_mod_limit_block"},
		{"text": "Test Shop Mod Purchase", "method": "_debug_test_shop_mod_purchase"},
		
		# Game State
		{"text": "Show Score State", "method": "_debug_show_scores"},
		{"text": "Show All Items", "method": "_debug_show_items"},
		{"text": "Show Roll Stats", "method": "_debug_show_roll_stats"},
		{"text": "Clear All Items", "method": "_debug_clear_items"},
		
		# Game Flow
		{"text": "Add Extra Rolls", "method": "_debug_add_rolls"},
		{"text": "Force End Turn", "method": "_debug_end_turn"},
		{"text": "Skip to Shop", "method": "_debug_skip_shop"},
		
		# System Testing
		{"text": "Test Score Calculation", "method": "_debug_test_scoring"},
		{"text": "Debug Multiplier System", "method": "_debug_multiplier_system"},
		{"text": "Trigger All Signals", "method": "_debug_test_signals"},
		{"text": "Save Debug State", "method": "_debug_save_state"},
		
		# Utilities
		{"text": "Load Debug State", "method": "_debug_load_state"},
		{"text": "Reset Game", "method": "_debug_reset_game"},
		{"text": "Clear Output", "method": "_on_clear_output_pressed"},
	]
	
	for button_data in buttons:
		var button = Button.new()
		button.text = button_data["text"]
		button.custom_minimum_size = Vector2(180, 30)
		
		# Connect using Callable
		var method_name = button_data["method"]
		button.pressed.connect(Callable(self, method_name))
		
		button_grid.add_child(button)

func toggle_debug_panel() -> void:
	print("[DebugPanel] Toggle called - current state: ", is_visible_debug)
	if is_visible_debug:
		hide_debug_panel()
	else:
		show_debug_panel()

func show_debug_panel() -> void:
	print("[DebugPanel] Showing panel")
	visible = true
	is_visible_debug = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Bring to front in case other UI was added after debug panel
	if get_parent():
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	
	log_debug("Debug panel opened")

func hide_debug_panel() -> void:
	print("[DebugPanel] Hiding panel")
	visible = false
	is_visible_debug = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_close_button_pressed() -> void:
	hide_debug_panel()
	log_debug("Debug panel closed via button")

func _on_clear_output_pressed() -> void:
	if output_text:
		output_text.text = ""
	print("[DebugPanel] Output cleared")

func _update_system_info() -> void:
	if not system_info_label or not is_visible_debug:
		return
	
	var fps = Engine.get_frames_per_second()
	var process_id = OS.get_process_id()
	var brief_stats = RollStats.get_brief_stats() if RollStats else "Stats: N/A"
	
	system_info_label.text = "FPS: %d | Process: %d | Nodes: %d\n%s" % [
		fps, 
		process_id,
		get_tree().get_node_count(),
		brief_stats
	]

func log_debug(message: String) -> void:
	var timestamp = Time.get_datetime_string_from_system()
	var log_line = "[%s] %s\n" % [timestamp, message]
	
	if output_text:
		output_text.text += log_line
		# Auto-scroll to bottom
		output_text.scroll_vertical = output_text.get_line_count()
	
	print("[DebugPanel] " + message)
	debug_command_executed.emit("log", message)

# Debug command implementations
func _debug_grant_powerup() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	# Try to grant a random power-up
	var pu_manager = game_controller.pu_manager
	if pu_manager and pu_manager.has_method("get_available_power_ups"):
		var available_ids = pu_manager.get_available_power_ups()
		# Filter out already owned PowerUps
		var unowned_ids = available_ids.filter(func(id): return not game_controller.active_power_ups.has(id))
		
		if unowned_ids.size() > 0:
			var random_id = unowned_ids[randi() % unowned_ids.size()]
			game_controller.grant_power_up(random_id)
			log_debug("Granted PowerUp: " + random_id)
		else:
			log_debug("No unowned PowerUps available to grant")
	else:
		log_debug("PowerUpManager not found or method missing")

func _debug_grant_consumable() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var consumable_manager = game_controller.consumable_manager
	if consumable_manager and consumable_manager.has_method("get_available_consumables"):
		var available_ids = consumable_manager.get_available_consumables()
		if available_ids.size() > 0:
			var random_id = available_ids[randi() % available_ids.size()]
			game_controller.grant_consumable(random_id)
			log_debug("Granted Consumable: " + random_id)
		else:
			log_debug("No Consumables available to grant")
	else:
		log_debug("ConsumableManager not found or method missing")

func _debug_grant_any_score() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("any_score")
		log_debug("Granted AnyScore consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_register_any_score() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var consumable_manager = game_controller.consumable_manager
	if not consumable_manager:
		log_debug("ERROR: ConsumableManager not available")
		return
	
	# Load the AnyScore data resource
	var any_score_data = load("res://Scripts/Consumable/AnyScoreConsumable.tres") as ConsumableData
	if any_score_data:
		if consumable_manager.has_method("register_consumable_def"):
			consumable_manager.register_consumable_def(any_score_data)
			log_debug("Registered AnyScore consumable for testing")
		else:
			log_debug("ConsumableManager missing register_consumable_def method")
	else:
		log_debug("ERROR: Failed to load AnyScore data resource")

func _debug_grant_random_uncommon_powerup() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("random_power_up_uncommon")
		log_debug("Granted Random Uncommon PowerUp consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_add_money() -> void:
	if PlayerEconomy:
		var old_money = PlayerEconomy.money
		PlayerEconomy.add_money(100)
		log_debug("Money: %d -> %d (+100)" % [old_money, PlayerEconomy.money])
	else:
		log_debug("ERROR: PlayerEconomy not available")

func _debug_force_dice() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var dice_hand = game_controller.dice_hand
	if dice_hand and dice_hand.dice_list.size() > 0:
		for die in dice_hand.dice_list:
			die.value = 6
			die.update_visual()  # Update visual to match new value
		dice_hand._update_results()  # Update DiceResults singleton
		log_debug("Set all dice to 6")
	else:
		log_debug("DiceHand not found or no dice available")

func _debug_show_scores() -> void:
	var state_info = []
	
	# ScoreModifierManager state
	if ScoreModifierManager:
		var total_additive = ScoreModifierManager.get_total_additive()
		var total_multiplier = ScoreModifierManager.get_total_multiplier()
		state_info.append("Score Modifiers: +" + str(total_additive) + " additive, " + str(total_multiplier) + "x multiplier")
	
	# PlayerEconomy state
	if PlayerEconomy:
		state_info.append("Money: $%d" % PlayerEconomy.money)
	
	# Active items count
	if game_controller:
		var powerup_count = game_controller.active_power_ups.size()
		var consumable_count = game_controller.active_consumables.size()
		var mod_count = game_controller.active_mods.size()
		state_info.append("Active: %d PowerUps, %d Consumables, %d Mods" % [powerup_count, consumable_count, mod_count])
	
	var full_state = "\n".join(state_info)
	log_debug("GAME STATE:\n" + full_state)

func _debug_show_roll_stats() -> void:
	log_debug("ROLL STATISTICS:\n" + RollStats.get_stats_summary())

func _debug_clear_items() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	# Clear active items
	var cleared_count = 0
	for id in game_controller.active_power_ups.keys():
		game_controller.revoke_power_up(id)
		cleared_count += 1
	
	for id in game_controller.active_consumables.keys():
		# Remove consumables (they don't have revoke)
		game_controller.active_consumables.erase(id)
		cleared_count += 1
	
	log_debug("Cleared %d items" % cleared_count)

func _debug_grant_mod() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var mod_manager = game_controller.mod_manager
	if mod_manager and mod_manager.has_method("get_available_mods"):
		var available_ids = mod_manager.get_available_mods()
		if available_ids.size() > 0:
			var random_id = available_ids[randi() % available_ids.size()]
			game_controller.grant_mod(random_id)
			log_debug("Granted Mod: " + random_id)
		else:
			log_debug("No Mods available to grant")
	else:
		log_debug("ModManager not found or method missing")

func _debug_add_big_money() -> void:
	if PlayerEconomy:
		var old_money = PlayerEconomy.money
		PlayerEconomy.add_money(1000)
		log_debug("Money: %d -> %d (+1000)" % [old_money, PlayerEconomy.money])
	else:
		log_debug("ERROR: PlayerEconomy not available")

func _debug_reset_money() -> void:
	if PlayerEconomy:
		var old_money = PlayerEconomy.money
		PlayerEconomy.money = 500  # Default starting money
		log_debug("Money reset: %d -> 500" % old_money)
	else:
		log_debug("ERROR: PlayerEconomy not available")

func _debug_force_ones() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var dice_hand = game_controller.dice_hand
	if dice_hand and dice_hand.dice_list.size() > 0:
		for die in dice_hand.dice_list:
			die.value = 1
			die.update_visual()  # Update visual to match new value
		dice_hand._update_results()  # Update DiceResults singleton
		log_debug("Set all dice to 1")
	else:
		log_debug("DiceHand not found or no dice available")

func _debug_force_yahtzee() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var dice_hand = game_controller.dice_hand
	if dice_hand and dice_hand.dice_list.size() > 0:
		for die in dice_hand.dice_list:
			die.value = 5
			die.update_visual()  # Update visual to match new value
		dice_hand._update_results()  # Update DiceResults singleton
		log_debug("Set all dice to 5 (Yahtzee)")
	else:
		log_debug("DiceHand not found or no dice available")

func _debug_force_large_straight() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var dice_hand = game_controller.dice_hand
	if dice_hand and dice_hand.dice_list.size() > 0:
		# Set dice to 1,2,3,4,5 for a large straight
		var large_straight_values = [1, 2, 3, 4, 5]
		for i in range(min(dice_hand.dice_list.size(), large_straight_values.size())):
			dice_hand.dice_list[i].value = large_straight_values[i]
			dice_hand.dice_list[i].update_visual()  # Update visual to match new value
		dice_hand._update_results()  # Update DiceResults singleton
		log_debug("Set dice to 1,2,3,4,5 (Large Straight) - perfect for Perfect Strangers PowerUp test!")
	else:
		log_debug("DiceHand not found or no dice available")

func _debug_show_items() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var items_info = []
	
	# PowerUps
	if game_controller.active_power_ups.size() > 0:
		items_info.append("=== ACTIVE POWER-UPS ===")
		for id in game_controller.active_power_ups.keys():
			var powerup = game_controller.active_power_ups[id]
			items_info.append("- %s: %s" % [id, powerup.get_script().get_path().get_file()])
	
	# Consumables
	if game_controller.active_consumables.size() > 0:
		items_info.append("=== ACTIVE CONSUMABLES ===")
		for id in game_controller.active_consumables.keys():
			var consumable = game_controller.active_consumables[id]
			items_info.append("- %s: %s" % [id, consumable.get_script().get_path().get_file()])
	
	# Mods
	if game_controller.active_mods.size() > 0:
		items_info.append("=== ACTIVE MODS ===")
		for id in game_controller.active_mods.keys():
			var mod = game_controller.active_mods[id]
			items_info.append("- %s: %s" % [id, mod.get_script().get_path().get_file()])
	
	if items_info.is_empty():
		log_debug("No active items found")
	else:
		log_debug("\n".join(items_info))

func _debug_add_rolls() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var turn_tracker = game_controller.turn_tracker
	if turn_tracker and turn_tracker.has_method("add_rolls"):
		var old_rolls = turn_tracker.rolls_left
		turn_tracker.add_rolls(3)
		log_debug("Rolls: %d -> %d (+3)" % [old_rolls, turn_tracker.rolls_left])
	else:
		log_debug("TurnTracker not found or method missing")

func _debug_end_turn() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var turn_tracker = game_controller.turn_tracker
	if turn_tracker and turn_tracker.has_method("end_turn"):
		turn_tracker.end_turn()
		log_debug("Force ended current turn")
	else:
		log_debug("TurnTracker not found or method missing")

func _debug_test_scoring() -> void:
	var test_results = []
	
	# Test ScoreModifierManager
	if ScoreModifierManager:
		test_results.append("=== SCORE MODIFIER TEST ===")
		var base_score = 25
		var additive = ScoreModifierManager.get_total_additive()
		var multiplier = ScoreModifierManager.get_total_multiplier()
		var final_score = (base_score + additive) * multiplier
		test_results.append("Base: %d + Additive: %d = %d" % [base_score, additive, base_score + additive])
		test_results.append("Then × " + str(multiplier) + " = " + str(final_score) + " final")
	
	# Test dice evaluation
	if game_controller:
		var dice_hand = game_controller.dice_hand
		if dice_hand and ScoreEvaluatorSingleton:
			test_results.append("=== DICE EVALUATION TEST ===")
			var dice_values = dice_hand.get_current_dice_values() if dice_hand.has_method("get_current_dice_values") else [1,2,3,4,5]
			test_results.append("Current dice: %s" % str(dice_values))
			# Add more scoring tests here if methods are available
	
	if test_results.is_empty():
		log_debug("Score testing not available - missing required components")
	else:
		log_debug("\n".join(test_results))

func _debug_test_signals() -> void:
	log_debug("=== SIGNAL TEST ===")
	
	# Test debug panel signal
	debug_command_executed.emit("test", "Debug signal working")
	
	# Test game controller signals if available
	if game_controller:
		if game_controller.has_signal("power_up_granted"):
			log_debug("GameController signals available")
		else:
			log_debug("GameController signals not found")
	
	# Test autoload signals
	if ScoreModifierManager and ScoreModifierManager.has_signal("additive_changed"):
		log_debug("ScoreModifierManager signals available")
	else:
		log_debug("ScoreModifierManager signals not found")
	
	log_debug("Signal test completed")

func _debug_grant_mods() -> void:
	# Renamed old method to be more specific
	_debug_grant_mod()

func _debug_skip_shop() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var round_manager = game_controller.round_manager
	if round_manager and round_manager.has_method("skip_to_shop"):
		round_manager.skip_to_shop()
		log_debug("Skipped to shop phase")
	else:
		log_debug("RoundManager not found or skip method missing")

func _debug_reset_game() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	# Clear all items first
	_debug_clear_items()
	
	# Reset money
	_debug_reset_money()
	
	# Reset turn tracker if possible
	var turn_tracker = game_controller.turn_tracker
	if turn_tracker and turn_tracker.has_method("reset"):
		turn_tracker.reset()
		log_debug("Turn tracker reset")
	
	# Clear debug output
	if output_text:
		output_text.text = ""
	
	log_debug("=== GAME RESET COMPLETED ===")

# Debug state save/load for quick testing scenarios
var debug_state_data: Dictionary = {}

func _debug_save_state() -> void:
	debug_state_data.clear()
	
	# Save economy state
	if PlayerEconomy:
		debug_state_data["money"] = PlayerEconomy.money
	
	# Save score modifier state
	if ScoreModifierManager:
		debug_state_data["additive"] = ScoreModifierManager.get_total_additive()
		debug_state_data["multiplier"] = ScoreModifierManager.get_total_multiplier()
	
	# Save active items count
	if game_controller:
		debug_state_data["powerup_count"] = game_controller.active_power_ups.size()
		debug_state_data["consumable_count"] = game_controller.active_consumables.size()
		debug_state_data["mod_count"] = game_controller.active_mods.size()
	
	# Save turn state
	var turn_tracker = game_controller.turn_tracker if game_controller else null
	if turn_tracker:
		debug_state_data["rolls_left"] = turn_tracker.rolls_left
	
	log_debug("Debug state saved: Money=%s, Items=%d/%d/%d" % [
		debug_state_data.get("money", "?"),
		debug_state_data.get("powerup_count", 0),
		debug_state_data.get("consumable_count", 0),
		debug_state_data.get("mod_count", 0)
	])

func _debug_load_state() -> void:
	if debug_state_data.is_empty():
		log_debug("No debug state saved to load")
		return
	
	log_debug("Loading debug state...")
	
	# Note: This is a basic implementation
	# Full state restoration would require more complex logic
	
	var loaded_info = []
	for key in debug_state_data.keys():
		loaded_info.append("%s: %s" % [key, debug_state_data[key]])
	
	log_debug("Saved state data:\n" + "\n".join(loaded_info))
	log_debug("(Full state restoration not implemented - this shows what was saved)")

func _debug_activate_perfect_strangers() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	# Find the Perfect Strangers PowerUp in active power-ups
	var perfect_strangers_pu = game_controller.active_power_ups.get("perfect_strangers")
	if not perfect_strangers_pu:
		log_debug("ERROR: Perfect Strangers PowerUp not found - make sure to grant it first!")
		return
	
	# Manually activate the multiplier
	if perfect_strangers_pu.has_method("_activate_multiplier"):
		perfect_strangers_pu._activate_multiplier()
		perfect_strangers_pu.emit_signal("description_updated", "perfect_strangers", perfect_strangers_pu.get_current_description())
		log_debug("Perfect Strangers multiplier manually activated! Next scores should be 1.5x")
	else:
		log_debug("ERROR: Perfect Strangers PowerUp doesn't have _activate_multiplier method")
	
	# Show current multiplier state
	if ScoreModifierManager:
		var total_multiplier = ScoreModifierManager.get_total_multiplier()
		log_debug("Current total multiplier: " + str(total_multiplier) + "x")

func _debug_apply_division_debuff() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	if game_controller.is_debuff_active("the_division"):
		log_debug("The Division debuff is already active")
		return
	
	game_controller.apply_debuff("the_division")
	log_debug("Applied The Division debuff - all multipliers now divide instead!")
	
	# Show current state
	if ScoreModifierManager:
		var total_modifier = ScoreModifierManager.get_total_multiplier()
		log_debug("Current total modifier after applying The Division: " + str(total_modifier) + "x")

func _debug_remove_division_debuff() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	if not game_controller.is_debuff_active("the_division"):
		log_debug("The Division debuff is not currently active")
		return
	
	game_controller.disable_debuff("the_division")
	log_debug("Removed The Division debuff - multipliers restored to normal")
	
	# Show current state
	if ScoreModifierManager:
		var total_modifier = ScoreModifierManager.get_total_multiplier()
		log_debug("Current total modifier after removing The Division: " + str(total_modifier) + "x")

func _debug_test_division_perfect_strangers() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	log_debug("=== TESTING THE DIVISION + PERFECT STRANGERS ===")
	
	# 1. Ensure Perfect Strangers is active
	if not game_controller.active_power_ups.has("perfect_strangers"):
		game_controller.grant_power_up("perfect_strangers")
		log_debug("Granted Perfect Strangers PowerUp")
	
	# 2. Set up a large straight for Perfect Strangers activation
	_debug_force_large_straight()
	
	# 3. Show normal multiplier
	log_debug("--- BEFORE DIVISION DEBUFF ---")
	if ScoreModifierManager:
		var normal_multiplier = ScoreModifierManager.get_total_multiplier()
		log_debug("Normal total multiplier: " + str(normal_multiplier) + "x")
		var test_score = 40  # Large straight score
		var normal_result = test_score * normal_multiplier
		log_debug("Example: 40pt Large Straight × " + str(normal_multiplier) + " = " + str(normal_result) + " points")
	
	# 4. Apply The Division debuff
	if not game_controller.is_debuff_active("the_division"):
		game_controller.apply_debuff("the_division")
		log_debug("Applied The Division debuff")
	
	# 5. Show division effect
	log_debug("--- AFTER DIVISION DEBUFF ---")
	if ScoreModifierManager:
		var division_modifier = ScoreModifierManager.get_total_multiplier()
		log_debug("Division total modifier: " + str(division_modifier) + "x")
		var test_score = 40  # Large straight score
		var division_result = test_score * division_modifier
		log_debug("Example: 40pt Large Straight × " + str(division_modifier) + " = " + str(division_result) + " points")
		log_debug("EFFECT: Score is now DIVIDED by the original multiplier instead of multiplied!")
	
	log_debug("Test complete! Use 'Remove The Division Debuff' to restore normal behavior.")

func _debug_multiplier_system() -> void:
	log_debug("\n=== MULTIPLIER SYSTEM DEBUG ===")
	
	if not ScoreModifierManager:
		log_debug("✗ ScoreModifierManager NOT FOUND!")
		return
	
	log_debug("✓ ScoreModifierManager found")
	
	# Check current state
	var total_multiplier = ScoreModifierManager.get_total_multiplier()
	var total_additive = ScoreModifierManager.get_total_additive()
	var active_multipliers = ScoreModifierManager._active_multipliers
	var active_additives = ScoreModifierManager._active_additives
	
	log_debug("Current total multiplier: " + str(total_multiplier))
	log_debug("Current total additive: " + str(total_additive))
	log_debug("Active multipliers: " + str(active_multipliers))
	log_debug("Active additives: " + str(active_additives))
	
	# Check Perfect Strangers PowerUp state
	if game_controller and game_controller.active_power_ups.has("perfect_strangers"):
		var ps_powerup = game_controller.active_power_ups["perfect_strangers"]
		log_debug("✓ Perfect Strangers PowerUp found")
		log_debug("  - Multiplier activated: " + str(ps_powerup.multiplier_activated))
		log_debug("  - Current multiplier: " + str(ps_powerup.current_multiplier))
	else:
		log_debug("✗ Perfect Strangers PowerUp NOT found or not active")
	
	# Check dice state
	if game_controller and game_controller.dice_hand:
		var dice_values = game_controller.dice_hand.get_current_dice_values()
		log_debug("Current dice values: " + str(dice_values))
		
		# Check if Perfect Strangers condition would be met
		var unique_values = {}
		var all_different = true
		for value in dice_values:
			if value in unique_values:
				all_different = false
				break
			unique_values[value] = true
		
		log_debug("Dice count: " + str(dice_values.size()) + " (need 5+)")
		log_debug("All different: " + str(all_different))
		log_debug("Perfect Strangers condition met: " + str(dice_values.size() >= 5 and all_different))
	else:
		log_debug("✗ Cannot access dice values")
	
	# Test calculation
	var test_score = 15
	var calculated_score = (test_score + total_additive) * total_multiplier
	var final_score = ceil(calculated_score)
	log_debug("\nTest calculation (score=15):")
	log_debug("  (15 + " + str(total_additive) + ") × " + str(total_multiplier) + " = " + str(calculated_score))
	log_debug("  Rounded up: " + str(final_score))

# New debug methods for mod limit testing

func _debug_show_mod_dice_count() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var dice_hand = game_controller.dice_hand
	if not dice_hand:
		log_debug("ERROR: DiceHand not found")
		return
	
	var current_dice_count = dice_hand.dice_list.size()
	var expected_dice_count = game_controller._get_expected_dice_count()
	var mod_count = game_controller._get_total_active_mod_count()
	
	log_debug("=== MOD/DICE COUNT STATUS ===")
	log_debug("Current dice spawned: " + str(current_dice_count))
	log_debug("Expected dice count: " + str(expected_dice_count))
	log_debug("Total mods applied: " + str(mod_count))
	log_debug("Mod limit reached (vs expected): " + str(mod_count >= expected_dice_count))
	log_debug("Mod limit reached (vs current): " + str(mod_count >= current_dice_count))
	log_debug("Remaining mod slots (expected): " + str(max(0, expected_dice_count - mod_count)))
	log_debug("Remaining mod slots (current): " + str(max(0, current_dice_count - mod_count)))
	
	# Show breakdown per die (only if dice are spawned)
	if current_dice_count > 0:
		var dice_breakdown = []
		for i in range(dice_hand.dice_list.size()):
			var die = dice_hand.dice_list[i]
			var die_mod_count = die.active_mods.size()
			dice_breakdown.append("Die %d: %d mods" % [i + 1, die_mod_count])
		
		log_debug("Dice breakdown: " + ", ".join(dice_breakdown))
	else:
		log_debug("No dice currently spawned")

func _debug_fill_dice_with_mods() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var dice_hand = game_controller.dice_hand
	if not dice_hand:
		log_debug("ERROR: DiceHand not found")
		return
	
	var mod_manager = game_controller.mod_manager
	if not mod_manager:
		log_debug("ERROR: ModManager not found")
		return
	
	log_debug("=== FILLING ALL DICE WITH MODS ===")
	
	# Get available mod types
	var available_mods = mod_manager.get_available_mods()
	if available_mods.is_empty():
		log_debug("No mods available to grant")
		return
	
	var mods_granted = 0
	var dice_count = dice_hand.dice_list.size()
	
	# Try to grant one mod to each die
	for i in range(dice_count):
		var die = dice_hand.dice_list[i]
		if die.active_mods.size() == 0:  # Only add to empty dice
			var mod_id = available_mods[i % available_mods.size()]  # Cycle through available mods
			game_controller.grant_mod(mod_id)
			mods_granted += 1
			log_debug("Granted mod '" + mod_id + "' to die " + str(i + 1))
	
	log_debug("Total mods granted: " + str(mods_granted))
	_debug_show_mod_dice_count()  # Show final status

func _debug_test_mod_limit_block() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	log_debug("=== TESTING MOD LIMIT BLOCKING ===")
	
	# First show current status
	_debug_show_mod_dice_count()
	
	# Try to grant one more mod than should be allowed
	var mod_manager = game_controller.mod_manager
	if not mod_manager:
		log_debug("ERROR: ModManager not found")
		return
	
	var available_mods = mod_manager.get_available_mods()
	if available_mods.is_empty():
		log_debug("No mods available to test with")
		return
	
	var test_mod_id = available_mods[0]
	log_debug("Attempting to grant mod '" + test_mod_id + "' (should be blocked if limit reached)")
	
	var mod_count_before = game_controller._get_total_active_mod_count()
	game_controller.grant_mod(test_mod_id)
	var mod_count_after = game_controller._get_total_active_mod_count()
	
	if mod_count_after == mod_count_before:
		log_debug("✓ MOD LIMIT WORKING: Grant was blocked as expected")
	else:
		log_debug("✗ MOD LIMIT FAILED: Grant was allowed when it shouldn't be")
	
	_debug_show_mod_dice_count()  # Show final status

func _debug_test_shop_mod_purchase() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	log_debug("=== TESTING SHOP MOD PURCHASE & REMOVAL ===")
	
	var shop_ui = game_controller.shop_ui
	if not shop_ui:
		log_debug("ERROR: ShopUI not found")
		return
	
	# Show the shop if it's hidden
	if not shop_ui.visible:
		shop_ui.show()
		log_debug("Shop UI opened for testing")
	
	# Get the mod container and list current items
	var mod_container = shop_ui.mod_container
	if not mod_container:
		log_debug("ERROR: Mod container not found in shop")
		return
	
	var mod_items_before = mod_container.get_child_count()
	log_debug("Mod items in shop before purchase: " + str(mod_items_before))
	
	# List all mod items in shop
	for i in range(mod_container.get_child_count()):
		var child = mod_container.get_child(i)
		if child is ShopItem:
			log_debug("  Mod " + str(i + 1) + ": " + child.item_id + " (price: $" + str(child.price) + ")")
	
	# Try to find and purchase the first affordable mod
	var purchased_mod = null
	for child in mod_container.get_children():
		if child is ShopItem:
			if PlayerEconomy.can_afford(child.price):
				log_debug("Attempting to purchase mod: " + child.item_id + " for $" + str(child.price))
				purchased_mod = child
				break
	
	if not purchased_mod:
		log_debug("No affordable mods found in shop to test with")
		return
	
	# Store the mod info before purchase
	var _mod_id = purchased_mod.item_id
	var mod_price = purchased_mod.price
	var money_before = PlayerEconomy.money
	
	# Check if mod limit validation is working
	log_debug("Checking mod limit validation...")
	var current_mod_count = game_controller._get_total_active_mod_count()
	var expected_dice_count = game_controller._get_expected_dice_count()
	var current_dice_count = game_controller.dice_hand.dice_list.size() if game_controller.dice_hand else 0
	log_debug("Current mods: " + str(current_mod_count) + ", Expected dice: " + str(expected_dice_count) + ", Current dice: " + str(current_dice_count))
	
	if current_mod_count >= expected_dice_count:
		log_debug("Mod limit reached (vs expected dice count) - testing that purchase is blocked...")
		# Try to purchase and it should be blocked
		purchased_mod._on_buy_button_pressed()
		var money_after_blocked = PlayerEconomy.money
		if money_after_blocked == money_before:
			log_debug("✓ Purchase correctly blocked when mod limit reached")
		else:
			log_debug("✗ Purchase NOT blocked when mod limit reached!")
		return
	
	# Simulate the purchase by calling the button press
	log_debug("Proceeding with purchase test (limit not reached)...")
	purchased_mod._on_buy_button_pressed()
	
	# Check results after purchase
	await get_tree().process_frame  # Wait one frame for queue_free to process
	
	var money_after = PlayerEconomy.money
	var mod_items_after = mod_container.get_child_count()
	
	log_debug("=== PURCHASE RESULTS ===")
	log_debug("Money: $" + str(money_before) + " -> $" + str(money_after) + " (spent: $" + str(money_before - money_after) + ")")
	log_debug("Shop mod items: " + str(mod_items_before) + " -> " + str(mod_items_after) + " (removed: " + str(mod_items_before - mod_items_after) + ")")
	
	if money_after == money_before - mod_price:
		log_debug("✓ Money deducted correctly")
	else:
		log_debug("✗ Money deduction incorrect (expected: -$" + str(mod_price) + ")")
	
	if mod_items_after == mod_items_before - 1:
		log_debug("✓ Mod item removed from shop correctly")
	else:
		log_debug("✗ Mod item NOT removed from shop (expected -1 item)")
	
	# Check if the mod was applied to a die
	_debug_show_mod_dice_count()

## _debug_activate_crossing_challenge()
##
## Activates The Crossing Challenge for testing
func _debug_activate_crossing_challenge() -> void:
	log_debug("=== ACTIVATING THE CROSSING CHALLENGE ===")
	
	if not game_controller:
		log_debug("✗ GameController not found!")
		return
	
	var challenge_id = "the_crossing_challenge"
	
	if game_controller.active_challenges.has(challenge_id):
		log_debug("The Crossing Challenge is already active")
		return
	
	game_controller.activate_challenge(challenge_id)
	log_debug("✓ The Crossing Challenge activated!")
	log_debug("Target: 150 points with The Division debuff active")

## _debug_activate_pts150_challenge()
##
## Activates the 150pts Roll Minus One Challenge for comparison testing
func _debug_activate_pts150_challenge() -> void:
	log_debug("=== ACTIVATING 150PTS ROLL MINUS ONE CHALLENGE ===")
	
	if not game_controller:
		log_debug("✗ GameController not found!")
		return
	
	var challenge_id = "pts_150_roll_score_minus_one"
	
	if game_controller.active_challenges.has(challenge_id):
		log_debug("150pts Roll Minus One Challenge is already active")
		return
	
	game_controller.activate_challenge(challenge_id)
	log_debug("✓ 150pts Roll Minus One Challenge activated!")
	log_debug("Target: 150 points with Roll Score Minus One debuff active")

## _debug_show_active_challenges()
##
## Shows all currently active challenges and their status
func _debug_show_active_challenges() -> void:
	log_debug("=== ACTIVE CHALLENGES STATUS ===")
	
	if not game_controller:
		log_debug("✗ GameController not found!")
		return
	
	var active_challenges = game_controller.active_challenges
	
	if active_challenges.is_empty():
		log_debug("No challenges currently active")
		return
	
	log_debug("Active challenges (" + str(active_challenges.size()) + "):")
	
	for challenge_id in active_challenges.keys():
		var challenge = active_challenges[challenge_id]
		var progress = challenge.get_progress() * 100.0
		var target_score = challenge.get_target_score()
		
		log_debug("• " + challenge_id)
		log_debug("  Target Score: " + str(target_score))
		log_debug("  Progress: " + str(progress).pad_decimals(1) + "%")
		
		if game_controller.scorecard:
			var current_score = game_controller.scorecard.get_total_score()
			log_debug("  Current Score: " + str(current_score))
		
		log_debug("  Status: " + ("Completed" if progress >= 100.0 else "In Progress"))
