extends Control
class_name DiceAreaContainer

## DiceAreaContainer
##
## A container that manages the visual dice area with proper centering,
## multi-row support (up to 16 dice in 2 rows of 8), and visual borders.
## Handles positioning calculations and provides entry/exit animation directions.

signal dice_area_ready

## Entry animation directions
enum EntryDirection { TOP, BOTTOM, LEFT, RIGHT, TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }

## Configuration
@export var max_dice_per_row: int = 8
@export var max_rows: int = 2
@export var dice_spacing: float = 80.0
@export var row_spacing: float = 90.0
@export var border_padding: float = 20.0
@export var show_border: bool = true
@export var border_color: Color = Color(0.3, 0.3, 0.4, 0.5)
@export var border_width: float = 2.0

## Animation settings
@export var entry_duration: float = 0.4
@export var exit_duration: float = 0.3
@export var animation_stagger: float = 0.05

## Internal state
var _dice_positions: Array[Vector2] = []

## Called when node enters the scene tree
func _ready() -> void:
	add_to_group("dice_area_container")
	emit_signal("dice_area_ready")


## _draw()
##
## Draws the visual border around the dice area if enabled.
func _draw() -> void:
	if show_border:
		var rect = Rect2(Vector2.ZERO, size)
		draw_rect(rect, border_color, false, border_width)


## calculate_dice_positions(dice_count: int) -> Array[Vector2]
##
## Calculates centered positions for dice based on count.
## Returns an array of local positions within this container.
## Supports up to 16 dice in 2 rows, with balanced distribution.
func calculate_dice_positions(dice_count: int) -> Array[Vector2]:
	_dice_positions.clear()
	
	if dice_count <= 0:
		return _dice_positions
	
	var clamped_count = mini(dice_count, max_dice_per_row * max_rows)
	
	# Calculate row distribution (balanced: 9 dice → 5 top, 4 bottom)
	var top_row_count: int = 0
	var bottom_row_count: int = 0
	
	if clamped_count <= max_dice_per_row:
		top_row_count = clamped_count
		bottom_row_count = 0
	else:
		# Balanced distribution: larger half on top
		top_row_count = ceili(clamped_count / 2.0)
		bottom_row_count = clamped_count - top_row_count
	
	var area_center_x = size.x / 2.0
	var area_center_y = size.y / 2.0
	
	# Calculate vertical offset for multi-row
	var total_height = row_spacing if bottom_row_count > 0 else 0.0
	var start_y = area_center_y - (total_height / 2.0)
	
	# Generate top row positions (centered)
	var top_row_width = (top_row_count - 1) * dice_spacing
	var top_start_x = area_center_x - (top_row_width / 2.0)
	
	for i in range(top_row_count):
		var pos = Vector2(top_start_x + i * dice_spacing, start_y)
		_dice_positions.append(pos)
	
	# Generate bottom row positions (centered)
	if bottom_row_count > 0:
		var bottom_row_width = (bottom_row_count - 1) * dice_spacing
		var bottom_start_x = area_center_x - (bottom_row_width / 2.0)
		
		for i in range(bottom_row_count):
			var pos = Vector2(bottom_start_x + i * dice_spacing, start_y + row_spacing)
			_dice_positions.append(pos)
	
	return _dice_positions


## get_entry_direction(index: int, total_count: int) -> EntryDirection
##
## Returns a varied entry direction for the die at the given index.
## Provides visual variety with dice entering from different directions.
func get_entry_direction(index: int, total_count: int) -> EntryDirection:
	# Use a pattern that distributes directions nicely
	# For small counts, use simpler patterns
	if total_count <= 4:
		match index % 4:
			0: return EntryDirection.TOP_LEFT
			1: return EntryDirection.TOP_RIGHT
			2: return EntryDirection.BOTTOM_LEFT
			3: return EntryDirection.BOTTOM_RIGHT
	elif total_count <= 8:
		# Single row: alternate left/right with some top/bottom
		match index % 4:
			0: return EntryDirection.LEFT
			1: return EntryDirection.RIGHT
			2: return EntryDirection.TOP
			3: return EntryDirection.BOTTOM
	else:
		# Two rows: top row from top, bottom row from bottom
		var top_row_count = ceili(total_count / 2.0)
		if index < top_row_count:
			# Top row dice
			if index % 2 == 0:
				return EntryDirection.TOP_LEFT
			else:
				return EntryDirection.TOP_RIGHT
		else:
			# Bottom row dice
			if index % 2 == 0:
				return EntryDirection.BOTTOM_LEFT
			else:
				return EntryDirection.BOTTOM_RIGHT
	
	return EntryDirection.LEFT


## get_entry_offset(direction: EntryDirection, distance: float) -> Vector2
##
## Returns the starting offset position for a die based on entry direction.
func get_entry_offset(direction: EntryDirection, distance: float = 400.0) -> Vector2:
	match direction:
		EntryDirection.TOP:
			return Vector2(0, -distance)
		EntryDirection.BOTTOM:
			return Vector2(0, distance)
		EntryDirection.LEFT:
			return Vector2(-distance, 0)
		EntryDirection.RIGHT:
			return Vector2(distance, 0)
		EntryDirection.TOP_LEFT:
			return Vector2(-distance * 0.707, -distance * 0.707)
		EntryDirection.TOP_RIGHT:
			return Vector2(distance * 0.707, -distance * 0.707)
		EntryDirection.BOTTOM_LEFT:
			return Vector2(-distance * 0.707, distance * 0.707)
		EntryDirection.BOTTOM_RIGHT:
			return Vector2(distance * 0.707, distance * 0.707)
	return Vector2(-distance, 0)


## get_exit_direction(index: int, total_count: int) -> EntryDirection
##
## Returns exit direction for the die at the given index.
## Typically opposite to entry or radiating outward from center.
func get_exit_direction(index: int, total_count: int) -> EntryDirection:
	# Exit in the opposite direction they came from, or radiate outward
	var entry_dir = get_entry_direction(index, total_count)
	
	# Map to opposite direction
	match entry_dir:
		EntryDirection.TOP:
			return EntryDirection.BOTTOM
		EntryDirection.BOTTOM:
			return EntryDirection.TOP
		EntryDirection.LEFT:
			return EntryDirection.RIGHT
		EntryDirection.RIGHT:
			return EntryDirection.LEFT
		EntryDirection.TOP_LEFT:
			return EntryDirection.BOTTOM_RIGHT
		EntryDirection.TOP_RIGHT:
			return EntryDirection.BOTTOM_LEFT
		EntryDirection.BOTTOM_LEFT:
			return EntryDirection.TOP_RIGHT
		EntryDirection.BOTTOM_RIGHT:
			return EntryDirection.TOP_LEFT
	
	return EntryDirection.RIGHT


## local_to_global_dice_position(local_pos: Vector2) -> Vector2
##
## Converts a local dice position to global coordinates.
func local_to_global_dice_position(local_pos: Vector2) -> Vector2:
	return global_position + local_pos


## get_recommended_size(dice_count: int) -> Vector2
##
## Returns the recommended container size for the given dice count.
func get_recommended_size(dice_count: int) -> Vector2:
	var clamped_count = mini(dice_count, max_dice_per_row * max_rows)
	
	var top_row_count: int
	var bottom_row_count: int
	
	if clamped_count <= max_dice_per_row:
		top_row_count = clamped_count
		bottom_row_count = 0
	else:
		top_row_count = ceili(clamped_count / 2.0)
		bottom_row_count = clamped_count - top_row_count
	
	var width_dice = maxi(top_row_count, bottom_row_count)
	var rows = 1 if bottom_row_count == 0 else 2
	
	var width = (width_dice - 1) * dice_spacing + border_padding * 2 + 64  # 64 = dice size
	var height = row_spacing * (rows - 1) + border_padding * 2 + 64
	
	return Vector2(width, height)
