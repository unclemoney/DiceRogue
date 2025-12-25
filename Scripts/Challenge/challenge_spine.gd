extends Control
class_name ChallengeSpine
## ChallengeSpine
##
## A spine component that displays challenge information on a POST_IT_NOTE texture.
## Shows the current goal in large font. When clicked, triggers fan-out to show all challenges.
## Hovering for 0.3s shows a detailed tooltip with challenge information.

signal spine_clicked()
signal spine_hovered(mouse_pos: Vector2)
signal spine_unhovered()

@export var spine_texture: Texture2D

@onready var spine_rect: TextureRect
@onready var goal_label: Label
@onready var points_label: Label
@onready var title_label: Label
@onready var reward_label: Label

# Text to display
var _goal_text: String = "No Goal"
var _points_goal: int = 0
var _current_progress: int = 0
var _reward_text: String = ""

# Animation properties
var _base_position: Vector2
var _hover_offset: Vector2 = Vector2(0, -5)
var _current_tween: Tween

# Hover tooltip
var _hover_timer: Timer = null
var _tooltip: PanelContainer = null
var _tooltip_label: RichTextLabel = null
const HOVER_DELAY: float = 0.3  # Match other tooltips


func _ready() -> void:
	_create_spine_structure()
	_create_hover_tooltip()
	_create_hover_timer()
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
	if _hover_timer:
		_hover_timer.stop()
	_hide_tooltip()


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
	goal_label.position = Vector2(-50, 35)
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
	points_label.position = Vector2(-50, -10)
	points_label.size = Vector2(100, 30)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	points_label.add_theme_font_size_override("font_size", 18)
	points_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	points_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(points_label)

	# Create title label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.position = Vector2(-40, -15)
	title_label.size = Vector2(80, 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1))
	title_label.text = "CHALLENGE"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)
	
	# Create reward label (shows reward at top of post-it, title-style)
	reward_label = Label.new()
	reward_label.name = "RewardLabel"
	reward_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	reward_label.position = Vector2(-50, 60)
	reward_label.size = Vector2(100, 25)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_size_override("font_size", 16)
	reward_label.add_theme_color_override("font_color", Color(0.1, 0.5, 0.1, 1))  # Green for money
	reward_label.text = ""
	reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reward_label)

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


## _create_hover_tooltip()
##
## Creates the tooltip panel that shows on hover delay.
func _create_hover_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.name = "ChallengeTooltip"
	_tooltip.visible = false
	_tooltip.z_index = 100
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Style the tooltip
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_color = Color(0.9, 0.8, 0.3, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 4
	_tooltip.add_theme_stylebox_override("panel", style)
	
	# Create RichTextLabel for content
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.name = "TooltipLabel"
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.custom_minimum_size = Vector2(180, 80)
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Style the label
	var font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if font:
		_tooltip_label.add_theme_font_override("normal_font", font)
	_tooltip_label.add_theme_font_size_override("normal_font_size", 12)
	_tooltip_label.add_theme_color_override("default_color", Color.WHITE)
	
	_tooltip.add_child(_tooltip_label)


## _create_hover_timer()
##
## Creates the timer used for hover delay before showing tooltip.
func _create_hover_timer() -> void:
	_hover_timer = Timer.new()
	_hover_timer.name = "HoverTimer"
	_hover_timer.one_shot = true
	_hover_timer.wait_time = HOVER_DELAY
	_hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(_hover_timer)


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


## set_current_progress(progress)
##
## Updates the current progress for tooltip display.
func set_current_progress(progress: int) -> void:
	_current_progress = progress


## set_reward_text(text)
##
## Sets the reward text for tooltip display.
func set_reward_text(text: String) -> void:
	_reward_text = text


## set_reward_label(text)
##
## Updates the reward label displayed at the bottom of the post-it note.
func set_reward_label(text: String) -> void:
	_reward_text = text
	if reward_label:
		reward_label.text = text


func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	position = pos


## _show_tooltip()
##
## Displays the tooltip panel with challenge details.
## Called after hover timer expires.
func _show_tooltip() -> void:
	if not _tooltip or not is_instance_valid(_tooltip):
		return
	
	# Build tooltip content
	# _goal_text is the challenge display name
	var content := "[b]%s[/b]\n" % _goal_text
	content += "[color=#888888]Target:[/color] %d pts\n" % _points_goal
	content += "[color=#888888]Progress:[/color] %d / %d pts\n" % [_current_progress, _points_goal]
	if _reward_text != "":
		content += "[color=#ffcc00]Reward:[/color] %s" % _reward_text
	
	_tooltip_label.text = content
	_position_tooltip()
	_tooltip.visible = true


## _hide_tooltip()
##
## Hides the tooltip panel.
func _hide_tooltip() -> void:
	if _tooltip and is_instance_valid(_tooltip):
		_tooltip.visible = false


## _position_tooltip()
##
## Positions the tooltip panel near the spine, adjusting for screen edges.
func _position_tooltip() -> void:
	if not _tooltip:
		return
	
	# Position tooltip to the right of the spine
	var tooltip_offset := Vector2(size.x + 10, -20)
	var tooltip_pos := global_position + tooltip_offset
	
	# Adjust if it would go off screen
	var viewport_size := get_viewport_rect().size
	if tooltip_pos.x + _tooltip.size.x > viewport_size.x - 20:
		# Position to the left instead
		tooltip_pos.x = global_position.x - _tooltip.size.x - 10
	
	if tooltip_pos.y + _tooltip.size.y > viewport_size.y - 20:
		tooltip_pos.y = viewport_size.y - _tooltip.size.y - 20
	
	if tooltip_pos.y < 20:
		tooltip_pos.y = 20
	
	_tooltip.global_position = tooltip_pos


## _on_hover_timer_timeout()
##
## Called when the hover delay timer expires.
## Shows the tooltip panel.
func _on_hover_timer_timeout() -> void:
	_show_tooltip()


func _on_mouse_entered() -> void:
	emit_signal("spine_hovered", global_position)
	
	if not is_inside_tree() or not is_instance_valid(self):
		return
	
	if not get_parent():
		return
	
	# Start hover timer for tooltip
	if _hover_timer and is_instance_valid(_hover_timer):
		_hover_timer.start()
	
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
	
	# Stop hover timer and hide tooltip
	if _hover_timer and is_instance_valid(_hover_timer):
		_hover_timer.stop()
	_hide_tooltip()
	
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween().set_parallel()
	_current_tween.tween_property(self, "position", _base_position, 0.1)
	_current_tween.tween_property(self, "scale", Vector2.ONE, 0.1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("spine_clicked")
