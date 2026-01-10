@tool
extends EditorPlugin

## plugin.gd
##
## EditorPlugin that registers the Resource Viewer bottom panel dock.
## Scans resource folders for PowerUps, Consumables, Mods, and Colored Dice.

const ResourceViewerScene := preload("res://addons/resource_viewer/ResourceViewer.tscn")

var resource_viewer_instance: Control = null


func _enter_tree() -> void:
	print("[ResourceViewer] Plugin entering tree...")
	
	# Instantiate the resource viewer UI
	resource_viewer_instance = ResourceViewerScene.instantiate()
	
	# Add as bottom panel
	add_control_to_bottom_panel(resource_viewer_instance, "Resource Viewer")
	
	print("[ResourceViewer] Plugin initialized successfully")


func _exit_tree() -> void:
	print("[ResourceViewer] Plugin exiting tree...")
	
	# Remove from bottom panel
	if resource_viewer_instance:
		remove_control_from_bottom_panel(resource_viewer_instance)
		resource_viewer_instance.queue_free()
		resource_viewer_instance = null
	
	print("[ResourceViewer] Plugin cleaned up")
