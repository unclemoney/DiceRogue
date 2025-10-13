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
		{"text": "Grant Random Mod", "method": "_debug_grant_mod"},
		
		# Economy
		{"text": "Add $100", "method": "_debug_add_money"},
		{"text": "Add $1000", "method": "_debug_add_big_money"},
		{"text": "Reset Money", "method": "_debug_reset_money"},
		
		# Dice Control
		{"text": "Roll All 6s", "method": "_debug_force_dice"},
		{"text": "Roll All 1s", "method": "_debug_force_ones"},
		{"text": "Roll Yahtzee", "method": "_debug_force_yahtzee"},
		
		# Game State
		{"text": "Show Score State", "method": "_debug_show_scores"},
		{"text": "Show All Items", "method": "_debug_show_items"},
		{"text": "Clear All Items", "method": "_debug_clear_items"},
		
		# Game Flow
		{"text": "Add Extra Rolls", "method": "_debug_add_rolls"},
		{"text": "Force End Turn", "method": "_debug_end_turn"},
		{"text": "Skip to Shop", "method": "_debug_skip_shop"},
		
		# System Testing
		{"text": "Test Score Calculation", "method": "_debug_test_scoring"},
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
	
	system_info_label.text = "FPS: %d | Process: %d | Nodes: %d" % [
		fps, 
		process_id,
		get_tree().get_node_count()
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
	var pu_manager = game_controller.get("pu_manager")
	if pu_manager and pu_manager.has_method("get_random_power_up_id"):
		var random_id = pu_manager.get_random_power_up_id()
		if random_id:
			game_controller._grant_power_up(random_id)
			log_debug("Granted PowerUp: " + random_id)
		else:
			log_debug("No PowerUps available to grant")
	else:
		log_debug("PowerUpManager not found or method missing")

func _debug_grant_consumable() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var consumable_manager = game_controller.get("consumable_manager")
	if consumable_manager and consumable_manager.has_method("get_random_consumable_id"):
		var random_id = consumable_manager.get_random_consumable_id()
		if random_id:
			game_controller._grant_consumable(random_id)
			log_debug("Granted Consumable: " + random_id)
		else:
			log_debug("No Consumables available to grant")
	else:
		log_debug("ConsumableManager not found or method missing")

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
	
	var dice_hand = game_controller.get("dice_hand")
	if dice_hand and dice_hand.has_method("debug_set_all_values"):
		dice_hand.debug_set_all_values(6)
		log_debug("Set all dice to 6")
	else:
		log_debug("DiceHand not found or debug method missing")

func _debug_show_scores() -> void:
	var state_info = []
	
	# ScoreModifierManager state
	if ScoreModifierManager:
		var total_additive = ScoreModifierManager.get_total_additive()
		var total_multiplier = ScoreModifierManager.get_total_multiplier()
		state_info.append("Score Modifiers: +%d additive, %.2fx multiplier" % [total_additive, total_multiplier])
	
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

func _debug_clear_items() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	# Clear active items
	var cleared_count = 0
	for id in game_controller.active_power_ups.keys():
		game_controller._revoke_power_up(id)
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
	
	var mod_manager = game_controller.get("mod_manager")
	if mod_manager and mod_manager.has_method("get_random_mod_id"):
		var random_id = mod_manager.get_random_mod_id()
		if random_id:
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
	
	var dice_hand = game_controller.get("dice_hand")
	if dice_hand and dice_hand.has_method("debug_set_all_values"):
		dice_hand.debug_set_all_values(1)
		log_debug("Set all dice to 1")
	else:
		log_debug("DiceHand not found or debug method missing")

func _debug_force_yahtzee() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var dice_hand = game_controller.get("dice_hand")
	if dice_hand and dice_hand.has_method("debug_set_all_values"):
		dice_hand.debug_set_all_values(5)  # All 5s for Yahtzee
		log_debug("Set all dice to 5 (Yahtzee)")
	else:
		log_debug("DiceHand not found or debug method missing")

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
	
	var turn_tracker = game_controller.get("turn_tracker")
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
	
	var turn_tracker = game_controller.get("turn_tracker")
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
		test_results.append("Then × %.2f = %.0f final" % [multiplier, final_score])
	
	# Test dice evaluation
	if game_controller:
		var dice_hand = game_controller.get("dice_hand")
		if dice_hand and ScoreEvaluatorSingleton:
			test_results.append("=== DICE EVALUATION TEST ===")
			var dice_values = dice_hand.get_values() if dice_hand.has_method("get_values") else [1,2,3,4,5]
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
	
	var round_manager = game_controller.get("round_manager")
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
	var turn_tracker = game_controller.get("turn_tracker")
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
	var turn_tracker = game_controller.get("turn_tracker") if game_controller else null
	if turn_tracker and turn_tracker.has_method("get_rolls_left"):
		debug_state_data["rolls_left"] = turn_tracker.get_rolls_left()
	
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