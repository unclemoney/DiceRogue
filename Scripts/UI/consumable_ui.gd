extends Control
class_name ConsumableUI

@export var consumable_icon_scene: PackedScene

func _ready() -> void:
	if not consumable_icon_scene:
		push_error("ConsumableUI: consumable_icon_scene not set in inspector!")

func add_consumable(data: ConsumableData, consumable_instance: Consumable = null) -> ConsumableIcon:
	if not consumable_icon_scene:
		push_error("ConsumableUI: consumable_icon_scene not set!")
		print("  Scene path expected: res://Scenes/UI/ConsumableIcon.tscn")
		return null

	print("Adding consumable to UI:", data.id)
	var icon = consumable_icon_scene.instantiate() as ConsumableIcon
	if not icon:
		push_error("ConsumableUI: Failed to instantiate ConsumableIcon")
		return null

	add_child(icon)
	icon.set_data(data)
	
	# Connect signals if this is a score reroll consumable
	if data.id == "score_reroll" and consumable_instance:
		var reroll_consumable = consumable_instance as ScoreRerollConsumable
		if reroll_consumable:
			print("ConsumableUI: Connecting ScoreRerollConsumable signals")
			reroll_consumable.reroll_activated.connect(icon._on_reroll_activated)
			reroll_consumable.reroll_completed.connect(icon._on_reroll_completed)
			reroll_consumable.reroll_denied.connect(icon._on_reroll_denied)
	
	# Set default position if needed
	icon.position = Vector2(40, 40)
	return icon

func get_consumable_icon(id: String) -> ConsumableIcon:
	for child in get_children():
		if child is ConsumableIcon and child.data and child.data.id == id:
			return child
	return null

func remove_consumable(id: String) -> void:
	print("Removing consumable icon for:", id)
	for child in get_children():
		if child is ConsumableIcon and child.data and child.data.id == id:
			print("Found and removing consumable icon:", id)
			child.queue_free()
			return
	print("No consumable icon found for:", id)
