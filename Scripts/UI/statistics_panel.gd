extends Control
class_name StatisticsPanel

## StatisticsPanel
## 
## UI panel that displays all game statistics in a tabbed interface.
## Toggled with F10 key input.

@onready var tab_container: TabContainer = $Panel/VBox/TabContainer
@onready var core_tab: VBoxContainer = $Panel/VBox/TabContainer/Core/VBox
@onready var economic_tab: VBoxContainer = $Panel/VBox/TabContainer/Economic/VBox
@onready var dice_tab: VBoxContainer = $Panel/VBox/TabContainer/Dice/VBox
@onready var hands_tab: VBoxContainer = $Panel/VBox/TabContainer/Hands/VBox
@onready var items_tab: VBoxContainer = $Panel/VBox/TabContainer/Items/VBox
@onready var session_tab: VBoxContainer = $Panel/VBox/TabContainer/Session/VBox

var refresh_timer: Timer
var stats_node: Node

## _ready()
## 
## Initialize the statistics panel and set up refresh timer.
func _ready():
	visible = false
	_setup_refresh_timer()
	stats_node = get_node_or_null("/root/Statistics")
	
	if not stats_node:
		print("[StatisticsPanel] WARNING: Statistics autoload not found!")
	
	# Ensure proper tab setup
	call_deferred("_initialize_panel")

## _initialize_panel()
## 
## Deferred initialization to ensure all nodes are ready.
func _initialize_panel():
	_populate_statistics_tabs()
	
	# Verify content was created
	if core_tab and core_tab.get_child_count() > 0:
		print("[StatisticsPanel] Content successfully created - ", core_tab.get_child_count(), " elements in core tab")
	else:
		print("[StatisticsPanel] ERROR: No content created in core tab!")

## _setup_refresh_timer()
## 
## Create and configure the refresh timer for real-time updates.
func _setup_refresh_timer():
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 1.0  # Update every second
	refresh_timer.timeout.connect(_refresh_statistics)
	add_child(refresh_timer)

## toggle_visibility()
## 
## Show/hide the statistics panel and manage refresh timer.
func toggle_visibility():
	visible = !visible
	
	if visible:
		# Apply proper positioning (learned from F11 test)
		var panel_child = get_node_or_null("Panel")
		if panel_child:
			# Ensure panel is properly positioned and sized
			panel_child.modulate = Color(1, 1, 1, 0.95)  # Semi-transparent white
			panel_child.position = Vector2(100, 100)  # Fixed position that works
			panel_child.size = Vector2(1100, 500)  # Proper size
			panel_child.visible = true
		
		stats_node = get_node_or_null("/root/Statistics")  # Refresh reference
		_refresh_statistics()
		refresh_timer.start()
	else:
		refresh_timer.stop()

## _populate_statistics_tabs()
## 
## Create the initial UI structure for all statistics tabs.
func _populate_statistics_tabs():
	# Validate tab references exist
	if not tab_container:
		print("[StatisticsPanel] ERROR: TabContainer not found!")
		return
	
	if not core_tab or not economic_tab or not dice_tab or not hands_tab or not items_tab or not session_tab:
		print("[StatisticsPanel] ERROR: Missing tab containers!")
		return
	
	_create_core_tab()
	_create_economic_tab()
	_create_dice_tab()
	_create_hands_tab()
	_create_items_tab()
	_create_session_tab()

## _is_statistics_available() -> bool
## 
## Check if the Statistics autoload is available.
func _is_statistics_available() -> bool:
	return stats_node != null

## _create_core_tab()
## 
## Create the Core Metrics tab content.
func _create_core_tab():
	_clear_tab(core_tab)
	
	var title = Label.new()
	title.text = "Core Game Metrics"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core_tab.add_child(title)
	
	_add_separator(core_tab)
	
	if not _is_statistics_available():
		_add_stat_label(core_tab, "Statistics System", "Not Available")
		_add_stat_label(core_tab, "Status", "Waiting for autoload...")
		_add_stat_label(core_tab, "Debug Info", "Press F10 to refresh")
		return
	
	_add_stat_label(core_tab, "Total Turns", str(stats_node.total_turns))
	_add_stat_label(core_tab, "Total Rolls", str(stats_node.total_rolls))
	_add_stat_label(core_tab, "Total Rerolls", str(stats_node.total_rerolls))
	_add_stat_label(core_tab, "Hands Completed", str(stats_node.hands_completed))
	_add_stat_label(core_tab, "Failed Hands", str(stats_node.failed_hands))
	_add_stat_label(core_tab, "Scoring Percentage", "%.1f%%" % stats_node.get_scoring_percentage())

## _create_economic_tab()
## 
## Create the Economic Metrics tab content.
func _create_economic_tab():
	_clear_tab(economic_tab)
	
	var title = Label.new()
	title.text = "Economic Metrics"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	economic_tab.add_child(title)
	
	_add_separator(economic_tab)
	
	if not _is_statistics_available():
		_add_stat_label(economic_tab, "Statistics", "Not Available")
		_add_stat_label(economic_tab, "Current Money", "Unknown")
		_add_stat_label(economic_tab, "Status", "Autoload not ready")
		return
	
	_add_stat_label(economic_tab, "Current Money", str(stats_node.current_money))
	_add_stat_label(economic_tab, "Total Money Earned", str(stats_node.total_money_earned))
	_add_stat_label(economic_tab, "Total Money Spent", str(stats_node.total_money_spent))
	_add_stat_label(economic_tab, "Spent on Power-ups", str(stats_node.money_spent_on_powerups))
	_add_stat_label(economic_tab, "Spent on Consumables", str(stats_node.money_spent_on_consumables))
	_add_stat_label(economic_tab, "Spent on Mods", str(stats_node.money_spent_on_mods))
	_add_stat_label(economic_tab, "Money per Turn", "%.2f" % stats_node.get_money_efficiency())

## _create_dice_tab()
## 
## Create the Dice Metrics tab content.
func _create_dice_tab():
	_clear_tab(dice_tab)
	
	var title = Label.new()
	title.text = "Dice Metrics"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.ORANGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_tab.add_child(title)
	
	_add_separator(dice_tab)
	
	if not _is_statistics_available():
		_add_stat_label(dice_tab, "Statistics", "Not Available")
		_add_stat_label(dice_tab, "Dice Locked", "0")
		_add_stat_label(dice_tab, "Highest Roll", "Unknown")
		_add_stat_label(dice_tab, "Snake Eyes", "0")
		_add_stat_label(dice_tab, "Yahtzee Count", "0")
		return
	
	_add_stat_label(dice_tab, "Dice Locked", str(stats_node.dice_locked_count))
	_add_stat_label(dice_tab, "Highest Single Roll", str(stats_node.highest_single_roll))
	_add_stat_label(dice_tab, "Snake Eyes Count", str(stats_node.snake_eyes_count))
	_add_stat_label(dice_tab, "Yahtzee Count", str(stats_node.yahtzee_count))
	_add_stat_label(dice_tab, "Favorite Dice Color", stats_node.get_favorite_dice_color().capitalize())
	
	_add_separator(dice_tab)
	
	var color_title = Label.new()
	color_title.text = "Rolls by Color:"
	color_title.add_theme_font_size_override("font_size", 14)
	dice_tab.add_child(color_title)
	
	if stats_node.dice_rolled_by_color.is_empty():
		_add_stat_label(dice_tab, "  No colored dice", "rolled yet")
	else:
		for color in stats_node.dice_rolled_by_color.keys():
			_add_stat_label(dice_tab, "  " + color.capitalize(), str(stats_node.dice_rolled_by_color[color]))

## _create_hands_tab()
## 
## Create the Hand Statistics tab content.
func _create_hands_tab():
	_clear_tab(hands_tab)
	
	var title = Label.new()
	title.text = "Hand Statistics"
	title.add_theme_font_size_override("font_size", 18)
	hands_tab.add_child(title)
	
	_add_separator(hands_tab)
	
	if not _is_statistics_available():
		_add_stat_label(hands_tab, "Statistics", "Not Available")
		_add_stat_label(hands_tab, "Yahtzee Hands", "Unknown")
		_add_stat_label(hands_tab, "Status", "Autoload not ready")
		return
	
	# Number categories
	var numbers_title = Label.new()
	numbers_title.text = "Number Categories:"
	numbers_title.add_theme_font_size_override("font_size", 14)
	hands_tab.add_child(numbers_title)
	
	_add_stat_label(hands_tab, "  Ones", str(stats_node.ones_scored))
	_add_stat_label(hands_tab, "  Twos", str(stats_node.twos_scored))
	_add_stat_label(hands_tab, "  Threes", str(stats_node.threes_scored))
	_add_stat_label(hands_tab, "  Fours", str(stats_node.fours_scored))
	_add_stat_label(hands_tab, "  Fives", str(stats_node.fives_scored))
	_add_stat_label(hands_tab, "  Sixes", str(stats_node.sixes_scored))
	
	_add_separator(hands_tab)
	
	# Special categories
	var special_title = Label.new()
	special_title.text = "Special Categories:"
	special_title.add_theme_font_size_override("font_size", 14)
	hands_tab.add_child(special_title)
	
	_add_stat_label(hands_tab, "  Three of a Kind", str(stats_node.three_of_kind_scored))
	_add_stat_label(hands_tab, "  Four of a Kind", str(stats_node.four_of_kind_scored))
	_add_stat_label(hands_tab, "  Full House", str(stats_node.full_house_scored))
	_add_stat_label(hands_tab, "  Small Straight", str(stats_node.small_straight_scored))
	_add_stat_label(hands_tab, "  Large Straight", str(stats_node.large_straight_scored))
	_add_stat_label(hands_tab, "  Yahtzee", str(stats_node.yahtzee_scored))
	_add_stat_label(hands_tab, "  Chance", str(stats_node.chance_scored))

## _create_items_tab()
## 
## Create the Items & Power-ups tab content.
func _create_items_tab():
	_clear_tab(items_tab)
	
	var title = Label.new()
	title.text = "Items & Power-ups"
	title.add_theme_font_size_override("font_size", 18)
	items_tab.add_child(title)
	
	_add_separator(items_tab)
	
	if not _is_statistics_available():
		_add_stat_label(items_tab, "Statistics", "Not Available")
		_add_stat_label(items_tab, "Power-ups Bought", "0")
		_add_stat_label(items_tab, "Items Status", "Tracking offline")
		return
	
	# Purchases
	var purchase_title = Label.new()
	purchase_title.text = "Purchases:"
	purchase_title.add_theme_font_size_override("font_size", 14)
	items_tab.add_child(purchase_title)
	
	_add_stat_label(items_tab, "  Power-ups Bought", str(stats_node.powerups_purchased))
	_add_stat_label(items_tab, "  Consumables Bought", str(stats_node.consumables_purchased))
	_add_stat_label(items_tab, "  Mods Bought", str(stats_node.mods_purchased))
	
	_add_separator(items_tab)
	
	# Usage
	var usage_title = Label.new()
	usage_title.text = "Usage:"
	usage_title.add_theme_font_size_override("font_size", 14)
	items_tab.add_child(usage_title)
	
	_add_stat_label(items_tab, "  Power-ups Used", str(stats_node.powerups_used))
	_add_stat_label(items_tab, "  Consumables Used", str(stats_node.consumables_used))

## _create_session_tab()
## 
## Create the Session Metrics tab content.
func _create_session_tab():
	_clear_tab(session_tab)
	
	var title = Label.new()
	title.text = "Session Metrics"
	title.add_theme_font_size_override("font_size", 18)
	session_tab.add_child(title)
	
	_add_separator(session_tab)
	
	if not _is_statistics_available():
		_add_stat_label(session_tab, "Statistics", "Not Available")
		_add_stat_label(session_tab, "Play Time", "00:00:00")
		_add_stat_label(session_tab, "Status", "Autoload missing")
		_add_stat_label(session_tab, "Panel Test", "UI is working!")
		return
	
	var play_time = stats_node.get_total_play_time()
	var total_seconds = int(play_time)
	var hours = int(float(total_seconds) / 3600.0)
	var minutes = int(float(total_seconds % 3600) / 60.0)
	var seconds = total_seconds % 60
	var time_string = "%02d:%02d:%02d" % [hours, minutes, seconds]
	
	_add_stat_label(session_tab, "Play Time", time_string)
	_add_stat_label(session_tab, "Highest Score", str(stats_node.highest_score))
	_add_stat_label(session_tab, "Longest Streak", str(stats_node.longest_streak))
	_add_stat_label(session_tab, "Current Streak", str(stats_node.current_streak))
	_add_stat_label(session_tab, "Average Score/Hand", "%.2f" % stats_node.get_average_score_per_hand())

## _refresh_statistics()
## 
## Refresh all statistics displays with current data.
func _refresh_statistics():
	if visible:
		stats_node = get_node_or_null("/root/Statistics")  # Re-check availability
		_populate_statistics_tabs()

## _add_stat_label(parent: Node, label_text: String, value_text: String)
## 
## Add a formatted statistic label to the parent container.
func _add_stat_label(parent: Node, label_text: String, value_text: String):
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size.y = 25  # Ensure minimum height for visibility
	
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 200
	label.custom_minimum_size.y = 20
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	
	var value = Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.y = 20
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_color", Color.CYAN)
	
	hbox.add_child(label)
	hbox.add_child(value)
	parent.add_child(hbox)

## _add_separator(parent: Node)
## 
## Add a visual separator to the parent container.
func _add_separator(parent: Node):
	var separator = HSeparator.new()
	separator.custom_minimum_size.y = 10
	parent.add_child(separator)

## _clear_tab(tab: Node)
## 
## Clear all children from a tab container.
func _clear_tab(tab: Node):
	if not tab:
		return
	
	for child in tab.get_children():
		child.queue_free()
