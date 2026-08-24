extends Node

## _mom_visual_shot.gd (temporary visual verification)
##
## Instantiates the Mom dialog popup, shows a multi-response beat, then a
## terminal beat, saving a viewport screenshot of each to
## Tests/_layout_shots/ so panel size and portrait framing can be eyeballed.
## Run windowed (NOT headless):
##   godot --path . Tests/_mom_visual_shot.tscn

const Handler := preload("res://Scripts/Core/mom_logic_handler.gd")


func _ready() -> void:
	var scene: PackedScene = load("res://Scenes/UI/mom_dialog_popup.tscn")
	var dialog = scene.instantiate()
	add_child(dialog)

	dialog.show_node(Handler.get_dialog_node("checkin_neutral"))
	await get_tree().create_timer(2.0).timeout
	await _shot("mom_dialog_responses.png")

	dialog.show_node(Handler.get_dialog_node("sass_storm_off"))
	await get_tree().create_timer(2.0).timeout
	await _shot("mom_dialog_terminal.png")

	get_tree().quit(0)


func _shot(file_name: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "res://Tests/_layout_shots/" + file_name
	var err := img.save_png(path)
	print("[MomVisualShot] saved %s (err=%d)" % [path, err])
