extends Node2D

## ScorecardIntegrationTest
##
## Test scene for verifying ScoreCardUI integration into the GameUI container.

const SCREEN_WIDTH: float = 1280.0
const SCREEN_HEIGHT: float = 720.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	add_child(bg)

	var canvas := CanvasLayer.new()
	canvas.name = "UICanvasLayer"
	add_child(canvas)

	var game_ui := preload("res://Scenes/UI/GameUI.tscn").instantiate()
	game_ui.name = "GameUI"
	canvas.add_child(game_ui)

	print("[ScorecardIntegrationTest] ScoreCardUI integrated into ScorecardContainer.")
