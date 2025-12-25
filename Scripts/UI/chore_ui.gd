extends Control
class_name ChoreUI

## ChoreUI
##
## Displays the chore progress bar and current task in the top-left corner.
## Progress increases by 1 each dice roll and decreases by 20 when tasks complete.
## Shows a details panel on hover with the current task information.
## Clicking on the meter fans out to show completed chores and Mom's mood.

signal task_clicked

@export var chores_manager_path: NodePath

# Node references
var progress_bar: ProgressBar
var task_label: Label
var details_panel: PanelContainer
var details_label: RichTextLabel
var _chores_manager = null  # ChoresManager - duck typed to avoid class resolution issues

# Fan-out state
enum State { SPINE, FANNED }
var _current_state: State = State.SPINE
var _background: ColorRect = null
var _fanned_cards: Array[Control] = []
var _is_animating: bool = false
var _fan_center: Vector2

# Visual settings
const BAR_WIDTH: float = 100.0
const BAR_HEIGHT: float = 40.0
const DANGER_THRESHOLD: float = 80.0
const WARNING_THRESHOLD: float = 60.0

func _ready() -> void:
	_create_ui_structure()
	_create_background_overlay()
	_setup_signals()
	_fan_center = get_viewport_rect().size / 2.0
	print("[ChoreUI] Initialized")

## set_chores_manager()
##
## Sets the ChoresManager reference and connects signals.
##
## Parameters:
##   manager: ChoresManager - the ChoresManager instance
func set_chores_manager(manager) -> void:
	if _chores_manager:
		_disconnect_signals()
	
	_chores_manager = manager
	
	if _chores_manager:
		_chores_manager.progress_changed.connect(_on_progress_changed)
		_chores_manager.task_selected.connect(_on_task_selected)
		_chores_manager.task_completed.connect(_on_task_completed)
		if _chores_manager.has_signal("task_rotated"):
			_chores_manager.task_rotated.connect(_on_task_rotated)
		
		# Defer initialization to ensure UI nodes exist
		call_deferred("_initialize_from_manager")
	
	print("[ChoreUI] Connected to ChoresManager")

## _initialize_from_manager()
##
## Deferred initialization after UI is ready.
func _initialize_from_manager() -> void:
	if not _chores_manager:
		return
	
	# Initialize with current values
	_on_progress_changed(_chores_manager.current_progress)
	if _chores_manager.current_task:
		_on_task_selected(_chores_manager.current_task)
		print("[ChoreUI] Initialized with task: %s" % _chores_manager.current_task.display_name)
	else:
		print("[ChoreUI] No initial task available")

func _disconnect_signals() -> void:
	if _chores_manager:
		if _chores_manager.progress_changed.is_connected(_on_progress_changed):
			_chores_manager.progress_changed.disconnect(_on_progress_changed)
		if _chores_manager.task_selected.is_connected(_on_task_selected):
			_chores_manager.task_selected.disconnect(_on_task_selected)
		if _chores_manager.task_completed.is_connected(_on_task_completed):
			_chores_manager.task_completed.disconnect(_on_task_completed)
		if _chores_manager.has_signal("task_rotated") and _chores_manager.task_rotated.is_connected(_on_task_rotated):
			_chores_manager.task_rotated.disconnect(_on_task_rotated)

func _create_ui_structure() -> void:
	# Set size and position - wider and shorter layout
	custom_minimum_size = Vector2(140, 100)
	size = Vector2(140, 100)
	
	# Main container
	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)
	
	# Title
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "GOOF-OFF"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color.BLACK)
	main_container.add_child(title_label)
	
	# Subtitle
	var subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = "METER"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color.BLACK)
	main_container.add_child(subtitle_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	main_container.add_child(spacer)
	
	# Progress bar container (centered)
	var bar_container = CenterContainer.new()
	bar_container.name = "BarContainer"
	bar_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(bar_container)
	
	# Progress bar (horizontal now)
	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	progress_bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	progress_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	_apply_progress_bar_style()
	bar_container.add_child(progress_bar)
	
	# Task label (short name)
	task_label = Label.new()
	task_label.name = "TaskLabel"
	task_label.text = "..."
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task_label.add_theme_font_size_override("font_size", 10)
	task_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_label.custom_minimum_size = Vector2(80, 0)
	#main_container.add_child(task_label)
	
	# Details panel (shown on hover)
	details_panel = PanelContainer.new()
	details_panel.name = "DetailsPanel"
	details_panel.visible = false
	details_panel.position = Vector2(85, 0)  # Position to the right
	details_panel.custom_minimum_size = Vector2(180, 80)
	_apply_panel_style()
	add_child(details_panel)
	
	# Details content
	var details_vbox = VBoxContainer.new()
	details_panel.add_child(details_vbox)
	
	var details_title = Label.new()
	details_title.name = "DetailsTitle"
	details_title.text = "Current Task"
	details_title.add_theme_font_size_override("font_size", 14)
	details_title.add_theme_color_override("font_color", Color.YELLOW)
	details_vbox.add_child(details_title)
	
	details_label = RichTextLabel.new()
	details_label.name = "DetailsLabel"
	details_label.bbcode_enabled = true
	details_label.fit_content = true
	details_label.custom_minimum_size = Vector2(170, 50)
	details_label.add_theme_color_override("default_color", Color.WHITE)
	details_vbox.add_child(details_label)

func _apply_progress_bar_style() -> void:
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.border_color = Color(0.3, 0.3, 0.3)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.7, 0.2)  # Green
	fill_style.set_corner_radius_all(2)
	progress_bar.add_theme_stylebox_override("fill", fill_style)

func _apply_panel_style() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(5)
	panel_style.set_content_margin_all(8)
	details_panel.add_theme_stylebox_override("panel", panel_style)

func _setup_signals() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _on_progress_changed(new_value: int) -> void:
	if progress_bar:
		# Update max value based on scaled threshold
		if _chores_manager and _chores_manager.has_method("get_scaled_max_progress"):
			progress_bar.max_value = _chores_manager.get_scaled_max_progress()
		progress_bar.value = new_value
		_update_progress_color(new_value)
		_update_details_with_progress()
	print("[ChoreUI] Progress updated: %d" % new_value)

func _on_task_selected(task) -> void:  # ChoreData - duck typed
	if task == null:
		if task_label:
			task_label.text = "..."
		if details_label:
			details_label.text = "No task"
		return
	
	if task_label:
		task_label.text = task.display_name
	
	_update_details_with_progress()
	
	print("[ChoreUI] Task selected: %s" % task.display_name)

func _on_task_completed(_task) -> void:  # ChoreData - duck typed, unused
	# Flash effect when task completes
	_play_completion_flash()


## _update_details_with_progress()
##
## Updates the details tooltip with current task info and progress.
## Shows scaled max progress threshold in the tooltip.
func _update_details_with_progress() -> void:
	if not details_label or not _chores_manager:
		return
	
	var task = _chores_manager.current_task
	var current_progress_val = _chores_manager.current_progress
	var max_progress = 100  # Default
	
	# Get scaled max progress if available
	if _chores_manager.has_method("get_scaled_max_progress"):
		max_progress = _chores_manager.get_scaled_max_progress()
	
	if task:
		details_label.text = "[b]%s[/b]\n%s\n[color=#888888]Progress:[/color] %d / %d" % [
			task.display_name,
			task.description,
			current_progress_val,
			max_progress
		]
	else:
		details_label.text = "[color=#888888]Progress:[/color] %d / %d" % [current_progress_val, max_progress]


func _update_progress_color(value: int) -> void:
	var fill_style = progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style == null:
		return
	
	# Create a new stylebox to avoid modifying shared resource
	var new_style = StyleBoxFlat.new()
	new_style.set_corner_radius_all(2)
	
	if value >= DANGER_THRESHOLD:
		new_style.bg_color = Color(0.8, 0.2, 0.2)  # Red
	elif value >= WARNING_THRESHOLD:
		new_style.bg_color = Color(0.8, 0.6, 0.2)  # Orange
	else:
		new_style.bg_color = Color(0.2, 0.7, 0.2)  # Green
	
	progress_bar.add_theme_stylebox_override("fill", new_style)

func _play_completion_flash() -> void:
	var tween = create_tween()
	tween.tween_property(progress_bar, "modulate", Color(0.5, 1.0, 0.5), 0.1)
	tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.2)
	# Also play bounce animation on completion
	_play_meter_bounce()

## _on_task_rotated()
##
## Handler for when chores auto-rotate every 20 rolls.
## Plays a bounce animation to indicate the change.
func _on_task_rotated(_task) -> void:
	print("[ChoreUI] Task rotated, playing bounce animation")
	_play_meter_bounce()

## _play_meter_bounce()
##
## Plays a bouncy scale animation on the progress bar to indicate an update.
## Uses elastic easing for a playful bounce effect.
func _play_meter_bounce() -> void:
	if not progress_bar:
		return
	
	# Store original scale
	var original_scale = progress_bar.scale
	if original_scale == Vector2.ZERO:
		original_scale = Vector2.ONE
	
	# Create bounce tween
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# Bounce up then back to normal
	tween.tween_property(progress_bar, "scale", original_scale * 1.15, 0.15)
	tween.tween_property(progress_bar, "scale", original_scale, 0.15)

## _update_details_position()
##
## Calculates smart tooltip position to avoid going off-screen.
## Shows tooltip on left side if it would extend beyond viewport right edge.
func _update_details_position() -> void:
	if not details_panel:
		return
	
	# Wait for size to be calculated
	await get_tree().process_frame
	
	var viewport_size = get_viewport_rect().size
	var panel_global_pos = global_position
	var panel_size = details_panel.size
	var self_size = size
	
	# Default position: to the right
	var target_x = self_size.x + 5  # 5px gap
	
	# Check if tooltip extends beyond viewport right edge
	var tooltip_right_edge = panel_global_pos.x + target_x + panel_size.x
	if tooltip_right_edge > viewport_size.x:
		# Flip to left side
		target_x = -panel_size.x - 5
	
	# Check vertical positioning
	var target_y = 0.0
	var tooltip_bottom_edge = panel_global_pos.y + target_y + panel_size.y
	if tooltip_bottom_edge > viewport_size.y:
		target_y = viewport_size.y - panel_global_pos.y - panel_size.y - 10
	
	details_panel.position = Vector2(target_x, target_y)

func _on_mouse_entered() -> void:
	if _current_state == State.SPINE:
		details_panel.visible = true
		_update_details_position()

func _on_mouse_exited() -> void:
	details_panel.visible = false

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			task_clicked.emit()
			_toggle_fan_state()


## _create_background_overlay()
##
## Creates the semi-transparent background overlay for fanned state.
func _create_background_overlay() -> void:
	_background = ColorRect.new()
	_background.name = "FanBackground"
	_background.color = Color(0, 0, 0, 0.5)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_background.visible = false
	_background.z_index = 50
	
	# Add to scene tree at root level to cover everything
	call_deferred("_add_background_to_scene")


func _add_background_to_scene() -> void:
	var root = get_tree().current_scene
	if root and is_instance_valid(_background):
		root.add_child(_background)
		_background.gui_input.connect(_on_background_clicked)
		_position_background()


func _position_background() -> void:
	if not _background or not is_instance_valid(_background):
		return
	
	var viewport_size = get_viewport_rect().size
	_background.position = Vector2.ZERO
	_background.size = viewport_size


func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_fold_back_cards()


## _toggle_fan_state()
##
## Toggles between spine and fanned states.
func _toggle_fan_state() -> void:
	if _is_animating:
		return
	
	if _current_state == State.SPINE:
		_fan_out_completed_chores()
	else:
		_fold_back_cards()


## _fan_out_completed_chores()
##
## Displays completed chores and Mom's mood as cards in a fan layout.
func _fan_out_completed_chores() -> void:
	if not _chores_manager:
		return
	
	_is_animating = true
	_current_state = State.FANNED
	
	# Hide details panel
	details_panel.visible = false
	
	# Show and animate background
	_position_background()
	_background.visible = true
	_background.modulate.a = 0
	var bg_tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 1.0, 0.2)
	
	# Create cards: Mom's mood card + completed chores
	var cards_to_create: Array = []
	
	# Mom's mood card (always first)
	var mood_card = _create_mood_card()
	cards_to_create.append(mood_card)
	
	# Completed chores cards (with checkmarks)
	for chore in _chores_manager.completed_chores:
		var chore_card = _create_completed_chore_card(chore)
		cards_to_create.append(chore_card)
	
	# If no completed chores, show "No Chores Completed" message
	if _chores_manager.completed_chores.is_empty():
		var no_chores_card = _create_no_chores_card()
		cards_to_create.append(no_chores_card)
	
	# Calculate positions for fan layout
	var positions = _calculate_fan_positions(cards_to_create.size())
	
	# Add cards to background and animate
	for i in range(cards_to_create.size()):
		var card = cards_to_create[i]
		_background.add_child(card)
		_fanned_cards.append(card)
		_animate_card_fan_in(card, positions[i], i * 0.05)
	
	# Mark animation complete
	await get_tree().create_timer(0.3 + cards_to_create.size() * 0.05).timeout
	_is_animating = false


## _create_mood_card()
##
## Creates a card displaying Mom's current mood.
func _create_mood_card() -> Control:
	var card = Control.new()
	card.name = "MoodCard"
	card.custom_minimum_size = Vector2(140, 160)
	card.size = Vector2(140, 160)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background texture
	var texture_rect = TextureRect.new()
	var coupon_texture = load("res://Resources/Art/Background/COUPON_NOTE.png")
	if coupon_texture:
		texture_rect.texture = coupon_texture
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(texture_rect)
	
	# Title label
	var title = Label.new()
	title.text = "MOM'S MOOD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-60, 20)
	title.size = Vector2(120, 25)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)
	
	# Emoji (big mood indicator)
	var emoji_label = Label.new()
	emoji_label.text = _chores_manager.get_mood_emoji() if _chores_manager.has_method("get_mood_emoji") else "😐"
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.set_anchors_preset(Control.PRESET_CENTER)
	emoji_label.position = Vector2(-60, -10)
	emoji_label.size = Vector2(120, 50)
	emoji_label.add_theme_font_size_override("font_size", 36)
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(emoji_label)
	
	# Mood text
	var mood_text = Label.new()
	var mood_desc = _chores_manager.get_mood_description() if _chores_manager.has_method("get_mood_description") else "Neutral"
	mood_text.text = mood_desc + "\n" + str(_chores_manager.mom_mood) + "/10"
	mood_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mood_text.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	mood_text.position = Vector2(-60, -55)
	mood_text.size = Vector2(120, 40)
	mood_text.add_theme_font_size_override("font_size", 11)
	mood_text.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	mood_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(mood_text)
	
	return card


## _create_completed_chore_card(chore)
##
## Creates a card for a completed chore with a checkmark.
func _create_completed_chore_card(chore) -> Control:
	var card = Control.new()
	card.name = "ChoreCard_" + str(chore.id) if chore else "ChoreCard"
	card.custom_minimum_size = Vector2(140, 160)
	card.size = Vector2(140, 160)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background texture
	var texture_rect = TextureRect.new()
	var coupon_texture = load("res://Resources/Art/Background/COUPON_NOTE.png")
	if coupon_texture:
		texture_rect.texture = coupon_texture
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(texture_rect)
	
	# Checkmark
	var checkmark = Label.new()
	checkmark.text = "✓"
	checkmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	checkmark.set_anchors_preset(Control.PRESET_CENTER_TOP)
	checkmark.position = Vector2(-60, 15)
	checkmark.size = Vector2(120, 30)
	checkmark.add_theme_font_size_override("font_size", 24)
	checkmark.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
	checkmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(checkmark)
	
	# Chore name
	var name_label = Label.new()
	name_label.text = chore.display_name if chore else "Unknown"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.set_anchors_preset(Control.PRESET_CENTER)
	name_label.position = Vector2(-60, 0)
	name_label.size = Vector2(120, 60)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)
	
	return card


## _create_no_chores_card()
##
## Creates a card indicating no chores have been completed.
func _create_no_chores_card() -> Control:
	var card = Control.new()
	card.name = "NoChoresCard"
	card.custom_minimum_size = Vector2(140, 160)
	card.size = Vector2(140, 160)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background texture
	var texture_rect = TextureRect.new()
	var coupon_texture = load("res://Resources/Art/Background/COUPON_NOTE.png")
	if coupon_texture:
		texture_rect.texture = coupon_texture
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(texture_rect)
	
	# Message
	var message = Label.new()
	message.text = "No Chores\nCompleted\nYet!"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.set_anchors_preset(Control.PRESET_CENTER)
	message.position = Vector2(-60, -30)
	message.size = Vector2(120, 80)
	message.add_theme_font_size_override("font_size", 12)
	message.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3))
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(message)
	
	return card


## _calculate_fan_positions(count)
##
## Calculates positions for cards in a fan/arc layout.
func _calculate_fan_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	if count == 0:
		return positions
	
	var card_width = 150.0
	var total_width = count * card_width
	var start_x = _fan_center.x - total_width / 2.0
	
	for i in range(count):
		var x = start_x + (i * card_width)
		var y = _fan_center.y - 80  # Slightly above center
		positions.append(Vector2(x, y))
	
	return positions


## _animate_card_fan_in(card, target_position, delay)
##
## Animates a card from the meter position to its fan position.
func _animate_card_fan_in(card: Control, target_position: Vector2, delay: float) -> void:
	# Start from this UI's position
	card.position = global_position
	card.modulate.a = 0
	card.scale = Vector2(0.5, 0.5)
	
	# Set pivot for scaling
	card.pivot_offset = card.size / 2.0
	
	var tween = create_tween()
	tween.set_parallel()
	
	tween.tween_property(card, "position", target_position, 0.3)\
		.set_delay(delay)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.2)\
		.set_delay(delay)
	tween.tween_property(card, "scale", Vector2.ONE, 0.3)\
		.set_delay(delay)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


## _fold_back_cards()
##
## Animates cards back and returns to spine state.
func _fold_back_cards() -> void:
	if _is_animating:
		return
	
	_is_animating = true
	
	# Animate cards back
	for i in range(_fanned_cards.size()):
		var card = _fanned_cards[i]
		if is_instance_valid(card):
			var tween = create_tween()
			tween.set_parallel()
			tween.tween_property(card, "position", global_position, 0.2)
			tween.tween_property(card, "modulate:a", 0.0, 0.2)
			tween.tween_property(card, "scale", Vector2(0.5, 0.5), 0.2)
	
	# Fade out background
	if _background:
		var bg_tween = create_tween()
		bg_tween.tween_property(_background, "modulate:a", 0.0, 0.2)
	
	# Clean up after animation
	await get_tree().create_timer(0.25).timeout
	
	for card in _fanned_cards:
		if is_instance_valid(card):
			card.queue_free()
	_fanned_cards.clear()
	
	if _background:
		_background.visible = false
	
	_current_state = State.SPINE
	_is_animating = false
