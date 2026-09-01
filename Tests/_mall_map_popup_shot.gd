extends Control

## _mall_map_popup_shot.gd (temporary visual verification)
##
## Opens the MallMapPopup with stub managers, saves a viewport screenshot to
## Tests/_layout_shots/ so the layout can be eyeballed.
## Run windowed (NOT headless):
##   godot --path . Tests/_mall_map_popup_shot.tscn

const MallMapPopupScene := preload("res://Scenes/UI/MallMapPopup.tscn")

class StubChannelManager extends RefCounted:
	var current_channel: int = 1
	var zone_store_names: Dictionary = {}

	func assign_stores_to_zones(_seed: int = 0) -> void:
		pass

	func get_store_name(zone: int, round_number: int) -> String:
		return "Stub Store %d-%d" % [zone, round_number]

	func get_round_config(_channel: int = -1, _round_number: int = 1):
		return null

	func get_mall_zone_label(channel: int = -1) -> String:
		return "Mall Zone %02d" % channel

	func get_selector_zone_name(channel: int = -1) -> String:
		return "Zone %d" % channel

	func get_selector_directory_label(channel: int = -1) -> String:
		return "%02d" % channel

	func get_selector_section_id(_channel: int = -1) -> String:
		return "specialty"

	func get_selector_tooltip_flavor(_channel: int = -1) -> String:
		return ""

	func get_channel_display_text(channel: int = -1) -> String:
		return "%02d" % channel

	func get_scaled_target_score(base_score: int, _channel: int = -1) -> int:
		return base_score


class StubDebuffManager extends RefCounted:
	var defs: Dictionary = {}

	func get_def(id: String):
		return defs.get(id)


class StubDebuffDef extends RefCounted:
	var display_name: String = ""

	func _init(p_name: String) -> void:
		display_name = p_name


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	call_deferred("_run")


func _run() -> void:
	var channel_manager := StubChannelManager.new()
	channel_manager.current_channel = 1

	var debuff_manager := StubDebuffManager.new()
	debuff_manager.defs["hail_satan"] = StubDebuffDef.new("Hail Satan")

	var round_manager := RoundManager.new()
	round_manager.channel_manager = channel_manager
	for i in range(6):
		var debuff_ids: Array[String] = []
		if i == 1:
			debuff_ids.append("hail_satan")
		round_manager.rounds_data.append({
			"round_number": i + 1,
			"store_name": channel_manager.get_store_name(1, i + 1),
			"dice_type": "d6",
			"target_score": 0,
			"completed": i == 0,
			"failed": false,
			"debuff_ids": debuff_ids,
		})
	round_manager.current_round = 1

	var popup = MallMapPopupScene.instantiate()
	add_child(popup)
	popup.setup(channel_manager, round_manager, debuff_manager)
	popup.open()
	await get_tree().create_timer(1.2).timeout
	await _shot("mall_map_popup.png")

	# Second shot with the store tooltip visible on the current store.
	var current_marker = popup._store_markers[1][1]
	popup._show_store_tooltip(current_marker)
	await get_tree().create_timer(0.3).timeout
	await _shot("mall_map_popup_tooltip.png")

	get_tree().quit(0)


func _shot(file_name: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "res://Tests/_layout_shots/" + file_name
	var err := img.save_png(path)
	print("[MallMapPopupShot] saved %s (err=%d)" % [path, err])
