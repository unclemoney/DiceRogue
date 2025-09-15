extends Control
class_name ChallengeUI

signal challenge_selected(id: String)

@export var challenge_icon_scene: PackedScene = preload("res://Scenes/Challenge/ChallengeIcon.tscn")
@export var round_manager_path: NodePath
@export var max_challenges: int = 3

@onready var dice_label: Label = $DiceLabel
@onready var round_manager: RoundManager = get_node_or_null(round_manager_path)
@onready var container: HBoxContainer

var _challenges: Dictionary = {}  # id -> ChallengeIcon

func _ready() -> void:
	print("[ChallengeUI] Initializing...")
	print("[ChallengeUI] Children:", get_children())
	print("[ChallengeUI] challenge_icon_scene set:", challenge_icon_scene != null)
	
	# Try to find Container under VBoxContainer first
	if has_node("VBoxContainer/Container"):
		container = $VBoxContainer/Container
		print("[ChallengeUI] Found Container under VBoxContainer")
		
		# Apply correct container settings for proper layout
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.visible = true
		container.anchor_right = 1.0
		container.anchor_bottom = 0.0
		container.offset_top = 0
		container.offset_bottom = 64
		container.add_theme_constant_override("separation", 40)
		print("[ChallengeUI] Reconfigured existing Container")
	else:
		# Check for direct child Container
		if has_node("Container"):
			container = $Container
			print("[ChallengeUI] Found Container as direct child")
			
			# Apply correct container settings for proper layout
			container.mouse_filter = Control.MOUSE_FILTER_PASS
			container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.visible = true
			container.add_theme_constant_override("separation", 40)
			print("[ChallengeUI] Reconfigured existing Container")
		else:
			# Fallback: create Container at root if not found
			print("[ChallengeUI] Creating Container")
			container = HBoxContainer.new()
			container.name = "Container"
			container.mouse_filter = Control.MOUSE_FILTER_PASS
			container.set_anchors_preset(Control.PRESET_TOP_WIDE)
			container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_theme_constant_override("separation", 40)
			add_child(container)
	
	if not challenge_icon_scene:
		push_error("[ChallengeUI] No challenge_icon_scene set!")
		challenge_icon_scene = load("res://Scenes/Challenge/challenge_icon.tscn")
		if not challenge_icon_scene:
			push_error("[ChallengeUI] Failed to load default challenge_icon scene")
	
	# Connect to round_manager to update dice label each round
	if round_manager:
		round_manager.round_started.connect(_on_round_started)
		_update_dice_label(round_manager.get_current_round_data())
	else:
		push_error("[ChallengeUI] round_manager_path not set or node missing")
	
	print("[ChallengeUI] Initialization complete")
	# Debug container properties
	print("[ChallengeUI] Container visible:", container.visible)
	print("[ChallengeUI] Container rect size:", container.size)
	print("[ChallengeUI] Container global position:", container.global_position)

func _on_round_started(round_number: int) -> void:
	if round_manager:
		var round_data = round_manager.get_current_round_data()
		_update_dice_label(round_data)

func _update_dice_label(round_data: Dictionary) -> void:
	if dice_label and round_data.has("dice_type"):
		print("Updating dice label to:", round_data["dice_type"])
		dice_label.text = "%s" % round_data["dice_type"]

func add_challenge(data: ChallengeData, challenge: Challenge) -> ChallengeIcon:
	print("[ChallengeUI] Adding challenge:", data.id if data else "null")
	
	if not challenge_icon_scene:
		push_error("[ChallengeUI] Cannot add challenge - no icon scene!")
		return null
		
	# Check if this challenge is already added
	if _challenges.has(data.id):
		print("[ChallengeUI] Challenge already exists:", data.id)
		return _challenges[data.id]
		
	if not container:
		push_error("[ChallengeUI] Container is null, trying to create it")
		container = HBoxContainer.new()
		container.name = "Container"
		add_child(container)
	
	var icon = challenge_icon_scene.instantiate() as ChallengeIcon
	if not icon:
		push_error("[ChallengeUI] Failed to instantiate challenge icon!")
		return null
	
	var actual_target_score = challenge.get_target_score() if challenge and challenge.has_method("get_target_score") else data.target_score	
	
	# Add icon to container instead of directly to the UI
	container.add_child(icon)
	
	# Debug node structure
	print("[ChallengeUI] Icon child count:", icon.get_child_count())
	for child in icon.get_children():
		print("[ChallengeUI] Child node:", child.name)
	
	# Set data after adding to tree
	icon.set_data_with_target_score(data, actual_target_score)
	icon.set_data(data)
	icon.set_meta("last_pos", icon.position)
	
	_challenges[data.id] = icon
	
	# Connect challenge signals
	challenge.challenge_updated.connect(_on_challenge_progress_updated.bind(data.id))
	challenge.challenge_completed.connect(_on_challenge_completed.bind(data.id))
	challenge.challenge_failed.connect(_on_challenge_failed.bind(data.id))
	
	# Connect icon signal
	if not icon.is_connected("challenge_selected", _on_challenge_selected):
		icon.challenge_selected.connect(_on_challenge_selected)
	
	print("[ChallengeUI] Added challenge:", data.id)
	return icon

func _on_challenge_selected(id: String) -> void:
	print("[ChallengeUI] Challenge selected:", id)
	emit_signal("challenge_selected", id)

func remove_challenge(id: String) -> void:
	if not _challenges.has(id):
		return
		
	var icon = _challenges[id]
	if icon:
		icon.queue_free()
	_challenges.erase(id)
	print("[ChallengeUI] Removed challenge icon:", id)
	# Animate the remaining cards to their new positions
	await get_tree().process_frame # Wait for layout to update
	animate_challenge_shift()

func get_challenge_icon(id: String) -> ChallengeIcon:
	if container:
		for child in container.get_children():
			if child is ChallengeIcon and child.data and child.data.id == id:
				return child
	return null

func animate_challenge_shift() -> void:
	# Animate all ChallengeIcons to their new positions after a layout change
	print("[ChallengeUI] Animating challenge icons to new positions")
	for child in container.get_children():
		if child is ChallengeIcon:
			var icon := child as ChallengeIcon
			var target_pos := icon.position
			if not icon.has_meta("last_pos"):
				icon.set_meta("last_pos", target_pos)
			var last_pos: Vector2 = icon.get_meta("last_pos")
			# Move icon to last known position before tweening to new position
			icon.position = last_pos
			# Tween to new position
			print("[ChallengeUI] Tweening icon", icon.data.id if icon.data else "unknown", "from", last_pos, "to", target_pos)
			var tween := create_tween()
			tween.tween_property(icon, "position", target_pos, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			icon.set_meta("last_pos", target_pos)

func animate_challenge_removal(challenge_id: String, on_finished: Callable) -> void:
	var icon = get_challenge_icon(challenge_id)
	if icon:
		print("[ChallengeUI] Animating challenge icon for removal:", challenge_id)
		var tween := create_tween()
		# 1. Squish down
		tween.tween_property(icon, "scale", Vector2(1.2, 0.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# 2. Stretch up
		tween.tween_property(icon, "scale", Vector2(0.8, 1.6), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# 3. Move up and fade out
		var start_pos = icon.position
		var end_pos = start_pos + Vector2(0, -icon.size.y * 8)
		tween.tween_property(icon, "position", end_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(icon, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_LINEAR)
		# 4. When finished, call the provided callback
		tween.finished.connect(on_finished)
	else:
		print("[ChallengeUI] No icon found for challenge, skipping animation:", challenge_id)
		on_finished.call()

func _on_challenge_progress_updated(progress: float, id: String) -> void:
	var icon = get_challenge_icon(id)
	if icon:
		icon.set_progress(progress)

func _on_challenge_completed(id: String) -> void:
	var icon = get_challenge_icon(id)
	if icon:
		icon.set_progress(1.0)
		
		# Create a success effect
		var tween = create_tween()
		tween.tween_property(icon, "modulate", Color(0.2, 1.0, 0.2), 0.5)
		tween.tween_property(icon, "modulate", Color.WHITE, 0.5)

func _on_challenge_failed(id: String) -> void:
	var icon = get_challenge_icon(id)
	if icon:
		# Create a failure effect
		var tween = create_tween()
		tween.tween_property(icon, "modulate", Color(1.0, 0.2, 0.2), 0.5)
		tween.tween_property(icon, "modulate", Color.WHITE, 0.5)
