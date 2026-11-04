extends SceneTree

const Baker := preload("res://Scripts/Editor/powerup_foil_baker.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var baker := Baker.new()
	await baker.bake_all()
