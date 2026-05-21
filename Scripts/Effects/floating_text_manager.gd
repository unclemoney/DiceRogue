extends Node

## FloatingTextManager
##
## Autoload singleton for spawning floating text popups outside of scoring.
## Wraps FloatingNumber for currency changes, unlocks, debuffs, mod sales, streaks, etc.

const FloatingNumberScript := preload("res://Scripts/Effects/floating_number.gd")

const COLOR_MONEY_POSITIVE := Color(0.2, 1.0, 0.2, 1.0)
const COLOR_MONEY_NEGATIVE := Color(1.0, 0.2, 0.2, 1.0)
const COLOR_GENERIC_GOOD := Color(1.0, 0.9, 0.2, 1.0)
const COLOR_GENERIC_BAD := Color(1.0, 0.3, 0.3, 1.0)
const COLOR_NEUTRAL := Color(0.9, 0.9, 0.9, 1.0)
const COLOR_SYNERGY := Color(1.0, 0.5, 0.0, 1.0)

## show_currency_popup(node, amount, is_positive)
##
## Spawns a "+$X" or "-$X" floating popup starting at the node's global position.
## The popup floats upward and fades out automatically.
func show_currency_popup(source_node: Node, amount: int, is_positive: bool = true) -> void:
	if not source_node or not is_instance_valid(source_node):
		return
	
	var text := "+$%d" % amount if is_positive else "-$%d" % amount
	var color := COLOR_MONEY_POSITIVE if is_positive else COLOR_MONEY_NEGATIVE
	var font_scale := 1.0 + minf(amount / 100.0, 1.5)
	
	_show_popup_at_node(source_node, text, color, font_scale)


## show_generic_popup(node, text, color, font_scale)
##
## Spawns a custom floating text popup at the node's global position.
func show_generic_popup(source_node: Node, text: String, color: Color = COLOR_GENERIC_GOOD, font_scale: float = 1.0) -> void:
	if not source_node or not is_instance_valid(source_node):
		return
	
	_show_popup_at_node(source_node, text, color, font_scale)


## show_popup_at_position(parent, position, text, color, font_scale)
##
## Spawns a floating text popup at an explicit global position.
func show_popup_at_position(parent: Node, position: Vector2, text: String, color: Color = COLOR_GENERIC_GOOD, font_scale: float = 1.0) -> void:
	if not parent or not is_instance_valid(parent):
		return
	
	FloatingNumberScript.create_floating_number(parent, position, text, font_scale, color)


## show_synergy_popup(node)
##
## Spawns a "SYNERGY!" popup for combined bonus moments.
func show_synergy_popup(source_node: Node) -> void:
	show_generic_popup(source_node, "SYNERGY!", COLOR_SYNERGY, 1.5)


## show_streak_popup(node, multiplier)
##
## Spawns a streak multiplier popup like "1.5x STREAK!".
func show_streak_popup(source_node: Node, multiplier: float) -> void:
	var text := "%.1fx STREAK!" % multiplier
	show_generic_popup(source_node, text, COLOR_GENERIC_GOOD, 1.3)


## show_blocked_popup(node)
##
## Spawns a "BLOCKED!" popup for debuff resistance.
func show_blocked_popup(source_node: Node) -> void:
	show_generic_popup(source_node, "BLOCKED!", Color(0.4, 0.7, 1.0, 1.0), 1.2)


## show_jackpot_popup(node)
##
## Spawns a large "JACKPOT!" popup for Yahtzee / huge scores.
func show_jackpot_popup(source_node: Node) -> void:
	show_generic_popup(source_node, "JACKPOT!", Color(1.0, 0.8, 0.0, 1.0), 2.0)


func _show_popup_at_node(source_node: Node, text: String, color: Color, font_scale: float) -> void:
	var viewport := source_node.get_viewport()
	if not viewport:
		return
	
	# Always parent floating text to the root Window so it lives in screen space.
	# Using the Camera2D as parent causes coordinate mismatch for Controls.
	var root: Node = source_node.get_tree().root
	
	var global_pos := Vector2.ZERO
	if source_node is CanvasItem:
		global_pos = (source_node as CanvasItem).global_position
		if source_node is Control:
			global_pos += (source_node as Control).size / 2.0
	
	FloatingNumberScript.create_floating_number(root, global_pos, text, font_scale, color)
