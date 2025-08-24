extends TextureRect
class_name ModIcon

@export var data: ModData
@export var tooltip_offset := Vector2(-50, -50)

@onready var tooltip: Label = $TooltipBg/Tooltip
@onready var tooltip_bg: PanelContainer = $TooltipBg

func _ready() -> void:
	if not tooltip or not tooltip_bg:
		push_error("[ModIcon] Tooltip nodes not found")
		return
		
	if data:
		#texture = data.icon
		tooltip.text = data.display_name
		tooltip_bg.visible = false
	else:
		push_error("[ModIcon] No ModData assigned")
		return
		
	# Set up mouse interactions
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if tooltip_bg and data:
		print("[ModIcon] Mouse entered for", data.display_name)
		tooltip_bg.visible = true
		tooltip_bg.global_position = get_global_mouse_position() + tooltip_offset

func _on_mouse_exited() -> void:
	if tooltip_bg:
		tooltip_bg.visible = false
