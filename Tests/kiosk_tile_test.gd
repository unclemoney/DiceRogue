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
var _profile_mode: int = 0

func _ready() -> void:
	print("[KioskTileTest] Starting...")
	_create_log_label()
	_create_sample_icons()
	_apply_badge_profile_to_all(_profile_mode)
	_log_label.text = "Hover tiles and badges. Click SELL or tile to verify input ownership.\nPress 1 default foil, 2 matching-set foil, 3 rainbow foil."


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		match key_event.keycode:
			KEY_1:
				_set_badge_profile_mode(0)
				get_viewport().set_input_as_handled()
			KEY_2:
				_set_badge_profile_mode(1)
				get_viewport().set_input_as_handled()
			KEY_3:
				_set_badge_profile_mode(2)
				get_viewport().set_input_as_handled()

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
	var spacing := 236.0
	var _total_width := (count - 1) * spacing + card_size.x
	var start_x := 0 #(size.x - total_width) * 0.5
	var pos_y := size.y * 0.25 - card_size.y * 0.5

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
				data.description = "One-line control sample for spacing."
			1:
				data.display_name = "Medium Length"
				data.description = "Two-line mall-core copy sample to verify wrap and contrast on the glass interior."
			2:
				data.display_name = "A Much Longer Power Name"
				data.description = "This description is intentionally longer so the chrome tile has to maintain readable hierarchy between the artwork pocket and the SELL button."
			3:
				data.display_name = "Extremely Long Powerup Name That Should Truncate"
				data.description = "A dense readability test. This should wrap cleanly, keep the button row clear, and avoid colliding with the artwork even when the title has already been forced to shrink."
			4:
				data.display_name = "MaxedOutPowerupNameLengthTestForTruncationBehavior"
				data.description = "Legendary long-description sample with enough text to stress the new description panel padding, the improved contrast, and the final chrome border visibility around the interior pass."
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


func _set_badge_profile_mode(mode: int) -> void:
	_profile_mode = mode
	_apply_badge_profile_to_all(_profile_mode)
	match _profile_mode:
		0:
			_log_label.text = "Badge foil: default subtle silver/pearl profile. Press 2 or 3 for stronger synergy previews."
		1:
			_log_label.text = "Badge foil: matching-set preview. Hover badges to inspect stronger gloss and iridescence."
		2:
			_log_label.text = "Badge foil: rainbow preview. Hover badges to inspect full-spectrum foil response."


func _apply_badge_profile_to_all(mode: int) -> void:
	for icon in _icons:
		if not icon:
			continue
		var tile := icon.get_node_or_null("KioskTile") as KioskTile
		if not tile or not tile.sticker_badge:
			continue
		match mode:
			0:
				tile.sticker_badge.reset_holo_profile()
			1:
				tile.sticker_badge.apply_matching_set_profile()
			2:
				tile.sticker_badge.apply_rainbow_profile()
