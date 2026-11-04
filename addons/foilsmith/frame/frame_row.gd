@tool
@icon("res://addons/foilsmith/frame/component.svg")
class_name FrameRow
extends FoilsmithComponent
## A frame component: Row (`row` in the frame JSON).
## Its children are components too, side by side: each sized by its Width.


func kind() -> String:
	return "row"
