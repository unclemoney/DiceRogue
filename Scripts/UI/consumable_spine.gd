# ConsumableSpine.gd
extends Control
class_name ConsumableSpine

signal spine_clicked(consumable_id: String)
signal spine_hovered(consumable_id: String, mouse_pos: Vector2)
signal spine_unhovered(consumable_id: String)

@export var data: ConsumableData
@export var spine_texture: Texture2D

@onready var spine_rect: TextureRect
@onready var title_label: Label
@onready var count_label: Label

# Count tracking
var _count: int = 1

# Animation properties
var _base_position: Vector2 = Vector2.ZERO
var _hover_offset: Vector2 = Vector2(0, -3)
var _current_tween: Tween
var _is_initialized: bool = false

func _ready() -> void:
	_create_spine_structure()
	_apply_data_to_ui()
	
	# Set spine size for coupon (horizontal layout) - use call_deferred to avoid anchor warning
	call_deferred("_set_spine_size")
	call_deferred("_initialize_base_position")

	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _initialize_base_position() -> void:
	# Initialize base position from current position if not already set by set_base_position
	if not _is_initialized:
		if _base_position == Vector2.ZERO:
			_base_position = position
		_is_initialized = true

func _exit_tree() -> void:
	# Clean up any active tweens to prevent warnings
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null

func _set_spine_size() -> void:
	# Larger size for COUPON_NOTE texture (corkboard style)
	custom_minimum_size = Vector2(80, 100)
	set_deferred("size", Vector2(80, 100))
	# Ensure we can receive mouse clicks
	mouse_filter = Control.MOUSE_FILTER_STOP

func _create_spine_structure() -> void:
	# Create spine texture display
	spine_rect = TextureRect.new()
	spine_rect.name = "SpineRect"
	spine_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	spine_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spine_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spine_rect)
	
	# Create title label (visible on spine)
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 8)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)
	
	# Create count label (shows multiple instances)
	count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	count_label.position = Vector2(-15, 5)  # Top right corner
	count_label.size = Vector2(20, 20)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color.YELLOW)
	count_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.visible = false  # Hidden by default (only shown when count > 1)
	add_child(count_label)



func _apply_data_to_ui() -> void:
	if not data:
		return
	
	# Set spine texture (COUPON_NOTE for corkboard style)
	if not spine_texture:
		spine_texture = load("res://Resources/Art/Background/COUPON_NOTE.png")
		if not spine_texture:
			push_error("[ConsumableSpine] Failed to load COUPON_NOTE texture")
			# Use a fallback colored rectangle
			spine_rect.texture = null
	
	if spine_rect and spine_texture:
		spine_rect.texture = spine_texture
	
	# Set title text (abbreviated for spine)
	if title_label and data:
		var abbreviated_name: String = _get_abbreviated_name(data.display_name)
		title_label.text = abbreviated_name

func _get_abbreviated_name(full_name: String) -> String:
	# Create abbreviated name that fits on spine
	var words: PackedStringArray = full_name.split(" ")
	if words.size() == 1:
		# Single word - take first few characters
		return full_name.substr(0, min(8, full_name.length()))
	else:
		# Multiple words - take first letter of each word
		var abbreviation: String = ""
		for word in words:
			if word.length() > 0:
				abbreviation += word[0].to_upper()
		return abbreviation

func set_data(new_data: ConsumableData) -> void:
	data = new_data
	if is_node_ready():
		_apply_data_to_ui()

func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	position = pos
	_is_initialized = true  # Mark as initialized when base position is explicitly set

func _on_mouse_entered() -> void:
	if data:
		emit_signal("spine_hovered", data.id, global_position)
	
	# Safety check - don't animate until properly initialized
	if not _is_initialized:
		return
	
	# Safety check - don't create tweens on invalid nodes
	if not is_inside_tree() or not is_instance_valid(self):
		return
	
	# Additional check - don't animate if we don't have a proper parent
	if not get_parent():
		return
	
	# Animate hover effect
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween().set_parallel()
	_current_tween.tween_property(self, "position", _base_position + _hover_offset, 0.1)
	_current_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func _on_mouse_exited() -> void:
	if data:
		emit_signal("spine_unhovered", data.id)
	
	# Safety check - don't animate until properly initialized
	if not _is_initialized:
		return
	
	# Safety check - don't create tweens on invalid nodes
	if not is_inside_tree() or not is_instance_valid(self):
		return
	
	# Additional check - don't animate if we don't have a proper parent
	if not get_parent():
		return
	
	# Animate back to base position
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween().set_parallel()
	_current_tween.tween_property(self, "position", _base_position, 0.1)
	_current_tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if data:
			emit_signal("spine_clicked", data.id)

## set_count(count)
##
## Updates the count display for this consumable spine. Shows a count label when count > 1.
func set_count(count: int) -> void:
	_count = count
	if count_label:
		if count > 1:
			count_label.text = str(count)
			count_label.visible = true
		else:
			count_label.visible = false
