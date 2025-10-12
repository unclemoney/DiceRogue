extends Node

## DebugHelper
##
## Simple helper to manage debug panel creation and ensure only one instance exists.
## Add this script as an autoload or attach to your main scene.

func _ready() -> void:
	# Create debug panel if it doesn't exist
	if not DebugPanel.instance:
		var debug_panel = preload("res://Scenes/UI/DebugPanel.tscn").instantiate()
		get_tree().current_scene.add_child(debug_panel)
		print("[DebugHelper] Debug panel created and added to scene")
	else:
		print("[DebugHelper] Debug panel already exists")

func _input(event: InputEvent) -> void:
	# Global F12 handler as backup
	if event is InputEventKey and event.keycode == KEY_F12 and event.pressed and not event.echo:
		if DebugPanel.instance:
			DebugPanel.instance.toggle_debug_panel()
		else:
			print("[DebugHelper] No debug panel instance found")
		get_viewport().set_input_as_handled()