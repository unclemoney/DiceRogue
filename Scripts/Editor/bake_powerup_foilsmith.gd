@tool
extends EditorScript

## Run from the Script editor after changing PowerUp art. The SceneTree wrapper
## run_powerup_foilsmith_bake.gd supports the same bake from the command line.

const Baker := preload("res://Scripts/Editor/powerup_foil_baker.gd")


func _run() -> void:
	var baker := Baker.new()
	await baker.bake_all()
