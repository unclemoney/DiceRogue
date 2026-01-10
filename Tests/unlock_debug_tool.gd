extends Control

## UnlockDebugTool
##
## A comprehensive debug tool for testing and verifying all unlock conditions.
## Shows real-time progress for all unlockable items organized by type,
## with manual trigger buttons for simulating game events.

# Fonts
var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

# UI References
var tab_container: TabContainer
var event_panel: PanelContainer
var log_output: RichTextLabel
var progress_manager: Node

# Item displays by type
var item_displays: Dictionary = {}  # item_id -> Dictionary with UI elements

# Unlock condition class reference
const UnlockConditionClass = preload("res://Scripts/Core/unlock_condition.gd")
const UnlockableItemClass = preload("res://Scripts/Core/unlockable_item.gd")


func _ready() -> void:
	progress_manager = get_node_or_null("/root/ProgressManager")
	if not progress_manager:
		push_error("[UnlockDebugTool] ProgressManager not found!")
		return
	
	_build_ui()
	_populate_all_tabs()
	_connect_signals()
	_log("=== Unlock Debug Tool Ready ===")
	_log("Items loaded: %d" % progress_manager.unlockable_items.size())


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Main layout - split into left (tabs) and right (event triggers + log)
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 10)
	add_child(main_hbox)
	
	# Left side - Tab container with item displays (70% width)
	var left_panel = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.7
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.1, 0.08, 0.12, 0.95)
	left_style.set_corner_radius_all(8)
	left_panel.add_theme_stylebox_override("panel", left_style)
	main_hbox.add_child(left_panel)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 5)
	left_panel.add_child(left_vbox)
	
	# Title
	var title = Label.new()
	title.text = "UNLOCK CONDITION DEBUG TOOL"
	title.add_theme_font_override("font", vcr_font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(title)
	
	# Tab container
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_theme_font_override("font", vcr_font)
	tab_container.add_theme_font_size_override("font_size", 14)
	left_vbox.add_child(tab_container)
	
	# Create tabs for each item type
	_create_item_tab("PowerUps", UnlockableItemClass.ItemType.POWER_UP)
	_create_item_tab("Consumables", UnlockableItemClass.ItemType.CONSUMABLE)
	_create_item_tab("Mods", UnlockableItemClass.ItemType.MOD)
	_create_item_tab("Colored Dice", UnlockableItemClass.ItemType.COLORED_DICE_FEATURE)
	
	# Right side - Event triggers and log (30% width)
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.3
	right_vbox.add_theme_constant_override("separation", 10)
	main_hbox.add_child(right_vbox)
	
	# Event trigger panel
	_build_event_panel(right_vbox)
	
	# Stats display panel
	_build_stats_panel(right_vbox)
	
	# Log output
	_build_log_panel(right_vbox)


func _create_item_tab(tab_name: String, item_type: int) -> void:
	var scroll = ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_container.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.name = "ItemContainer"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)


func _build_event_panel(parent: Control) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# Section title
	var title = Label.new()
	title.text = "EVENT TRIGGERS"
	title.add_theme_font_override("font", vcr_font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6, 1.0))
	vbox.add_child(title)
	
	# Money triggers
	_add_section_label(vbox, "Money:")
	var money_hbox = HBoxContainer.new()
	money_hbox.add_theme_constant_override("separation", 5)
	vbox.add_child(money_hbox)
	_add_trigger_button(money_hbox, "+$10", _on_add_money.bind(10))
	_add_trigger_button(money_hbox, "+$50", _on_add_money.bind(50))
	_add_trigger_button(money_hbox, "+$100", _on_add_money.bind(100))
	
	# Score triggers
	_add_section_label(vbox, "Score:")
	var score_hbox = HBoxContainer.new()
	score_hbox.add_theme_constant_override("separation", 5)
	vbox.add_child(score_hbox)
	_add_trigger_button(score_hbox, "50pts", _on_add_score.bind(50))
	_add_trigger_button(score_hbox, "100pts", _on_add_score.bind(100))
	_add_trigger_button(score_hbox, "200pts", _on_add_score.bind(200))
	
	# Game event triggers
	_add_section_label(vbox, "Events:")
	var event_hbox = HBoxContainer.new()
	event_hbox.add_theme_constant_override("separation", 5)
	vbox.add_child(event_hbox)
	_add_trigger_button(event_hbox, "Yahtzee", _on_roll_yahtzee)
	_add_trigger_button(event_hbox, "Straight", _on_roll_straight)
	
	var event_hbox2 = HBoxContainer.new()
	event_hbox2.add_theme_constant_override("separation", 5)
	vbox.add_child(event_hbox2)
	_add_trigger_button(event_hbox2, "Consumable", _on_use_consumable)
	_add_trigger_button(event_hbox2, "Color Bonus", _on_color_bonus)
	
	# Game completion triggers
	_add_section_label(vbox, "Game Flow:")
	var game_hbox = HBoxContainer.new()
	game_hbox.add_theme_constant_override("separation", 5)
	vbox.add_child(game_hbox)
	_add_trigger_button(game_hbox, "Start Game", _on_start_game)
	_add_trigger_button(game_hbox, "End Game", _on_end_game)
	
	var game_hbox2 = HBoxContainer.new()
	game_hbox2.add_theme_constant_override("separation", 5)
	vbox.add_child(game_hbox2)
	_add_trigger_button(game_hbox2, "Win Game", _on_win_game)
	_add_trigger_button(game_hbox2, "Complete Ch", _on_complete_channel)
	
	# Debug actions
	_add_section_label(vbox, "Debug:")
	var debug_hbox = HBoxContainer.new()
	debug_hbox.add_theme_constant_override("separation", 5)
	vbox.add_child(debug_hbox)
	_add_trigger_button(debug_hbox, "Check All", _on_check_all_unlocks)
	_add_trigger_button(debug_hbox, "Refresh", _on_refresh_display)
	
	var debug_hbox2 = HBoxContainer.new()
	debug_hbox2.add_theme_constant_override("separation", 5)
	vbox.add_child(debug_hbox2)
	_add_trigger_button(debug_hbox2, "Reset Stats", _on_reset_game_stats)


func _build_stats_panel(parent: Control) -> void:
	var panel = PanelContainer.new()
	panel.name = "StatsPanel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.1, 0.95)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "StatsContainer"
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "CURRENT GAME STATS"
	title.add_theme_font_override("font", vcr_font)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.8, 0.6, 0.8, 1.0))
	vbox.add_child(title)
	
	# Will be populated dynamically
	var stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.add_theme_font_override("font", vcr_font)
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	vbox.add_child(stats_label)
	
	_update_stats_display()


func _build_log_panel(parent: Control) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.95)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "LOG OUTPUT"
	title.add_theme_font_override("font", vcr_font)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9, 1.0))
	vbox.add_child(title)
	
	log_output = RichTextLabel.new()
	log_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_output.bbcode_enabled = true
	log_output.scroll_following = true
	log_output.add_theme_font_override("normal_font", vcr_font)
	log_output.add_theme_font_size_override("normal_font_size", 11)
	vbox.add_child(log_output)


func _add_section_label(parent: Control, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", vcr_font)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	parent.add_child(label)


func _add_trigger_button(parent: Control, text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_override("font", vcr_font)
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(70, 30)
	btn.pressed.connect(callback)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.18, 0.25, 1.0)
	style.border_color = Color(0.4, 0.35, 0.5, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.3, 0.25, 0.35, 1.0)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	parent.add_child(btn)
	return btn


func _populate_all_tabs() -> void:
	if not progress_manager:
		return
	
	_populate_tab("PowerUps", UnlockableItemClass.ItemType.POWER_UP)
	_populate_tab("Consumables", UnlockableItemClass.ItemType.CONSUMABLE)
	_populate_tab("Mods", UnlockableItemClass.ItemType.MOD)
	_populate_tab("Colored Dice", UnlockableItemClass.ItemType.COLORED_DICE_FEATURE)


func _populate_tab(tab_name: String, item_type: int) -> void:
	var scroll = tab_container.get_node_or_null(tab_name)
	if not scroll:
		return
	
	var container = scroll.get_node_or_null("ItemContainer")
	if not container:
		return
	
	# Clear existing items
	for child in container.get_children():
		child.queue_free()
	
	# Get all items of this type (locked and unlocked)
	var items: Array = []
	for item_id in progress_manager.unlockable_items:
		var item = progress_manager.unlockable_items[item_id]
		if item.item_type == item_type:
			items.append(item)
	
	# Sort by unlocked status (locked first), then by name
	items.sort_custom(func(a, b):
		if a.is_unlocked != b.is_unlocked:
			return not a.is_unlocked  # Locked items first
		return a.display_name < b.display_name
	)
	
	# Create display for each item
	for item in items:
		_create_item_display(container, item)


func _create_item_display(parent: Control, item) -> void:
	var panel = PanelContainer.new()
	panel.name = "Item_" + item.id
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.18, 0.9)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	
	# Color border based on status
	if item.is_unlocked:
		style.border_color = Color(0.3, 0.7, 0.3, 1.0)  # Green for unlocked
	else:
		var progress = progress_manager.get_condition_progress(item.id)
		if progress["percentage"] >= 80.0:
			style.border_color = Color(1.0, 0.85, 0.0, 1.0)  # Gold for close
		else:
			style.border_color = Color(0.7, 0.4, 0.4, 1.0)  # Red for locked
	
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	panel.add_child(hbox)
	
	# Left side - Item info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item.display_name
	name_label.add_theme_font_override("font", vcr_font)
	name_label.add_theme_font_size_override("font_size", 14)
	if item.is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	info_vbox.add_child(name_label)
	
	# Item ID (smaller)
	var id_label = Label.new()
	id_label.text = "ID: " + item.id
	id_label.add_theme_font_override("font", vcr_font)
	id_label.add_theme_font_size_override("font_size", 10)
	id_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	info_vbox.add_child(id_label)
	
	# Unlock requirement
	var req_label = Label.new()
	req_label.text = item.get_unlock_description()
	req_label.add_theme_font_override("font", vcr_font)
	req_label.add_theme_font_size_override("font_size", 11)
	req_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1.0))
	info_vbox.add_child(req_label)
	
	# Right side - Progress and status
	var progress_vbox = VBoxContainer.new()
	progress_vbox.custom_minimum_size = Vector2(150, 0)
	progress_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(progress_vbox)
	
	# Status label
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_override("font", vcr_font)
	status_label.add_theme_font_size_override("font_size", 12)
	
	if item.is_unlocked:
		status_label.text = "✓ UNLOCKED"
		status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))
	else:
		status_label.text = "🔒 LOCKED"
		status_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5, 1.0))
	progress_vbox.add_child(status_label)
	
	# Progress bar (for locked items)
	if not item.is_unlocked:
		var progress_data = progress_manager.get_condition_progress(item.id)
		
		var progress_bar = ProgressBar.new()
		progress_bar.name = "ProgressBar"
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = progress_data["percentage"]
		progress_bar.custom_minimum_size = Vector2(0, 16)
		progress_bar.show_percentage = false
		
		var bar_style = StyleBoxFlat.new()
		bar_style.bg_color = Color(0.2, 0.15, 0.25, 1.0)
		bar_style.set_corner_radius_all(3)
		progress_bar.add_theme_stylebox_override("background", bar_style)
		
		var fill_style = StyleBoxFlat.new()
		if progress_data["percentage"] >= 80:
			fill_style.bg_color = Color(0.9, 0.75, 0.1, 1.0)  # Gold
		else:
			fill_style.bg_color = Color(0.3, 0.5, 0.7, 1.0)  # Blue
		fill_style.set_corner_radius_all(3)
		progress_bar.add_theme_stylebox_override("fill", fill_style)
		progress_vbox.add_child(progress_bar)
		
		# Progress text
		var progress_text = Label.new()
		progress_text.name = "ProgressText"
		progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		progress_text.add_theme_font_override("font", vcr_font)
		progress_text.add_theme_font_size_override("font_size", 11)
		progress_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		
		if progress_data["target"] > 0:
			progress_text.text = "%d / %d (%.0f%%)" % [progress_data["current"], progress_data["target"], progress_data["percentage"]]
		else:
			progress_text.text = "Per-game condition"
		progress_vbox.add_child(progress_text)
	
	# Debug buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 5)
	progress_vbox.add_child(btn_hbox)
	
	var unlock_btn = Button.new()
	unlock_btn.text = "Lock" if item.is_unlocked else "Unlock"
	unlock_btn.add_theme_font_override("font", vcr_font)
	unlock_btn.add_theme_font_size_override("font_size", 10)
	unlock_btn.pressed.connect(_on_toggle_unlock.bind(item.id))
	btn_hbox.add_child(unlock_btn)
	
	var check_btn = Button.new()
	check_btn.text = "Check"
	check_btn.add_theme_font_override("font", vcr_font)
	check_btn.add_theme_font_size_override("font_size", 10)
	check_btn.pressed.connect(_on_check_item.bind(item.id))
	btn_hbox.add_child(check_btn)
	
	# Store reference for updates
	item_displays[item.id] = {
		"panel": panel,
		"status_label": status_label
	}


func _connect_signals() -> void:
	if progress_manager.has_signal("item_unlocked"):
		progress_manager.item_unlocked.connect(_on_item_unlocked)


func _update_stats_display() -> void:
	var stats_panel = get_node_or_null("MainContainer/StatsPanel")
	if not stats_panel:
		# Find it in the hierarchy
		var found = _find_node_recursive(self, "StatsPanel")
		if not found:
			return
		stats_panel = found
	
	var stats_label = stats_panel.get_node_or_null("StatsContainer/StatsLabel")
	if not stats_label:
		return
	
	if not progress_manager:
		stats_label.text = "No ProgressManager"
		return
	
	var game_stats = progress_manager.current_game_stats
	var cumulative = progress_manager.cumulative_stats
	
	var text = ""
	text += "-- This Game --\n"
	text += "Money: $%d\n" % game_stats.get("money_earned", 0)
	text += "Max Score: %d\n" % game_stats.get("max_category_score", 0)
	text += "Yahtzees: %d\n" % game_stats.get("yahtzees_rolled", 0)
	text += "Straights: %d\n" % game_stats.get("straights_rolled", 0)
	text += "Consumables: %d\n" % game_stats.get("consumables_used", 0)
	text += "Color Bonuses: %d\n" % game_stats.get("same_color_bonuses", 0)
	text += "Tracking: %s\n" % ("YES" if progress_manager.is_tracking_game else "NO")
	text += "\n-- Cumulative --\n"
	text += "Total $: %d\n" % cumulative.get("total_money_earned", 0)
	text += "Games Done: %d\n" % cumulative.get("games_completed", 0)
	text += "Games Won: %d\n" % cumulative.get("games_won", 0)
	text += "Best Channel: %d" % cumulative.get("highest_channel_completed", 0)
	
	stats_label.text = text


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	return null


func _log(message: String) -> void:
	if log_output:
		var timestamp = Time.get_time_string_from_system()
		log_output.append_text("[%s] %s\n" % [timestamp, message])
	print("[UnlockDebugTool] " + message)


# =====================
# Event Trigger Handlers
# =====================

func _on_add_money(amount: int) -> void:
	if not progress_manager.is_tracking_game:
		progress_manager.start_game_tracking()
	progress_manager.track_money_earned(amount)
	_log("Added $%d (total: $%d)" % [amount, progress_manager.current_game_stats.get("money_earned", 0)])
	_update_stats_display()
	_check_and_report_progress()


func _on_add_score(points: int) -> void:
	if not progress_manager.is_tracking_game:
		progress_manager.start_game_tracking()
	progress_manager.track_score_assigned("test_category", points)
	_log("Scored %d pts (max: %d)" % [points, progress_manager.current_game_stats.get("max_category_score", 0)])
	_update_stats_display()
	_check_and_report_progress()


func _on_roll_yahtzee() -> void:
	if not progress_manager.is_tracking_game:
		progress_manager.start_game_tracking()
	progress_manager.track_yahtzee_rolled()
	_log("Yahtzee rolled (total: %d)" % progress_manager.current_game_stats.get("yahtzees_rolled", 0))
	_update_stats_display()
	_check_and_report_progress()


func _on_roll_straight() -> void:
	if not progress_manager.is_tracking_game:
		progress_manager.start_game_tracking()
	progress_manager.track_straight_rolled()
	_log("Straight rolled (total: %d)" % progress_manager.current_game_stats.get("straights_rolled", 0))
	_update_stats_display()
	_check_and_report_progress()


func _on_use_consumable() -> void:
	if not progress_manager.is_tracking_game:
		progress_manager.start_game_tracking()
	progress_manager.track_consumable_used()
	_log("Consumable used (total: %d)" % progress_manager.current_game_stats.get("consumables_used", 0))
	_update_stats_display()
	_check_and_report_progress()


func _on_color_bonus() -> void:
	if not progress_manager.is_tracking_game:
		progress_manager.start_game_tracking()
	progress_manager.track_color_bonus()
	_log("Color bonus triggered (total: %d)" % progress_manager.current_game_stats.get("same_color_bonuses", 0))
	_update_stats_display()
	_check_and_report_progress()


func _on_start_game() -> void:
	progress_manager.start_game_tracking()
	_log("Game tracking started")
	_update_stats_display()


func _on_end_game() -> void:
	var final_score = progress_manager.current_game_stats.get("max_category_score", 0) * 5
	progress_manager.end_game_tracking(final_score)
	_log("Game ended with score: %d" % final_score)
	_update_stats_display()
	_on_refresh_display()


func _on_win_game() -> void:
	if not progress_manager.is_tracking_game:
		progress_manager.start_game_tracking()
	progress_manager.current_game_stats["game_completed"] = true
	var final_score = 1000
	progress_manager.end_game_tracking(final_score)
	progress_manager.cumulative_stats["games_won"] = progress_manager.cumulative_stats.get("games_won", 0) + 1
	_log("Game won! (total wins: %d)" % progress_manager.cumulative_stats.get("games_won", 0))
	_update_stats_display()
	_on_refresh_display()


func _on_complete_channel() -> void:
	var current = progress_manager.cumulative_stats.get("highest_channel_completed", 0)
	progress_manager.cumulative_stats["highest_channel_completed"] = current + 1
	_log("Channel completed! (highest: %d)" % progress_manager.cumulative_stats["highest_channel_completed"])
	_update_stats_display()
	_check_and_report_progress()


func _on_check_all_unlocks() -> void:
	_log("=== Checking All Unlock Conditions ===")
	var newly_unlocked = progress_manager.check_all_unlock_conditions()
	if newly_unlocked.size() > 0:
		_log("[color=green]Newly unlocked: %s[/color]" % str(newly_unlocked))
	else:
		_log("No new unlocks")
	_on_refresh_display()


func _on_refresh_display() -> void:
	_populate_all_tabs()
	_update_stats_display()
	_log("Display refreshed")


func _on_reset_game_stats() -> void:
	progress_manager.start_game_tracking()  # This resets current_game_stats
	_log("Game stats reset")
	_update_stats_display()


func _on_toggle_unlock(item_id: String) -> void:
	var item = progress_manager.unlockable_items.get(item_id)
	if not item:
		return
	
	if item.is_unlocked:
		progress_manager.debug_lock_item(item_id)
		_log("Locked: %s" % item_id)
	else:
		progress_manager.debug_unlock_item(item_id)
		_log("[color=green]Unlocked: %s[/color]" % item_id)
	
	_on_refresh_display()


func _on_check_item(item_id: String) -> void:
	var item = progress_manager.unlockable_items.get(item_id)
	if not item:
		_log("[color=red]Item not found: %s[/color]" % item_id)
		return
	
	_log("=== Checking: %s ===" % item.display_name)
	_log("  ID: %s" % item_id)
	_log("  Type: %s" % item.get_type_string())
	_log("  Status: %s" % ("UNLOCKED" if item.is_unlocked else "LOCKED"))
	
	if item.unlock_condition:
		var cond = item.unlock_condition
		_log("  Condition Type: %s" % UnlockConditionClass.ConditionType.keys()[cond.condition_type])
		_log("  Target Value: %d" % cond.target_value)
		
		var progress = progress_manager.get_condition_progress(item_id)
		_log("  Progress: %d / %d (%.1f%%)" % [progress["current"], progress["target"], progress["percentage"]])
		
		# Check if it would be satisfied now
		var would_satisfy = cond.is_satisfied(progress_manager.current_game_stats, progress_manager.cumulative_stats)
		_log("  Would Satisfy Now: %s" % ("YES" if would_satisfy else "NO"))
	else:
		_log("  No condition attached")


func _on_item_unlocked(item_id: String) -> void:
	_log("[color=yellow]*** ITEM UNLOCKED: %s ***[/color]" % item_id)
	_on_refresh_display()


func _check_and_report_progress() -> void:
	# Check which items are close to unlocking
	for item_id in progress_manager.unlockable_items:
		var item = progress_manager.unlockable_items[item_id]
		if item.is_unlocked:
			continue
		
		var progress = progress_manager.get_condition_progress(item_id)
		if progress["percentage"] >= 80 and progress["percentage"] < 100:
			_log("[color=gold]Close to unlock: %s (%.0f%%)[/color]" % [item.display_name, progress["percentage"]])
