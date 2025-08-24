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
	
	if debuff_instance:
		debuff_instance.debuff_started.connect(
			func(): icon.set_active(true))
		debuff_instance.debuff_ended.connect(
			func(): icon.set_active(false))

	# Set default position if needed
	icon.position = Vector2(40, 40)
	return icon

func remove_debuff(id: String) -> void:
	print("Removing debuff icon for:", id)
	for child in get_children():
		if child is DebuffIcon and child.data and child.data.id == id:
			print("Found and removing debuff icon:", id)
			child.queue_free()
			return
	print("No debuff icon found for:", id)
