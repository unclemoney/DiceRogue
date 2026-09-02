extends Node

## _synergy_halo_shot.gd (temporary visual verification)
##
## Instantiates PowerUpUI with 5 PG-13 power-ups, activates the matching-set
## synergy, and screenshots the compact row and fan view (with banner).
## Then activates the rainbow bonus for a third shot.
## Saves to Tests/_layout_shots/. Run windowed (NOT headless):
##   godot --path . Tests/_synergy_halo_shot.tscn

const POWER_UP_UI_SCENE := preload("res://Scenes/UI/power_up_ui.tscn")
const POG_GRID := preload("res://Resources/Art/Powerups/parental_guidance_pg_pog_grid_5x5.png")

var _power_up_ui: PowerUpUI
var _synergy_manager: SynergyManager


## _make_pog_icon(index)
##
## Extracts a single cell from the 5x5 pog grid tileset for use as an icon.
func _make_pog_icon(index: int) -> AtlasTexture:
	var cell := Vector2(POG_GRID.get_size()) / 5.0
	var col := index % 5
	@warning_ignore("integer_division")
	var row := index / 5
	var atlas := AtlasTexture.new()
	atlas.atlas = POG_GRID
	atlas.region = Rect2(Vector2(col, row) * cell, cell)
	return atlas


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	_synergy_manager = SynergyManager.new()
	add_child(_synergy_manager)

	_power_up_ui = POWER_UP_UI_SCENE.instantiate()
	_power_up_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_power_up_ui.position = Vector2(40, 40)
	_power_up_ui.size = Vector2(520, 86)
	_power_up_ui.custom_minimum_size = Vector2(520, 86)
	add_child(_power_up_ui)

	await get_tree().create_timer(0.5).timeout
	_power_up_ui._connect_synergy_manager()

	for i in range(5):
		var data := PowerUpData.new()
		data.id = "shot_pu_%d" % i
		data.display_name = "Shot Power %d" % i
		data.rating = "PG-13"
		data.icon = _make_pog_icon(i)
		_power_up_ui.add_power_up(data)

	# Activate the PG-13 matching set (+50).
	_synergy_manager._rating_counts["PG-13"] = 5
	_synergy_manager._active_synergies["synergy_PG_13_sets"] = 50
	_power_up_ui._update_synergy_halos()

	await get_tree().create_timer(0.8).timeout
	await _shot("synergy_halo_compact.png")

	# Fan out: halo on cards + banner.
	_power_up_ui._open_fan_view()
	await get_tree().create_timer(1.5).timeout
	await _shot("synergy_halo_fan.png")

	# Rainbow bonus: hue-cycling halos, updated banner.
	for rating in SynergyManager.ALL_RATINGS:
		_synergy_manager._rating_counts[rating] = max(1, _synergy_manager._rating_counts.get(rating, 0))
	_synergy_manager._active_synergies["synergy_rainbow"] = SynergyManager.RAINBOW_MULTIPLIER
	_power_up_ui._update_synergy_halos()
	await get_tree().create_timer(0.5).timeout
	await _shot("synergy_halo_rainbow.png")

	get_tree().quit(0)


func _shot(file_name: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "res://Tests/_layout_shots/" + file_name
	var err := img.save_png(path)
	print("[SynergyHaloShot] saved %s (err=%d)" % [path, err])
