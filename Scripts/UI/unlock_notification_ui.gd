extends Control
class_name UnlockNotificationUI

## UnlockNotificationUI
##
## Displays notifications when players unlock new items at the end of games.
## Shows animated popup cards for each newly unlocked item.

signal notification_dismissed

const CARD_SIZE = Vector2(200, 150)
const ANIMATION_DURATION = 0.5
const DISPLAY_DURATION = 3.0

var notification_cards: Array[Control] = []
var current_tween: Tween

func _ready() -> void:
	add_to_group("unlock_notification_ui")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color.TRANSPARENT

## Show unlock notifications for multiple items
## @param unlocked_items: Array of item IDs that were unlocked
func show_unlock_notifications(unlocked_items: Array[String]) -> void:
	if unlocked_items.is_empty():
		return
	
	print("[UnlockNotificationUI] Showing %d unlock notifications" % unlocked_items.size())
	
	# Clear any existing notifications
	_clear_notifications()
	
	# Get ProgressManager to fetch item data
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("[UnlockNotificationUI] ProgressManager not found")
		return
	
	# Create notification cards for each unlocked item
	var card_index = 0
	for item_id in unlocked_items:
		if progress_manager.unlockable_items.has(item_id):
			var item = progress_manager.unlockable_items[item_id]
			_create_notification_card(item, card_index)
			card_index += 1
	
	# Show the notification overlay
	_animate_notifications_in()

## Create a notification card for an unlocked item
## @param item: UnlockableItem that was unlocked
## @param index: Position index for card layout
func _create_notification_card(item, index: int) -> void:
	# Create card container
	var card = PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.position = _get_card_position(index)
	card.modulate = Color.TRANSPARENT
	
	# Style the card
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.3, 0.95)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.8, 0.8, 0.1, 1.0)  # Golden border
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	card.add_theme_stylebox_override("panel", style)
	
	# Create content layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	# Add "UNLOCKED!" header
	var header_label = RichTextLabel.new()
	header_label.custom_minimum_size = Vector2(180, 25)
	header_label.fit_content = true
	header_label.scroll_active = false
	header_label.text = "[center][color=gold][wave amp=20 freq=3]UNLOCKED![/wave][/color][/center]"
	vbox.add_child(header_label)
	
	# Add item name
	var name_label = RichTextLabel.new()
	name_label.custom_minimum_size = Vector2(180, 30)
	name_label.fit_content = true
	name_label.scroll_active = false
	name_label.add_theme_font_size_override("normal_font_size", 14)
	name_label.text = "[center][b]%s[/b][/center]" % item.display_name
	vbox.add_child(name_label)
	
	# Add item type
	var type_label = Label.new()
	type_label.text = item.get_type_string()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	vbox.add_child(type_label)
	
	# Add description
	var desc_label = RichTextLabel.new()
	desc_label.custom_minimum_size = Vector2(180, 50)
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.add_theme_font_size_override("normal_font_size", 10)
	desc_label.text = "[center]%s[/center]" % item.description
	vbox.add_child(desc_label)
	
	# Add card to scene and track it
	add_child(card)
	notification_cards.append(card)

## Calculate position for a notification card
## @param index: Card index for positioning
## @return Vector2: Position for the card
func _get_card_position(index: int) -> Vector2:
	var screen_size = get_viewport().get_visible_rect().size
	var cards_per_row = max(1, int(screen_size.x / (CARD_SIZE.x + 20)))
	
	var row = index / cards_per_row
	var col = index % cards_per_row
	
	var start_x = (screen_size.x - (cards_per_row * (CARD_SIZE.x + 20))) / 2
	var start_y = screen_size.y / 2 - (CARD_SIZE.y / 2)
	
	return Vector2(
		start_x + col * (CARD_SIZE.x + 20),
		start_y + row * (CARD_SIZE.y + 30)
	)

## Animate notification cards appearing
func _animate_notifications_in() -> void:
	if notification_cards.is_empty():
		return
	
	# Show the overlay
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color.WHITE
	
	# Animate each card in sequence
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	for i in range(notification_cards.size()):
		var card = notification_cards[i]
		var delay = i * 0.1  # Stagger the animations
		
		# Slide in from off-screen
		var start_pos = card.position
		card.position.x = -CARD_SIZE.x
		
		current_tween.tween_interval(delay)
		current_tween.tween_property(card, "position:x", start_pos.x, ANIMATION_DURATION)
		current_tween.tween_property(card, "modulate", Color.WHITE, ANIMATION_DURATION)
	
	# Auto-dismiss after display duration
	current_tween.tween_interval(DISPLAY_DURATION)
	current_tween.tween_callback(_animate_notifications_out)

## Animate notification cards disappearing
func _animate_notifications_out() -> void:
	if notification_cards.is_empty():
		_dismiss_notifications()
		return
	
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	for i in range(notification_cards.size()):
		var card = notification_cards[i]
		var delay = i * 0.05  # Quick stagger out
		
		current_tween.tween_interval(delay)
		current_tween.tween_property(card, "modulate", Color.TRANSPARENT, ANIMATION_DURATION * 0.5)
		current_tween.tween_property(card, "position:x", get_viewport().get_visible_rect().size.x, ANIMATION_DURATION * 0.5)
	
	current_tween.tween_interval(ANIMATION_DURATION * 0.5)
	current_tween.tween_callback(_dismiss_notifications)

## Clean up and dismiss notifications
func _dismiss_notifications() -> void:
	_clear_notifications()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color.TRANSPARENT
	notification_dismissed.emit()

## Clear all notification cards
func _clear_notifications() -> void:
	for card in notification_cards:
		if is_instance_valid(card):
			card.queue_free()
	notification_cards.clear()
	
	if current_tween:
		current_tween.kill()

## Handle input to allow manual dismissal
func _unhandled_input(event: InputEvent) -> void:
	if not notification_cards.is_empty() and (
		event is InputEventMouseButton or 
		event is InputEventKey
	):
		if event.pressed:
			_animate_notifications_out()
			get_viewport().set_input_as_handled()
