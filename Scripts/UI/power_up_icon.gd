extends TextureButton
class_name PowerUpIcon

@export var data: PowerUpData
@export var glow_intensity: float = 0.1
@onready var hover_label: Label = $LabelBg/HoverLabel
@onready var label_bg: PanelContainer = $LabelBg
@onready var sell_button: Button = $SellButton
var _shader_material: ShaderMaterial
var _is_selected: bool = false
var _is_hovering := false
var _current_tween: Tween
var _sell_button_visible := false

signal power_up_selected(power_up_id: String)
signal power_up_deselected(power_up_id: String)
signal power_up_sell_requested(power_up_id: String)

func _ready() -> void:
	print("[PowerUpIcon] Initializing...")
	
	# Fix: Setup correct size and display properties
	custom_minimum_size = Vector2(64, 64)
	#expand = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	# Fix: Make sure icon is properly visible
	modulate.a = 1.0
	visible = true
	
	# Fix: Size flags for proper positioning in container
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Handle missing nodes
	if not has_node("LabelBg"):
		push_error("Missing LabelBg")
		# Create a minimal version if missing
		var panel = PanelContainer.new()
		panel.name = "LabelBg"
		panel.position = Vector2(0, 64)  # Position below the icon
		panel.size = Vector2(64, 20)
		var label = Label.new()
		label.name = "HoverLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(label)
		add_child(panel)
	
	if not has_node("SellButton"):
		push_error("Missing SellButton")
		# Create a minimal button if missing
		var button = Button.new()
		button.name = "SellButton"
		button.text = "Sell"
		button.position = Vector2(64, 0)  # Position to the right of the icon
		button.size = Vector2(40, 20)
		add_child(button)

	label_bg = $LabelBg
	hover_label = $LabelBg/HoverLabel
	sell_button = $SellButton

	label_bg.visible = false
	sell_button.visible = false
	sell_button.text = "Sell"
	
	# Connect sell button
	sell_button.pressed.connect(_on_sell_button_pressed)

	if not data:
		push_warning("data was null — assigning fallback icon")
		texture_normal = preload("res://icon.svg")
	else:
		_apply_data()

	# Force the proper setting of mouse filter
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Use the more explicit connection syntax
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)
	
	# Setup shader material
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = preload("res://Scripts/Shaders/power_up_ui_highlight.gdshader")
	_shader_material.set_shader_parameter("glow_intensity", glow_intensity) # Start active
	material = _shader_material
	
	_reset_visual_state()
	
	# Start as selected (activated) by default
	_is_selected = true
	
	# Ensure proper sizing and margins
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Debug info
	print("[PowerUpIcon] Initialization complete")
	print("[PowerUpIcon] Icon visible:", visible)
	print("[PowerUpIcon] Icon size:", size)
	print("[PowerUpIcon] Icon custom minimum size:", custom_minimum_size)
	print("[PowerUpIcon] Icon global position:", global_position)

func set_data(new_data: PowerUpData) -> void:
	data = new_data
	if data.icon != null:
		texture_normal = data.icon
		hover_label.text = data.display_name
	else:
		push_warning("PowerUpIcon: setdata icon is null, using fallback")
		texture_normal = preload("res://icon.svg")

func _apply_data() -> void:
	texture_normal = data.icon
	hover_label.text = data.display_name
	print("[PowerUpIcon] Applied data:", data.id, data.display_name)

func _on_mouse_entered() -> void:
	print("[PowerUpIcon] Mouse entered:", data.id)
	print("Hover label text:", hover_label.text)
	_is_hovering = true
	
	# Show label for all hover cases
	# Cancel any existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	# 1. Show label immediately
	label_bg.visible = true
	label_bg.modulate.a = 0.0
	label_bg.scale = Vector2(0.8, 0.8)

	# 2. Create new tween
	_current_tween = get_tree().create_tween()

	# 3. Fade in (faster)
	_current_tween.tween_property(
		label_bg, "modulate:a", 1.0, 0.1
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 4. Bounce scale (faster)
	_current_tween.tween_property(
		label_bg, "scale", Vector2(1.1, 1.1), 0.1
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 5. Settle scale (faster)
	_current_tween.tween_property(
		label_bg, "scale", Vector2.ONE, 0.05
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_mouse_exited() -> void:
	print("[PowerUpIcon] Mouse exited:", data.id)
	_is_hovering = false
	
	# Cancel any existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = get_tree().create_tween()
	
	# Faster fade out
	_current_tween.tween_property(
		label_bg, "modulate:a", 0.0, 0.1
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# Add visibility change handler
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_is_hovering = false
				_reset_visual_state()
				
func _on_pressed() -> void:
	# Toggle sell button visibility
	_sell_button_visible = !_sell_button_visible
	sell_button.visible = _sell_button_visible

func _on_sell_button_pressed() -> void:
	# Emit signal that this power-up should be sold
	print("[PowerUpIcon] Sell requested for:", data.id)
	emit_signal("power_up_sell_requested", data.id)
	# Hide the sell button
	_sell_button_visible = false
	sell_button.visible = false

func _reset_visual_state() -> void:
	# Cancel any running tweens
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	# Reset shader - always activated
	if _shader_material:
		_shader_material.set_shader_parameter("glow_intensity", glow_intensity)
	
	# Reset label
	if label_bg:
		label_bg.visible = _is_hovering
		label_bg.modulate.a = 1.0 if _is_hovering else 0.0
		label_bg.scale = Vector2.ONE
	
	# Reset sell button
	if sell_button:
		sell_button.visible = _sell_button_visible
