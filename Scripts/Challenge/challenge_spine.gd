extends Control
class_name ChallengeSpine
## ChallengeSpine
##
## A spine component that displays challenge information on a POST_IT_NOTE texture.
## Shows the current goal in large font. When clicked, triggers fan-out to show all challenges.

signal spine_clicked()
signal spine_hovered(mouse_pos: Vector2)
signal spine_unhovered()

@export var spine_texture: Texture2D

@onready var spine_rect: TextureRect
@onready var goal_label: Label
@onready var points_label: Label

# Text to display
var _goal_text: String = "No Goal"
var _points_goal: int = 0

# Animation properties
var _base_position: Vector2
var _hover_offset: Vector2 = Vector2(0, -5)
var _current_tween: Tween


func _ready() -> void:
	_create_spine_structure()
	_apply_data_to_ui()
	
	# Set spine size for post-it note
	call_deferred("_set_spine_size")
	
	# Connect mouse signals if not already connected (may be connected in scene)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _exit_tree() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null


func _set_spine_size() -> void:
	custom_minimum_size = Vector2(120, 120)
	set_deferred("size", Vector2(120, 120))


func _create_spine_structure() -> void:
	# Create spine texture display (POST_IT_NOTE)
	spine_rect = TextureRect.new()
	spine_rect.name = "SpineRect"
	spine_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	spine_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spine_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spine_rect)
	
	# Create goal label (main text on post-it)
	goal_label = Label.new()
	goal_label.name = "GoalLabel"
	goal_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	goal_label.position = Vector2(-50, 15)
	goal_label.size = Vector2(100, 40)
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	goal_label.add_theme_font_size_override("font_size", 12)
	goal_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 1))
	goal_label.add_theme_color_override("font_shadow_color", Color(0.5, 0.5, 0.4, 0.3))
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(goal_label)
	
	# Create points label (shows points goal under title)
	points_label = Label.new()
	points_label.name = "PointsLabel"
	points_label.set_anchors_preset(Control.PRESET_CENTER)
	points_label.position = Vector2(-50, 10)
	points_label.size = Vector2(100, 30)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	points_label.add_theme_font_size_override("font_size", 18)
	points_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	points_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(points_label)


func _apply_data_to_ui() -> void:
	# Load POST_IT_NOTE texture
	if not spine_texture:
		spine_texture = load("res://Resources/Art/Background/POST_IT_NOTE.png")
		if not spine_texture:
			push_error("[ChallengeSpine] Failed to load POST_IT_NOTE texture")
	
	if spine_rect and spine_texture:
		spine_rect.texture = spine_texture
	
	# Update labels
	if goal_label:
		goal_label.text = _goal_text
	
	if points_label:
		points_label.text = str(_points_goal) + " pts"


## set_goal_text(text)
##
## Updates the goal text displayed on the post-it note.
func set_goal_text(text: String) -> void:
	_goal_text = text
	if goal_label:
		goal_label.text = text


## set_points_goal(points)
##
## Updates the points goal displayed under the title.
func set_points_goal(points: int) -> void:
	_points_goal = points
	if points_label:
		points_label.text = str(points) + " pts"


func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	position = pos


func _on_mouse_entered() -> void:
	emit_signal("spine_hovered", global_position)
	
	if not is_inside_tree() or not is_instance_valid(self):
		return
	
	if not get_parent():
		return
	
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween().set_parallel()
	_current_tween.tween_property(self, "position", _base_position + _hover_offset, 0.1)
	_current_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)


func _on_mouse_exited() -> void:
	emit_signal("spine_unhovered")
	
	if not is_inside_tree() or not is_instance_valid(self):
		return
	
	if not get_parent():
		return
	
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween().set_parallel()
	_current_tween.tween_property(self, "position", _base_position, 0.1)
	_current_tween.tween_property(self, "scale", Vector2.ONE, 0.1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("spine_clicked")
