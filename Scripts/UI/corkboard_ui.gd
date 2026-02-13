extends Control
class_name CorkboardUI
## CorkboardUI
##
## Main unified UI that combines Challenge, Debuff, and Consumable displays
## on a cork board aesthetic in the upper-left quadrant of the screen.

# Signals forwarded from sub-systems
signal challenge_selected(id: String)
signal debuff_selected(id: String)
signal consumable_used(consumable_id: String)
signal consumable_sold(consumable_id: String)
signal max_consumables_reached

# Export paths for manager references
@export var round_manager_path: NodePath
@export var chore_ui_path: NodePath = ^"Panel/ChoreUI"
@export var shop_ui_path: NodePath

# Scene references
@export var challenge_spine_scene: PackedScene
@export var challenge_icon_scene: PackedScene
@export var debuff_spine_scene: PackedScene
@export var debuff_icon_scene: PackedScene
@export var consumable_spine_scene: PackedScene
@export var consumable_icon_scene: PackedScene

# Node references for labels
@onready var spine_label: Label

# Node references
@onready var panel: Panel = $Panel
@onready var round_manager: RoundManager = get_node_or_null(round_manager_path)
@onready var chore_ui = get_node_or_null(chore_ui_path)

# Challenge system data
var _challenge_data := {}  # challenge_id -> ChallengeData
var _challenge_instances := {}  # challenge_id -> Challenge instance
var _challenge_spine: Control = null  # Single spine showing current goal
var _challenge_fanned_icons := {}  # challenge_id -> ChallengeIcon

# Debuff system data  
var _debuff_data := {}  # debuff_id -> DebuffData
var _debuff_instances := {}  # debuff_id -> Debuff instance
var _debuff_spine: Control = null  # Single spine showing list note
var _debuff_fanned_icons := {}  # debuff_id -> DebuffIcon

# Consumable system data
var _consumable_data := {}  # consumable_id -> ConsumableData
var _consumable_spines := {}  # consumable_id -> ConsumableSpine
var _consumable_fanned_icons := {}  # consumable_id -> ConsumableIcon
var _active_consumable_count: int = 0

# Configuration
@export var max_challenges: int = 3
@export var max_debuffs: int = 5
@export var max_consumables: int = 3

# State management
enum State { SPINES, FANNED_CHALLENGES, FANNED_DEBUFFS, FANNED_CONSUMABLES }
var _current_state: State = State.SPINES
var _is_animating: bool = false

# Layout positions (relative to panel)
var _challenge_spine_pos := Vector2(20, 20)
var _debuff_spine_pos := Vector2(20, 150)
var _consumable_spine_start := Vector2(180, 20)
var _consumable_spine_spacing := 50.0

# Animation and overlay
var _background: ColorRect
var _fan_center: Vector2
var _idle_tweens: Array[Tween] = []
var _spine_tooltip: PanelContainer
var _spine_tooltip_label: Label

# Dice label for round info
var _current_dice_type: String = "d6"

# Shop auto-minimize state
var _shop_ui: Control = null
var _shop_was_visible_before_fan: bool = false


func _ready() -> void:
	print("[CorkboardUI] Initializing...")
	add_to_group("corkboard_ui")
	
	# Calculate center for fanned cards
	_fan_center = get_viewport_rect().size / 2.0
	
	# Allow children to render outside CorkboardUI bounds (for fan-out overlay)
	clip_contents = false
	
	# Load default scenes if not set
	_load_default_scenes()
	
	# Create background overlay for fanned state
	_create_background()
	
	# Create tooltip for spine hover
	_create_spine_tooltip()
	
	# Create the spines on the cork board
	_create_challenge_spine()
	_create_debuff_spine()
	_create_consumable_label()
	
	# Get shop UI reference for auto-minimize
	if shop_ui_path:
		_shop_ui = get_node_or_null(shop_ui_path)
	if not _shop_ui:
		_shop_ui = get_node_or_null("../ShopUI")
	
	# Connect to round manager for dice label updates
	if round_manager:
		round_manager.round_started.connect(_on_round_started)
		var round_data = round_manager.get_current_round_data()
		if round_data:
			_update_dice_label(round_data)
	
	print("[CorkboardUI] Initialization complete")


func _load_default_scenes() -> void:
	if not challenge_spine_scene:
		challenge_spine_scene = load("res://Scenes/Challenge/ChallengeSpine.tscn")
	if not challenge_icon_scene:
		challenge_icon_scene = load("res://Scenes/Challenge/ChallengeIcon.tscn")
	if not debuff_spine_scene:
		debuff_spine_scene = load("res://Scenes/Debuff/DebuffSpine.tscn")
	if not debuff_icon_scene:
		debuff_icon_scene = load("res://Scenes/Debuff/DebuffIcon.tscn")
	if not consumable_spine_scene:
		consumable_spine_scene = load("res://Scenes/UI/consumable_spine.tscn")
	if not consumable_icon_scene:
		consumable_icon_scene = load("res://Scenes/Consumable/consumable_icon.tscn")


func _create_background() -> void:
	_background = ColorRect.new()
	_background.name = "FanBackground"
	_background.color = Color(0, 0, 0, 0.5)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_background.visible = false
	_background.z_index = 121  # Above shop UI (100) but below fanned icons (125+), separate from PowerUpUI bg (120)
	
	add_child(_background)
	_background.gui_input.connect(_on_background_clicked)
	
	# Position background to cover full viewport after tree is ready
	call_deferred("_position_background")


func _position_background() -> void:
	if not _background or not is_instance_valid(_background):
		return
	
	var viewport_size = get_viewport_rect().size
	_background.position = -global_position  # Offset to account for CorkboardUI position
	_background.size = viewport_size


func _create_spine_tooltip() -> void:
	_spine_tooltip = PanelContainer.new()
	_spine_tooltip.name = "SpineTooltip"
	_spine_tooltip.visible = false
	_spine_tooltip.z_index = 140  # Above fanned icons but won't block due to MOUSE_FILTER_IGNORE
	_spine_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block clicks
	_apply_hover_tooltip_style(_spine_tooltip)
	
	_spine_tooltip_label = Label.new()
	_spine_tooltip_label.name = "SpineTooltipLabel"
	_spine_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spine_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spine_tooltip_label.custom_minimum_size = Vector2(200, 0)
	_apply_hover_label_style(_spine_tooltip_label)
	
	_spine_tooltip.add_child(_spine_tooltip_label)
	add_child(_spine_tooltip)


func _apply_hover_tooltip_style(panel_container: PanelContainer) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_color = Color(0.8, 0.7, 0.3, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 4
	panel_container.add_theme_stylebox_override("panel", style)


func _apply_hover_label_style(label: Label) -> void:
	var font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))


#region Challenge System
func _create_challenge_spine() -> void:
	if not challenge_spine_scene:
		push_error("[CorkboardUI] challenge_spine_scene not loaded")
		return
	
	_challenge_spine = challenge_spine_scene.instantiate()
	_challenge_spine.position = _challenge_spine_pos
	_challenge_spine.z_index = 10
	panel.add_child(_challenge_spine)
	
	# Set base position so hover animations work correctly
	if _challenge_spine.has_method("set_base_position"):
		_challenge_spine.set_base_position(_challenge_spine_pos)
	
	# Connect signals
	_challenge_spine.spine_clicked.connect(_on_challenge_spine_clicked)
	_challenge_spine.spine_hovered.connect(_on_challenge_spine_hovered)
	_challenge_spine.spine_unhovered.connect(_on_challenge_spine_unhovered)
	
	# Initialize with empty state
	_update_challenge_spine_display()


func _update_challenge_spine_display() -> void:
	if not _challenge_spine:
		return
	
	# Get current active challenge goal for display
	var goal_text := "No Challenges"
	var points_goal := 0
	var reward_text := ""
	var current_progress := 0
	if _challenge_data.size() > 0:
		var first_key = _challenge_data.keys()[0]
		var data: ChallengeData = _challenge_data[first_key]
		if data:
			goal_text = data.display_name
			# Use challenge instance's scaled target score if available, otherwise fall back to data
			if _challenge_instances.has(first_key):
				var challenge_instance = _challenge_instances[first_key]
				if challenge_instance and challenge_instance.has_method("get_target_score"):
					points_goal = challenge_instance.get_target_score()
				else:
					points_goal = data.target_score
			else:
				points_goal = data.target_score
			if data.reward_money > 0:
				reward_text = "$%d" % data.reward_money
			# Get current progress from challenge instance
			if _challenge_instances.has(first_key):
				var challenge_instance = _challenge_instances[first_key]
				if challenge_instance and challenge_instance.has_method("get_current_score"):
					current_progress = challenge_instance.get_current_score()
	
	# Update reward text at the top of the spine (title-style label)
	if _challenge_spine.has_method("set_reward_label"):
		_challenge_spine.set_reward_label(reward_text)
	
	if _challenge_spine.has_method("set_goal_text"):
		_challenge_spine.set_goal_text(goal_text)
	
	# Update points goal display
	if _challenge_spine.has_method("set_points_goal"):
		_challenge_spine.set_points_goal(points_goal)
	
	# Update reward text for tooltip
	if _challenge_spine.has_method("set_reward_text"):
		_challenge_spine.set_reward_text(reward_text)
	
	# Update current progress for tooltip
	if _challenge_spine.has_method("set_current_progress"):
		_challenge_spine.set_current_progress(current_progress)


func add_challenge(data: ChallengeData, challenge: Challenge) -> Node:
	print("[CorkboardUI] Adding challenge:", data.id if data else "null")
	
	if _challenge_data.size() >= max_challenges:
		print("[CorkboardUI] Maximum challenges reached")
		return null
	
	if not data:
		push_error("[CorkboardUI] Cannot add null challenge data")
		return null
	
	_challenge_data[data.id] = data
	_challenge_instances[data.id] = challenge
	
	_update_challenge_spine_display()
	
	# Return the spine for compatibility
	return _challenge_spine


func remove_challenge(id: String) -> void:
	if not _challenge_data.has(id):
		return
	
	_challenge_data.erase(id)
	_challenge_instances.erase(id)
	
	if _challenge_fanned_icons.has(id):
		var icon = _challenge_fanned_icons[id]
		if is_instance_valid(icon):
			icon.queue_free()
		_challenge_fanned_icons.erase(id)
	
	_update_challenge_spine_display()
	print("[CorkboardUI] Removed challenge:", id)


## clear_all_challenges() -> void
##
## Removes all challenges from the UI. Called on new channel start.
func clear_all_challenges() -> void:
	print("[CorkboardUI] Clearing all challenges")
	
	# Clear fanned icons
	for id in _challenge_fanned_icons.keys():
		var icon = _challenge_fanned_icons[id]
		if is_instance_valid(icon):
			icon.queue_free()
	_challenge_fanned_icons.clear()
	
	# Clear data
	_challenge_data.clear()
	_challenge_instances.clear()
	
	# Update display
	_update_challenge_spine_display()
	
	print("[CorkboardUI] Cleared all challenges")


## get_challenge_spine_position()
##
## Returns the global center position of the challenge spine for celebration effects.
##
## Returns: Vector2 - the center position of the challenge spine
func get_challenge_spine_position() -> Vector2:
	if _challenge_spine and is_instance_valid(_challenge_spine):
		var spine_center = _challenge_spine.global_position + (_challenge_spine.size / 2.0)
		return spine_center
	# Fallback to default position if spine doesn't exist
	return global_position + _challenge_spine_pos + Vector2(60, 60)


func animate_challenge_removal(id: String, callback: Callable = Callable()) -> void:
	if not _challenge_data.has(id):
		if callback.is_valid():
			callback.call()
		return
	
	# Animate the spine briefly then remove
	if _challenge_spine and is_instance_valid(_challenge_spine):
		var tween = create_tween()
		tween.tween_property(_challenge_spine, "modulate:a", 0.5, 0.2)
		tween.tween_property(_challenge_spine, "modulate:a", 1.0, 0.2)
		tween.tween_callback(func():
			remove_challenge(id)
			if callback.is_valid():
				callback.call()
		)
	else:
		remove_challenge(id)
		if callback.is_valid():
			callback.call()


func _on_challenge_spine_clicked() -> void:
	if _is_animating:
		return
	
	if _current_state == State.FANNED_CHALLENGES:
		_fold_back_cards()
	else:
		_fan_out_challenges()


func _on_challenge_spine_hovered(mouse_pos: Vector2) -> void:
	if _current_state != State.SPINES:
		return
	
	var challenge_tooltip := "Challenges:\n"
	for id in _challenge_data:
		var data: ChallengeData = _challenge_data[id]
		challenge_tooltip += "• " + data.display_name + "\n"
	
	if _challenge_data.is_empty():
		challenge_tooltip = "No active challenges"
	
	challenge_tooltip += "\nDice: " + _current_dice_type
	
	_show_tooltip(challenge_tooltip, mouse_pos)


func _on_challenge_spine_unhovered() -> void:
	_hide_tooltip()


func _fan_out_challenges() -> void:
	if _challenge_data.is_empty():
		return
	
	_is_animating = true
	_current_state = State.FANNED_CHALLENGES
	
	# Auto-minimize shop if it's open
	if _shop_ui and _shop_ui.visible:
		_shop_was_visible_before_fan = true
		_shop_ui.temporarily_minimize()
		print("[CorkboardUI] Shop was open, temporarily minimized for challenges")
	else:
		_shop_was_visible_before_fan = false
	
	# Show background
	_background.visible = true
	_background.modulate.a = 0
	var bg_tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 1.0, 0.2)
	
	# Hide spine
	if _challenge_spine:
		_challenge_spine.modulate.a = 0
	
	# For each challenge, create 5 POST_IT_NOTEs: Name, Points, Dice, Progress, Reward
	# Calculate positions for all notes
	var all_notes: Array = []
	
	for challenge_id in _challenge_data:
		var data: ChallengeData = _challenge_data[challenge_id]
		var challenge_instance = _challenge_instances.get(challenge_id)
		
		# Get target score from challenge instance (with channel scaling) if available
		var target_score := 0
		if challenge_instance and challenge_instance.has_method("get_target_score"):
			target_score = challenge_instance.get_target_score()
		else:
			target_score = data.target_score
		
		# Create the 5 POST_IT_NOTE cards for this challenge
		var name_note = _create_challenge_post_it("CHALLENGE", data.display_name, challenge_id)
		var points_note = _create_challenge_post_it("GOAL", str(target_score) + " pts", challenge_id)
		var dice_note = _create_challenge_post_it("DICE", data.dice_type if data.dice_type else _current_dice_type, challenge_id)
		
		# Calculate progress percentage
		var progress_pct := 0
		if challenge_instance and challenge_instance.has_method("get_current_score"):
			var current_score = challenge_instance.get_current_score()
			if target_score > 0:
				progress_pct = int((float(current_score) / float(target_score)) * 100)
		var progress_note = _create_challenge_post_it("PROGRESS", str(progress_pct) + "%", challenge_id)
		
		# Create reward note with special styling
		var reward_text = "$%d" % data.reward_money
		var reward_note = _create_challenge_post_it("REWARD", reward_text, challenge_id, true)
		
		all_notes.append(name_note)
		all_notes.append(points_note)
		all_notes.append(dice_note)
		all_notes.append(progress_note)
		all_notes.append(reward_note)
	
	# Add "NEXT UP" post-it showing upcoming challenge name if available
	var next_challenge_note = _create_next_challenge_preview_note()
	if next_challenge_note:
		all_notes.append(next_challenge_note)
	
	# Calculate fan positions for all notes
	var positions = _calculate_fan_positions(all_notes.size())
	
	# Add notes to self (not _background) so they receive mouse input above the background
	for i in range(all_notes.size()):
		var note = all_notes[i]
		add_child(note)
		note.z_index = 125 + i
		_challenge_fanned_icons[note.name] = note
		_animate_card_fan_in(note, positions[i], i * 0.03)
	
	# Mark animation complete after delay
	await get_tree().create_timer(0.3 + all_notes.size() * 0.03).timeout
	_is_animating = false
	_start_idle_animations()


## Creates a uniform POST_IT_NOTE card for challenge display
## is_reward_card: bool - if true, applies special green money styling
func _create_challenge_post_it(title: String, value: String, challenge_id: String, is_reward_card: bool = false) -> Control:
	var note = Control.new()
	note.name = "ChallengeNote_" + title + "_" + challenge_id
	note.custom_minimum_size = Vector2(120, 120)
	note.size = Vector2(120, 120)
	note.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Store base position for hover animation
	note.set_meta("base_position", Vector2.ZERO)
	note.set_meta("challenge_id", challenge_id)
	
	# Background texture
	var texture_rect = TextureRect.new()
	texture_rect.texture = load("res://Resources/Art/Background/POST_IT_NOTE.png")
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(texture_rect)
	
	# Title label at top
	var title_label = Label.new()
	title_label.text = title
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.position = Vector2(-50, 25)
	title_label.size = Vector2(100, 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 12)
	# Reward card has green title
	if is_reward_card:
		title_label.add_theme_color_override("font_color", Color(0.1, 0.5, 0.1, 1))
	else:
		title_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(title_label)
	
	# Value label in center
	var value_label = Label.new()
	value_label.text = value
	value_label.set_anchors_preset(Control.PRESET_CENTER)
	value_label.position = Vector2(-55, -15)
	value_label.size = Vector2(110, 60)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Reward card has larger green money text
	if is_reward_card:
		value_label.add_theme_font_size_override("font_size", 22)
		value_label.add_theme_color_override("font_color", Color(0.1, 0.6, 0.1, 1))
	else:
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(value_label)
	
	# Connect hover signals
	note.mouse_entered.connect(_on_challenge_note_mouse_entered.bind(note))
	note.mouse_exited.connect(_on_challenge_note_mouse_exited.bind(note))
	note.gui_input.connect(_on_challenge_note_gui_input.bind(note))
	
	return note


## _create_next_challenge_preview_note() -> Control
##
## Creates a special POST_IT_NOTE showing the next challenge name.
## Returns null if there is no next challenge (final round).
func _create_next_challenge_preview_note() -> Control:
	print("[CorkboardUI] _create_next_challenge_preview_note called")
	
	# Try to get round_manager from path first, fallback to game_controller
	var rm = round_manager
	if not rm:
		var game_controller = get_tree().get_first_node_in_group("game_controller")
		if game_controller:
			rm = game_controller.round_manager
			print("[CorkboardUI] Found round_manager via game_controller:", rm)
	
	if not rm:
		print("[CorkboardUI] No round_manager - cannot create next challenge preview")
		return null
	
	print("[CorkboardUI] rm.current_round =", rm.current_round)
	print("[CorkboardUI] rm.rounds_data.size() =", rm.rounds_data.size())
	
	# Get next round index (current_round is 0-based)
	var next_round_index = rm.current_round + 1
	
	# Check if there's a next round available
	if next_round_index >= rm.rounds_data.size():
		print("[CorkboardUI] No more rounds after current - no next challenge preview")
		return null  # No more rounds after this one
	
	# Get the next round's challenge data
	var next_round_data = rm.rounds_data[next_round_index]
	var next_challenge_id = next_round_data.get("challenge_id", "")
	print("[CorkboardUI] next_challenge_id =", next_challenge_id)
	
	if next_challenge_id.is_empty():
		print("[CorkboardUI] Next round has no challenge_id")
		return null
	
	# Get the ChallengeData for the next challenge - use rm's direct reference
	var challenge_mgr = rm.challenge_manager
	print("[CorkboardUI] challenge_mgr =", challenge_mgr)
	
	var next_challenge_data: ChallengeData = null
	if challenge_mgr and challenge_mgr.has_method("get_def"):
		next_challenge_data = challenge_mgr.get_def(next_challenge_id)
		print("[CorkboardUI] next_challenge_data =", next_challenge_data)
	else:
		print("[CorkboardUI] Could not find challenge_manager or get_def method")
	
	var next_challenge_name = "???"
	var next_challenge_goal = ""
	if next_challenge_data:
		next_challenge_name = next_challenge_data.display_name
		next_challenge_goal = next_challenge_data.description if next_challenge_data.description else ""
	
	print("[CorkboardUI] next_challenge_name =", next_challenge_name)
	print("[CorkboardUI] next_challenge_goal =", next_challenge_goal)
	
	# Create the "NEXT UP" post-it note with distinct styling
	# Make it taller to fit goal text below the name
	var note_height = 140 if next_challenge_goal.is_empty() else 160
	var note = Control.new()
	note.name = "ChallengeNote_NEXT_UP_" + next_challenge_id
	note.custom_minimum_size = Vector2(140, note_height)
	note.size = Vector2(140, note_height)
	note.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Store base position for hover animation
	note.set_meta("base_position", Vector2.ZERO)
	note.set_meta("challenge_id", next_challenge_id)
	
	# Background texture
	var texture_rect = TextureRect.new()
	texture_rect.texture = load("res://Resources/Art/Background/POST_IT_NOTE.png")
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Give it a slight blue/purple tint to distinguish from current challenge notes
	texture_rect.modulate = Color(0.9, 0.9, 1.0, 1.0)
	note.add_child(texture_rect)
	
	# Title label at top - "NEXT UP"
	var title_label = Label.new()
	title_label.text = "NEXT UP"
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.position = Vector2(-55, 18)
	title_label.size = Vector2(110, 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.6, 1))  # Blue/purple tint
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(title_label)
	
	# Value label - challenge name
	var value_label = Label.new()
	value_label.text = next_challenge_name
	value_label.set_anchors_preset(Control.PRESET_CENTER)
	value_label.position = Vector2(-60, -25)
	value_label.size = Vector2(120, 30)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.4, 1))  # Darker blue text
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(value_label)
	
	# Goal label - challenge description/goal below the name
	if not next_challenge_goal.is_empty():
		var goal_label = Label.new()
		goal_label.text = next_challenge_goal
		goal_label.set_anchors_preset(Control.PRESET_CENTER)
		goal_label.position = Vector2(-60, 10)
		goal_label.size = Vector2(120, 50)
		goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		goal_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		goal_label.add_theme_font_size_override("font_size", 10)
		goal_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.55, 0.9))  # Lighter blue/grey
		goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.add_child(goal_label)
	
	# Connect hover signals
	note.mouse_entered.connect(_on_challenge_note_mouse_entered.bind(note))
	note.mouse_exited.connect(_on_challenge_note_mouse_exited.bind(note))
	note.gui_input.connect(_on_challenge_note_gui_input.bind(note))
	
	print("[CorkboardUI] Created NEXT UP preview for challenge: %s" % next_challenge_name)
	return note


func _on_challenge_note_mouse_entered(note: Control) -> void:
	if not is_instance_valid(note):
		return
	
	var base_pos = note.get_meta("base_position", note.position)
	var tween = create_tween().set_parallel()
	tween.tween_property(note, "position", base_pos + Vector2(0, -10), 0.1)
	tween.tween_property(note, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(note, "z_index", 135, 0.0)  # Boost above other fanned cards


func _on_challenge_note_mouse_exited(note: Control) -> void:
	if not is_instance_valid(note):
		return
	
	var base_pos = note.get_meta("base_position", note.position)
	var tween = create_tween().set_parallel()
	tween.tween_property(note, "position", base_pos, 0.1)
	tween.tween_property(note, "scale", Vector2.ONE, 0.1)
	tween.tween_property(note, "z_index", 125, 0.0)  # Return to standard fanned z


func _on_challenge_note_gui_input(event: InputEvent, note: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var challenge_id = note.get_meta("challenge_id", "")
		if challenge_id:
			emit_signal("challenge_selected", challenge_id)


func _create_dice_label_note() -> Control:
	# Create a uniform post-it note showing the dice type (same size as other challenge notes)
	return _create_challenge_post_it("DICE TYPE", _current_dice_type, "_global")
#endregion


#region Debuff System
func _create_debuff_spine() -> void:
	if not debuff_spine_scene:
		push_error("[CorkboardUI] debuff_spine_scene not loaded")
		return
	
	_debuff_spine = debuff_spine_scene.instantiate()
	_debuff_spine.position = _debuff_spine_pos
	_debuff_spine.z_index = 10
	panel.add_child(_debuff_spine)
	
	# Set base position so hover animations work correctly
	if _debuff_spine.has_method("set_base_position"):
		_debuff_spine.set_base_position(_debuff_spine_pos)
	
	# Connect signals
	_debuff_spine.spine_clicked.connect(_on_debuff_spine_clicked)
	_debuff_spine.spine_hovered.connect(_on_debuff_spine_hovered)
	_debuff_spine.spine_unhovered.connect(_on_debuff_spine_unhovered)
	
	# Initialize with empty state
	_update_debuff_spine_display()


func _update_debuff_spine_display() -> void:
	if not _debuff_spine:
		return
	
	var debuff_count := _debuff_data.size()
	var has_debuffs := debuff_count > 0
	
	if _debuff_spine.has_method("set_has_debuffs"):
		_debuff_spine.set_has_debuffs(has_debuffs)
	if _debuff_spine.has_method("set_debuff_count"):
		_debuff_spine.set_debuff_count(debuff_count)


func add_debuff(data: DebuffData, debuff_instance: Debuff = null) -> Node:
	print("[CorkboardUI] Adding debuff:", data.id if data else "null")
	
	if _debuff_data.size() >= max_debuffs:
		print("[CorkboardUI] Maximum debuffs reached")
		return null
	
	if not data:
		push_error("[CorkboardUI] Cannot add null debuff data")
		return null
	
	_debuff_data[data.id] = data
	if debuff_instance:
		_debuff_instances[data.id] = debuff_instance
	
	_update_debuff_spine_display()
	
	return _debuff_spine


func remove_debuff(id: String) -> void:
	if not _debuff_data.has(id):
		return
	
	_debuff_data.erase(id)
	_debuff_instances.erase(id)
	
	if _debuff_fanned_icons.has(id):
		var icon = _debuff_fanned_icons[id]
		if is_instance_valid(icon):
			icon.queue_free()
		_debuff_fanned_icons.erase(id)
	
	_update_debuff_spine_display()
	print("[CorkboardUI] Removed debuff:", id)


## clear_all_debuffs() -> void
##
## Removes all debuffs from the UI. Called on new channel start.
func clear_all_debuffs() -> void:
	print("[CorkboardUI] Clearing all debuffs")
	
	# Clear fanned icons
	for id in _debuff_fanned_icons.keys():
		var icon = _debuff_fanned_icons[id]
		if is_instance_valid(icon):
			icon.queue_free()
	_debuff_fanned_icons.clear()
	
	# Clear data
	_debuff_data.clear()
	_debuff_instances.clear()
	
	# Update display
	_update_debuff_spine_display()
	
	print("[CorkboardUI] Cleared all debuffs")


func animate_debuff_removal(id: String, callback: Callable = Callable()) -> void:
	if not _debuff_data.has(id):
		if callback.is_valid():
			callback.call()
		return
	
	if _debuff_spine and is_instance_valid(_debuff_spine):
		var tween = create_tween()
		tween.tween_property(_debuff_spine, "modulate:a", 0.5, 0.2)
		tween.tween_property(_debuff_spine, "modulate:a", 1.0, 0.2)
		tween.tween_callback(func():
			remove_debuff(id)
			if callback.is_valid():
				callback.call()
		)
	else:
		remove_debuff(id)
		if callback.is_valid():
			callback.call()


func _on_debuff_spine_clicked() -> void:
	if _is_animating:
		return
	
	if _current_state == State.FANNED_DEBUFFS:
		_fold_back_cards()
	else:
		_fan_out_debuffs()


func _on_debuff_spine_hovered(mouse_pos: Vector2) -> void:
	if _current_state != State.SPINES:
		return
	
	var debuff_tooltip := "Debuffs:\n"
	for id in _debuff_data:
		var data: DebuffData = _debuff_data[id]
		debuff_tooltip += "• " + data.display_name + "\n"
	
	if _debuff_data.is_empty():
		debuff_tooltip = "No active debuffs"
	
	_show_tooltip(debuff_tooltip, mouse_pos)


func _on_debuff_spine_unhovered() -> void:
	_hide_tooltip()


func _fan_out_debuffs() -> void:
	if _debuff_data.is_empty():
		return
	
	_is_animating = true
	_current_state = State.FANNED_DEBUFFS
	
	# Auto-minimize shop if it's open
	if _shop_ui and _shop_ui.visible:
		_shop_was_visible_before_fan = true
		_shop_ui.temporarily_minimize()
		print("[CorkboardUI] Shop was open, temporarily minimized for debuffs")
	else:
		_shop_was_visible_before_fan = false
	
	# Show background
	_background.visible = true
	_background.modulate.a = 0
	var bg_tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 1.0, 0.2)
	
	# Hide spine
	if _debuff_spine:
		_debuff_spine.modulate.a = 0
	
	# Create fanned debuff icons
	var positions = _calculate_fan_positions(_debuff_data.size())
	var i := 0
	
	for id in _debuff_data:
		var data: DebuffData = _debuff_data[id]
		var target_pos = positions[i]
		
		if debuff_icon_scene:
			var icon = debuff_icon_scene.instantiate()
			add_child(icon)
			icon.z_index = 125 + i
			icon.set_data(data)
			_debuff_fanned_icons[id] = icon
			
			icon.debuff_selected.connect(func(debuff_id): emit_signal("debuff_selected", debuff_id))
			
			_animate_card_fan_in(icon, target_pos, i * 0.05)
		i += 1
	
	await get_tree().create_timer(0.3 + _debuff_data.size() * 0.05).timeout
	_is_animating = false
	_start_idle_animations()
#endregion


#region Consumable System
func add_consumable(data: ConsumableData) -> Node:
	print("[CorkboardUI] Adding consumable:", data.id if data else "null")
	
	if _consumable_data.size() >= max_consumables:
		print("[CorkboardUI] Maximum consumables reached")
		emit_signal("max_consumables_reached")
		return null
	
	if not data:
		push_error("[CorkboardUI] Cannot add null consumable data")
		return null
	
	if not consumable_spine_scene:
		push_error("[CorkboardUI] consumable_spine_scene not set")
		return null
	
	_consumable_data[data.id] = data
	_active_consumable_count += 1
	
	# Create spine for this consumable
	var spine = consumable_spine_scene.instantiate()
	spine.set_data(data)
	
	var spine_x = _consumable_spine_start.x + (_consumable_spines.size() * _consumable_spine_spacing)
	var spine_pos = Vector2(spine_x, _consumable_spine_start.y)
	spine.position = spine_pos
	spine.set_base_position(spine_pos)
	spine.z_index = 15
	
	# Reset layout mode and anchors to prevent position issues
	spine.set_anchors_preset(Control.PRESET_TOP_LEFT)
	spine.set_anchor(SIDE_RIGHT, 0)
	spine.set_anchor(SIDE_BOTTOM, 0)
	
	panel.add_child(spine)
	_consumable_spines[data.id] = spine
	
	# Connect signals - the signal emits consumable_id, don't double-bind
	spine.spine_clicked.connect(_on_consumable_spine_clicked)
	spine.spine_hovered.connect(_on_consumable_spine_hovered)
	spine.spine_unhovered.connect(_on_consumable_spine_unhovered)
	
	# Update the label to show new count
	update_consumable_label()
	
	return spine


func remove_consumable(id: String) -> void:
	if not _consumable_data.has(id):
		return
	
	_consumable_data.erase(id)
	
	if _consumable_spines.has(id):
		var spine = _consumable_spines[id]
		if is_instance_valid(spine):
			spine.queue_free()
		_consumable_spines.erase(id)
	
	if _consumable_fanned_icons.has(id):
		var icon = _consumable_fanned_icons[id]
		if is_instance_valid(icon):
			icon.queue_free()
		_consumable_fanned_icons.erase(id)
	
	_active_consumable_count = max(0, _active_consumable_count - 1)
	_reposition_consumable_spines()
	update_consumable_label()
	
	# Check if overflow mode can be exited
	if _overflow_mode:
		_check_overflow_complete()
	# If we're in fanned state and no consumables left, fold back
	elif _active_consumable_count <= 0 and _current_state == State.FANNED_CONSUMABLES:
		_cleanup_empty_consumable_state()
	
	print("[CorkboardUI] Removed consumable:", id)


## clear_all_consumables() -> void
##
## Removes all consumables from the UI. Called on new channel start.
func clear_all_consumables() -> void:
	print("[CorkboardUI] Clearing all consumables")
	
	# Clear spines
	for id in _consumable_spines.keys():
		var spine = _consumable_spines[id]
		if is_instance_valid(spine):
			spine.queue_free()
	_consumable_spines.clear()
	
	# Clear fanned icons
	for id in _consumable_fanned_icons.keys():
		var icon = _consumable_fanned_icons[id]
		if is_instance_valid(icon):
			icon.queue_free()
	_consumable_fanned_icons.clear()
	
	# Clear data
	_consumable_data.clear()
	_active_consumable_count = 0
	
	# Update label
	update_consumable_label()
	
	print("[CorkboardUI] Cleared all consumables")


func _reposition_consumable_spines() -> void:
	var i := 0
	for id in _consumable_spines:
		var spine = _consumable_spines[id]
		if is_instance_valid(spine):
			var new_x = _consumable_spine_start.x + (i * _consumable_spine_spacing)
			var new_pos = Vector2(new_x, _consumable_spine_start.y)
			spine.set_base_position(new_pos)
			var tween = create_tween()
			tween.tween_property(spine, "position", new_pos, 0.2)
		i += 1


func _on_consumable_spine_clicked(consumable_id: String) -> void:
	print("[CorkboardUI] Consumable spine clicked:", consumable_id)
	if _is_animating:
		return
	
	if _current_state == State.FANNED_CONSUMABLES:
		_fold_back_cards()
	else:
		_fan_out_consumables()


func _on_consumable_spine_hovered(_consumable_id: String, mouse_pos: Vector2) -> void:
	if _current_state != State.SPINES:
		return
	
	var consumable_tooltip := "Consumables:\n"
	for id in _consumable_data:
		var data: ConsumableData = _consumable_data[id]
		consumable_tooltip += "• " + data.display_name + "\n"
	
	if _consumable_data.is_empty():
		consumable_tooltip = "No consumables"
	
	_show_tooltip(consumable_tooltip, mouse_pos)


func _on_consumable_spine_unhovered(_consumable_id: String) -> void:
	_hide_tooltip()


func _fan_out_consumables() -> void:
	if _consumable_data.is_empty():
		return
	
	_is_animating = true
	_current_state = State.FANNED_CONSUMABLES
	
	# Auto-minimize shop if it's open
	if _shop_ui and _shop_ui.visible:
		_shop_was_visible_before_fan = true
		_shop_ui.temporarily_minimize()
		print("[CorkboardUI] Shop was open, temporarily minimized for consumables")
	else:
		_shop_was_visible_before_fan = false
	
	# Update background position before showing
	_position_background()
	
	# Show background
	_background.visible = true
	_background.modulate.a = 0
	var bg_tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 1.0, 0.2)
	
	# Hide spines
	for id in _consumable_spines:
		var spine = _consumable_spines[id]
		if is_instance_valid(spine):
			spine.modulate.a = 0
	
	# Create fanned consumable icons
	var positions = _calculate_fan_positions(_consumable_data.size())
	var i := 0
	
	for id in _consumable_data:
		var data: ConsumableData = _consumable_data[id]
		var target_pos = positions[i]
		
		if consumable_icon_scene:
			var icon = consumable_icon_scene.instantiate()
			add_child(icon)
			icon.z_index = 125 + i
			icon.set_data(data)
			_consumable_fanned_icons[id] = icon
			
			icon.consumable_used.connect(func(cid): emit_signal("consumable_used", cid))
			icon.consumable_sell_requested.connect(func(cid): emit_signal("consumable_sold", cid))
			
			_animate_card_fan_in(icon, target_pos, i * 0.05)
		i += 1
	
	await get_tree().create_timer(0.3 + _consumable_data.size() * 0.05).timeout
	_is_animating = false
	_start_idle_animations()
	
	# Update usability after fanning out
	update_consumable_usability()


func update_consumable_usability() -> void:
	
	# Only update when we have fanned icons
	if _consumable_fanned_icons.is_empty():
		return
	
	# Apply usability logic to fanned icons
	for consumable_id in _consumable_fanned_icons.keys():
		var icon = _consumable_fanned_icons.get(consumable_id)
		var data: ConsumableData = _consumable_data.get(consumable_id)
		
		if not icon or not data or not is_instance_valid(icon):
			continue
		
		# Check if consumable can be used based on game state
		var is_useable: bool = _can_use_consumable(data)
		
		# Apply usability to icon
		if icon.has_method("set_useable"):
			icon.set_useable(is_useable)


func _can_use_consumable(data: ConsumableData) -> bool:
	# Debuff check: If consumables are blocked by a debuff, always return false
	if get_meta("consumables_blocked", false):
		return false

	# Global check: All consumables require an active turn (prevents between-round usage)
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.turn_tracker:
		if not game_controller.turn_tracker.is_active:
			return false
	
	# Check specific consumable requirements
	match data.id:
		"any_score":
			# AnyScore requires dice values and at least one open category
			var dice_values = DiceResults.values
			if dice_values.is_empty():
				return false
			
			# Check for open categories via game controller
			if game_controller and game_controller.scorecard:
				var scorecard = game_controller.scorecard
				
				# Check upper section for open categories
				for category in scorecard.upper_scores.keys():
					if scorecard.upper_scores[category] == null:
						return true
				
				# Check lower section for open categories
				for category in scorecard.lower_scores.keys():
					if scorecard.lower_scores[category] == null:
						return true
				
				# No open categories found
				return false
			else:
				return false
		"random_power_up_uncommon":
			# Random PowerUp consumable requires available PowerUp slots
			if game_controller and game_controller.powerup_ui:
				return not game_controller.powerup_ui.has_max_power_ups()
			else:
				return false
		"green_envy":
			# Green Envy requires dice to be rolled
			var dice_values = DiceResults.values
			return not dice_values.is_empty()
		"empty_shelves":
			# Empty Shelves requires dice to be rolled
			var dice_values = DiceResults.values
			return not dice_values.is_empty()
		"double_or_nothing":
			# Double or Nothing MUST be used at the beginning of the turn
			if game_controller and game_controller.turn_tracker:
				var turn_tracker = game_controller.turn_tracker
				return turn_tracker.is_active and turn_tracker.rolls_left >= turn_tracker.MAX_ROLLS - 1
			else:
				return false
		"the_pawn_shop":
			# The Pawn Shop requires at least one PowerUp to sell
			if game_controller:
				return not game_controller.active_power_ups.is_empty()
			else:
				return false
		_:
			# Default: all other consumables (including upgrades) are useable when fanned
			return true


func update_consumable_count(consumable_id: String, count: int) -> void:
	if _consumable_spines.has(consumable_id):
		var spine = _consumable_spines[consumable_id]
		if is_instance_valid(spine) and spine.has_method("set_count"):
			spine.set_count(count)

func _create_consumable_label() -> void:
	# Create title label
	spine_label = Label.new()
	spine_label.name = "SpineLabel"
	spine_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	spine_label.position = Vector2(70, 5)
	spine_label.size = Vector2(120, 20)
	spine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spine_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spine_label.add_theme_font_size_override("font_size", 18)
	spine_label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1))
	spine_label.add_theme_font_override("font", load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf"))
	spine_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spine_label.visible = true
	add_child(spine_label)
	
	# Initialize label with count
	update_consumable_label()


## update_consumable_label()
##
## Updates the consumable spine label to show current count and max.
func update_consumable_label() -> void:
	if spine_label:
		spine_label.text = "COUPONS %d/%d" % [_active_consumable_count, max_consumables]
#endregion


#region Shared Fan/Fold Animation System
func _calculate_fan_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count == 0:
		return positions
	
	var card_spacing := 120.0
	var total_width := (count - 1) * card_spacing
	
	# Calculate center in viewport coordinates
	# Since _background.position = -global_position, viewport coords work directly
	var viewport_center = get_viewport_rect().size / 2.0
	var start_x: float = viewport_center.x - total_width / 2.0
	
	for i in range(count):
		# Use viewport coords directly - background offset handles the conversion
		var pos := Vector2(start_x + i * card_spacing, viewport_center.y - 50)
		positions.append(pos)
	
	return positions


func _animate_card_fan_in(card: Control, target_pos: Vector2, delay: float) -> void:
	# Start from center of viewport
	var viewport_center = get_viewport_rect().size / 2.0
	
	card.position = viewport_center
	card.scale = Vector2(0.1, 0.1)
	card.modulate.a = 0
	card.z_index = 125  # Above background (120) and shop (100)
	
	# Store base position for hover animations
	card.set_meta("base_position", target_pos)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "position", target_pos, 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)


func _fold_back_cards() -> void:
	_is_animating = true
	_stop_idle_animations()
	
	# Animate all fanned icons back to center
	var all_icons: Array = []
	
	for icon in _challenge_fanned_icons.values():
		if is_instance_valid(icon):
			all_icons.append(icon)
	
	for icon in _debuff_fanned_icons.values():
		if is_instance_valid(icon):
			all_icons.append(icon)
	
	for icon in _consumable_fanned_icons.values():
		if is_instance_valid(icon):
			all_icons.append(icon)
	
	# Also handle dice label note (now a child of self, not _background)
	var dice_label_note = get_node_or_null("DiceLabelNote")
	if dice_label_note and is_instance_valid(dice_label_note):
		all_icons.append(dice_label_note)
	
	for i in range(all_icons.size()):
		var icon = all_icons[i]
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(icon, "position", _fan_center, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(icon, "scale", Vector2(0.1, 0.1), 0.2)
		tween.tween_property(icon, "modulate:a", 0, 0.15)
		
		if i == all_icons.size() - 1:
			tween.tween_callback(_on_fold_complete).set_delay(0.2)
	
	# If no icons, complete immediately
	if all_icons.is_empty():
		_on_fold_complete()


func _on_fold_complete() -> void:
	# Clean up fanned icons
	for icon in _challenge_fanned_icons.values():
		if is_instance_valid(icon):
			icon.queue_free()
	_challenge_fanned_icons.clear()
	
	for icon in _debuff_fanned_icons.values():
		if is_instance_valid(icon):
			icon.queue_free()
	_debuff_fanned_icons.clear()
	
	for icon in _consumable_fanned_icons.values():
		if is_instance_valid(icon):
			icon.queue_free()
	_consumable_fanned_icons.clear()
	
	# Clean up dice label note (now a child of self, not _background)
	var dice_label_note = get_node_or_null("DiceLabelNote")
	if dice_label_note and is_instance_valid(dice_label_note):
		dice_label_note.queue_free()
	
	# Hide background
	var bg_tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 0, 0.2)
	bg_tween.tween_callback(func(): _background.visible = false)
	
	# Show spines again
	if _challenge_spine:
		_challenge_spine.modulate.a = 1.0
	if _debuff_spine:
		_debuff_spine.modulate.a = 1.0
	for id in _consumable_spines:
		var spine = _consumable_spines[id]
		if is_instance_valid(spine):
			spine.modulate.a = 1.0
	
	_current_state = State.SPINES
	_is_animating = false
	
	# Restore shop if we minimized it
	if _shop_was_visible_before_fan:
		if _shop_ui and not _shop_ui.visible:
			_shop_ui.restore_from_minimize()
			print("[CorkboardUI] Restored shop after fold complete")
		_shop_was_visible_before_fan = false


func _start_idle_animations() -> void:
	_stop_idle_animations()
	
	var all_icons: Array = []
	all_icons.append_array(_challenge_fanned_icons.values())
	all_icons.append_array(_debuff_fanned_icons.values())
	all_icons.append_array(_consumable_fanned_icons.values())
	
	# Also check for dice label note (now a child of self, not _background)
	var dice_label_note = get_node_or_null("DiceLabelNote")
	if dice_label_note and is_instance_valid(dice_label_note):
		all_icons.append(dice_label_note)
	
	for i in range(all_icons.size()):
		var icon = all_icons[i]
		if not is_instance_valid(icon):
			continue
		
		var base_pos = icon.position
		var tween = create_tween().set_loops()
		var offset = sin(i * 0.5) * 3
		tween.tween_property(icon, "position:y", base_pos.y + offset, 1.0 + i * 0.1).set_trans(Tween.TRANS_SINE)
		tween.tween_property(icon, "position:y", base_pos.y - offset, 1.0 + i * 0.1).set_trans(Tween.TRANS_SINE)
		_idle_tweens.append(tween)


func _stop_idle_animations() -> void:
	for tween in _idle_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_idle_tweens.clear()


func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Block folding if in overflow mode
		if _overflow_mode:
			print("[CorkboardUI] Cannot close - must use or sell %d consumables first" % _overflow_target_count)
			return
		if _current_state != State.SPINES and not _is_animating:
			_fold_back_cards()
#endregion


#region Tooltip System
func _show_tooltip(text: String, near_pos: Vector2) -> void:
	if not _spine_tooltip:
		return
	
	_spine_tooltip_label.text = text
	_spine_tooltip.visible = true
	
	# Position tooltip to the right and below the hover position (not under mouse)
	var tooltip_pos = near_pos + Vector2(100, 50)  # Offset to the right and below
	var viewport_size = get_viewport_rect().size
	
	# Keep tooltip on screen
	await get_tree().process_frame
	var tooltip_size = _spine_tooltip.size
	
	if tooltip_pos.x + tooltip_size.x > viewport_size.x:
		tooltip_pos.x = near_pos.x - tooltip_size.x - 10  # Show to the left instead
	if tooltip_pos.y + tooltip_size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - tooltip_size.y - 10
	
	_spine_tooltip.global_position = tooltip_pos


func _hide_tooltip() -> void:
	if _spine_tooltip:
		_spine_tooltip.visible = false
#endregion


#region Round Manager Integration
func _on_round_started(_round_number: int) -> void:
	if round_manager:
		var round_data = round_manager.get_current_round_data()
		_update_dice_label(round_data)


func _update_dice_label(round_data: Dictionary) -> void:
	if round_data and round_data.has("dice_type"):
		_current_dice_type = round_data["dice_type"]
		_update_challenge_spine_display()
#endregion


#region Utility Functions for GameController Compatibility
func has_max_consumables() -> bool:
	return _active_consumable_count >= max_consumables


func get_consumable_count() -> int:
	return _consumable_data.size()


func get_challenge_count() -> int:
	return _challenge_data.size()


func get_debuff_count() -> int:
	return _debuff_data.size()


## fold_back()
##
## Public method to fold back any fanned view and hide the background.
## Called when shop opens or other UI needs to dismiss the corkboard fan.
func fold_back() -> void:
	print("[CorkboardUI] fold_back() called - current state:", State.keys()[_current_state])
	
	# Immediately hide background regardless of state
	if _background:
		_background.visible = false
		_background.modulate.a = 0.0
	
	# If we're in a fanned state, clean up
	if _current_state != State.SPINES:
		_stop_idle_animations()
		_cleanup_all_fanned_icons()
		
		# Show spines again
		if _challenge_spine:
			_challenge_spine.modulate.a = 1.0
		if _debuff_spine:
			_debuff_spine.modulate.a = 1.0
		for id in _consumable_spines:
			var spine = _consumable_spines[id]
			if is_instance_valid(spine):
				spine.modulate.a = 1.0
		
		_current_state = State.SPINES
		_is_animating = false
	
	# Restore shop if we minimized it
	if _shop_was_visible_before_fan:
		if _shop_ui and not _shop_ui.visible:
			_shop_ui.restore_from_minimize()
			print("[CorkboardUI] Restored shop after immediate fold back")
		_shop_was_visible_before_fan = false
	
	print("[CorkboardUI] fold_back() complete")


## _cleanup_all_fanned_icons()
##
## Immediately cleans up all fanned icons without animation.
func _cleanup_all_fanned_icons() -> void:
	for icon in _challenge_fanned_icons.values():
		if is_instance_valid(icon):
			icon.queue_free()
	_challenge_fanned_icons.clear()
	
	for icon in _debuff_fanned_icons.values():
		if is_instance_valid(icon):
			icon.queue_free()
	_debuff_fanned_icons.clear()
	
	for icon in _consumable_fanned_icons.values():
		if is_instance_valid(icon):
			icon.queue_free()
	_consumable_fanned_icons.clear()
	
	# Clean up dice label note (now a child of self, not _background)
	var dice_label_note = get_node_or_null("DiceLabelNote")
	if dice_label_note and is_instance_valid(dice_label_note):
		dice_label_note.queue_free()


## _cleanup_empty_consumable_state()
##
## Cleans up UI state when all consumables have been removed while fanned.
func _cleanup_empty_consumable_state() -> void:
	print("[CorkboardUI] Cleaning up empty consumable state")
	
	_stop_idle_animations()
	
	# Clear fanned icons
	for icon in _consumable_fanned_icons.values():
		if is_instance_valid(icon):
			icon.queue_free()
	_consumable_fanned_icons.clear()
	
	# Hide background immediately
	if _background:
		_background.visible = false
		_background.modulate.a = 0.0
	
	# Reset state
	_current_state = State.SPINES
	_is_animating = false
	
	# Restore shop if we minimized it
	if _shop_was_visible_before_fan:
		if _shop_ui and not _shop_ui.visible:
			_shop_ui.restore_from_minimize()
			print("[CorkboardUI] Restored shop after empty consumable cleanup")
		_shop_was_visible_before_fan = false


## handle_consumable_overflow(excess_count)
##
## Called when player loses Extra Coupons powerup and has more consumables than the default max.
## Forces the fan-out view open and displays a message requiring the player to use or sell
## consumables until count is at or below max_consumables.
var _overflow_mode: bool = false
var _overflow_target_count: int = 0
var _overflow_label: Label = null

func handle_consumable_overflow(excess_count: int) -> void:
	print("[CorkboardUI] handle_consumable_overflow called with excess_count: %d" % excess_count)
	print("[CorkboardUI] Current state: %s, Active count: %d, Max: %d" % [State.keys()[_current_state], _active_consumable_count, max_consumables])
	
	if excess_count <= 0:
		print("[CorkboardUI] No overflow needed (excess <= 0)")
		return
	
	print("[CorkboardUI] Entering overflow mode - must reduce by %d consumables" % excess_count)
	_overflow_mode = true
	_overflow_target_count = excess_count
	
	# Force fan out if not already
	if _current_state != State.FANNED_CONSUMABLES:
		print("[CorkboardUI] Forcing fan out for overflow mode")
		_fan_out_consumables()
		await get_tree().create_timer(0.7).timeout
		print("[CorkboardUI] Fan out animation completed")
	
	# Create overflow label
	_create_overflow_label()
	_update_overflow_label()
	print("[CorkboardUI] Overflow label created and updated")


func _create_overflow_label() -> void:
	if _overflow_label and is_instance_valid(_overflow_label):
		return
	
	_overflow_label = Label.new()
	_overflow_label.name = "OverflowLabel"
	_overflow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overflow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Position above the fanned cards
	_overflow_label.position = Vector2(_fan_center.x - 200, _fan_center.y - 180)
	_overflow_label.custom_minimum_size = Vector2(400, 50)
	_overflow_label.z_index = 145  # Above fanned icons
	
	# Style the label
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font:
		_overflow_label.add_theme_font_override("font", vcr_font)
	_overflow_label.add_theme_font_size_override("font_size", 24)
	_overflow_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_overflow_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_overflow_label.add_theme_constant_override("outline_size", 4)
	
	_background.add_child(_overflow_label)


func _update_overflow_label() -> void:
	if _overflow_label and is_instance_valid(_overflow_label):
		_overflow_label.text = "Must Use or Sell %d Consumables" % _overflow_target_count
		_overflow_label.visible = _overflow_mode


func _check_overflow_complete() -> void:
	if not _overflow_mode:
		return
	
	var excess: int = _active_consumable_count - max_consumables
	if excess <= 0:
		print("[CorkboardUI] Overflow resolved - exiting overflow mode")
		_overflow_mode = false
		_overflow_target_count = 0
		
		# Hide and cleanup overflow label
		if _overflow_label and is_instance_valid(_overflow_label):
			_overflow_label.queue_free()
			_overflow_label = null
		
		# Allow normal fan out closure
		_fold_back_cards()
	else:
		# Update remaining count
		_overflow_target_count = excess
		_update_overflow_label()
		print("[CorkboardUI] Still in overflow mode - %d excess remaining" % excess)


## set_chores_manager()
##
## Passes the ChoresManager to the embedded ChoreUI.
##
## Parameters:
##   manager: ChoresManager - the ChoresManager instance
func set_chores_manager(manager) -> void:
	if chore_ui and chore_ui.has_method("set_chores_manager"):
		chore_ui.set_chores_manager(manager)
		print("[CorkboardUI] Connected ChoreUI to ChoresManager")


## get_chore_ui()
##
## Returns the embedded ChoreUI for external access.
##
## Returns: ChoreUI or null
func get_chore_ui():
	return chore_ui
#endregion
