extends Resource
class_name PowerUpData

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export var id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var scene: PackedScene  # your logic scene, e.g. ExtraDicePowerUp.tscn
@export var price: int = 100
@export var rarity: String = "common"  # common, uncommon, rare, epic, legendary

static func get_rarity_display_char(rarity_string: String) -> String:
	match rarity_string.to_lower():
		"common": return "C"
		"uncommon": return "U"
		"rare": return "R"
		"epic": return "E"
		"legendary": return "L"
		_: return "C"

static func get_rarity_weight(rarity_string: String) -> int:
	match rarity_string.to_lower():
		"common": return 60
		"uncommon": return 25
		"rare": return 10
		"epic": return 4
		"legendary": return 1
		_: return 60
