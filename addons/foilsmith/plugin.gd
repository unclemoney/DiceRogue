@tool
extends EditorPlugin
## Registers the FoilsmithCard node (it is also a global class, so it shows up in the Create Node
## dialog either way; the plugin gives it its icon and keeps the shader's uniforms out of the way).
## The frame nodes (FoilsmithFrame and its components) are global classes too.


func _enter_tree() -> void:
	add_custom_type("FoilsmithCard", "Control", preload("res://addons/foilsmith/foilsmith_card.gd"), load("res://addons/foilsmith/icon.svg"))


func _exit_tree() -> void:
	remove_custom_type("FoilsmithCard")
	# free the depth model's GPU memory, if "Bake depth" loaded it
	FoilsmithDepth.release()
