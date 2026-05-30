extends Control
class_name ChallengeUI

signal challenge_selected(id: String)

@export var challenge_icon_scene: PackedScene = preload("res://Scenes/Challenge/ChallengeIcon.tscn")
@export var round_manager_path: NodePath
@export var max_challenges: int = 3

@onready var round_manager: RoundManager = get_node_or_null(round_manager_path)
@onready var container: HBoxContainer

var _challenges: Dictionary = {}  # id -> ChallengeIcon

func _ready() -> void:
	print("[ChallengeUI] Initializing...")
	print("[ChallengeUI] challenge_icon_scene set:", challenge_icon_scene != null)
	
	# Ensure this UI layer receives input for fan-out clicks
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Defensive cleanup: remove deprecated hardcoded nodes if editor cached an old scene
	for old_name in ["Label", "TextureRect", "Area2D", "DiceLabel", "VBoxContainer"]:
		var old_node = get_node_or_null(old_name)
		if old_node:
			old_node.queue_free()
	
	# Create Container as direct child (reuse if already present)
	if has_node("Container"):
		container = $Container
	else:
		container = HBoxContainer.new()
		container.name = "Container"
		add_child(container)
	
	# Configure container to fill parent
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("separation", 24)
	
	if not challenge_icon_scene:
		push_error("[ChallengeUI] No challenge_icon_scene set!")
		challenge_icon_scene = load("res://Scenes/Challenge/challenge_icon.tscn")
		if not challenge_icon_scene:
			push_error("[ChallengeUI] Failed to load default challenge_icon scene")
	
	print("[ChallengeUI] Initialization complete")
	print("[ChallengeUI] Container visible:", container.visible)
	print("[ChallengeUI] Container rect size:", container.size)
	print("[ChallengeUI] Container global position:", container.global_position)

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
	
	# Size up the icon and disable its own input so ChallengeUI gets the click
	icon.custom_minimum_size = Vector2(110, 150)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Debug node structure
	print("[ChallengeUI] Icon child count:", icon.get_child_count())
	for child in icon.get_children():
		print("[ChallengeUI] Child node:", child.name)
	
	# Set data after adding to tree
	icon.set_data_with_target_score(data, actual_target_score)
	icon.set_data(data)
	icon.set_meta("last_pos", icon.position)
	
	# Juice: target score count-up animation
	icon.animate_target_score_countup()
	
	_challenges[data.id] = icon
	
	# Connect challenge signals
	challenge.challenge_updated.connect(_on_challenge_progress_updated.bind(data.id))
	challenge.challenge_completed.connect(_on_challenge_completed.bind(data.id))
	challenge.challenge_failed.connect(_on_challenge_failed.bind(data.id))
	
	# Connect icon signal
	if not icon.is_connected("challenge_selected", _on_challenge_selected):
		icon.challenge_selected.connect(_on_challenge_selected)
	
	print("[ChallengeUI] Added challenge:", data.id)
	
	# Juice: challenge reveal banner
	_show_challenge_reveal_banner(data.display_name if data else "CHALLENGE")
	
	return icon

func _show_challenge_reveal_banner(challenge_name: String) -> void:
	var banner = Label.new()
	banner.text = "CHALLENGE ACCEPTED\n%s" % challenge_name
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.position.y = 40
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.z_index = 200
	
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font:
		banner.add_theme_font_override("font", vcr_font)
	banner.add_theme_font_size_override("font_size", 28)
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	
	get_tree().root.add_child(banner)
	
	var tfx = get_node_or_null("/root/TweenFXHelper")
	if tfx:
		tfx.play_preset(banner, "fly_in_down")
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_challenge_reveal_sound"):
		audio_mgr.play_challenge_reveal_sound()
	
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(banner):
		var fade = create_tween()
		fade.tween_property(banner, "modulate:a", 0.0, 0.3)
		fade.tween_callback(banner.queue_free)


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
		# Juice: challenge failed effect
		var tfx = get_node_or_null("/root/TweenFXHelper")
		if tfx:
			tfx.negative_hit(icon)
		
		# "FAILED" stamp
		var stamp = Label.new()
		stamp.text = "FAILED"
		stamp.set_anchors_preset(Control.PRESET_CENTER)
		stamp.z_index = 50
		stamp.rotation_degrees = -15
		var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
		if vcr_font:
			stamp.add_theme_font_override("font", vcr_font)
		stamp.add_theme_font_size_override("font_size", 28)
		stamp.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1, 1.0))
		icon.add_child(stamp)
		
		if tfx:
			tfx.play_preset(stamp, "impact_land")
		
		# Failure sound
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_denied_sound"):
			audio_mgr.play_denied_sound()
		
		# Red vignette pulse
		var vignette = ColorRect.new()
		vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		vignette.color = Color(0.8, 0.1, 0.1, 0.0)
		vignette.z_index = 40
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vignette)
		var vig_tween = create_tween()
		vig_tween.tween_property(vignette, "color:a", 0.15, 0.2)
		vig_tween.tween_property(vignette, "color:a", 0.0, 0.4)
		vig_tween.tween_callback(vignette.queue_free)
		
		# Original failure color tween
		var tween = create_tween()
		tween.tween_property(icon, "modulate", Color(1.0, 0.2, 0.2), 0.5)
		tween.tween_property(icon, "modulate", Color.WHITE, 0.5)


# ---- Fan-out system ----
enum State { NORMAL, FANNED_OUT }
var _current_state: State = State.NORMAL
var _background: ColorRect
var _fanned_icons: Dictionary = {}
var _icon_positions: Dictionary = {}

func _get_fan_overlay() -> CanvasLayer:
	return FanOverlayHelper.get_overlay(self)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _current_state == State.FANNED_OUT:
			_fold_back_challenges()
			get_viewport().set_input_as_handled()
		elif _current_state == State.NORMAL:
			if not _challenges.is_empty():
				_fan_out_challenges()
				get_viewport().set_input_as_handled()

func _fan_out_challenges() -> void:
	if _current_state == State.FANNED_OUT:
		return
	_current_state = State.FANNED_OUT
	
	var overlay := _get_fan_overlay()
	var viewport_size := get_viewport_rect().size
	
	# Create background
	_background = FanOverlayHelper.create_background("ChallengeFanBackground")
	overlay.add_child(_background)
	_background.visible = true
	_background.gui_input.connect(_on_background_clicked)
	
	_icon_positions.clear()
	_fanned_icons.clear()
	
	var challenge_ids := _challenges.keys()
	var count := challenge_ids.size()
	var spacing := 120
	var total_width := count * spacing
	var start_x := (viewport_size.x - total_width) / 2.0 + spacing / 2.0
	var center_y := viewport_size.y / 2.0
	
	for i in range(count):
		var id: String = challenge_ids[i]
		var icon: ChallengeIcon = _challenges[id]
		if not icon:
			continue
		_icon_positions[id] = icon.position
		_fanned_icons[id] = icon
		if icon.get_parent() != overlay:
			icon.reparent(overlay, false)
		icon.position = Vector2(start_x + i * spacing - icon.size.x / 2.0, center_y - icon.size.y / 2.0)
		icon.z_index = 200 + i

func _fold_back_challenges() -> void:
	if _current_state == State.NORMAL:
		return
	_current_state = State.NORMAL
	
	for id in _fanned_icons.keys():
		var icon: ChallengeIcon = _fanned_icons[id]
		if not is_instance_valid(icon):
			continue
		if icon.get_parent() != container:
			icon.reparent(container, false)
		if _icon_positions.has(id):
			icon.position = _icon_positions[id]
		icon.z_index = 0
	
	_fanned_icons.clear()
	_icon_positions.clear()
	
	if _background:
		_background.queue_free()
		_background = null

func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_fold_back_challenges()
