# Scripts/Core/tutorial_step.gd
extends Resource
class_name TutorialStep

## TutorialStep Resource
##
## Defines a single step or part of a tutorial sequence.
## Can be multi-part for complex topics (e.g., "Scoring 1/3", "Scoring 2/3").
## Supports UI highlighting, action requirements, and Mom's dialog expressions.

## Unique identifier for this step (e.g., "intro", "roll_dice", "scoring_1")
@export var id: String = ""

## Part number for multi-part steps (1-based). Use 1 for single-part steps.
@export var part: int = 1

## Total parts for this topic (e.g., 3 for a three-part explanation).
## Used to display "Part X of Y" in the UI.
@export var total_parts: int = 1

## Display title shown in the tutorial dialog (e.g., "Rolling the Dice")
@export var title: String = ""

## Mom's tutorial message. Supports BBCode for formatting.
## Example: "[color=gold]Click the ROLL button[/color] to roll your dice!"
@export_multiline var message: String = ""

## Mom's expression during this step.
## Valid values: "happy", "neutral", "upset"
@export_enum("happy", "neutral", "upset") var mom_expression: String = "happy"

## NodePath to the UI element to highlight (relative to game scene root).
## Leave empty for no highlight.
## Example: "GameButtonUI/RollButton" or "ScoreCardUI"
@export var highlight_node_path: String = ""

## Whether to show the "↓ CLICK HERE ↓" indicator above the highlighted element.
@export var show_click_indicator: bool = false

## Required action to complete this step.
## Valid values: "none", "click_roll", "click_shop", "click_next_turn", 
## "click_next_round", "click_scorecard", "lock_die", "use_consumable",
## "purchase_item", "click_continue"
@export_enum("none", "click_roll", "click_shop", "click_next_turn", 
	"click_next_round", "click_scorecard", "lock_die", "use_consumable",
	"purchase_item", "click_continue") var required_action: String = "click_continue"

## Signal to listen for to mark step complete (alternative to required_action).
## Format: "object_path:signal_name" e.g., "GameButtonUI:dice_rolled"
## Leave empty to use required_action instead.
@export var completion_signal: String = ""

## ID of the next step to show after this one.
## Leave empty if this is the final step in the tutorial.
@export var next_step_id: String = ""

## Whether to pause the game while this step is displayed.
## Useful for introduction steps or complex explanations.
@export var pause_game: bool = false

## Optional delay (in seconds) before showing this step.
## Useful for timing tutorial steps with animations.
@export var delay_before: float = 0.0

## Category tag for grouping related steps (e.g., "basics", "scoring", "powerups").
## Used for organizing steps in the content editor.
@export var category: String = "basics"

## Dialog position hint for this step.
## Controls where the tutorial dialog appears to avoid covering important UI.
## Valid values: "auto", "top", "bottom", "left", "right", "center"
## "auto" tries to position opposite to the highlighted element.
@export_enum("auto", "top", "bottom", "left", "right", "center") var dialog_position: String = "auto"

## Manual highlight size override (in pixels).
## Leave at (0, 0) to use automatic size detection.
## Useful for Node2D elements where auto-detection doesn't work well.
@export var highlight_size: Vector2 = Vector2.ZERO

## Manual highlight offset (in pixels).
## Applied to the highlight position for fine-tuning alignment.
## Useful when the highlight needs to be slightly adjusted from the node's position.
@export var highlight_offset: Vector2 = Vector2.ZERO

## Whether to show the semi-transparent backdrop that dims the screen.
## Set to false for steps where you want the full scene visible without dimming.
@export var show_backdrop: bool = true


## validate_paths(root_node)
##
## Validates that all NodePaths in this step resolve to actual nodes.
## Logs errors for invalid paths but does not throw.
##
## @param root_node: The root node to resolve paths from (typically the game scene root)
## @return bool: True if all paths are valid, false if any path is invalid
func validate_paths(root_node: Node) -> bool:
	if not root_node:
		push_error("[TutorialStep:%s] Cannot validate paths - root_node is null" % id)
		return false
	
	var all_valid := true
	
	# Validate highlight_node_path if specified
	if highlight_node_path != "":
		var highlight_node = root_node.get_node_or_null(highlight_node_path)
		if highlight_node == null:
			push_error("[TutorialStep:%s] Invalid highlight_node_path: '%s' - node not found" % [id, highlight_node_path])
			all_valid = false
		elif not highlight_node is CanvasItem:
			push_error("[TutorialStep:%s] highlight_node_path '%s' is not a CanvasItem (Control or Node2D)" % [id, highlight_node_path])
			all_valid = false
	
	# Validate completion_signal path if specified
	if completion_signal != "":
		var parts = completion_signal.split(":")
		if parts.size() != 2:
			push_error("[TutorialStep:%s] Invalid completion_signal format: '%s' - expected 'node_path:signal_name'" % [id, completion_signal])
			all_valid = false
		else:
			var signal_node = root_node.get_node_or_null(parts[0])
			if signal_node == null:
				push_error("[TutorialStep:%s] completion_signal node not found: '%s'" % [id, parts[0]])
				all_valid = false
			elif not signal_node.has_signal(parts[1]):
				push_error("[TutorialStep:%s] completion_signal '%s' not found on node '%s'" % [id, parts[1], parts[0]])
				all_valid = false
	
	return all_valid


## get_step_label() -> String
##
## Returns a formatted label for multi-part steps.
## Example: "Part 2 of 3" or empty string for single-part steps.
func get_step_label() -> String:
	if total_parts <= 1:
		return ""
	return "Part %d of %d" % [part, total_parts]


## is_final_step() -> bool
##
## Returns true if this is the last step in the tutorial sequence.
func is_final_step() -> bool:
	return next_step_id == ""


## get_highlight_path() -> NodePath
##
## Returns the highlight_node_path as a NodePath for use with get_node().
func get_highlight_path() -> NodePath:
	if highlight_node_path == "":
		return NodePath()
	return NodePath(highlight_node_path)
