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
@onready var tab_container: TabContainer
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
	main_container.custom_minimum_size = Vector2(1200, 600)
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
	
	# Tab container for organized debug sections
	tab_container = TabContainer.new()
	tab_container.custom_minimum_size = Vector2(1100, 400)
	tab_container.add_theme_color_override("font_color", Color.WHITE)
	main_container.add_child(tab_container)
	
	_create_debug_tabs()
	
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

func _create_debug_tabs() -> void:
	# Define button categories for tabs
	var tab_definitions = {
		"Economy": [
			{"text": "Add $100", "method": "_debug_add_money"},
			{"text": "Add $1000", "method": "_debug_add_big_money"},
			{"text": "Reset Money", "method": "_debug_reset_money"},
		],
		"Items": [
			{"text": "Grant Random PowerUp", "method": "_debug_grant_powerup"},
			{"text": "Grant Random Consumable", "method": "_debug_grant_consumable"},
			{"text": "Grant AnyScore", "method": "_debug_grant_any_score"},
			{"text": "Grant Green Envy", "method": "_debug_grant_green_envy"},
			{"text": "Grant Poor House", "method": "_debug_grant_poor_house"},
			{"text": "Grant Empty Shelves", "method": "_debug_grant_empty_shelves"},
			{"text": "Grant Double Or Nothing", "method": "_debug_grant_double_or_nothing"},
			{"text": "Grant The Rarities", "method": "_debug_grant_the_rarities"},
			{"text": "Grant The Pawn Shop", "method": "_debug_grant_the_pawn_shop"},
			{"text": "Grant One Extra Dice", "method": "_debug_grant_one_extra_dice"},
			{"text": "Grant Go Broke or Go Home", "method": "_debug_grant_go_broke_or_go_home"},
			{"text": "Grant Free Chores", "method": "_debug_grant_free_chores"},
			{"text": "Grant All Chores", "method": "_debug_grant_all_chores"},
			{"text": "Grant One Free Mod", "method": "_debug_grant_one_free_mod"},
			{"text": "Grant Random Uncommon PowerUp", "method": "_debug_grant_random_uncommon_powerup"},
			{"text": "Register AnyScore", "method": "_debug_register_any_score"},
			{"text": "Grant Random Mod", "method": "_debug_grant_mod"},
			{"text": "Test Consumer PowerUp", "method": "_debug_test_consumer_powerup"},
			{"text": "Grant Lower Ten", "method": "_debug_grant_lower_ten"},
			{"text": "Grant Different Straights", "method": "_debug_grant_different_straights"},
			{"text": "Grant Plus The Last", "method": "_debug_grant_plus_thelast"},
			{"text": "Grant Allowance", "method": "_debug_grant_allowance"},
			{"text": "Grant Ungrounded", "method": "_debug_grant_ungrounded"},
			{"text": "Show All Items", "method": "_debug_show_items"},
			{"text": "Clear All Items", "method": "_debug_clear_items"},
		],
		"Score Card Upgrades": [
			{"text": "Grant Master Upgrade", "method": "_debug_grant_master_upgrade"},
			{"text": "Grant Ones Upgrade", "method": "_debug_grant_ones_upgrade"},
			{"text": "Grant Yahtzee Upgrade", "method": "_debug_grant_yahtzee_upgrade"},
			{"text": "Upgrade All Categories (Direct)", "method": "_debug_upgrade_all_categories"},
			{"text": "Show Category Levels", "method": "_debug_show_category_levels"},
			{"text": "Unlock All Upgrade Consumables", "method": "_debug_unlock_all_upgrade_consumables"},
			{"text": "Lock All Upgrade Consumables", "method": "_debug_lock_all_upgrade_consumables"},
		],
		"Dice Control": [
			{"text": "Roll All 6s", "method": "_debug_force_dice"},
			{"text": "Roll All 1s", "method": "_debug_force_ones"},
			{"text": "Roll Yahtzee", "method": "_debug_force_yahtzee"},
			{"text": "Roll Large Straight", "method": "_debug_force_large_straight"},
			{"text": "Activate Perfect Strangers", "method": "_debug_activate_perfect_strangers"},
		],
		"Dice Colors": [
			{"text": "Toggle Dice Colors", "method": "_debug_toggle_dice_colors"},
			{"text": "Force All Green", "method": "_debug_force_all_green"},
			{"text": "Force All Red", "method": "_debug_force_all_red"},
			{"text": "Force All Purple", "method": "_debug_force_all_purple"},
			{"text": "Force All Blue", "method": "_debug_force_all_blue"},
			{"text": "Clear All Colors", "method": "_debug_clear_all_colors"},
			{"text": "Show Color Effects", "method": "_debug_show_color_effects"},
			{"text": "Test Color Scoring", "method": "_debug_test_color_scoring"},
			{"text": "Reset Call Counter", "method": "_debug_reset_call_counter"},
		],
		"Testing": [
			{"text": "Apply The Division Debuff", "method": "_debug_apply_division_debuff"},
			{"text": "Remove The Division Debuff", "method": "_debug_remove_division_debuff"},
			{"text": "Apply Half Additive Debuff", "method": "_debug_apply_half_additive_debuff"},
			{"text": "Remove Half Additive Debuff", "method": "_debug_remove_half_additive_debuff"},
			{"text": "Apply Too Greedy Debuff", "method": "_debug_apply_too_greedy_debuff"},
			{"text": "Remove Too Greedy Debuff", "method": "_debug_remove_too_greedy_debuff"},
			{"text": "Test Division vs Perfect Strangers", "method": "_debug_test_division_perfect_strangers"},
			{"text": "Activate The Crossing Challenge", "method": "_debug_activate_crossing_challenge"},
			{"text": "Activate 150pts Roll Minus One", "method": "_debug_activate_pts150_challenge"},
			{"text": "Activate Tough Addition Challenge", "method": "_debug_activate_tough_addition_challenge"},
			{"text": "Activate Greed Isn't Good Challenge", "method": "_debug_activate_greed_isnt_good_challenge"},
			{"text": "Show Active Challenges", "method": "_debug_show_active_challenges"},
			{"text": "Show Mod/Dice Count", "method": "_debug_show_mod_dice_count"},
			{"text": "Fill All Dice w/ Mods", "method": "_debug_fill_dice_with_mods"},
			{"text": "Test Mod Limit Block", "method": "_debug_test_mod_limit_block"},
			{"text": "Test Shop Mod Purchase", "method": "_debug_test_shop_mod_purchase"},
		],
		"Game State": [
			{"text": "Show Score State", "method": "_debug_show_scores"},
			{"text": "Show Roll Stats", "method": "_debug_show_roll_stats"},
			{"text": "Add Extra Rolls", "method": "_debug_add_rolls"},
			{"text": "Force End Turn", "method": "_debug_end_turn"},
			{"text": "Skip to Shop", "method": "_debug_skip_shop"},
			{"text": "Test Score Calculation", "method": "_debug_test_scoring"},
			{"text": "Debug Multiplier System", "method": "_debug_multiplier_system"},
			{"text": "Trigger All Signals", "method": "_debug_test_signals"},
		],
		"Utilities": [
			{"text": "Save Debug State", "method": "_debug_save_state"},
			{"text": "Load Debug State", "method": "_debug_load_state"},
			{"text": "Reset Game", "method": "_debug_reset_game"},
			{"text": "Clear Output", "method": "_on_clear_output_pressed"},
		],
		"Progress": [
			{"text": "Show Progress Stats", "method": "_debug_show_progress_stats"},
			{"text": "Print All Item Status", "method": "_debug_print_all_item_status"},
			{"text": "Unlock All Items", "method": "_debug_unlock_all_items"},
			{"text": "Lock All Items", "method": "_debug_lock_all_items"},
			{"text": "Unlock All Colored Dice", "method": "_debug_unlock_all_colored_dice"},
			{"text": "Lock All Colored Dice", "method": "_debug_lock_all_colored_dice"},
			{"text": "Unlock PowerUp: Step By Step", "method": "_debug_unlock_step_by_step"},
			{"text": "Lock PowerUp: Step By Step", "method": "_debug_lock_step_by_step"},
			{"text": "Unlock Consumable: Quick Cash", "method": "_debug_unlock_quick_cash"},
			{"text": "Lock Consumable: Quick Cash", "method": "_debug_lock_quick_cash"},
			{"text": "Force Complete Game", "method": "_debug_force_complete_game"},
			{"text": "Simulate Yahtzee Roll", "method": "_debug_simulate_yahtzee"},
			{"text": "Simulate High Score", "method": "_debug_simulate_high_score"},
			{"text": "Reset Progress Data", "method": "_debug_reset_progress"},
			{"text": "Save Progress", "method": "_debug_save_progress"},
		],
		"Chores": [
			{"text": "Add Progress +10", "method": "_debug_chores_add_progress"},
			{"text": "Add Progress +50", "method": "_debug_chores_add_big_progress"},
			{"text": "Complete Current Task", "method": "_debug_chores_complete_task"},
			{"text": "Trigger Mom Immediately", "method": "_debug_chores_trigger_mom"},
			{"text": "Select New Task", "method": "_debug_chores_new_task"},
			{"text": "Reset Progress", "method": "_debug_chores_reset"},
			{"text": "Show Chore State", "method": "_debug_chores_show_state"},
			{"text": "Show PowerUp Ratings", "method": "_debug_chores_show_ratings"},
			{"text": "Test Mom Dialog (Neutral)", "method": "_debug_chores_mom_neutral"},
			{"text": "Test Mom Dialog (Upset)", "method": "_debug_chores_mom_upset"},
			{"text": "Test Mom Dialog (Happy)", "method": "_debug_chores_mom_happy"},
		],
		"Synergies": [
			{"text": "Show Synergy Status", "method": "_debug_synergy_show_status"},
			{"text": "Grant 5 G-Rated", "method": "_debug_synergy_grant_5_g"},
			{"text": "Grant 5 PG-Rated", "method": "_debug_synergy_grant_5_pg"},
			{"text": "Grant 5 PG-13-Rated", "method": "_debug_synergy_grant_5_pg13"},
			{"text": "Grant 5 R-Rated", "method": "_debug_synergy_grant_5_r"},
			{"text": "Grant 5 NC-17-Rated", "method": "_debug_synergy_grant_5_nc17"},
			{"text": "Grant Rainbow Set", "method": "_debug_synergy_grant_rainbow"},
			{"text": "Clear All PowerUps", "method": "_debug_synergy_clear_all"},
			{"text": "Show Rating Counts", "method": "_debug_synergy_show_counts"},
			{"text": "Show Active Bonuses", "method": "_debug_synergy_show_bonuses"},
		],
		"Tutorial": [
			{"text": "Start Tutorial", "method": "_debug_tutorial_start"},
			{"text": "Skip Tutorial", "method": "_debug_tutorial_skip"},
			{"text": "Next Step", "method": "_debug_tutorial_next_step"},
			{"text": "Previous Step", "method": "_debug_tutorial_prev_step"},
			{"text": "Next Part", "method": "_debug_tutorial_next_part"},
			{"text": "Reset Tutorial Progress", "method": "_debug_tutorial_reset"},
			{"text": "Show Tutorial State", "method": "_debug_tutorial_show_state"},
			{"text": "Show All Steps", "method": "_debug_tutorial_list_steps"},
			{"text": "Jump to Step (Console)", "method": "_debug_tutorial_jump_prompt"},
			{"text": "Force Complete Tutorial", "method": "_debug_tutorial_force_complete"},
		],
		"Difficulty": [
			{"text": "Show Channel Info", "method": "_debug_difficulty_show_channel"},
			{"text": "Show Round Config", "method": "_debug_difficulty_show_round"},
			{"text": "Show Active Debuffs", "method": "_debug_difficulty_show_debuffs"},
			{"text": "Show All Debuff Info", "method": "_debug_difficulty_show_all_debuffs"},
			{"text": "Toggle Verbose Mode", "method": "_debug_difficulty_toggle_verbose"},
			{"text": "Force Apply Debuffs", "method": "_debug_difficulty_force_apply"},
			{"text": "Clear Active Debuffs", "method": "_debug_difficulty_clear_debuffs"},
			{"text": "Show Multiplier Breakdown", "method": "_debug_difficulty_show_multipliers"},
		]
	}
	
	# Create tabs
	for tab_name in tab_definitions.keys():
		var scroll_container = ScrollContainer.new()
		scroll_container.name = tab_name
		tab_container.add_child(scroll_container)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)
		scroll_container.add_child(vbox)
		
		var button_grid = GridContainer.new()
		button_grid.columns = 3  # 3 columns for better fit in tabs
		button_grid.add_theme_constant_override("h_separation", 8)
		button_grid.add_theme_constant_override("v_separation", 4)
		vbox.add_child(button_grid)
		
		# Add buttons for this tab
		for button_data in tab_definitions[tab_name]:
			var button = Button.new()
			button.text = button_data["text"]
			button.custom_minimum_size = Vector2(160, 30)
			button.add_theme_font_size_override("font_size", 10)
			
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

func _debug_grant_green_envy() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("green_envy")
		log_debug("Granted Green Envy consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_grant_poor_house() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("poor_house")
		log_debug("Granted Poor House consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_grant_empty_shelves() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("empty_shelves")
		log_debug("Granted Empty Shelves consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_grant_double_or_nothing() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("double_or_nothing")
		log_debug("Granted Double Or Nothing consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_grant_the_rarities() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("the_rarities")
		log_debug("Granted The Rarities consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_grant_the_pawn_shop() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("the_pawn_shop")
		log_debug("Granted The Pawn Shop consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_grant_one_extra_dice() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("one_extra_dice")
		log_debug("Granted One Extra Dice consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_grant_go_broke_or_go_home() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("go_broke_or_go_home")
		log_debug("Granted Go Broke or Go Home consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_grant_free_chores() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("free_chores")
		log_debug("Granted Free Chores consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_grant_all_chores() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("all_chores")
		log_debug("Granted All Chores consumable")
	else:
		log_debug("GameController missing grant_consumable method")

func _debug_grant_one_free_mod() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("one_free_mod")
		log_debug("Granted One Free Mod consumable")
	else:
		log_debug("GameController missing grant_consumable method")

## Grant the Lower Ten powerup (uncommon) - +10 points for lower section scores
func _debug_grant_lower_ten() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_power_up"):
		game_controller.grant_power_up("lower_ten")
		log_debug("Granted Lower Ten PowerUp")
	else:
		log_debug("GameController missing grant_power_up method")

## Grant the Different Straights powerup (rare) - allows straights with one gap
func _debug_grant_different_straights() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_power_up"):
		game_controller.grant_power_up("different_straights")
		log_debug("Granted Different Straights PowerUp")
	else:
		log_debug("GameController missing grant_power_up method")

## Grant the Plus The Last powerup (rare) - adds last scored value to current score
func _debug_grant_plus_thelast() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_power_up"):
		game_controller.grant_power_up("plus_thelast")
		log_debug("Granted Plus The Last PowerUp")
	else:
		log_debug("GameController missing grant_power_up method")

## Grant the Allowance powerup (common) - $100 on game completion
func _debug_grant_allowance() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_power_up"):
		game_controller.grant_power_up("allowance")
		log_debug("Granted Allowance PowerUp")
	else:
		log_debug("GameController missing grant_power_up method")

## Grant the Ungrounded powerup (legendary) - blocks all debuffs
func _debug_grant_ungrounded() -> void:
	if not game_controller:
		log_debug("No GameController found")
		return
	
	if game_controller.has_method("grant_power_up"):
		game_controller.grant_power_up("ungrounded")
		log_debug("Granted Ungrounded PowerUp")
	else:
		log_debug("GameController missing grant_power_up method")

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

## _debug_apply_half_additive_debuff()
##
## Applies the Half Additive debuff for testing
func _debug_apply_half_additive_debuff() -> void:
	log_debug("=== APPLYING HALF ADDITIVE DEBUFF ===")
	
	if not game_controller:
		log_debug("✗ GameController not found!")
		return
	
	if game_controller.is_debuff_active("half_additive"):
		log_debug("Half Additive debuff is already active")
		return
	
	game_controller.apply_debuff("half_additive")
	log_debug("✓ Half Additive debuff applied!")
	log_debug("Effect: All additive bonuses are halved before multipliers apply")

## _debug_remove_half_additive_debuff()
##
## Removes the Half Additive debuff
func _debug_remove_half_additive_debuff() -> void:
	log_debug("=== REMOVING HALF ADDITIVE DEBUFF ===")
	
	if not game_controller:
		log_debug("✗ GameController not found!")
		return
	
	if not game_controller.is_debuff_active("half_additive"):
		log_debug("Half Additive debuff is not active")
		return
	
	game_controller.disable_debuff("half_additive")
	log_debug("✓ Half Additive debuff removed!")

## _debug_apply_too_greedy_debuff()
##
## Applies the Too Greedy debuff for testing
func _debug_apply_too_greedy_debuff() -> void:
	log_debug("=== APPLYING TOO GREEDY DEBUFF ===")
	
	if not game_controller:
		log_debug("✗ GameController not found!")
		return
	
	if game_controller.is_debuff_active("too_greedy"):
		log_debug("Too Greedy debuff is already active")
		return
	
	game_controller.apply_debuff("too_greedy")
	var current_money = PlayerEconomy.get_money()
	log_debug("✓ Too Greedy debuff applied!")
	log_debug("Effect: Money over $50 penalizes score (current: $%d, penalty: -%d)" % [current_money, roundi(float(current_money) / 100.0) if current_money > 50 else 0])

## _debug_remove_too_greedy_debuff()
##
## Removes the Too Greedy debuff
func _debug_remove_too_greedy_debuff() -> void:
	log_debug("=== REMOVING TOO GREEDY DEBUFF ===")
	
	if not game_controller:
		log_debug("✗ GameController not found!")
		return
	
	if not game_controller.is_debuff_active("too_greedy"):
		log_debug("Too Greedy debuff is not active")
		return
	
	game_controller.disable_debuff("too_greedy")
	log_debug("✓ Too Greedy debuff removed!")

## _debug_activate_tough_addition_challenge()
##
## Activates the Tough Addition Challenge for testing
func _debug_activate_tough_addition_challenge() -> void:
	log_debug("=== ACTIVATING TOUGH ADDITION CHALLENGE ===")
	
	if not game_controller:
		log_debug("✗ GameController not found!")
		return
	
	var challenge_id = "tough_addition"
	
	if game_controller.active_challenges.has(challenge_id):
		log_debug("Tough Addition Challenge is already active")
		return
	
	game_controller.activate_challenge(challenge_id)
	log_debug("✓ Tough Addition Challenge activated!")
	log_debug("Target: 350 points with Half Additive debuff active")
	log_debug("Difficulty: 3 | Reward: $200")

## _debug_activate_greed_isnt_good_challenge()
##
## Activates the Greed Isn't Good Challenge for testing
func _debug_activate_greed_isnt_good_challenge() -> void:
	log_debug("=== ACTIVATING GREED ISN'T GOOD CHALLENGE ===")
	
	if not game_controller:
		log_debug("✗ GameController not found!")
		return
	
	var challenge_id = "greed_isnt_good"
	
	if game_controller.active_challenges.has(challenge_id):
		log_debug("Greed Isn't Good Challenge is already active")
		return
	
	game_controller.activate_challenge(challenge_id)
	log_debug("✓ Greed Isn't Good Challenge activated!")
	log_debug("Target: 450 points with Too Greedy debuff active")
	log_debug("Difficulty: 4 | Reward: $250")

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

## Debug functions for dice color system
func _debug_toggle_dice_colors() -> void:
	if not _get_dice_color_manager():
		return
	var current_state = _get_dice_color_manager().are_colors_enabled()
	_get_dice_color_manager().set_colors_enabled(not current_state)
	log_debug("Dice colors " + ("ENABLED" if not current_state else "DISABLED"))

func _debug_force_all_green() -> void:
	var dice_hand = _get_dice_hand()
	if not dice_hand:
		return
		
	dice_hand.debug_force_all_colors(preload("res://Scripts/Core/dice_color.gd").Type.GREEN)
	log_debug("Forced all dice to GREEN color")
	
	# Use DiceColorManager debug function for comprehensive testing
	DiceColorManager.force_all_green()

func _debug_force_all_red() -> void:
	var dice_hand = _get_dice_hand()
	if not dice_hand:
		return
		
	dice_hand.debug_force_all_colors(preload("res://Scripts/Core/dice_color.gd").Type.RED)
	log_debug("Forced all dice to RED color")

func _debug_force_all_purple() -> void:
	var dice_hand = _get_dice_hand()
	if not dice_hand:
		return
		
	dice_hand.debug_force_all_colors(preload("res://Scripts/Core/dice_color.gd").Type.PURPLE)
	log_debug("Forced all dice to PURPLE color")

func _debug_force_all_blue() -> void:
	var dice_hand = _get_dice_hand()
	if not dice_hand:
		return
		
	dice_hand.debug_force_all_colors(preload("res://Scripts/Core/dice_color.gd").Type.BLUE)
	log_debug("Forced all dice to BLUE color")

func _debug_clear_all_colors() -> void:
	var dice_hand = _get_dice_hand()
	if not dice_hand:
		return
		
	dice_hand.debug_clear_all_colors()
	log_debug("Cleared all dice colors")

func _debug_show_color_effects() -> void:
	var dice_hand = _get_dice_hand()
	if not dice_hand:
		return
		
	var effects = dice_hand.get_color_effects()
	var counts = dice_hand.get_color_counts()
	
	log_debug("=== DICE COLOR EFFECTS ===")
	var dice_color_manager = _get_dice_color_manager()
	if dice_color_manager:
		log_debug("Colors enabled: " + str(dice_color_manager.are_colors_enabled()))
	else:
		log_debug("Colors enabled: N/A (manager not found)")
	log_debug("Color counts:")
	log_debug("  Green: " + str(counts.green))
	log_debug("  Red: " + str(counts.red))
	log_debug("  Purple: " + str(counts.purple))
	log_debug("  None: " + str(counts.none))
	
	log_debug("Color effects:")
	log_debug("  Green money bonus: $" + str(effects.green_money))
	log_debug("  Red additive bonus: +" + str(effects.red_additive))
	log_debug("  Purple multiplier: x" + str(effects.purple_multiplier))
	log_debug("  Same color bonus (5+): " + str(effects.same_color_bonus))

func _get_dice_hand():
	var dice_hand = get_tree().get_first_node_in_group("dice_hand")
	if not dice_hand:
		log_debug("ERROR: Could not find dice hand")
		return null
	return dice_hand

func _get_dice_color_manager():
	# Try to get the DiceColorManager autoload via tree search
	if get_tree():
		var manager = get_tree().get_first_node_in_group("dice_color_manager")
		if manager:
			return manager
		
		# Try to find it by name in autoloads (backup method)
		var main_scene = get_tree().current_scene
		if main_scene:
			var autoload_node = main_scene.get_node_or_null("/root/DiceColorManager")
			if autoload_node:
				return autoload_node
	
	log_debug("ERROR: Could not find DiceColorManager")
	return null

## Test comprehensive dice color scoring pipeline
func _debug_test_color_scoring():
	log_debug("=== TESTING DICE COLOR SCORING ===")
	
	var dice_hand = get_tree().get_first_node_in_group("dice_hand")
	if not dice_hand:
		log_debug("ERROR: No dice hand found!")
		return
	
	var dice_list = dice_hand.get_dice()
	if dice_list.size() < 5:
		log_debug("ERROR: Need at least 5 dice for test")
		return
	
	# Force specific values for predictable testing
	for i in range(dice_list.size()):
		dice_list[i].value = i + 2  # Values: 2, 3, 4, 5, 6
	
	# Set test colors: 2 green (money), 2 red (additive), 1 purple (multiplier)
	var DiceColorType = preload("res://Scripts/Core/dice_color.gd").Type
	dice_list[0].force_color(DiceColorType.GREEN)   # Die value 2 = $2
	dice_list[1].force_color(DiceColorType.GREEN)   # Die value 3 = $3 (total $5)
	dice_list[2].force_color(DiceColorType.RED)     # Die value 4 = +4 additive
	dice_list[3].force_color(DiceColorType.RED)     # Die value 5 = +5 additive (total +9)
	dice_list[4].force_color(DiceColorType.PURPLE)  # Die value 6 = x6 multiplier
	
	log_debug("Set test colors: 2 Green ($5), 2 Red (+9), 1 Purple (x6)")
	
	# Test the color effects calculation
	var color_effects = dice_hand.get_color_effects()
	log_debug("Color effects result: " + str(color_effects))
	
	# Test a scoring calculation
	var scorecard = get_tree().get_first_node_in_group("scorecard")
	if scorecard:
		var test_score = scorecard.calculate_score("chance", [2, 3, 4, 5, 6])
		log_debug("Test 'chance' score with effects: " + str(test_score))
		log_debug("Expected: Base 20 + 9 additive = 29, then x6 = 174, plus $5 to economy")
	else:
		log_debug("ERROR: No scorecard found!")
	
	log_debug("=== TEST COMPLETE ===")

## Reset scorecard call counter for debugging
func _debug_reset_call_counter():
	var scorecard = get_tree().get_first_node_in_group("scorecard")
	if scorecard and scorecard.has_method("reset_call_counter"):
		scorecard.reset_call_counter()
		log_debug("Reset scorecard call counter")
	else:
		log_debug("ERROR: Could not find scorecard or reset method")

## Test TheConsumerIsAlwaysRight PowerUp by granting it and simulating consumable usage
func _debug_test_consumer_powerup():
	if not game_controller:
		log_debug("ERROR: No GameController found")
		return
	
	log_debug("=== Testing TheConsumerIsAlwaysRight PowerUp ===")
	
	# Get initial state
	var initial_consumables = Statistics.consumables_used
	var initial_multiplier = ScoreModifierManager.get_total_multiplier()
	log_debug("Initial state: %d consumables used, %.2fx multiplier" % [initial_consumables, initial_multiplier])
	
	# Grant the PowerUp
	game_controller.grant_power_up("the_consumer_is_always_right")
	await get_tree().process_frame
	
	var after_grant_multiplier = ScoreModifierManager.get_total_multiplier()
	log_debug("After granting PowerUp: %.2fx multiplier" % after_grant_multiplier)
	
	# Simulate using consumables by calling the method that tracks statistics
	log_debug("Simulating consumable usage...")
	game_controller._on_consumable_used("poor_house")
	await get_tree().process_frame
	
	var after_first_use = Statistics.consumables_used
	var after_first_multiplier = ScoreModifierManager.get_total_multiplier()
	log_debug("After 1st consumable: %d total used, %.2fx multiplier" % [after_first_use, after_first_multiplier])
	
	# Grant another consumable and use it
	game_controller.grant_consumable("any_score")
	await get_tree().process_frame
	game_controller._on_consumable_used("any_score")
	await get_tree().process_frame
	
	var after_second_use = Statistics.consumables_used
	var after_second_multiplier = ScoreModifierManager.get_total_multiplier()
	log_debug("After 2nd consumable: %d total used, %.2fx multiplier" % [after_second_use, after_second_multiplier])
	
	# Test score calculation
	var scorecard = get_tree().get_first_node_in_group("scorecard")
	if scorecard:
		var test_dice = [3, 3, 3, 4, 5]  # Three 3s = 9 points base
		var result = scorecard.calculate_score_with_breakdown("three_of_a_kind", test_dice)
		log_debug("Score test - Base: %d, Final: %d, Multiplier: %.2fx" % [
			result.breakdown_info.base_score,
			result.final_score,
			result.breakdown_info.multiplier
		])

# ========================================
# PROGRESS SYSTEM DEBUG FUNCTIONS
# ========================================

func _debug_show_progress_stats() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		log_debug("ERROR: ProgressManager not found")
		return
	
	log_debug("=== PROGRESS SYSTEM STATUS ===")
	log_debug("Game tracking active: %s" % progress_manager.is_tracking_game)
	log_debug("Games completed: %d" % progress_manager.cumulative_stats.get("games_completed", 0))
	log_debug("Total score: %d" % progress_manager.cumulative_stats.get("total_score", 0))
	log_debug("Total yahtzees: %d" % progress_manager.cumulative_stats.get("total_yahtzees", 0))

func _debug_print_all_item_status() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		log_debug("ERROR: ProgressManager not found")
		return
	
	log_debug("=== ALL ITEM STATUS ===")
	
	# Try to find managers through GameController
	var gc = get_tree().get_first_node_in_group("game_controller")
	var power_up_manager = null
	var consumable_manager = null
	var mod_manager = null
	
	if gc:
		# Use GameController's node paths to find managers
		power_up_manager = gc.get_node_or_null(gc.power_up_manager_path)
		consumable_manager = gc.get_node_or_null(gc.consumable_manager_path) 
		mod_manager = gc.get_node_or_null(gc.mod_manager_path)
	
	# Fallback: try to find managers by common paths
	if not power_up_manager:
		power_up_manager = get_tree().get_first_node_in_group("power_up_manager")
	if not consumable_manager:
		consumable_manager = get_tree().get_first_node_in_group("consumable_manager")
	if not mod_manager:
		mod_manager = get_tree().get_first_node_in_group("mod_manager")
	
	# Check PowerUps
	if power_up_manager and power_up_manager.has_method("get_available_power_ups"):
		log_debug("\n--- POWERUPS ---")
		var power_ups = power_up_manager.get_available_power_ups()
		for power_up_id in power_ups:
			var is_unlocked = progress_manager.is_item_unlocked(power_up_id)
			var status = "UNLOCKED" if is_unlocked else "LOCKED"
			log_debug("  %s: %s" % [power_up_id, status])
	else:
		log_debug("\n--- POWERUPS ---")
		log_debug("PowerUpManager not found. Checked paths:")
		if gc:
			log_debug("  GameController path: %s" % gc.power_up_manager_path)
		log_debug("  Group search: power_up_manager")
	
	# Check Consumables 
	if consumable_manager:
		log_debug("\n--- CONSUMABLES ---")
		var consumables = []
		if consumable_manager.has_method("get_all_consumable_ids"):
			consumables = consumable_manager.get_all_consumable_ids()
		elif "_defs_by_id" in consumable_manager:
			consumables = consumable_manager._defs_by_id.keys()
		
		for consumable_id in consumables:
			var is_unlocked = progress_manager.is_item_unlocked(consumable_id)
			var status = "UNLOCKED" if is_unlocked else "LOCKED"
			log_debug("  %s: %s" % [consumable_id, status])
	else:
		log_debug("\n--- CONSUMABLES ---")
		log_debug("ConsumableManager not found. Checked paths:")
		if gc:
			log_debug("  GameController path: %s" % gc.consumable_manager_path)
		log_debug("  Group search: consumable_manager")
	
	# Check Mods
	if mod_manager:
		log_debug("\n--- MODS ---")
		var mods = []
		if "_defs_by_id" in mod_manager:
			mods = mod_manager._defs_by_id.keys()
		
		for mod_id in mods:
			var is_unlocked = progress_manager.is_item_unlocked(mod_id)
			var status = "UNLOCKED" if is_unlocked else "LOCKED"
			log_debug("  %s: %s" % [mod_id, status])
	else:
		log_debug("\n--- MODS ---")
		log_debug("ModManager not found. Checked paths:")
		if gc:
			log_debug("  GameController path: %s" % gc.mod_manager_path)
		log_debug("  Group search: mod_manager")
	
	# Check Unlockable Items in ProgressManager
	log_debug("\n--- PROGRESS MANAGER ITEMS ---")
	if "unlockable_items" in progress_manager:
		for item_id in progress_manager.unlockable_items:
			var item = progress_manager.unlockable_items[item_id]
			var status = "UNLOCKED" if item.is_unlocked else "LOCKED"
			var type_str = item.get_type_string() if item.has_method("get_type_string") else "Unknown"
			log_debug("  %s (%s): %s" % [item_id, type_str, status])
	
	log_debug("\n=== STATUS REPORT COMPLETE ===\n")
	
	# Show current game stats if tracking
	if progress_manager.is_tracking_game:
		log_debug("--- Current Game Stats ---")
		for key in progress_manager.current_game_stats:
			var value = progress_manager.current_game_stats[key]
			log_debug("%s: %s" % [key, str(value)])
	
	# Count locked vs unlocked items
	var total_items = progress_manager.unlockable_items.size()
	var unlocked_count = 0
	for item_id in progress_manager.unlockable_items:
		var item = progress_manager.unlockable_items[item_id]
		if item.is_unlocked:
			unlocked_count += 1
	
	log_debug("Items: %d/%d unlocked" % [unlocked_count, total_items])

func _debug_unlock_all_items() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		log_debug("ERROR: ProgressManager not found")
		return
	
	var count = 0
	log_debug("Unlocking all items...")
	for item_id in progress_manager.unlockable_items:
		progress_manager.debug_unlock_item(item_id)
		count += 1
	
	log_debug("Unlocked %d items - shop should refresh automatically" % count)

func _debug_lock_all_items() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		log_debug("ERROR: ProgressManager not found")
		return
	
	var count = 0
	log_debug("Locking all items...")
	for item_id in progress_manager.unlockable_items:
		progress_manager.debug_lock_item(item_id)
		count += 1
	
	log_debug("Locked %d items - shop should refresh automatically" % count)

func _debug_unlock_step_by_step() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		progress_manager.debug_unlock_item("step_by_step")
		log_debug("Unlocked Step By Step PowerUp")

func _debug_lock_step_by_step() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		progress_manager.debug_lock_item("step_by_step")
		log_debug("Locked Step By Step PowerUp")

func _debug_unlock_quick_cash() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		progress_manager.debug_unlock_item("quick_cash")
		log_debug("Unlocked Quick Cash Consumable")

func _debug_lock_quick_cash() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		progress_manager.debug_lock_item("quick_cash")
		log_debug("Locked Quick Cash Consumable")

func _debug_force_complete_game() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		log_debug("ERROR: ProgressManager not found")
		return
	
	# Force end game tracking with a test score
	if not progress_manager.is_tracking_game:
		progress_manager.start_game_tracking()
	
	progress_manager.end_game_tracking(250, true)  # 250 points, won game
	log_debug("Forced game completion with 250 points")

func _debug_simulate_yahtzee() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		# Ensure game tracking is started before tracking yahtzee
		if not progress_manager.is_tracking_game:
			progress_manager.start_game_tracking()
			log_debug("Started game tracking for yahtzee simulation")
		progress_manager.track_yahtzee_rolled()
		log_debug("Simulated yahtzee roll - current game yahtzees: %d" % progress_manager.current_game_stats.get("yahtzees_rolled", 0))

func _debug_simulate_high_score() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		progress_manager.track_score_assigned("yahtzee", 350)  # High score
		log_debug("Simulated high score of 350 points")

func _debug_reset_progress() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		log_debug("ERROR: ProgressManager not found")
		return
	
	# Reset cumulative stats
	progress_manager.cumulative_stats = {
		"games_completed": 0,
		"games_won": 0,
		"total_score": 0,
		"total_money_earned": 0,
		"total_consumables_used": 0,
		"total_yahtzees": 0,
		"total_straights": 0,
		"total_color_bonuses": 0
	}
	
	# Lock all items
	_debug_lock_all_items()
	
	log_debug("Reset all progress data")

func _debug_save_progress() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		progress_manager.save_progress()
		log_debug("Progress saved manually")
	else:
		log_debug("ProgressManager not found")

## _debug_unlock_all_colored_dice()
##
## Unlocks all colored dice features for testing colored dice shop functionality
func _debug_unlock_all_colored_dice() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		log_debug("ProgressManager not found")
		return
	
	var colored_dice_items = ["green_dice", "red_dice", "purple_dice", "blue_dice"]
	var unlocked_count = 0
	
	for item_id in colored_dice_items:
		if progress_manager.has_method("debug_unlock_item"):
			progress_manager.debug_unlock_item(item_id)
			unlocked_count += 1
			log_debug("Unlocked colored dice: %s" % item_id)
		else:
			log_debug("ProgressManager missing debug_unlock_item method")
			break
	
	log_debug("Unlocked %d colored dice features" % unlocked_count)

## _debug_lock_all_colored_dice()
##
## Locks all colored dice features for testing progression
func _debug_lock_all_colored_dice() -> void:
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		log_debug("ProgressManager not found")
		return
	
	var colored_dice_items = ["green_dice", "red_dice", "purple_dice", "blue_dice"]
	var locked_count = 0
	
	for item_id in colored_dice_items:
		if progress_manager.has_method("debug_lock_item"):
			progress_manager.debug_lock_item(item_id)
			locked_count += 1
			log_debug("Locked colored dice: %s" % item_id)
		else:
			log_debug("ProgressManager missing debug_lock_item method")
			break
	
	log_debug("Locked %d colored dice features" % locked_count)

# ============================================================================
# Score Card Upgrade Debug Functions
# ============================================================================

## _debug_grant_master_upgrade()
##
## Grants the Master Upgrade consumable that upgrades all categories.
func _debug_grant_master_upgrade() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("all_categories_upgrade")
		log_debug("Granted Master Upgrade (All Categories) consumable")
	else:
		log_debug("GameController missing grant_consumable method")

## _debug_grant_ones_upgrade()
##
## Grants the Ones Upgrade consumable for testing.
func _debug_grant_ones_upgrade() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("ones_upgrade")
		log_debug("Granted Ones Upgrade consumable")
	else:
		log_debug("GameController missing grant_consumable method")

## _debug_grant_yahtzee_upgrade()
##
## Grants the Yahtzee Upgrade consumable for testing.
func _debug_grant_yahtzee_upgrade() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	if game_controller.has_method("grant_consumable"):
		game_controller.grant_consumable("yahtzee_upgrade")
		log_debug("Granted Yahtzee Upgrade consumable")
	else:
		log_debug("GameController missing grant_consumable method")

## _debug_upgrade_all_categories()
##
## Directly upgrades all score card categories by one level (bypasses consumable).
func _debug_upgrade_all_categories() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		log_debug("ERROR: Scorecard not available")
		return
	
	if not scorecard.has_method("upgrade_category"):
		log_debug("ERROR: Scorecard missing upgrade_category method")
		return
	
	# Upgrade all upper section categories
	var upper_categories = ["ones", "twos", "threes", "fours", "fives", "sixes"]
	for cat in upper_categories:
		scorecard.upgrade_category(Scorecard.Section.UPPER, cat)
	
	# Upgrade all lower section categories
	var lower_categories = ["three_of_a_kind", "four_of_a_kind", "full_house", "small_straight", "large_straight", "yahtzee"]
	for cat in lower_categories:
		scorecard.upgrade_category(Scorecard.Section.LOWER, cat)
	
	log_debug("Upgraded all 12 score card categories by 1 level")

## _debug_show_category_levels()
##
## Displays current level of all score card categories.
func _debug_show_category_levels() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		log_debug("ERROR: Scorecard not available")
		return
	
	log_debug("=== Score Card Category Levels ===")
	
	# Show upper section levels
	log_debug("--- Upper Section ---")
	if scorecard.get("upper_levels"):
		for cat_name in scorecard.upper_levels:
			var level = scorecard.upper_levels[cat_name]
			log_debug("  %s: Level %d" % [cat_name, level])
	else:
		log_debug("  upper_levels not found")
	
	# Show lower section levels
	log_debug("--- Lower Section ---")
	if scorecard.get("lower_levels"):
		for cat_name in scorecard.lower_levels:
			var level = scorecard.lower_levels[cat_name]
			log_debug("  %s: Level %d" % [cat_name, level])
	else:
		log_debug("  lower_levels not found")

## _debug_unlock_all_upgrade_consumables()
##
## Unlocks all 13 score card upgrade consumables in ProgressManager.
func _debug_unlock_all_upgrade_consumables() -> void:
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if not progress_manager:
		log_debug("ProgressManager not found")
		return
	
	var upgrade_consumable_ids = [
		"ones_upgrade", "twos_upgrade", "threes_upgrade", 
		"fours_upgrade", "fives_upgrade", "sixes_upgrade",
		"three_of_a_kind_upgrade", "four_of_a_kind_upgrade", 
		"full_house_upgrade", "small_straight_upgrade", 
		"large_straight_upgrade", "yahtzee_upgrade", "chance_upgrade",
		"all_categories_upgrade"
	]
	
	var unlocked_count = 0
	for item_id in upgrade_consumable_ids:
		if progress_manager.has_method("debug_unlock_item"):
			progress_manager.debug_unlock_item(item_id)
			unlocked_count += 1
			log_debug("Unlocked: %s" % item_id)
		else:
			log_debug("ProgressManager missing debug_unlock_item method")
			break
	
	log_debug("Unlocked %d upgrade consumables" % unlocked_count)

## _debug_lock_all_upgrade_consumables()
##
## Locks all 13 score card upgrade consumables in ProgressManager.
func _debug_lock_all_upgrade_consumables() -> void:
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if not progress_manager:
		log_debug("ProgressManager not found")
		return
	
	var upgrade_consumable_ids = [
		"ones_upgrade", "twos_upgrade", "threes_upgrade", 
		"fours_upgrade", "fives_upgrade", "sixes_upgrade",
		"three_of_a_kind_upgrade", "four_of_a_kind_upgrade", 
		"full_house_upgrade", "small_straight_upgrade", 
		"large_straight_upgrade", "yahtzee_upgrade", "chance_upgrade",
		"all_categories_upgrade"
	]
	
	var locked_count = 0
	for item_id in upgrade_consumable_ids:
		if progress_manager.has_method("debug_lock_item"):
			progress_manager.debug_lock_item(item_id)
			locked_count += 1
			log_debug("Locked: %s" % item_id)
		else:
			log_debug("ProgressManager missing debug_lock_item method")
			break
	
	log_debug("Locked %d upgrade consumables" % locked_count)

# =============================================================================
# CHORES / MOM SYSTEM DEBUG FUNCTIONS
# =============================================================================

## _debug_chores_add_progress()
##
## Adds +10 to chore progress for testing progress bar and thresholds.
func _debug_chores_add_progress() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var chores_manager = game_controller.get("chores_manager")
	if not chores_manager:
		log_debug("ERROR: ChoresManager not found on GameController")
		return
	
	for i in range(10):
		chores_manager.increment_progress()
	log_debug("Added +10 to chore progress. Current: %d" % chores_manager.current_progress)

## _debug_chores_add_big_progress()
##
## Adds +50 to chore progress for quickly testing Mom trigger.
func _debug_chores_add_big_progress() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var chores_manager = game_controller.get("chores_manager")
	if not chores_manager:
		log_debug("ERROR: ChoresManager not found on GameController")
		return
	
	for i in range(50):
		chores_manager.increment_progress()
	log_debug("Added +50 to chore progress. Current: %d" % chores_manager.current_progress)

## _debug_chores_complete_task()
##
## Completes the current chore task (reduces progress by 20).
func _debug_chores_complete_task() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var chores_manager = game_controller.get("chores_manager")
	if not chores_manager:
		log_debug("ERROR: ChoresManager not found on GameController")
		return
	
	var prev_progress = chores_manager.current_progress
	chores_manager.complete_current_task()
	log_debug("Completed task! Progress: %d -> %d" % [prev_progress, chores_manager.current_progress])

## _debug_chores_trigger_mom()
##
## Immediately triggers the Mom check (bypasses progress threshold).
func _debug_chores_trigger_mom() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var chores_manager = game_controller.get("chores_manager")
	if not chores_manager:
		log_debug("ERROR: ChoresManager not found on GameController")
		return
	
	log_debug("Manually triggering Mom check...")
	chores_manager.mom_triggered.emit()

## _debug_chores_new_task()
##
## Forces selection of a new random task.
func _debug_chores_new_task() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var chores_manager = game_controller.get("chores_manager")
	if not chores_manager:
		log_debug("ERROR: ChoresManager not found on GameController")
		return
	
	chores_manager.select_new_task()
	if chores_manager.current_task:
		log_debug("New task: %s" % chores_manager.current_task.task_name)
	else:
		log_debug("No task selected")

## _debug_chores_reset()
##
## Resets chore progress to 0 and selects a new task.
func _debug_chores_reset() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var chores_manager = game_controller.get("chores_manager")
	if not chores_manager:
		log_debug("ERROR: ChoresManager not found on GameController")
		return
	
	chores_manager.reset_progress()
	log_debug("Chore progress reset to 0, new task selected")

## _debug_chores_show_state()
##
## Displays current state of the ChoresManager.
func _debug_chores_show_state() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var chores_manager = game_controller.get("chores_manager")
	if not chores_manager:
		log_debug("ERROR: ChoresManager not found on GameController")
		return
	
	log_debug("=== CHORES STATE ===")
	log_debug("Progress: %d / %d" % [chores_manager.current_progress, chores_manager.MAX_PROGRESS])
	log_debug("Tasks Completed: %d" % chores_manager.tasks_completed)
	
	if chores_manager.current_task:
		var task = chores_manager.current_task
		log_debug("Current Task: %s" % task.task_name)
		log_debug("  Description: %s" % task.description)
		log_debug("  Type: %d" % task.task_type)
		log_debug("  Difficulty: %d" % task.difficulty)
	else:
		log_debug("Current Task: None")

## _debug_chores_show_ratings()
##
## Shows rating for all active PowerUps.
func _debug_chores_show_ratings() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	log_debug("=== POWERUP RATINGS ===")
	
	if game_controller.active_power_ups.is_empty():
		log_debug("No active PowerUps")
		return
	
	var pu_manager = game_controller.pu_manager
	if not pu_manager:
		log_debug("ERROR: PowerUpManager not found")
		return
	
	for pu_id in game_controller.active_power_ups:
		var data = pu_manager.get_power_up_data(pu_id)
		if data:
			var rating_display = data.get_rating_display_char() if data.has_method("get_rating_display_char") else data.rating
			var restricted = data.is_rating_restricted() if data.has_method("is_rating_restricted") else false
			var nc17 = data.is_rating_nc17() if data.has_method("is_rating_nc17") else false
			log_debug("  %s: %s%s%s" % [
				pu_id,
				rating_display,
				" [RESTRICTED]" if restricted else "",
				" [NC-17]" if nc17 else ""
			])
		else:
			log_debug("  %s: (data not found)" % pu_id)

## _debug_chores_mom_neutral()
##
## Tests the Mom dialog with neutral expression.
func _debug_chores_mom_neutral() -> void:
	_test_mom_dialog("neutral", "Hi sweetie! Just checking in on you. Don't forget to do your chores!")

## _debug_chores_mom_upset()
##
## Tests the Mom dialog with upset expression.
func _debug_chores_mom_upset() -> void:
	_test_mom_dialog("upset", "[color=red]What is THIS?![/color] I told you not to play with those kinds of things! I'm taking this away!")

## _debug_chores_mom_happy()
##
## Tests the Mom dialog with happy expression.
func _debug_chores_mom_happy() -> void:
	_test_mom_dialog("happy", "[color=lime]Good job keeping your room clean![/color] I'm so proud of you, sweetie!")

## _test_mom_dialog()
##
## Helper to test mom dialog popup with specific expression.
func _test_mom_dialog(expression: String, message: String) -> void:
	# Try to find existing MomDialogPopup in the scene
	var mom_popup = get_tree().get_first_node_in_group("mom_dialog")
	
	if mom_popup and mom_popup.has_method("show_dialog"):
		mom_popup.show_dialog(expression, message)
		log_debug("Showed Mom dialog with '%s' expression" % expression)
	else:
		# Try to create one temporarily
		var mom_scene = load("res://Scenes/UI/mom_dialog_popup.tscn")
		if mom_scene:
			var popup = mom_scene.instantiate()
			get_tree().current_scene.add_child(popup)
			popup.show_dialog(expression, message)
			log_debug("Created temporary Mom dialog with '%s' expression" % expression)
		else:
			log_debug("ERROR: Could not find or create MomDialogPopup")


# ==================== SYNERGY DEBUG METHODS ====================

## _debug_synergy_show_status()
##
## Shows complete synergy status including counts and active bonuses.
func _debug_synergy_show_status() -> void:
	var synergy_manager = _get_synergy_manager()
	if not synergy_manager:
		log_debug("ERROR: SynergyManager not available")
		return
	
	synergy_manager.debug_print_status()
	log_debug("Synergy status printed to console")


## _debug_synergy_grant_5_g()
##
## Grants 5 G-rated PowerUps to test set bonus.
func _debug_synergy_grant_5_g() -> void:
	_grant_powerups_by_rating("G", 5)


## _debug_synergy_grant_5_pg()
##
## Grants 5 PG-rated PowerUps to test set bonus.
func _debug_synergy_grant_5_pg() -> void:
	_grant_powerups_by_rating("PG", 5)


## _debug_synergy_grant_5_pg13()
##
## Grants 5 PG-13-rated PowerUps to test set bonus.
func _debug_synergy_grant_5_pg13() -> void:
	_grant_powerups_by_rating("PG-13", 5)


## _debug_synergy_grant_5_r()
##
## Grants 5 R-rated PowerUps to test set bonus.
func _debug_synergy_grant_5_r() -> void:
	_grant_powerups_by_rating("R", 5)


## _debug_synergy_grant_5_nc17()
##
## Grants 5 NC-17-rated PowerUps to test set bonus.
func _debug_synergy_grant_5_nc17() -> void:
	_grant_powerups_by_rating("NC-17", 5)


## _debug_synergy_grant_rainbow()
##
## Grants one PowerUp of each rating to test rainbow bonus.
func _debug_synergy_grant_rainbow() -> void:
	log_debug("Attempting to grant rainbow set (one of each rating)...")
	
	var ratings := ["G", "PG", "PG-13", "R", "NC-17"]
	var granted_count := 0
	
	for rating in ratings:
		if _grant_powerups_by_rating(rating, 1):
			granted_count += 1
	
	log_debug("Rainbow grant complete: %d/%d ratings granted" % [granted_count, ratings.size()])
	_debug_synergy_show_counts()


## _debug_synergy_clear_all()
##
## Revokes all active PowerUps.
func _debug_synergy_clear_all() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	var power_up_ids = game_controller.active_power_ups.keys().duplicate()
	var cleared_count := 0
	
	for pu_id in power_up_ids:
		if game_controller.has_method("revoke_power_up"):
			game_controller.revoke_power_up(pu_id)
			cleared_count += 1
	
	log_debug("Cleared %d PowerUps" % cleared_count)


## _debug_synergy_show_counts()
##
## Shows current rating counts.
func _debug_synergy_show_counts() -> void:
	var synergy_manager = _get_synergy_manager()
	if not synergy_manager:
		log_debug("ERROR: SynergyManager not available")
		return
	
	var counts = synergy_manager.get_rating_counts()
	log_debug("=== RATING COUNTS ===")
	for rating in ["G", "PG", "PG-13", "R", "NC-17"]:
		var count = counts.get(rating, 0)
		var sets = count / 5
		var bonus = sets * 50
		log_debug("  %s: %d (sets: %d, bonus: +%d)" % [rating, count, sets, bonus])
	
	log_debug("Total Matching Bonus: +%d" % synergy_manager.get_total_matching_bonus())
	log_debug("Rainbow Active: %s" % synergy_manager.has_rainbow_bonus())


## _debug_synergy_show_bonuses()
##
## Shows currently active synergy bonuses.
func _debug_synergy_show_bonuses() -> void:
	var synergy_manager = _get_synergy_manager()
	if not synergy_manager:
		log_debug("ERROR: SynergyManager not available")
		return
	
	var active = synergy_manager.get_active_synergies()
	log_debug("=== ACTIVE SYNERGY BONUSES ===")
	
	if active.is_empty():
		log_debug("  No active synergies")
		return
	
	for synergy_id in active:
		var value = active[synergy_id]
		if synergy_id == "synergy_rainbow":
			log_debug("  Rainbow: %.1fx multiplier" % value)
		else:
			log_debug("  %s: +%d additive" % [synergy_id, value])


## _get_synergy_manager()
##
## Helper to find SynergyManager in the scene.
func _get_synergy_manager():
	if game_controller and game_controller.synergy_manager:
		return game_controller.synergy_manager
	
	var sm = get_tree().get_first_node_in_group("synergy_manager")
	if sm:
		return sm
	
	return null


## _grant_powerups_by_rating(rating, count)
##
## Grants up to `count` PowerUps with the specified rating.
## Returns true if at least one was granted.
func _grant_powerups_by_rating(rating: String, count: int) -> bool:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return false
	
	var pu_manager = game_controller.pu_manager
	if not pu_manager:
		log_debug("ERROR: PowerUpManager not available")
		return false
	
	# Find all PowerUps with matching rating that aren't already owned
	var available: Array[String] = []
	for pu_id in pu_manager.get_available_power_ups():
		if game_controller.active_power_ups.has(pu_id):
			continue  # Already owned
		
		var data = pu_manager.get_def(pu_id)
		if data and data.rating == rating:
			available.append(pu_id)
	
	if available.is_empty():
		log_debug("No available %s-rated PowerUps to grant" % rating)
		return false
	
	var granted := 0
	for i in range(min(count, available.size())):
		var pu_id = available[i]
		game_controller.grant_power_up(pu_id)
		log_debug("Granted %s-rated PowerUp: %s" % [rating, pu_id])
		granted += 1
	
	log_debug("Granted %d/%d %s-rated PowerUps" % [granted, count, rating])
	return granted > 0


#region Tutorial Debug Methods

## _get_tutorial_manager()
##
## Helper to get TutorialManager autoload.
func _get_tutorial_manager():
	return get_node_or_null("/root/TutorialManager")

## _get_progress_manager()
##
## Helper to get ProgressManager autoload for tutorial methods.
func _get_progress_manager_tutorial():
	return get_node_or_null("/root/ProgressManager")

## _debug_tutorial_start()
##
## Starts the tutorial from the beginning.
func _debug_tutorial_start() -> void:
	var tutorial_mgr = _get_tutorial_manager()
	if not tutorial_mgr:
		log_debug("ERROR: TutorialManager autoload not available")
		return
	
	if tutorial_mgr.is_tutorial_active():
		log_debug("Tutorial already active - skipping first to restart")
		tutorial_mgr.skip_tutorial()
		await get_tree().create_timer(0.1).timeout
	
	tutorial_mgr.start_tutorial()
	log_debug("Tutorial started from step: %s" % tutorial_mgr.current_step_id)

## _debug_tutorial_skip()
##
## Skips the current tutorial.
func _debug_tutorial_skip() -> void:
	var tutorial_mgr = _get_tutorial_manager()
	if not tutorial_mgr:
		log_debug("ERROR: TutorialManager autoload not available")
		return
	
	if not tutorial_mgr.is_tutorial_active():
		log_debug("No tutorial currently active")
		return
	
	tutorial_mgr.skip_tutorial()
	log_debug("Tutorial skipped")

## _debug_tutorial_next_step()
##
## Advances to the next tutorial step.
func _debug_tutorial_next_step() -> void:
	var tutorial_mgr = _get_tutorial_manager()
	if not tutorial_mgr:
		log_debug("ERROR: TutorialManager autoload not available")
		return
	
	if not tutorial_mgr.is_tutorial_active():
		log_debug("No tutorial currently active")
		return
	
	var current = tutorial_mgr.current_step_id
	tutorial_mgr.complete_step()
	log_debug("Advanced from %s to %s" % [current, tutorial_mgr.current_step_id])

## _debug_tutorial_prev_step()
##
## Goes back to the previous tutorial step.
func _debug_tutorial_prev_step() -> void:
	var tutorial_mgr = _get_tutorial_manager()
	if not tutorial_mgr:
		log_debug("ERROR: TutorialManager autoload not available")
		return
	
	if not tutorial_mgr.is_tutorial_active():
		log_debug("No tutorial currently active")
		return
	
	# Get list of step IDs and find current index
	var step_ids = tutorial_mgr.get_all_step_ids()
	var current_idx = step_ids.find(tutorial_mgr.current_step_id)
	
	if current_idx <= 0:
		log_debug("Already at first step")
		return
	
	var prev_step = step_ids[current_idx - 1]
	tutorial_mgr.progress_to_step(prev_step)
	log_debug("Moved back to step: %s" % prev_step)

## _debug_tutorial_next_part()
##
## Advances to the next part of a multi-part step.
func _debug_tutorial_next_part() -> void:
	var tutorial_mgr = _get_tutorial_manager()
	if not tutorial_mgr:
		log_debug("ERROR: TutorialManager autoload not available")
		return
	
	if not tutorial_mgr.is_tutorial_active():
		log_debug("No tutorial currently active")
		return
	
	var step = tutorial_mgr.get_current_step()
	if step and step.total_parts > 1:
		tutorial_mgr.advance_part()
		log_debug("Advanced to part %d/%d" % [tutorial_mgr.current_part, step.total_parts])
	else:
		log_debug("Current step is not multi-part")

## _debug_tutorial_reset()
##
## Resets tutorial progress (marks as not completed).
func _debug_tutorial_reset() -> void:
	var tutorial_mgr = _get_tutorial_manager()
	var progress_mgr = _get_progress_manager_tutorial()
	
	if tutorial_mgr and tutorial_mgr.is_tutorial_active():
		tutorial_mgr.skip_tutorial()
	
	if progress_mgr:
		progress_mgr.tutorial_completed = false
		progress_mgr.tutorial_in_progress = false
		progress_mgr.save_current_profile()
	log_debug("Tutorial progress reset - will auto-start on next game")

## _debug_tutorial_show_state()
##
## Displays current tutorial state.
func _debug_tutorial_show_state() -> void:
	var tutorial_mgr = _get_tutorial_manager()
	var progress_mgr = _get_progress_manager_tutorial()
	
	log_debug("=== TUTORIAL STATE ===")
	if progress_mgr:
		log_debug("  Completed: %s" % progress_mgr.tutorial_completed)
		log_debug("  In Progress: %s" % progress_mgr.tutorial_in_progress)
	
	if not tutorial_mgr:
		log_debug("  TutorialManager: NOT AVAILABLE")
		return
	
	log_debug("  Active: %s" % tutorial_mgr.is_tutorial_active())
	
	if tutorial_mgr.is_tutorial_active():
		log_debug("  Current Step: %s" % tutorial_mgr.current_step_id)
		log_debug("  Current Part: %d" % tutorial_mgr.current_part)
		var step = tutorial_mgr.get_current_step()
		if step:
			log_debug("  Step Title: %s" % step.title)
			log_debug("  Total Parts: %d" % step.total_parts)
			log_debug("  Required Action: %s" % step.required_action)
	
	log_debug("  Total Steps Loaded: %d" % tutorial_mgr.get_all_step_ids().size())

## _debug_tutorial_list_steps()
##
## Lists all available tutorial steps.
func _debug_tutorial_list_steps() -> void:
	var tutorial_mgr = _get_tutorial_manager()
	if not tutorial_mgr:
		log_debug("ERROR: TutorialManager autoload not available")
		return
	
	var step_ids = tutorial_mgr.get_all_step_ids()
	log_debug("=== TUTORIAL STEPS (%d total) ===" % step_ids.size())
	
	for step_id in step_ids:
		var step = tutorial_mgr.get_step(step_id)
		if step:
			var current_marker = ""
			if tutorial_mgr.is_tutorial_active() and tutorial_mgr.current_step_id == step_id:
				current_marker = " <-- CURRENT"
			log_debug("  %s: %s (parts: %d)%s" % [step_id, step.title, step.total_parts, current_marker])

## _debug_tutorial_jump_prompt()
##
## Shows instructions for jumping to a specific step.
func _debug_tutorial_jump_prompt() -> void:
	var tutorial_mgr = _get_tutorial_manager()
	if not tutorial_mgr:
		log_debug("ERROR: TutorialManager autoload not available")
		return
	
	var step_ids = tutorial_mgr.get_all_step_ids()
	log_debug("=== JUMP TO STEP ===")
	log_debug("Available step IDs:")
	for step_id in step_ids:
		log_debug("  - %s" % step_id)
	log_debug("")
	log_debug("To jump, use console:")
	log_debug("  TutorialManager.progress_to_step(\"step_id\")")

## _debug_tutorial_force_complete()
##
## Marks the tutorial as completed without running through it.
func _debug_tutorial_force_complete() -> void:
	var tutorial_mgr = _get_tutorial_manager()
	var progress_mgr = _get_progress_manager_tutorial()
	
	if tutorial_mgr and tutorial_mgr.is_tutorial_active():
		tutorial_mgr.skip_tutorial()
	
	if progress_mgr:
		progress_mgr.tutorial_completed = true
		progress_mgr.tutorial_in_progress = false
		progress_mgr.save_current_profile()
	log_debug("Tutorial marked as completed")
#endregion

#region Difficulty Debug Methods
## _debug_difficulty_show_channel()
##
## Displays current channel information including difficulty settings.
func _debug_difficulty_show_channel() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not found")
		return
	
	if not game_controller.channel_manager:
		log_debug("ERROR: ChannelManager not found")
		return
	
	var channel_mgr = game_controller.channel_manager
	var channel_number = channel_mgr.current_channel
	var channel = channel_mgr.get_channel_config(channel_number)
	
	if not channel:
		log_debug("ERROR: No channel config found for channel %d" % channel_number)
		return
	
	log_debug("=== CHANNEL INFORMATION ===")
	log_debug("Name: %s" % channel.display_name)
	log_debug("Description: %s" % channel.description)
	log_debug("Channel Number: %d" % channel.channel_number)
	
	# Show round difficulty configurations
	log_debug("")
	log_debug("--- Round Difficulty Configs ---")
	if channel.round_configs and channel.round_configs.size() > 0:
		for i in range(channel.round_configs.size()):
			var config = channel.round_configs[i]
			if config:
				var debuff_info = "max_debuffs=%d, cap=%d" % [config.max_debuffs, config.debuff_difficulty_cap]
				var tier_info = "challenge_range=%s" % str(config.challenge_difficulty_range)
				log_debug("  Round %d: %s, %s" % [i + 1, tier_info, debuff_info])
			else:
				log_debug("  Round %d: No config defined" % [i + 1])
	else:
		log_debug("  No round configs defined")
	
	log_debug("")
	log_debug("Scaling Factors:")
	log_debug("  Goal Score Multiplier: %.2f" % channel.goal_score_multiplier)
	log_debug("  Yahtzee Bonus Multiplier: %.2f" % channel.yahtzee_bonus_multiplier)
	log_debug("  Shop Price Multiplier: %.2f" % channel.shop_price_multiplier)
	log_debug("  Debuff Intensity Multiplier: %.2f" % channel.debuff_intensity_multiplier)

## _debug_difficulty_show_round()
##
## Shows the current round's difficulty configuration in detail.
func _debug_difficulty_show_round() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not found")
		return
	
	if not game_controller.channel_manager:
		log_debug("ERROR: ChannelManager not found")
		return
	
	var channel_mgr = game_controller.channel_manager
	var channel_number = channel_mgr.current_channel
	var channel = channel_mgr.get_channel_config(channel_number)
	
	var current_round = 1
	if game_controller.round_manager:
		current_round = game_controller.round_manager.current_round + 1  # Convert to 1-based
	
	log_debug("=== ROUND %d CONFIGURATION ===" % current_round)
	log_debug("Channel: %s (#%d)" % [channel.display_name if channel else "Unknown", channel_number])
	
	if not channel:
		log_debug("ERROR: No channel config found")
		return
	
	var config = null
	if channel.round_configs:
		var idx = current_round - 1
		if idx >= 0 and idx < channel.round_configs.size():
			config = channel.round_configs[idx]
	
	if config:
		log_debug("Challenge Settings:")
		log_debug("  Difficulty Range: %s" % str(config.challenge_difficulty_range))
		log_debug("")
		log_debug("Debuff Settings:")
		log_debug("  Max Debuffs: %d" % config.max_debuffs)
		log_debug("  Difficulty Cap: %d (Level %d max)" % [config.debuff_difficulty_cap, config.debuff_difficulty_cap])
	else:
		log_debug("No difficulty config for this round")
	
	# Show active challenge if any
	if game_controller.challenge_manager:
		var cm = game_controller.challenge_manager
		if cm.has_method("get_current_challenge"):
			var challenge = cm.get_current_challenge()
			if challenge:
				log_debug("")
				log_debug("Active Challenge:")
				log_debug("  Name: %s" % challenge.challenge_name)
				log_debug("  Target: %d" % challenge.target_score)
				log_debug("  Tier: %d" % challenge.tier)

## _debug_difficulty_show_debuffs()
##
## Shows currently active debuffs with their details.
func _debug_difficulty_show_debuffs() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not found")
		return
	
	var debuff_mgr = game_controller.debuff_manager
	if not debuff_mgr:
		log_debug("ERROR: DebuffManager not found")
		return
	
	log_debug("=== ACTIVE DEBUFFS ===")
	
	var active_ids = []
	if debuff_mgr.has_method("get_active_debuff_ids"):
		active_ids = debuff_mgr.get_active_debuff_ids()
	elif "_active_debuff_ids" in debuff_mgr:
		active_ids = debuff_mgr._active_debuff_ids
	
	if active_ids.size() == 0:
		log_debug("No active debuffs this round")
		return
	
	log_debug("Count: %d" % active_ids.size())
	log_debug("")
	
	for debuff_id in active_ids:
		log_debug("  - %s" % debuff_id)

## _debug_difficulty_show_all_debuffs()
##
## Shows all available debuffs with their difficulty ratings.
func _debug_difficulty_show_all_debuffs() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not found")
		return
	
	var debuff_mgr = game_controller.debuff_manager
	if not debuff_mgr:
		log_debug("ERROR: DebuffManager not found")
		return
	
	log_debug("=== ALL DEBUFFS BY DIFFICULTY ===")
	
	if debuff_mgr.has_method("get_all_debuff_info"):
		var info = debuff_mgr.get_all_debuff_info()
		log_debug(info)
	else:
		# Manual fallback
		for level in range(1, 6):
			log_debug("")
			log_debug("--- Level %d Debuffs ---" % level)
			if debuff_mgr.has_method("get_debuffs_by_difficulty"):
				var debuffs = debuff_mgr.get_debuffs_by_difficulty(level)
				if debuffs.size() == 0:
					log_debug("  (none)")
				else:
					for debuff in debuffs:
						log_debug("  - %s" % debuff.debuff_name)
			else:
				log_debug("  (get_debuffs_by_difficulty not available)")

## _debug_difficulty_toggle_verbose()
##
## Toggles verbose mode for debuff selection logging.
func _debug_difficulty_toggle_verbose() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not found")
		return
	
	var debuff_mgr = game_controller.debuff_manager
	if not debuff_mgr:
		log_debug("ERROR: DebuffManager not found")
		return
	
	if "_verbose_mode" in debuff_mgr:
		debuff_mgr._verbose_mode = not debuff_mgr._verbose_mode
		log_debug("Verbose mode: %s" % ("ENABLED" if debuff_mgr._verbose_mode else "DISABLED"))
		if debuff_mgr._verbose_mode:
			log_debug("Debuff selection will now print detailed logs to console")
	else:
		log_debug("ERROR: _verbose_mode not found in DebuffManager")

## _debug_difficulty_force_apply()
##
## Forces immediate debuff application for the current round.
func _debug_difficulty_force_apply() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not found")
		return
	
	var debuff_mgr = game_controller.debuff_manager
	if not debuff_mgr:
		log_debug("ERROR: DebuffManager not found")
		return
	
	if not game_controller.channel_manager:
		log_debug("ERROR: ChannelManager not found")
		return
	
	var channel_mgr = game_controller.channel_manager
	var channel_number = channel_mgr.current_channel
	var channel = channel_mgr.get_channel_config(channel_number)
	
	var current_round = 1
	if game_controller.round_manager:
		current_round = game_controller.round_manager.current_round + 1  # 1-based
	
	if not channel:
		log_debug("ERROR: No channel config found for channel %d" % channel_number)
		return
	
	# Get round config from channel
	var round_config = channel.get_round_config(current_round)
	if not round_config:
		log_debug("ERROR: No round config for round %d" % current_round)
		return
	
	# Enable verbose for this operation
	var was_verbose = debuff_mgr._verbose_mode if "_verbose_mode" in debuff_mgr else false
	if "_verbose_mode" in debuff_mgr:
		debuff_mgr._verbose_mode = true
	
	log_debug("=== FORCING DEBUFF APPLICATION ===")
	log_debug("Channel: %s (#%d), Round: %d" % [channel.display_name, channel_number, current_round])
	log_debug("Round Config: max_debuffs=%d, difficulty_cap=%d" % [round_config.max_debuffs, round_config.debuff_difficulty_cap])
	
	# Get debuff_container from game_controller
	var debuff_container = game_controller.debuff_container
	if not debuff_container:
		log_debug("ERROR: debuff_container not found")
		return
	
	if debuff_mgr.has_method("apply_round_debuffs"):
		var spawned = debuff_mgr.apply_round_debuffs(debuff_container, round_config, channel_number)
		log_debug("Debuffs applied: %d spawned" % spawned.size())
	else:
		log_debug("ERROR: apply_round_debuffs method not found")
	
	# Restore verbose state
	if "_verbose_mode" in debuff_mgr:
		debuff_mgr._verbose_mode = was_verbose

## _debug_difficulty_clear_debuffs()
##
## Clears all active debuffs.
func _debug_difficulty_clear_debuffs() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not found")
		return
	
	var debuff_mgr = game_controller.debuff_manager
	if not debuff_mgr:
		log_debug("ERROR: DebuffManager not found")
		return
	
	if debuff_mgr.has_method("clear_active_debuffs"):
		debuff_mgr.clear_active_debuffs()
		log_debug("Active debuffs cleared")
	else:
		if "_active_debuff_ids" in debuff_mgr:
			debuff_mgr._active_debuff_ids.clear()
			log_debug("Active debuffs cleared (direct)")
		else:
			log_debug("ERROR: Cannot clear debuffs - no method or property found")

## _debug_difficulty_show_multipliers()
##
## Shows all active multipliers affecting scoring.
func _debug_difficulty_show_multipliers() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not found")
		return
	
	log_debug("=== MULTIPLIER BREAKDOWN ===")
	
	# Channel multipliers
	var channel = null
	var channel_number = 1
	if game_controller.channel_manager:
		channel_number = game_controller.channel_manager.current_channel
		channel = game_controller.channel_manager.get_channel_config(channel_number)
	
	if channel:
		log_debug("")
		log_debug("Channel Multipliers (%s #%d):" % [channel.display_name, channel_number])
		log_debug("  Goal Score: %.2fx" % channel.goal_score_multiplier)
		log_debug("  Yahtzee Bonus: %.2fx" % channel.yahtzee_bonus_multiplier)
		log_debug("  Shop Price: %.2fx" % channel.shop_price_multiplier)
		log_debug("  Debuff Intensity: %.2fx" % channel.debuff_intensity_multiplier)
	else:
		log_debug("")
		log_debug("Channel: No config loaded (channel %d)" % channel_number)
	
	# Debuff effects
	var debuff_mgr = game_controller.debuff_manager
	if debuff_mgr:
		var active_ids = []
		if debuff_mgr.has_method("get_active_debuff_ids"):
			active_ids = debuff_mgr.get_active_debuff_ids()
		elif "_active_debuff_ids" in debuff_mgr:
			active_ids = debuff_mgr._active_debuff_ids
		
		if active_ids.size() > 0:
			log_debug("")
			log_debug("Debuff Modifiers:")
			for debuff_id in active_ids:
				log_debug("  - %s (active)" % debuff_id)
	
	# PowerUp bonuses
	if game_controller.pu_manager:
		var owned = game_controller.active_power_ups
		if owned.size() > 0:
			log_debug("")
			log_debug("Active PowerUps: %d" % owned.size())
			for pu_id in owned:
				log_debug("  - %s" % pu_id)
	
	# ScoreModifierManager (autoload)
	if ScoreModifierManager:
		log_debug("")
		log_debug("ScoreModifierManager State:")
		log_debug("  Total Multiplier: %.2fx" % ScoreModifierManager.get_total_multiplier())
		log_debug("  Total Additive: +%d" % ScoreModifierManager.get_total_additive())
#endregion
