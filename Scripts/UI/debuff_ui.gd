extends Control
class_name DebuffUI

@export var debuff_icon_scene: PackedScene

func _ready() -> void:
	if not debuff_icon_scene:
		push_error("DebuffUI: debuff_icon_scene not set in inspector!")


func add_debuff(data: DebuffData, debuff_instance: Debuff = null) -> DebuffIcon:
	if not debuff_icon_scene:
		push_error("DebuffUI: debuff_icon_scene not set!")
		print("  Scene path expected: res://Scenes/UI/DebuffIcon.tscn")
		return null

	print("Adding debuff to UI:", data.id)
	var icon = debuff_icon_scene.instantiate() as DebuffIcon
	if not icon:
		push_error("DebuffUI: Failed to instantiate DebuffIcon")
		return null

	add_child(icon)
	icon.set_data(data)
	
	# Set default position if needed
	icon.position = Vector2(40, 40)
	return icon