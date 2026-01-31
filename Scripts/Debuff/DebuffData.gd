extends Resource
class_name DebuffData

## DebuffData
##
## Resource that defines a debuff's metadata and scene reference.
## Used by DebuffManager for spawning and by the automatic debuff
## selection system based on difficulty rating.

@export var id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var scene: PackedScene

## Difficulty rating (1-5) for automatic selection based on round config.
## 1 = Easy (early game), 5 = Brutal (late game only)
@export_range(1, 5) var difficulty_rating: int = 1
