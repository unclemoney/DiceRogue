extends Control
class_name KioskTileTest

## KioskTileTest.gd
## Standalone test scene for the mall-core KioskTile and PowerUpIcon wrapper.
## Creates several sample power-ups, instantiates PowerUpIcon nodes,
## and lays them out in a simple fan pattern to verify rendering,
## hover, selection, and sell signals.

const PowerUpIconScene = preload("res://Scenes/PowerUp/power_up_icon.tscn")
const ExtraRollsData = preload("res://Scripts/PowerUps/ExtraRolls.tres")

var _icons: Array[PowerUpIcon] = []
var _log_label: Label

func _ready() -> void:
	print("[KioskTileTest] Starting...")
	_create_log_label()
	_create_sample_icons()
	_log_label.text = "Hover tiles / click SELL / click tile to select.\nCheck Output for signals."

func _create_log_label() -> void:
	_log_label = Label.new()
	_log_label.name = "LogLabel"
	_log_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_log_label.add_theme_font_size_override("font_size", 14)
	_log_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_log_label)

func _create_sample_icons() -> void:
	var ratings := ["G", "PG", "PG-13", "R", "NC-17"]
	var rarities := ["common", "uncommon", "rare", "epic", "legendary"]
	var count := ratings.size()

	# Tile root is 200x300 but the chrome bezel draws 12px outside, so the
	# visual footprint is 224x324 and we space accordingly.
	var card_size := Vector2(224, 324)
	var spacing := 136.0
	var total_width := (count - 1) * spacing + card_size.x
	var start_x := (size.x - total_width) * 0.5
	var pos_y := size.y * 0.5 - card_size.y * 0.5

	for i in range(count):
		var icon: PowerUpIcon = PowerUpIconScene.instantiate()
		if not icon:
			push_error("[KioskTileTest] Failed to instantiate PowerUpIcon")
			continue

		var data: PowerUpData = ExtraRollsData.duplicate(true)
		data.id = "test_%s" % ratings[i]
		match i:
			0:
				data.display_name = "Short"
			1:
				data.display_name = "Medium Length"
			2:
				data.display_name = "A Much Longer Power Name"
			3:
				data.display_name = "Extremely Long Powerup Name That Should Truncate"
			4:
				data.display_name = "MaxedOutPowerupNameLengthTestForTruncationBehavior"
		data.rating = ratings[i]
		data.rarity = rarities[i]

		icon.set_data(data)
		icon.position = Vector2(start_x + i * spacing, pos_y)
		icon.power_up_selected.connect(_on_power_up_selected)
		icon.power_up_deselected.connect(_on_power_up_deselected)
		icon.power_up_sell_requested.connect(_on_power_up_sell_requested)

		add_child(icon)
		_icons.append(icon)

func _on_power_up_selected(id: String) -> void:
	print("[KioskTileTest] Selected: ", id)
	_log_label.text = "Selected: %s" % id

func _on_power_up_deselected(id: String) -> void:
	print("[KioskTileTest] Deselected: ", id)
	_log_label.text = "Deselected: %s" % id

func _on_power_up_sell_requested(id: String) -> void:
	print("[KioskTileTest] Sell requested: ", id)
	_log_label.text = "Sell requested: %s" % id
