@tool
extends Control

## resource_viewer_ui.gd
##
## UI controller for the Resource Viewer editor plugin.
## Provides tabbed interface for viewing PowerUps, Consumables, Mods, and Colored Dice.
## Supports sorting by Name, Price, Rarity, and Rating.

# Resource storage by type
var power_ups: Array = []
var consumables: Array = []
var mods: Array = []
var colored_dice: Array = []
var challenges: Array = []
var debuffs: Array = []

# Current sort settings
var current_sort_field: String = "name"
var sort_ascending: bool = true

# UI References
@onready var tab_container: TabContainer = $MarginContainer/VBoxContainer/TabContainer
@onready var sort_option: OptionButton = $MarginContainer/VBoxContainer/Toolbar/SortOption
@onready var sort_direction_btn: Button = $MarginContainer/VBoxContainer/Toolbar/SortDirectionBtn
@onready var refresh_btn: Button = $MarginContainer/VBoxContainer/Toolbar/RefreshBtn

# Tab-specific UI elements (created dynamically)
var item_lists: Dictionary = {}  # type -> ItemList
var property_grids: Dictionary = {}  # type -> GridContainer
var current_resources: Dictionary = {}  # type -> Array of loaded resources

# Currently selected resource for editing
var selected_resource: Resource = null
var selected_type: String = ""

# Resource folder paths
const POWER_UP_PATH := "res://Scripts/PowerUps/"
const CONSUMABLE_PATH := "res://Scripts/Consumable/"
const MOD_PATH := "res://Scripts/Mods/"
const COLORED_DICE_PATH := "res://Resources/Data/ColoredDice/"
const CHALLENGE_PATH := "res://Scripts/Challenge/"
const DEBUFF_PATH := "res://Scripts/Debuff/"


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	
	print("[ResourceViewer] UI initializing...")
	
	# Connect toolbar signals
	if sort_option:
		sort_option.item_selected.connect(_on_sort_option_selected)
	if sort_direction_btn:
		sort_direction_btn.pressed.connect(_on_sort_direction_pressed)
	if refresh_btn:
		refresh_btn.pressed.connect(_on_refresh_pressed)
	
	# Populate sort options
	_setup_sort_options()
	
	# Register tab UI elements
	_register_all_tabs()
	
	# Scan and load resources
	_scan_all_resources()
	
	# Update tab titles with counts
	_update_tab_titles()
	
	print("[ResourceViewer] UI ready")


## _register_all_tabs()
##
## Registers ItemList and PropertyGrid for each tab
func _register_all_tabs() -> void:
	if not tab_container:
		return
	
	# PowerUps tab
	var power_ups_tab = tab_container.get_node_or_null("PowerUps")
	if power_ups_tab:
		var item_list = power_ups_tab.get_node_or_null("ItemList")
		var prop_grid = power_ups_tab.get_node_or_null("ScrollContainer/PropertyGrid")
		if item_list and prop_grid:
			register_tab_ui("power_up", item_list, prop_grid)
	
	# Consumables tab
	var consumables_tab = tab_container.get_node_or_null("Consumables")
	if consumables_tab:
		var item_list = consumables_tab.get_node_or_null("ItemList")
		var prop_grid = consumables_tab.get_node_or_null("ScrollContainer/PropertyGrid")
		if item_list and prop_grid:
			register_tab_ui("consumable", item_list, prop_grid)
	
	# Mods tab
	var mods_tab = tab_container.get_node_or_null("Mods")
	if mods_tab:
		var item_list = mods_tab.get_node_or_null("ItemList")
		var prop_grid = mods_tab.get_node_or_null("ScrollContainer/PropertyGrid")
		if item_list and prop_grid:
			register_tab_ui("mod", item_list, prop_grid)
	
	# Colors tab
	var colors_tab = tab_container.get_node_or_null("Colors")
	if colors_tab:
		var item_list = colors_tab.get_node_or_null("ItemList")
		var prop_grid = colors_tab.get_node_or_null("ScrollContainer/PropertyGrid")
		if item_list and prop_grid:
			register_tab_ui("colored_dice", item_list, prop_grid)
	
	# Challenges tab
	var challenges_tab = tab_container.get_node_or_null("Challenges")
	if challenges_tab:
		var item_list = challenges_tab.get_node_or_null("ItemList")
		var prop_grid = challenges_tab.get_node_or_null("ScrollContainer/PropertyGrid")
		if item_list and prop_grid:
			register_tab_ui("challenge", item_list, prop_grid)
	
	# Debuffs tab
	var debuffs_tab = tab_container.get_node_or_null("Debuffs")
	if debuffs_tab:
		var item_list = debuffs_tab.get_node_or_null("ItemList")
		var prop_grid = debuffs_tab.get_node_or_null("ScrollContainer/PropertyGrid")
		if item_list and prop_grid:
			register_tab_ui("debuff", item_list, prop_grid)


## _setup_sort_options()
##
## Populates the sort dropdown with available options
func _setup_sort_options() -> void:
	if not sort_option:
		return
	
	sort_option.clear()
	sort_option.add_item("Name", 0)
	sort_option.add_item("Price", 1)
	sort_option.add_item("Rarity", 2)
	sort_option.add_item("Rating", 3)
	sort_option.select(0)


## _scan_all_resources()
##
## Scans all resource folders and loads .tres files
func _scan_all_resources() -> void:
	print("[ResourceViewer] Scanning resource folders...")
	
	power_ups = _scan_folder(POWER_UP_PATH, "PowerUpData")
	consumables = _scan_folder(CONSUMABLE_PATH, "ConsumableData")
	mods = _scan_folder(MOD_PATH, "ModData")
	colored_dice = _scan_folder(COLORED_DICE_PATH, "ColoredDiceData")
	challenges = _scan_folder(CHALLENGE_PATH, "ChallengeData")
	debuffs = _scan_folder(DEBUFF_PATH, "DebuffData")
	
	current_resources = {
		"power_up": power_ups,
		"consumable": consumables,
		"mod": mods,
		"colored_dice": colored_dice,
		"challenge": challenges,
		"debuff": debuffs
	}
	
	print("[ResourceViewer] Found: %d PowerUps, %d Consumables, %d Mods, %d Colored Dice, %d Challenges, %d Debuffs" % [
		power_ups.size(), consumables.size(), mods.size(), colored_dice.size(), challenges.size(), debuffs.size()
	])
	
	# Populate all tabs
	_populate_all_tabs()


## _scan_folder(path, expected_type)
##
## Scans a folder for .tres files and loads them
func _scan_folder(path: String, expected_type: String) -> Array:
	var resources: Array = []
	
	var dir = DirAccess.open(path)
	if not dir:
		print("[ResourceViewer] Could not open folder: %s" % path)
		return resources
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path = path + file_name
			var resource = ResourceLoader.load(full_path)
			if resource:
				resources.append(resource)
				print("[ResourceViewer] Loaded: %s" % full_path)
			else:
				print("[ResourceViewer] Failed to load: %s" % full_path)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return resources


## _update_tab_titles()
##
## Updates tab titles to show resource counts
func _update_tab_titles() -> void:
	if not tab_container:
		return
	
	# Tab indices: 0=PowerUps, 1=Consumables, 2=Mods, 3=ColoredDice, 4=Challenges, 5=Debuffs
	if tab_container.get_tab_count() > 0:
		tab_container.set_tab_title(0, "PowerUps (%d)" % power_ups.size())
	if tab_container.get_tab_count() > 1:
		tab_container.set_tab_title(1, "Consumables (%d)" % consumables.size())
	if tab_container.get_tab_count() > 2:
		tab_container.set_tab_title(2, "Mods (%d)" % mods.size())
	if tab_container.get_tab_count() > 3:
		tab_container.set_tab_title(3, "Colors (%d)" % colored_dice.size())
	if tab_container.get_tab_count() > 4:
		tab_container.set_tab_title(4, "Challenges (%d)" % challenges.size())
	if tab_container.get_tab_count() > 5:
		tab_container.set_tab_title(5, "Debuffs (%d)" % debuffs.size())


## _populate_all_tabs()
##
## Populates all tab ItemLists with sorted resources
func _populate_all_tabs() -> void:
	_populate_tab("power_up", power_ups)
	_populate_tab("consumable", consumables)
	_populate_tab("mod", mods)
	_populate_tab("colored_dice", colored_dice)
	_populate_tab("challenge", challenges)
	_populate_tab("debuff", debuffs)


## _populate_tab(type, resources)
##
## Populates a specific tab's ItemList with resources
func _populate_tab(type: String, resources: Array) -> void:
	if not item_lists.has(type):
		return
	
	var item_list: ItemList = item_lists[type]
	item_list.clear()
	
	# Sort resources
	var sorted_resources = _sort_resources(resources.duplicate(), type)
	current_resources[type] = sorted_resources
	
	for resource in sorted_resources:
		var display_text = _get_display_text(resource, type)
		item_list.add_item(display_text)


## _get_display_text(resource, type)
##
## Gets the display text for a resource in the ItemList
func _get_display_text(resource: Resource, type: String) -> String:
	var name_str = resource.display_name if resource.get("display_name") else resource.id
	var price_str = "$%d" % resource.price if resource.get("price") != null else ""
	
	# Add rarity for power-ups
	if type == "power_up" and resource.get("rarity"):
		var rarity_char = _get_rarity_char(resource.rarity)
		return "%s [%s] %s" % [name_str, rarity_char, price_str]
	
	return "%s %s" % [name_str, price_str]


## _get_rarity_char(rarity)
##
## Returns single character for rarity display
func _get_rarity_char(rarity: String) -> String:
	match rarity.to_lower():
		"common": return "C"
		"uncommon": return "U"
		"rare": return "R"
		"epic": return "E"
		"legendary": return "L"
		_: return "?"


## _get_rarity_weight(rarity)
##
## Returns numeric weight for rarity sorting (higher = rarer)
func _get_rarity_weight(rarity: String) -> int:
	match rarity.to_lower():
		"common": return 1
		"uncommon": return 2
		"rare": return 3
		"epic": return 4
		"legendary": return 5
		_: return 0


## _get_rating_weight(rating)
##
## Returns numeric weight for rating sorting
func _get_rating_weight(rating: String) -> int:
	match rating.to_upper():
		"G": return 1
		"PG": return 2
		"PG-13": return 3
		"R": return 4
		"NC-17": return 5
		_: return 0


## _sort_resources(resources, type)
##
## Sorts resources based on current sort settings
func _sort_resources(resources: Array, type: String) -> Array:
	match current_sort_field:
		"name":
			resources.sort_custom(func(a, b):
				var name_a = a.display_name if a.get("display_name") else a.id
				var name_b = b.display_name if b.get("display_name") else b.id
				if sort_ascending:
					return name_a.nocasecmp_to(name_b) < 0
				else:
					return name_a.nocasecmp_to(name_b) > 0
			)
		"price":
			resources.sort_custom(func(a, b):
				var price_a = a.price if a.get("price") != null else 0
				var price_b = b.price if b.get("price") != null else 0
				if sort_ascending:
					return price_a < price_b
				else:
					return price_a > price_b
			)
		"rarity":
			resources.sort_custom(func(a, b):
				var rarity_a = _get_rarity_weight(a.rarity) if a.get("rarity") else 0
				var rarity_b = _get_rarity_weight(b.rarity) if b.get("rarity") else 0
				if sort_ascending:
					return rarity_a < rarity_b
				else:
					return rarity_a > rarity_b
			)
		"rating":
			resources.sort_custom(func(a, b):
				var rating_a = _get_rating_weight(a.rating) if a.get("rating") else 0
				var rating_b = _get_rating_weight(b.rating) if b.get("rating") else 0
				if sort_ascending:
					return rating_a < rating_b
				else:
					return rating_a > rating_b
			)
	
	return resources


## _display_resource_properties(resource, type)
##
## Displays the properties of a selected resource with editable fields
func _display_resource_properties(resource: Resource, type: String) -> void:
	if not property_grids.has(type):
		return
	
	# Store reference for editing
	selected_resource = resource
	selected_type = type
	
	var grid: GridContainer = property_grids[type]
	
	# Clear existing children
	for child in grid.get_children():
		child.queue_free()
	
	# Add common properties
	_add_property_row(grid, "ID", str(resource.id) if resource.get("id") else "N/A", false)
	
	# Editable: Display Name (single line)
	_add_editable_line_row(grid, "Display Name", str(resource.display_name) if resource.get("display_name") else "", "display_name")
	
	# Editable: Description (multi-line)
	_add_editable_text_row(grid, "Description", str(resource.description) if resource.get("description") else "", "description")
	
	# Editable: Price
	_add_editable_number_row(grid, "Price", resource.price if resource.get("price") != null else 0, "price")
	
	# Type-specific properties
	match type:
		"power_up":
			# Editable: Rarity dropdown
			_add_editable_rarity_row(grid, "Rarity", str(resource.rarity) if resource.get("rarity") else "common")
			# Editable: Rating dropdown
			_add_editable_rating_row(grid, "Rating", str(resource.rating) if resource.get("rating") else "G")
			if resource.get("scene"):
				_add_property_row(grid, "Scene", resource.scene.resource_path, false)
		"consumable":
			# Consumables don't have rarity/rating but we can add them here if needed in the future
			if resource.get("scene"):
				_add_property_row(grid, "Scene", resource.scene.resource_path, false)
		"mod":
			# Mods don't have rarity/rating but we can add them here if needed in the future
			if resource.get("scene"):
				_add_property_row(grid, "Scene", resource.scene.resource_path, false)
		"colored_dice":
			if resource.get("color_type") != null:
				_add_property_row(grid, "Color Type", _get_color_type_name(resource.color_type), false)
			# Editable: Effect description
			_add_editable_text_row(grid, "Effect", str(resource.effect_description) if resource.get("effect_description") else "", "effect_description")
			# Editable: Rarity description
			_add_editable_text_row(grid, "Rarity Info", str(resource.rarity_description) if resource.get("rarity_description") else "", "rarity_description")
		"challenge":
			# Editable: Target score
			_add_editable_score_row(grid, "Target Score", resource.target_score if resource.get("target_score") != null else 0, "target_score")
			# Editable: Reward money
			_add_editable_number_row(grid, "Reward $", resource.reward_money if resource.get("reward_money") != null else 0, "reward_money")
			# Editable: Dice type
			_add_editable_line_row(grid, "Dice Type", str(resource.dice_type) if resource.get("dice_type") else "", "dice_type")
			# Read-only: Debuff IDs (comma-separated list)
			if resource.get("debuff_ids") and resource.debuff_ids.size() > 0:
				_add_property_row(grid, "Debuffs", ", ".join(resource.debuff_ids), false)
			if resource.get("scene"):
				_add_property_row(grid, "Scene", resource.scene.resource_path, false)
		"debuff":
			# Debuffs are simple - just display_name and description (already handled above)
			if resource.get("scene"):
				_add_property_row(grid, "Scene", resource.scene.resource_path, false)
	
	# Add save button at the bottom
	_add_save_button(grid)


## _get_color_type_name(color_type)
##
## Returns human-readable name for color type enum
func _get_color_type_name(color_type: int) -> String:
	match color_type:
		0: return "None"
		1: return "Green"
		2: return "Red"
		3: return "Purple"
		4: return "Blue"
		_: return "Unknown (%d)" % color_type


## _add_property_row(grid, label, value, editable)
##
## Adds a label-value pair to the property grid (read-only)
func _add_property_row(grid: GridContainer, label_text: String, value_text: String, _editable: bool = false) -> void:
	# Create label
	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_child(label)
	
	# Create value label (read-only)
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 12)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.custom_minimum_size.x = 200
	grid.add_child(value)


## _add_editable_line_row(grid, label_text, current_value, property_name)
##
## Adds a label with editable LineEdit for single-line text
func _add_editable_line_row(grid: GridContainer, label_text: String, current_value: String, property_name: String) -> void:
	# Create label
	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))  # Yellow tint for editable
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_child(label)
	
	# Create editable LineEdit
	var line_edit = LineEdit.new()
	line_edit.text = current_value
	line_edit.add_theme_font_size_override("font_size", 12)
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.custom_minimum_size.x = 200
	line_edit.set_meta("property_name", property_name)
	line_edit.text_changed.connect(func(new_text): _on_line_property_changed(new_text, property_name))
	grid.add_child(line_edit)


## _add_editable_text_row(grid, label_text, current_value, property_name)
##
## Adds a label with editable TextEdit for multi-line text
func _add_editable_text_row(grid: GridContainer, label_text: String, current_value: String, property_name: String) -> void:
	# Create label
	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))  # Yellow tint for editable
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_child(label)
	
	# Create editable TextEdit
	var text_edit = TextEdit.new()
	text_edit.text = current_value
	text_edit.add_theme_font_size_override("font_size", 12)
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.custom_minimum_size = Vector2(200, 60)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.set_meta("property_name", property_name)
	text_edit.text_changed.connect(func(): _on_text_property_changed(text_edit, property_name))
	grid.add_child(text_edit)


## _add_editable_number_row(grid, label_text, current_value, property_name)
##
## Adds a label with editable SpinBox for numeric values
func _add_editable_number_row(grid: GridContainer, label_text: String, current_value: int, property_name: String) -> void:
	# Create label
	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))  # Yellow tint for editable
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_child(label)
	
	# Create editable SpinBox
	var spin_box = SpinBox.new()
	spin_box.value = current_value
	spin_box.min_value = 0
	spin_box.max_value = 9999
	spin_box.step = 1
	spin_box.prefix = "$"
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_box.custom_minimum_size.x = 100
	spin_box.set_meta("property_name", property_name)
	spin_box.value_changed.connect(func(new_value): _on_number_property_changed(new_value, property_name))
	grid.add_child(spin_box)


## _add_editable_score_row(grid, label_text, current_value, property_name)
##
## Adds a label with editable SpinBox for score values (no $ prefix)
func _add_editable_score_row(grid: GridContainer, label_text: String, current_value: int, property_name: String) -> void:
	# Create label
	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))  # Yellow tint for editable
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_child(label)
	
	# Create editable SpinBox
	var spin_box = SpinBox.new()
	spin_box.value = current_value
	spin_box.min_value = 0
	spin_box.max_value = 99999
	spin_box.step = 1
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_box.custom_minimum_size.x = 100
	spin_box.set_meta("property_name", property_name)
	spin_box.value_changed.connect(func(new_value): _on_number_property_changed(new_value, property_name))
	grid.add_child(spin_box)


## _add_editable_rarity_row(grid, label_text, current_value)
##
## Adds a label with OptionButton for rarity selection
func _add_editable_rarity_row(grid: GridContainer, label_text: String, current_value: String) -> void:
	# Create label
	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))  # Yellow tint for editable
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_child(label)
	
	# Create OptionButton
	var option_btn = OptionButton.new()
	option_btn.add_item("common", 0)
	option_btn.add_item("uncommon", 1)
	option_btn.add_item("rare", 2)
	option_btn.add_item("epic", 3)
	option_btn.add_item("legendary", 4)
	option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Select current value
	var index = 0
	match current_value.to_lower():
		"common": index = 0
		"uncommon": index = 1
		"rare": index = 2
		"epic": index = 3
		"legendary": index = 4
	option_btn.select(index)
	
	option_btn.item_selected.connect(func(idx): _on_rarity_changed(idx))
	grid.add_child(option_btn)


## _add_editable_rating_row(grid, label_text, current_value)
##
## Adds a label with OptionButton for rating selection
func _add_editable_rating_row(grid: GridContainer, label_text: String, current_value: String) -> void:
	# Create label
	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))  # Yellow tint for editable
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_child(label)
	
	# Create OptionButton
	var option_btn = OptionButton.new()
	option_btn.add_item("G", 0)
	option_btn.add_item("PG", 1)
	option_btn.add_item("PG-13", 2)
	option_btn.add_item("R", 3)
	option_btn.add_item("NC-17", 4)
	option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Select current value
	var index = 0
	match current_value.to_upper():
		"G": index = 0
		"PG": index = 1
		"PG-13": index = 2
		"R": index = 3
		"NC-17": index = 4
	option_btn.select(index)
	
	option_btn.item_selected.connect(func(idx): _on_rating_changed(idx))
	grid.add_child(option_btn)


## _add_save_button(grid)
##
## Adds a save button that spans both columns
func _add_save_button(grid: GridContainer) -> void:
	# Empty spacer for alignment
	var spacer = Control.new()
	grid.add_child(spacer)
	
	# Save button
	var save_btn = Button.new()
	save_btn.text = "💾 Save Changes"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.custom_minimum_size.y = 30
	save_btn.pressed.connect(_on_save_resource_pressed)
	grid.add_child(save_btn)


## _on_text_property_changed(text_edit, property_name)
##
## Called when a text property is edited
func _on_text_property_changed(text_edit: TextEdit, property_name: String) -> void:
	if selected_resource and selected_resource.get(property_name) != null:
		selected_resource.set(property_name, text_edit.text)
		print("[ResourceViewer] Changed %s to: %s" % [property_name, text_edit.text.substr(0, 50)])


## _on_number_property_changed(new_value, property_name)
##
## Called when a numeric property is edited
func _on_number_property_changed(new_value: float, property_name: String) -> void:
	if selected_resource and selected_resource.get(property_name) != null:
		selected_resource.set(property_name, int(new_value))
		print("[ResourceViewer] Changed %s to: %d" % [property_name, int(new_value)])
		# Update item list to reflect price change
		_update_current_item_list()


## _on_line_property_changed(new_text, property_name)
##
## Called when a single-line text property is edited (LineEdit)
func _on_line_property_changed(new_text: String, property_name: String) -> void:
	if selected_resource and selected_resource.get(property_name) != null:
		selected_resource.set(property_name, new_text)
		print("[ResourceViewer] Changed %s to: %s" % [property_name, new_text])
		# Update item list to reflect display name change
		_update_current_item_list()


## _on_rarity_changed(index)
##
## Called when rarity dropdown selection changes
func _on_rarity_changed(index: int) -> void:
	if not selected_resource:
		return
	
	var rarity_values = ["common", "uncommon", "rare", "epic", "legendary"]
	if index >= 0 and index < rarity_values.size():
		selected_resource.rarity = rarity_values[index]
		print("[ResourceViewer] Changed rarity to: %s" % rarity_values[index])
		_update_current_item_list()


## _on_rating_changed(index)
##
## Called when rating dropdown selection changes
func _on_rating_changed(index: int) -> void:
	if not selected_resource:
		return
	
	var rating_values = ["G", "PG", "PG-13", "R", "NC-17"]
	if index >= 0 and index < rating_values.size():
		selected_resource.rating = rating_values[index]
		print("[ResourceViewer] Changed rating to: %s" % rating_values[index])


## _update_current_item_list()
##
## Updates the current tab's item list to reflect changes
func _update_current_item_list() -> void:
	if selected_type and item_lists.has(selected_type):
		var item_list: ItemList = item_lists[selected_type]
		var selected_idx = -1
		
		# Find selected item
		for i in range(item_list.item_count):
			if item_list.is_selected(i):
				selected_idx = i
				break
		
		# Repopulate
		_populate_tab(selected_type, current_resources[selected_type])
		
		# Reselect
		if selected_idx >= 0 and selected_idx < item_list.item_count:
			item_list.select(selected_idx)


## _on_save_resource_pressed()
##
## Saves the currently selected resource to disk
func _on_save_resource_pressed() -> void:
	if not selected_resource:
		print("[ResourceViewer] No resource selected to save")
		return
	
	var resource_path = selected_resource.resource_path
	if resource_path.is_empty():
		print("[ResourceViewer] Resource has no path, cannot save")
		return
	
	var error = ResourceSaver.save(selected_resource, resource_path)
	if error == OK:
		print("[ResourceViewer] ✓ Saved resource: %s" % resource_path)
	else:
		print("[ResourceViewer] ✗ Failed to save resource: %s (error %d)" % [resource_path, error])


## _on_sort_option_selected(index)
##
## Called when sort dropdown selection changes
func _on_sort_option_selected(index: int) -> void:
	match index:
		0: current_sort_field = "name"
		1: current_sort_field = "price"
		2: current_sort_field = "rarity"
		3: current_sort_field = "rating"
	
	print("[ResourceViewer] Sort changed to: %s" % current_sort_field)
	_populate_all_tabs()


## _on_sort_direction_pressed()
##
## Toggles sort direction ascending/descending
func _on_sort_direction_pressed() -> void:
	sort_ascending = not sort_ascending
	
	if sort_direction_btn:
		sort_direction_btn.text = "↑" if sort_ascending else "↓"
	
	print("[ResourceViewer] Sort direction: %s" % ("ascending" if sort_ascending else "descending"))
	_populate_all_tabs()


## _on_refresh_pressed()
##
## Rescans all resource folders
func _on_refresh_pressed() -> void:
	print("[ResourceViewer] Refreshing resources...")
	_scan_all_resources()
	_update_tab_titles()


## _on_item_selected(index, type)
##
## Called when an item is selected in an ItemList
func _on_item_selected(index: int, type: String) -> void:
	if not current_resources.has(type):
		return
	
	var resources = current_resources[type]
	if index >= 0 and index < resources.size():
		var resource = resources[index]
		_display_resource_properties(resource, type)


## register_tab_ui(type, item_list, property_grid)
##
## Registers UI elements for a specific tab type
func register_tab_ui(type: String, item_list: ItemList, property_grid: GridContainer) -> void:
	item_lists[type] = item_list
	property_grids[type] = property_grid
	
	# Connect item selection signal
	item_list.item_selected.connect(func(index): _on_item_selected(index, type))
	
	print("[ResourceViewer] Registered UI for tab: %s" % type)
