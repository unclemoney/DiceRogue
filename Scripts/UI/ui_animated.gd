class_name UIAnimated
extends Node

## UIAnimated
##
## Attach this as a child node to any Control or CanvasItem you want to animate
## declaratively. The parent node becomes the animation target.
##
## Usage:
##   1. Add UIAnimated as a child of a Button, Panel, etc.
##   2. Set entrance_preset / exit_preset in the Inspector.
##   3. Call UIAnimated.play_entrance() or let ContainerAnimator trigger it.

## Preset name for entrance animation. See TweenFXHelper.play_preset() for valid names.
@export var entrance_preset: String = "pop_in"
## Preset name for exit animation. See TweenFXHelper.play_preset() for valid names.
@export var exit_preset: String = "fade_out"
## Override stagger delay for this node (-1 uses the profile default).
@export var stagger_override: float = -1.0
## Delay before this node's animation starts (in seconds).
@export var delay: float = 0.0
## If true, entrance plays automatically when this node enters the tree.
@export var auto_trigger_on_ready: bool = false

@onready var _tfx: Node = get_node_or_null("/root/TweenFXHelper")


func _ready() -> void:
	if auto_trigger_on_ready:
		# Defer so parent is fully in tree and sized
		call_deferred("play_entrance")


## play_entrance(profile)
##
## Plays the configured entrance preset on the parent node.
## Returns the Tween so callers can await it, or null if invalid.
func play_entrance(profile: JuiceProfile = null) -> Tween:
	var target = get_parent() as CanvasItem
	if not target:
		push_warning("[UIAnimated] Parent is not a CanvasItem: " + str(get_parent()))
		return null
	if not _tfx:
		_tfx = get_node_or_null("/root/TweenFXHelper")
	if not _tfx:
		return null
	return _tfx.play_preset(target, entrance_preset, profile, delay)


## play_exit(profile)
##
## Plays the configured exit preset on the parent node.
## Returns the Tween so callers can await it, or null if invalid.
func play_exit(profile: JuiceProfile = null) -> Tween:
	var target = get_parent() as CanvasItem
	if not target:
		push_warning("[UIAnimated] Parent is not a CanvasItem: " + str(get_parent()))
		return null
	if not _tfx:
		_tfx = get_node_or_null("/root/TweenFXHelper")
	if not _tfx:
		return null
	return _tfx.play_preset(target, exit_preset, profile, delay)
