extends GPUParticles2D

## AmbientParticles
##
## Subtle floating dust motes for gameplay atmosphere.
## Toggleable via TweenFXHelper FX group.

var _tfx: Node = null

func _ready() -> void:
	_tfx = get_node_or_null("/root/TweenFXHelper")
	# Start emitting
	emitting = true

func _process(_delta: float) -> void:
	if _tfx and not _tfx.is_group_enabled(_tfx.Group.EVENTS):
		visible = false
	else:
		visible = true
