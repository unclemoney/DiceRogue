extends Node
class_name PowerUpFoilsmithTest

const TILE_SCENE := preload("res://Scenes/PowerUp/kiosk_tile.tscn")
const SAMPLE_DATA := preload("res://Scripts/PowerUps/ExtraRolls.tres")
const DATA_DIR := "res://Scripts/PowerUps"

var _failures := 0


func _ready() -> void:
	await _run_tests()
	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(_failures)


func _run_tests() -> void:
	_test_baked_assets()
	await _test_tile_runtime()
	await _test_fallback()
	print("PowerUpFoilsmithTest complete: %d failure(s)" % _failures)


func _test_baked_assets() -> void:
	var checked := 0
	for file in DirAccess.get_files_at(DATA_DIR):
		if not file.ends_with(".tres"):
			continue
		var path := DATA_DIR.path_join(file)
		var data := ResourceLoader.load(path) as PowerUpData
		if not data or not data.icon:
			continue
		checked += 1
		_check(not data.foilsmith_card_json.is_empty(), "%s has a Foilsmith JSON path" % data.id)
		if data.foilsmith_card_json.is_empty() or not FileAccess.file_exists(data.foilsmith_card_json):
			_check(false, "%s JSON exists: %s" % [data.id, data.foilsmith_card_json])
			continue
		var base := data.foilsmith_card_json.get_basename()
		for suffix in ["_art.png", "_fx.png", "_normal.png"]:
			_check(FileAccess.file_exists(base + suffix), "%s has %s" % [data.id, suffix])
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(data.foilsmith_card_json))
		_check(info is Dictionary, "%s JSON parses" % data.id)
		if info is Dictionary:
			_check(info.get("finish", "") == "holo", "%s uses HOLO" % data.id)
			_check(info.get("pixel_art", false), "%s uses pixel-art mode" % data.id)
			var native_size: Array = info.get("native_size", [])
			var valid_native_size := native_size.size() == 2
			if valid_native_size:
				valid_native_size = int(native_size[0]) == 64 and int(native_size[1]) == 64
			_check(valid_native_size, "%s uses a 64x64 native grid" % data.id)
	_check(checked > 0, "PowerUp data resources were discovered")


func _test_tile_runtime() -> void:
	var tile := TILE_SCENE.instantiate() as KioskTile
	add_child(tile)
	tile.set_data(SAMPLE_DATA)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(tile.title_pill != null, "Title has a pill container")
	if tile.title_pill:
		var title_style := tile.title_pill.get_theme_stylebox("panel") as StyleBoxFlat
		_check(title_style != null and title_style.bg_color.a < 1.0, "Title pill is translucent")
		_check(title_style != null and title_style.corner_radius_top_left >= 16, "Title pill has rounded ends")
	_check(not tile.description_panel.visible, "Hover mode hides inline descriptions")
	_check(tile.rarity_glow.material.get_shader_parameter("inner_spread") >= 26.0, "Rarity glow fills inward across the tilt gap")
	var resting_art_height := tile.art_stage.size.y
	tile.set_static_descriptions_enabled(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(tile.description_panel.visible, "Static mode shows inline descriptions")
	var description_style := tile.description_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(description_style != null and description_style.bg_color.a < 1.0, "Static description has a translucent background")
	_check(tile.sticker_badge.scale.x < 1.0, "Static mode shrinks the Mom badge")
	_check(tile.description_label.text == SAMPLE_DATA.description, "Inline description initializes from PowerUp data")
	_check(tile.description_label.max_lines_visible == 3, "Inline descriptions are capped at three lines")
	_check(tile.description_label.size.y >= 44.0, "Inline description fills its panel content height")
	_check(tile.art_stage.size.y < resting_art_height, "Static mode reserves space by shrinking the art stage")
	_check(tile.size == Vector2(200, 300), "Static mode preserves the 200x300 tile footprint")
	var radius := minf(tile.art_stage.size.x, tile.art_stage.size.y) * KioskTile.FOIL_CARD_SCALE * 0.5
	var glow_radius: float = tile.rarity_glow.material.get_shader_parameter("circle_radius")
	_check(absf(glow_radius - radius * KioskTile.RARITY_GLOW_RADIUS_SCALE) < 0.1, "Rarity ring uses its reduced radius scale")
	var rim_contact: Vector2 = tile.sticker_badge.position + Vector2(0.0, tile.sticker_badge.size.y * tile.sticker_badge.scale.y)
	_check(absf(rim_contact.distance_to(tile.art_stage.size * 0.5) - radius) < 0.1, "Scaled badge lower-left corner touches the upper-right POG rim")
	tile.set_description_text("Current bonus: +72")
	_check(tile.description_label.text == "Current bonus: +72", "Inline descriptions accept live updates")
	tile.set_static_descriptions_enabled(false)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not tile.description_panel.visible, "Hover mode hides the inline description again")
	_check(tile.sticker_badge.scale == Vector2.ONE, "Hover mode restores the Mom badge size")
	_check(tile.art_stage.size.y == resting_art_height, "Hover mode restores the full art stage")
	_check(tile.foilsmith_card.visible, "Baked Foilsmith card is visible")
	_check(not tile.artwork.visible, "Fallback art is hidden behind a valid bake")
	_check(not tile.foilsmith_card.click_to_flip, "POG click does not flip")
	_check(tile.foilsmith_card.mouse_filter == Control.MOUSE_FILTER_PASS, "Foilsmith passes clicks to the tile")
	_check(tile.foilsmith_card.follow_mouse, "Foilsmith pointer tilt is enabled")
	var motion := InputEventMouseMotion.new()
	motion.position = tile.foilsmith_card.size * Vector2(0.9, 0.1)
	tile.foilsmith_card._gui_input(motion)
	await get_tree().create_timer(0.15).timeout
	_check(tile.foilsmith_card.tilt.length() > 0.01, "Pointer motion tilts the POG")
	tile.foilsmith_card._notification(Control.NOTIFICATION_MOUSE_EXIT)
	_check(tile.foilsmith_card._target == Vector2.ZERO, "Mouse exit clears the tilt target")
	await get_tree().create_timer(0.6).timeout
	_check(tile.foilsmith_card.tilt.length() < 0.05, "Mouse exit resets POG tilt")
	_check(tile.foilsmith_card.art != null, "Foilsmith art loaded")
	if tile.foilsmith_card.art:
		var image := tile.foilsmith_card.art.get_image()
		var corners := [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), Vector2i(image.get_width() - 1, image.get_height() - 1)]
		for corner in corners:
			_check(image.get_pixelv(corner).a <= 0.01, "POG corner %s remains transparent" % corner)
	var clicked := {"value": ""}
	tile.tile_clicked.connect(func(id: String) -> void: clicked.value = id)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	tile._on_gui_input(click)
	_check(clicked.value == SAMPLE_DATA.id, "Tile click preserves selection signal")
	var sold := {"value": ""}
	tile.sell_requested.connect(func(id: String) -> void: sold.value = id)
	tile.sell_button.pressed.emit()
	_check(sold.value == SAMPLE_DATA.id, "SELL preserves its signal")
	_check(tile.cycle_foil_debug_layer() == FoilsmithCard.Layer.FOIL, "Debug layer cycles to FOIL")
	tile.reset_foil_debug_layer()
	_check(tile.foilsmith_card.layer == FoilsmithCard.Layer.SHADED, "Debug layer resets to shaded")
	tile.set_synergy_halo(PowerUpData.SynergyHaloMode.RAINBOW)
	_check(tile.synergy_halo.visible, "Synergy ring becomes visible")
	_check(tile.synergy_halo.material.get_shader_parameter("rainbow_mode") == 1.0, "Rainbow synergy stays enabled")
	tile.set_synergy_halo(PowerUpData.SynergyHaloMode.NONE)
	_check(not tile.synergy_halo.visible, "Synergy ring clears")
	tile.queue_free()
	await get_tree().process_frame


func _test_fallback() -> void:
	var tile := TILE_SCENE.instantiate() as KioskTile
	add_child(tile)
	var data := SAMPLE_DATA.duplicate(true) as PowerUpData
	data.foilsmith_card_json = ""
	tile.set_data(data)
	await get_tree().process_frame
	_check(not tile.foilsmith_card.visible, "Unbaked data does not show an empty Foilsmith card")
	_check(tile.artwork.visible and tile.artwork.texture == data.icon, "Unbaked data shows original artwork")
	tile.queue_free()
	await get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
