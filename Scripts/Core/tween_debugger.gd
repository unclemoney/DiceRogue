# Scripts/Core/tween_debugger.gd
# Temporary debug script to track down tween warnings
extends Node

var tween_creation_count := 0
var original_create_tween_method: Callable

func _ready() -> void:
	print("[TweenDebugger] Starting tween debugging system")
	# This will help us track when tweens are created
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_CRASH:
		print("[TweenDebugger] Game crashed - tween count was:", tween_creation_count)

# Custom method to wrap tween creation and add debugging
func debug_create_tween(node: Node, caller_info: String = "") -> Tween:
	tween_creation_count += 1
	print("[TweenDebugger] Tween #%d created by: %s (node: %s)" % [tween_creation_count, caller_info, node.name])
	
	if not node.is_inside_tree():
		print("[TweenDebugger] WARNING: Tween created on node NOT in tree: %s" % node.name)
	
	var tween = node.create_tween()
	
	# Connect to tween finished signal to track completion
	if tween:
		tween.finished.connect(_on_tween_finished.bind(tween_creation_count, caller_info))
	
	return tween

func _on_tween_finished(tween_id: int, caller_info: String) -> void:
	print("[TweenDebugger] Tween #%d finished (%s)" % [tween_id, caller_info])