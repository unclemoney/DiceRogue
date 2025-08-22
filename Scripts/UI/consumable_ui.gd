extends Control
class_name ConsumableUI

@export var consumable_icon_scene: PackedScene

func _ready() -> void:
	if not consumable_icon_scene:
		push_error("ConsumableUI: consumable_icon_scene not set in inspector!")

func add_consumable(data: ConsumableData) -> ConsumableIcon:
	if not consumable_icon_scene:
		push_error("ConsumableUI: consumable_icon_scene not set!")
		print("  Scene path expected: res://Scenes/UI/ConsumableIcon.tscn")
		return null

	print("Adding consumable to UI:", data.id)
	print("  Using scene:", consumable_icon_scene.resource_path)
	var icon = consumable_icon_scene.instantiate() as ConsumableIcon
	if not icon:
		push_error("ConsumableUI: Failed to instantiate ConsumableIcon")
		return null

	add_child(icon)
	icon.set_data(data)

	# Set default position if needed
	icon.position = Vector2(40, 40)  # Adjust these values
	# Or use anchors/margins if using Control nodes
	#icon.anchor_left = 0
	#icon.anchor_top = 0
	#icon.offset_left = 30
	#icon.offset_top = 30
	return icon