extends TextureRect
class_name ModIcon

@export var data: ModData
@export var tooltip_offset := Vector2(-50, -50)
@export var icon_size := Vector2(32, 32)  # Add size control

@onready var tooltip: Label = $TooltipBg/Tooltip
@onready var tooltip_bg: PanelContainer = $TooltipBg
@onready var modicon: Sprite2D = $Sprite2D

func _ready() -> void:
	if not tooltip or not tooltip_bg or not modicon:
		push_error("[ModIcon] Required nodes not found")
		return
		
	if data:
		# Set up the Sprite2D
		modicon.texture = data.icon
		modicon.scale = icon_size / data.icon.get_size()
		modicon.position = icon_size / 2  # Center in parent
		
		# Clear the TextureRect texture since we're using Sprite2D
		texture = null
		
		# Set up tooltip
		tooltip.text = data.display_name
		tooltip_bg.visible = false
		
		# Set control size to match icon
		custom_minimum_size = icon_size
		size = icon_size
	else:
		push_error("[ModIcon] No ModData assigned")
		return
		
	# Set up mouse interactions
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if tooltip_bg and data:
		#print("[ModIcon] Mouse entered for", data.display_name)
		tooltip_bg.visible = true
		tooltip_bg.global_position = get_global_mouse_position() + tooltip_offset

func _on_mouse_exited() -> void:
	if tooltip_bg:
		tooltip_bg.visible = false
