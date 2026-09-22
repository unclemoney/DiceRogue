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
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
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
	var shell_rect: Rect2 = selector.panel_container.get_global_rect()
	var grid_rect: Rect2 = selector._directory_grid.get_global_rect()
	var first_column = selector._directory_grid.get_child(0)
	var store_label = first_column.get_child(1)
	print("[MallSelectorShot] viewport=%s shell=%s grid=%s col_min=%.1f font=%d" % [
		str(get_viewport_rect().size),
		str(shell_rect),
		str(grid_rect),
		first_column.custom_minimum_size.x,
		store_label.get_theme_font_size("font_size"),
	])
	var img := get_viewport().get_texture().get_image()
	var path := "res://Tests/_layout_shots/mall_selector.png"
	var err := img.save_png(path)
	print("[MallSelectorShot] saved %s (err=%d)" % [path, err])
	get_tree().quit(0)
