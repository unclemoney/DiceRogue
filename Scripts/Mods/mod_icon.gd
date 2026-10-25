extends TextureRect
class_name ModIcon

const DISABLED_MOD_SHADER := preload("res://Scripts/Shaders/disabled_powerup_overlay.gdshader")
const TOOLTIP_SCENE := preload("res://Scenes/UI/tooltip.tscn")
const GLASS_BUTTON_FACTORY := preload("res://Scripts/UI/glass_button_factory.gd")

signal mod_sell_requested(mod_id: String)

@export var data: ModData
@export var tooltip_offset := Vector2(-50, -80)
@export var icon_size := Vector2(50, 60)  # Add size control (expanded for sell button)

@onready var modicon: Sprite2D = $Sprite2D
@onready var sell_button

var _tooltip: Tooltip

var _sell_button_visible := false
var _visual_disabled := false
var _default_modicon_material: Material = null
var _disabled_modicon_material: ShaderMaterial = null

func _ready() -> void:
	if not modicon:
		push_error("[ModIcon] Required nodes not found")
		return

	_default_modicon_material = modicon.material
	
	# Create the current-standard sell button at scene root to bypass UI blocking.
	sell_button = GLASS_BUTTON_FACTORY.create_button(
		"SELL",
		Vector2(44, 20),
		GLASS_BUTTON_FACTORY.palette_kiosk_sell(),
		8
	)
	sell_button.set_uniform_padding(2, 2)
	sell_button.name = "SellButton_" + str(get_instance_id())
	sell_button.visible = false
	sell_button.z_index = RenderLayers.Z_MOD_SELL
	sell_button.size = Vector2(44, 20)
	sell_button.mouse_filter = Control.MOUSE_FILTER_STOP
	sell_button.clip_contents = false
	
	# Connect the signal with debugging
	if not sell_button.pressed.is_connected(_on_sell_button_pressed):
		sell_button.pressed.connect(_on_sell_button_pressed)
		print("[ModIcon] Sell button signal connected")
	
	# Add additional debugging for mouse events on the button
	sell_button.gui_input.connect(_on_sell_button_input)
	sell_button.mouse_entered.connect(_on_sell_button_mouse_entered)
	sell_button.mouse_exited.connect(_on_sell_button_mouse_exited)
	
	# Add to scene root instead of ModIcon to bypass UI layer blocking
	var scene_root = get_tree().current_scene
	scene_root.add_child(sell_button)
	print("[ModIcon] Sell button created and added to scene root:", scene_root.name)
	print("[ModIcon] Button mouse_filter:", sell_button.mouse_filter)
	print("[ModIcon] Button z_index:", sell_button.z_index)
		
	if data:
		# Set up the Sprite2D
		modicon.texture = data.icon
		modicon.scale = Vector2(28, 28) / data.icon.get_size()  # Keep icon at 28x28
		modicon.position = icon_size * 0.5
		
		# Clear the TextureRect texture since we're using Sprite2D
		texture = null
		
		# Standard tooltip, shown at the fixed offset on hover
		_tooltip = TOOLTIP_SCENE.instantiate()
		_tooltip.name = "Tooltip"
		add_child(_tooltip)
		_tooltip.setup({"title": data.display_name})
		
		# Set control size to match icon
		custom_minimum_size = icon_size
		size = icon_size
	else:
		push_error("[ModIcon] No ModData assigned")
		return
	
	# PASS so the icon's tooltip/click handlers still work while unhandled
	# clicks propagate through to the die's Area2D physics picking
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_disabled_visual(_visual_disabled)
	
	print("[ModIcon] ModIcon mouse_filter set to PASS")
	print("[ModIcon] ModIcon z_index:", z_index)
	
	print("[ModIcon] Setup complete for mod: ", data.id if data else "no data")

## set_disabled_visual(disabled)
##
## Applies or removes the disabled overlay on the visible mod sprite.
func set_disabled_visual(disabled: bool) -> void:
	_visual_disabled = disabled
	if not modicon or not is_instance_valid(modicon):
		return

	if disabled:
		if _disabled_modicon_material == null:
			_disabled_modicon_material = ShaderMaterial.new()
			_disabled_modicon_material.shader = DISABLED_MOD_SHADER
			_disabled_modicon_material.set_shader_parameter("disabled", true)
		modicon.material = _disabled_modicon_material
		return

	modicon.material = _default_modicon_material

func _on_mouse_entered() -> void:
	if _tooltip and data:
		_tooltip.show_at(get_global_mouse_position() + tooltip_offset, get_global_rect())

func _on_mouse_exited() -> void:
	if _tooltip:
		_tooltip.hide()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("[ModIcon] Click detected on mod icon:", data.id if data else "no data")
		# Toggle sell button visibility
		_sell_button_visible = !_sell_button_visible
		if sell_button:
			sell_button.visible = _sell_button_visible
			print("[ModIcon] Sell button visibility set to:", _sell_button_visible)
			if _sell_button_visible:
				# Position button above the mod icon using global coordinates
				var my_global_rect = get_global_rect()
				sell_button.position = Vector2(my_global_rect.position.x + 3, my_global_rect.position.y - 10)
				print("[ModIcon] Button positioned at global:", sell_button.position)
				print("[ModIcon] ModIcon global rect:", my_global_rect)
				print("[ModIcon] Button global rect:", sell_button.get_global_rect())
				_debug_ui_layers_blocking_button()

func _debug_ui_layers_blocking_button() -> void:
	print("[ModIcon] ===== DEBUGGING UI LAYERS =====")
	var root = get_tree().current_scene
	_check_node_for_blocking(root, 0)
	print("[ModIcon] ===== END UI LAYER DEBUG =====")

func _check_node_for_blocking(node: Node, depth: int) -> void:
	var indent = "  ".repeat(depth)
	if node is Control:
		var ctrl = node as Control
		if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP and ctrl.visible:
			var global_rect = ctrl.get_global_rect()
			var button_rect = sell_button.get_global_rect()
			var overlaps = global_rect.intersects(button_rect)
			print(indent, "[BLOCKING?] ", ctrl.name, " z:", ctrl.z_index, " rect:", global_rect, " overlaps:", overlaps)
		elif ctrl.mouse_filter == Control.MOUSE_FILTER_PASS and ctrl.z_index > 5:
			print(indent, "[PASSTHROUGH] ", ctrl.name, " z:", ctrl.z_index)
	
	for child in node.get_children():
		_check_node_for_blocking(child, depth + 1)

func _on_sell_button_pressed() -> void:
	print("[ModIcon] ===== SELL BUTTON PRESSED =====")
	print("[ModIcon] Sell button pressed for mod:", data.id if data else "unknown")
	print("[ModIcon] Button exists:", sell_button != null)
	if sell_button:
		print("[ModIcon] Button visible:", sell_button.visible)
	else:
		print("[ModIcon] Button visible: no button")
	
	if data:
		print("[ModIcon] Emitting mod_sell_requested signal for:", data.id)
		emit_signal("mod_sell_requested", data.id)
	else:
		print("[ModIcon] No data available to sell")
	
	# Hide the sell button after selling
	_sell_button_visible = false
	if sell_button:
		sell_button.visible = false
		print("[ModIcon] Sell button hidden after sale")
	print("[ModIcon] ===== SELL BUTTON PRESS COMPLETE =====")

func _on_sell_button_input(event: InputEvent) -> void:
	print("[ModIcon] Sell button received input event:", event)
	if event is InputEventMouseButton:
		print("[ModIcon] Mouse button event - button:", event.button_index, "pressed:", event.pressed)

func _on_sell_button_mouse_entered() -> void:
	print("[ModIcon] Mouse ENTERED sell button")

func _on_sell_button_mouse_exited() -> void:
	print("[ModIcon] Mouse EXITED sell button")

func _exit_tree() -> void:
	# Clean up the sell button when ModIcon is removed
	if sell_button and is_instance_valid(sell_button):
		print("[ModIcon] Cleaning up sell button on exit")
		sell_button.queue_free()

## check_outside_click(event_position)
##
## Checks if a click occurred outside both the icon and sell button.
## Returns true if the sell button should be hidden.
func check_outside_click(event_position: Vector2) -> bool:
	if not _sell_button_visible:
		return false
	
	# Get global rectangles for both icon and button
	var icon_rect = get_global_rect()
	var button_rect = Rect2()
	
	if sell_button and sell_button.visible:
		button_rect = sell_button.get_global_rect()
	
	if not icon_rect.has_point(event_position) and not button_rect.has_point(event_position):
		# Click outside both icon and button, hide the sell button
		_sell_button_visible = false
		if sell_button:
			sell_button.visible = false
		return true
	
	return false
