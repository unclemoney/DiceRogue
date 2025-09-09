extends Resource
class_name ChallengeData

@export var id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var scene: PackedScene
@export var debuff_ids: Array[String] = []
@export var target_score: int = 0
@export var reward_money: int = 0
@export var dice_type: String = "d6"