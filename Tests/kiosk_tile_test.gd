extends Control
class_name KioskTileTest

## Interactive POG tile test: pointer tilt, rating stickers, circular rarity and
## synergy effects, selection, SELL, Foilsmith map layers, and fallback art.

const PowerUpIconScene = preload("res://Scenes/PowerUp/power_up_icon.tscn")
const ExtraRollsData = preload("res://Scripts/PowerUps/ExtraRolls.tres")

var _icons: Array[PowerUpIcon] = []
var _log_label: Label
var _profile_mode := 0
var _fallback_active := false


func _ready() -> void:
	_create_log_label()
	_create_sample_icons()
	_apply_badge_profile_to_all(_profile_mode)
	_show_controls()


func _show_controls() -> void:
	_log_label.text = "Hover POGs/badges; click tile or SELL. 1-3 badge foil; 4 Foilsmith map; 5 fallback art."


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_1:
			_set_badge_profile_mode(0)
		KEY_2:
			_set_badge_profile_mode(1)
		KEY_3:
			_set_badge_profile_mode(2)
		KEY_4:
			_cycle_foil_layers()
		KEY_5:
			_toggle_fallback()
		_:
			return
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
	var card_size := Vector2(200, 300)
	var spacing := 224.0
	var total_width := (ratings.size() - 1) * spacing + card_size.x
	var start_x := (size.x - total_width) * 0.5
	var pos_y := 42.0
	for i in range(ratings.size()):
		var icon: PowerUpIcon = PowerUpIconScene.instantiate()
		var data: PowerUpData = ExtraRollsData.duplicate(true)
		data.id = "test_%s" % ratings[i]
		data.rating = ratings[i]
		data.rarity = rarities[i]
		match i:
			0:
				data.display_name = "Short"
				data.description = "One-line control sample for spacing."
			1:
				data.display_name = "Medium Length"
				data.description = "Two-line POG tooltip copy sample."
			2:
				data.display_name = "A Much Longer Power Name"
				data.description = "A longer description verifies that the external tooltip owns all rules text."
			3:
				data.display_name = "Extremely Long Powerup Name That Should Truncate"
				data.description = "Long names must shrink or truncate without colliding with the POG or SELL button."
			4:
				data.display_name = "MaxedOutPowerupNameLengthTestForTruncationBehavior"
				data.description = "Legendary rarity and NC-17 rating remain independent visual signals."
		icon.set_data(data)
		icon.position = Vector2(start_x + i * spacing, pos_y)
		icon.power_up_selected.connect(_on_power_up_selected)
		icon.power_up_deselected.connect(_on_power_up_deselected)
		icon.power_up_sell_requested.connect(_on_power_up_sell_requested)
		add_child(icon)
		_icons.append(icon)


func _on_power_up_selected(id: String) -> void:
	_log_label.text = "Selected: %s" % id


func _on_power_up_deselected(id: String) -> void:
	_log_label.text = "Deselected: %s" % id


func _on_power_up_sell_requested(id: String) -> void:
	_log_label.text = "Sell requested: %s" % id


func _set_badge_profile_mode(mode: int) -> void:
	_profile_mode = mode
	_apply_badge_profile_to_all(_profile_mode)
	_log_label.text = "Badge foil profile: %d" % mode


func _apply_badge_profile_to_all(mode: int) -> void:
	for icon in _icons:
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


func _cycle_foil_layers() -> void:
	var layer := -1
	for icon in _icons:
		var tile := icon.get_node_or_null("KioskTile") as KioskTile
		if tile:
			layer = tile.cycle_foil_debug_layer()
	_log_label.text = "Foilsmith layer: %d (0 shaded, 1 foil, 2 depth, 3 pop-out, 4 normals)" % layer


func _toggle_fallback() -> void:
	_fallback_active = not _fallback_active
	for icon in _icons:
		var tile := icon.get_node_or_null("KioskTile") as KioskTile
		if not tile or not tile.data:
			continue
		var data := tile.data
		if not data.has_meta("original_foilsmith_card_json"):
			data.set_meta("original_foilsmith_card_json", data.foilsmith_card_json)
		data.foilsmith_card_json = "" if _fallback_active else str(data.get_meta("original_foilsmith_card_json"))
		tile.set_data(data)
	_log_label.text = "Fallback art: %s" % _fallback_active
