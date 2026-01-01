extends Control
class_name UnlockedItemPanel

## UnlockedItemPanel
##
## Modal panel that displays newly unlocked items one at a time with a card flip
## reveal animation. Shows between game end and End of Round Stats Panel.
## Each item is displayed with icon, name, description, hover info, and OK button.

signal item_acknowledged  # Emitted when player clicks OK for current item
signal all_items_acknowledged  # Emitted when all items have been acknowledged

# Animation constants
const FLIP_DURATION: float = 0.6
const REVEAL_PAUSE: float = 0.3
const CELEBRATION_PARTICLES: int = 20

# UI References
var overlay: ColorRect
var panel_container: PanelContainer
var card_front: Control  # Hidden state with "?"
var card_back: Control  # Revealed item content
var title_label: Label
var item_name_label: Label
var item_type_label: Label
var item_description_label: RichTextLabel
var unlock_reason_label: RichTextLabel
var item_icon: TextureRect
var ok_button: Button

# Queue of items to display
var _item_queue: Array = []  # Array of UnlockableItem resources
var _current_item = null
var _is_animating: bool = false

# Reference to ProgressManager for getting item details
var _progress_manager = null


func _ready() -> void:
	visible = false
	_progress_manager = get_node_or_null("/root/ProgressManager")
	
	# Ensure this control fills the entire screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	_build_ui()


## _build_ui()
##
## Programmatically builds the unlock panel UI with card flip animation support.
func _build_ui() -> void:
	# Create semi-transparent overlay
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Create centered panel container
	panel_container = PanelContainer.new()
	panel_container.name = "PanelContainer"
	panel_container.custom_minimum_size = Vector2(400, 350)
	panel_container.set_anchors_preset(Control.PRESET_CENTER)
	panel_container.offset_left = -200
	panel_container.offset_top = -175
	panel_container.offset_right = 200
	panel_container.offset_bottom = 175
	panel_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel_container.pivot_offset = Vector2(200, 175)  # Center pivot for flip animation
	
	# Load and apply the powerup hover theme
	var theme_path = "res://Resources/UI/powerup_hover_theme.tres"
	var panel_theme = load(theme_path) as Theme
	if panel_theme:
		panel_container.theme = panel_theme
	
	overlay.add_child(panel_container)
	
	# Create main content container
	var main_margin = MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 25)
	main_margin.add_theme_constant_override("margin_right", 25)
	main_margin.add_theme_constant_override("margin_top", 20)
	main_margin.add_theme_constant_override("margin_bottom", 20)
	panel_container.add_child(main_margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	main_margin.add_child(main_vbox)
	
	# Title with unlock icon
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "🎉 NEW UNLOCK! 🎉"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))  # Gold color
	main_vbox.add_child(title_label)
	
	# Separator
	var sep1 = HSeparator.new()
	main_vbox.add_child(sep1)
	
	# Card content area (holds both front and back)
	var card_container = Control.new()
	card_container.custom_minimum_size = Vector2(350, 180)
	main_vbox.add_child(card_container)
	
	# Card front (mystery state) - initially visible
	card_front = _create_card_front()
	card_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_container.add_child(card_front)
	
	# Card back (revealed content) - initially hidden
	card_back = _create_card_back()
	card_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_back.visible = false
	card_container.add_child(card_back)
	
	# Separator before button
	var sep2 = HSeparator.new()
	main_vbox.add_child(sep2)
	
	# OK Button
	ok_button = Button.new()
	ok_button.name = "OKButton"
	ok_button.text = "OK"
	ok_button.custom_minimum_size = Vector2(120, 40)
	ok_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_button.add_theme_font_size_override("font_size", 18)
	ok_button.pressed.connect(_on_ok_pressed)
	ok_button.disabled = true  # Disabled until reveal completes
	main_vbox.add_child(ok_button)


## _create_card_front() -> Control
##
## Creates the mystery/hidden state of the card (shown before flip).
func _create_card_front() -> Control:
	var container = CenterContainer.new()
	
	var mystery_label = Label.new()
	mystery_label.text = "?"
	mystery_label.add_theme_font_size_override("font_size", 96)
	mystery_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(mystery_label)
	
	return container


## _create_card_back() -> Control
##
## Creates the revealed content of the card.
func _create_card_back() -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	
	# Item icon and name row
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 15)
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(header_hbox)
	
	# Item icon
	item_icon = TextureRect.new()
	item_icon.custom_minimum_size = Vector2(64, 64)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_hbox.add_child(item_icon)
	
	# Name and type column
	var name_vbox = VBoxContainer.new()
	name_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(name_vbox)
	
	item_name_label = Label.new()
	item_name_label.text = "Item Name"
	item_name_label.add_theme_font_size_override("font_size", 22)
	item_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	name_vbox.add_child(item_name_label)
	
	item_type_label = Label.new()
	item_type_label.text = "Type: PowerUp"
	item_type_label.add_theme_font_size_override("font_size", 12)
	item_type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	name_vbox.add_child(item_type_label)
	
	# Description
	item_description_label = RichTextLabel.new()
	item_description_label.bbcode_enabled = true
	item_description_label.fit_content = true
	item_description_label.scroll_active = false
	item_description_label.custom_minimum_size = Vector2(320, 50)
	item_description_label.add_theme_font_size_override("normal_font_size", 14)
	item_description_label.text = "[center]Item description goes here[/center]"
	container.add_child(item_description_label)
	
	# Unlock reason (what achievement triggered this)
	unlock_reason_label = RichTextLabel.new()
	unlock_reason_label.bbcode_enabled = true
	unlock_reason_label.fit_content = true
	unlock_reason_label.scroll_active = false
	unlock_reason_label.custom_minimum_size = Vector2(320, 30)
	unlock_reason_label.add_theme_font_size_override("normal_font_size", 11)
	unlock_reason_label.text = "[center][color=lime]Unlocked by: Achievement[/color][/center]"
	container.add_child(unlock_reason_label)
	
	return container


## queue_items(item_ids: Array[String])
##
## Queues unlocked items to display sequentially.
## @param item_ids: Array of item IDs that were just unlocked
func queue_items(item_ids: Array) -> void:
	if not _progress_manager:
		push_error("[UnlockedItemPanel] ProgressManager not available")
		return
	
	# Get UnlockableItem objects from IDs
	for item_id in item_ids:
		if _progress_manager.unlockable_items.has(item_id):
			var item = _progress_manager.unlockable_items[item_id]
			_item_queue.append(item)
			print("[UnlockedItemPanel] Queued item for display: %s" % item.display_name)
		else:
			print("[UnlockedItemPanel] WARNING: Item ID '%s' not found in unlockable_items" % item_id)
	
	if _item_queue.size() > 0:
		print("[UnlockedItemPanel] Starting to display %d items" % _item_queue.size())
		_show_next_item()
	else:
		print("[UnlockedItemPanel] No valid items to display")
		all_items_acknowledged.emit()


## _show_next_item()
##
## Shows the next item in the queue with flip animation.
func _show_next_item() -> void:
	if _item_queue.is_empty():
		print("[UnlockedItemPanel] All items acknowledged")
		visible = false
		all_items_acknowledged.emit()
		return
	
	_current_item = _item_queue.pop_front()
	print("[UnlockedItemPanel] Showing item: %s" % _current_item.display_name)
	_populate_item_display(_current_item)
	
	# Reset card state for animation
	card_front.visible = true
	card_front.modulate.a = 1.0
	card_back.visible = false
	card_back.modulate.a = 1.0  # Changed from 0.0 - ensure it's visible when shown
	panel_container.scale = Vector2.ONE
	ok_button.disabled = true
	
	# Position and size this control to fill the viewport
	var viewport = get_viewport()
	if viewport:
		var viewport_rect = viewport.get_visible_rect()
		global_position = Vector2.ZERO
		size = viewport_rect.size
		# Set z_index high to ensure it's on top
		z_index = 100
	
	visible = true
	
	# Play flip animation
	_play_flip_animation()


## _populate_item_display(item)
##
## Fills the card back with item information.
func _populate_item_display(item) -> void:
	if not item:
		print("[UnlockedItemPanel] ERROR: item is null in _populate_item_display")
		return
	
	print("[UnlockedItemPanel] Populating display for: %s" % item.display_name)
	print("[UnlockedItemPanel] Description: %s" % item.description)
	print("[UnlockedItemPanel] Type: %s" % item.get_type_string())
	
	item_name_label.text = item.display_name
	item_type_label.text = "Type: %s" % item.get_type_string()
	item_description_label.text = "[center]%s[/center]" % item.description
	
	# Get unlock condition description
	var unlock_desc = item.get_unlock_description()
	unlock_reason_label.text = "[center][color=lime]✓ %s[/color][/center]" % unlock_desc
	
	# Set icon if available
	if item.icon:
		item_icon.texture = item.icon
		item_icon.visible = true
	else:
		# Create placeholder icon based on item type
		item_icon.texture = _create_placeholder_icon(item.item_type)
		item_icon.visible = true


## _create_placeholder_icon(item_type: int) -> Texture2D
##
## Creates a simple colored placeholder icon based on item type.
func _create_placeholder_icon(item_type: int) -> Texture2D:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var color: Color
	
	# Use UnlockableItem.ItemType enum values
	match item_type:
		0:  # POWER_UP
			color = Color(0.3, 0.6, 1.0)  # Blue
		1:  # CONSUMABLE
			color = Color(0.3, 1.0, 0.3)  # Green
		2:  # MOD
			color = Color(1.0, 0.5, 0.0)  # Orange
		3:  # COLORED_DICE_FEATURE
			color = Color(0.8, 0.3, 0.8)  # Purple
		_:
			color = Color(0.5, 0.5, 0.5)  # Gray
	
	img.fill(color)
	return ImageTexture.create_from_image(img)


## _play_flip_animation()
##
## Plays the card flip reveal animation.
func _play_flip_animation() -> void:
	print("[UnlockedItemPanel] Starting flip animation")
	_is_animating = true
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Initial pause
	tween.tween_interval(REVEAL_PAUSE)
	
	# First half of flip - scale X to 0 (card turning away)
	tween.tween_property(panel_container, "scale:x", 0.0, FLIP_DURATION / 2)
	
	# Swap card faces at midpoint
	tween.tween_callback(_swap_card_faces)
	
	# Second half of flip - scale X back to 1 (card turning toward)
	tween.tween_property(panel_container, "scale:x", 1.0, FLIP_DURATION / 2)
	
	# Enable OK button after animation
	tween.tween_callback(_on_animation_complete)


## _swap_card_faces()
##
## Swaps visibility of card front and back during flip animation.
func _swap_card_faces() -> void:
	print("[UnlockedItemPanel] _swap_card_faces called")
	print("[UnlockedItemPanel] Before swap - card_front.visible: %s, card_back.visible: %s" % [card_front.visible, card_back.visible])
	card_front.visible = false
	card_back.visible = true
	print("[UnlockedItemPanel] After swap - card_front.visible: %s, card_back.visible: %s" % [card_front.visible, card_back.visible])


## _on_animation_complete()
##
## Called when flip animation finishes.
func _on_animation_complete() -> void:
	print("[UnlockedItemPanel] Animation complete - enabling OK button")
	_is_animating = false
	ok_button.disabled = false
	ok_button.grab_focus()


## _on_ok_pressed()
##
## Handles OK button press - acknowledges current item and shows next.
func _on_ok_pressed() -> void:
	if _is_animating:
		return
	
	print("[UnlockedItemPanel] Item acknowledged: %s" % (_current_item.display_name if _current_item else "unknown"))
	item_acknowledged.emit()
	
	# Show next item or close panel
	_show_next_item()


## get_remaining_count() -> int
##
## Returns the number of items remaining in queue.
func get_remaining_count() -> int:
	return _item_queue.size()


## clear_queue()
##
## Clears all queued items and hides the panel.
func clear_queue() -> void:
	_item_queue.clear()
	_current_item = null
	visible = false
