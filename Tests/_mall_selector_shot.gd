extends Control

## _mall_selector_shot.gd (temporary visual verification)
##
## Shows the ChannelManagerUI mall selector with a real ChannelManager and
## saves a viewport screenshot to Tests/_layout_shots/.
## Run windowed (NOT headless):
##   godot --path . Tests/_mall_selector_shot.tscn

const ChannelManagerScript = preload("res://Scripts/Managers/channel_manager.gd")
const ChannelManagerUIScene = preload("res://Scenes/Managers/ChannelManagerUI.tscn")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	call_deferred("_run")


func _run() -> void:
	var channel_manager = ChannelManagerScript.new()
	channel_manager.name = "ChannelManager"
	add_child(channel_manager)

	var selector = ChannelManagerUIScene.instantiate()
	add_child(selector)
	await get_tree().process_frame
	selector.set_channel_manager(channel_manager)
	channel_manager.reset()
	selector.show_channel_selector()

	# Past the full staged entrance.
	await get_tree().create_timer(4.5).timeout
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "res://Tests/_layout_shots/mall_selector.png"
	var err := img.save_png(path)
	print("[MallSelectorShot] saved %s (err=%d)" % [path, err])
	get_tree().quit(0)
