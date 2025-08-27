extends Resource
class_name DiceData

@export var id: String = "d6"
@export var display_name: String = "D6"
@export var sides: int = 6
@export var textures: Array[Texture2D]

func _init() -> void:
	if textures.is_empty():
		# Load default d6 textures
		for i in range(1, 7):
			var texture = load("res://Resources/Art/Dice/dieWhite_border%d.png" % i)
			if texture:
				textures.append(texture)