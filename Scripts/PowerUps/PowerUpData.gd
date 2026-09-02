extends Resource
class_name PowerUpData

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

## Visual halo states for active synergies (see SynergyManager / synergy_halo.gdshader).
enum SynergyHaloMode {
	NONE,
	SET,
	RAINBOW
}

enum Rating {
	G,
	PG,
	PG_13,
	R,
	NC_17
}

@export var id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var scene: PackedScene  # your logic scene, e.g. ExtraDicePowerUp.tscn
@export var price: int = 100
@export var rarity: String = "common"  # common, uncommon, rare, epic, legendary
@export var rating: String = "G"  # G, PG, PG-13, R, NC-17

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

static func get_rating_display_char(rating_string: String) -> String:
	match rating_string.to_upper():
		"G": return "G"
		"PG": return "PG"
		"PG-13": return "PG-13"
		"R": return "R"
		"NC-17": return "NC-17"
		_: return "G"

static func is_rating_restricted(rating_string: String) -> bool:
	## Returns true if the rating is R or NC-17 (restricted content)
	var upper = rating_string.to_upper()
	return upper == "R" or upper == "NC-17"

static func is_rating_nc17(rating_string: String) -> bool:
	## Returns true if the rating is NC-17
	return rating_string.to_upper() == "NC-17"


static func get_rating_color(rating_string: String) -> Color:
	## Returns the UI display color for a PowerUp rating.
	## Used for rating labels and synergy halos. Unknown ratings default to white.
	match rating_string.to_upper():
		"G": return Color(0.65098, 0.941176, 0.745098, 1.0)
		"PG": return Color(1.0, 0.854902, 0.631373, 1.0)
		"PG-13": return Color(1.0, 0.662745, 0.34902, 1.0)
		"R": return Color(1.0, 0.470588, 0.576471, 1.0)
		"NC-17": return Color(0.886275, 0.560784, 0.72549, 1.0)
		_: return Color.WHITE


static func get_rating_progress_bonus(rating_string: String) -> int:
	## Returns the chore-progress bonus associated with a PowerUp rating.
	## Used by ChoresManager to scale goof-off meter progress per roll.
	## G = 0, PG = 0, PG-13 = 1, R = 2, NC-17 = 3.
	## Unknown ratings default to 0 (G).
	match rating_string.to_upper():
		"G": return 0
		"PG": return 0
		"PG-13": return 1
		"R": return 2
		"NC-17": return 3
		_: return 0


static func rating_rank(rating_string: String) -> int:
	## Returns the ordinal rank of a rating for tier comparisons.
	## G = 0, PG = 1, PG-13 = 2, R = 3, NC-17 = 4.
	## Used by the Rep system to gate kiosk inventory by POG tier
	## (ProgressManager.get_rep_tier()). Unknown ratings default to 0 (G).
	match rating_string.to_upper():
		"G": return 0
		"PG": return 1
		"PG-13": return 2
		"R": return 3
		"NC-17": return 4
		_: return 0
