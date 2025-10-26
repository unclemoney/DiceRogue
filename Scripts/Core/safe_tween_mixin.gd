# Scripts/Core/safe_tween_mixin.gd
# A mixin script that provides safer tween creation methods
extends RefCounted
class_name SafeTweenMixin

## safe_create_tween(node: Node, caller_info: String = "") -> Tween
##
## Creates a tween with safety checks to prevent "Target object freed before starting" warnings.
## This method validates that the node is still in the tree and valid before creating the tween.
## 
## Parameters:
## - node: The node that will own the tween
## - caller_info: Optional debug information about what's creating the tween
## 
## Returns null if the node is not safe for tween creation, otherwise returns a valid Tween.
static func safe_create_tween(node: Node, caller_info: String = "") -> Tween:
	if not node:
		if caller_info:
			print("[SafeTweenMixin] Cannot create tween: node is null (%s)" % caller_info)
		return null
	
	if not node.is_inside_tree():
		if caller_info:
			print("[SafeTweenMixin] Cannot create tween: node not in tree (%s)" % caller_info)
		return null
	
	if not is_instance_valid(node):
		if caller_info:
			print("[SafeTweenMixin] Cannot create tween: node is invalid (%s)" % caller_info)
		return null
	
	# All safety checks passed, create the tween
	return node.create_tween()

## safe_tween_property(tween: Tween, object: Object, property: NodePath, final_val: Variant, duration: float) -> PropertyTweener
##
## Safely creates a property tween with additional validation on the target object.
## 
## Returns null if the object is not valid for tweening.
static func safe_tween_property(tween: Tween, object: Object, property: NodePath, final_val: Variant, duration: float) -> PropertyTweener:
	if not tween:
		print("[SafeTweenMixin] Cannot tween property: tween is null")
		return null
	
	if not object:
		print("[SafeTweenMixin] Cannot tween property: object is null")
		return null
	
	if not is_instance_valid(object):
		print("[SafeTweenMixin] Cannot tween property: object is invalid")
		return null
	
	# For Node objects, also check if they're in the tree
	if object is Node:
		var node = object as Node
		if not node.is_inside_tree():
			print("[SafeTweenMixin] Cannot tween property: node not in tree")
			return null
	
	return tween.tween_property(object, property, final_val, duration)