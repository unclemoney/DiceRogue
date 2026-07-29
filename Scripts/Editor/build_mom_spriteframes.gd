@tool
extends EditorScript

## build_mom_spriteframes.gd
##
## Editor entry point for regenerating Mom's portrait SpriteFrames:
##   res://Resources/Art/Characters/Mom/mom_portrait_frames.tres
## Run from the Script editor (File > Run) after any sheet art update.
## Logic lives in mom_spriteframes_builder.gd so the same build can run
## headless via _run_mom_spriteframes_build.gd.

const Builder := preload("res://Scripts/Editor/mom_spriteframes_builder.gd")


func _run() -> void:
	Builder.build()
