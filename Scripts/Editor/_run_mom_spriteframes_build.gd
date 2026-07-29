extends SceneTree

## _run_mom_spriteframes_build.gd
##
## CLI runner that regenerates Mom's portrait SpriteFrames headless:
##   godot --headless --path . --script res://Scripts/Editor/_run_mom_spriteframes_build.gd
## Exit code 0 = success, 1 = build failed.

const Builder := preload("res://Scripts/Editor/mom_spriteframes_builder.gd")


func _init() -> void:
	var ok: bool = Builder.build()
	quit(0 if ok else 1)
