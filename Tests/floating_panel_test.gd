extends Node2D

## FloatingPanelTest
##
## Visual test for the FloatingNumber background panel feature.
## Spawns floating numbers with varied text, colors, and scales
## on a repeating timer so you can inspect panel sizing and rotation.

const FloatingNumberScript = preload("res://Scripts/Effects/floating_number.gd")

var spawn_timer: float = 0.0
const SPAWN_INTERVAL: float = 0.6

# Test data: [text, font_scale, color]
var test_cases: Array = [
	["+1", 1.0, Color.WHITE],
	["+50", 1.0, Color.WHITE],
	["x2.0", 1.5, Color.CYAN],
	["BONUS!", 1.2, Color.GREEN],
	["ACTIVE!", 1.0, Color.WHITE],
	["-15", 1.2, Color.RED],
	["+5", 0.8, Color.GREEN],
	["x1.5", 1.5, Color.CYAN],
	["$12", 1.0, Color.GREEN],
	["42", 2.0, Color.GOLD],
]

var current_index: int = 0


func _process(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_next()


func _spawn_next() -> void:
	var test = test_cases[current_index]
	current_index = (current_index + 1) % test_cases.size()

	var viewport_size = get_viewport().get_visible_rect().size
	# Spawn at a random horizontal position in the middle third of the screen
	var x = randf_range(viewport_size.x * 0.25, viewport_size.x * 0.75)
	var y = viewport_size.y * 0.6
	var pos = Vector2(x, y)

	var floating = FloatingNumberScript.create_floating_number(
		self, pos, test[0], test[1], test[2]
	)
	if floating:
		var panel_rot = rad_to_deg(floating.panel.rotation) if floating.panel else 0.0
		print("[FloatingPanelTest] Spawned '%s' at %s  panel_rotation=%.1f°" % [
			test[0], str(pos), panel_rot
		])
