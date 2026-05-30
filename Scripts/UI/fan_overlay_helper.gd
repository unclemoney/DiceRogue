extends RefCounted
class_name FanOverlayHelper

## FanOverlayHelper
##
## Static utility for creating and managing the shared CanvasLayer overlay used by
## PowerUpUI, ChallengeUI, DebuffUI, and ConsumableUI for spine/icon fan-out effects.
## Ensures a single overlay instance exists at the scene root and provides helpers
## for reparenting background nodes and positioning them in screen space.

const OVERLAY_NAME: String = "SpineFanOverlay"
const OVERLAY_LAYER: int = 10


## get_overlay(root: Node) -> CanvasLayer
##
## Returns the shared SpineFanOverlay CanvasLayer, creating it at the scene root if needed.
static func get_overlay(root: Node) -> CanvasLayer:
	var tree_root = root.get_tree().get_root()
	var overlay = tree_root.get_node_or_null(OVERLAY_NAME)
	if not overlay:
		overlay = CanvasLayer.new()
		overlay.name = OVERLAY_NAME
		overlay.layer = OVERLAY_LAYER
		tree_root.add_child(overlay)
	return overlay as CanvasLayer


## create_background(name: String) -> ColorRect
##
## Creates a full-screen semi-transparent black background ColorRect for fan-out mode.
static func create_background(node_name: String = "FanBackground") -> ColorRect:
	var bg = ColorRect.new()
	bg.name = node_name
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.visible = false
	return bg


## reparent_to_overlay(node: Control, overlay: CanvasLayer, viewport_size: Vector2)
##
## Safely reparents `node` to the CanvasLayer overlay and resets its transform to fill the screen.
static func reparent_to_overlay(node: Control, overlay: CanvasLayer, viewport_size: Vector2) -> void:
	if node.get_parent() != overlay:
		node.reparent(overlay, false)
	node.position = Vector2.ZERO
	node.size = viewport_size
	node.set_anchors_preset(Control.PRESET_FULL_RECT)


## reparent_back(node: Control, parent: Control)
##
## Safely reparents `node` back to its original parent and resets position/size.
static func reparent_back(node: Control, parent: Control) -> void:
	if node.get_parent() != parent:
		node.reparent(parent, false)
	node.position = Vector2.ZERO
	node.size = Vector2.ZERO
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
