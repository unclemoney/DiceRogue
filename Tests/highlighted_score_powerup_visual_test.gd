extends Node2D

const SCORECARD_UI_SCENE := preload("res://Scenes/UI/score_card_ui.tscn")


## _ready()
##
## Runtime smoke test for the Highlighted Score shader overlay and trigger burst.
## Instantiates the scorecard UI, binds a fresh Scorecard, plays the highlight,
## then triggers the burst animation before quitting.
func _ready() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.04, 0.09, 1.0)
	bg.size = Vector2(1280.0, 720.0)
	add_child(bg)

	var canvas := CanvasLayer.new()
	canvas.name = "UICanvasLayer"
	add_child(canvas)

	var scorecard_ui := SCORECARD_UI_SCENE.instantiate() as ScoreCardUI
	if not scorecard_ui:
		push_error("[HighlightedScorePowerUpVisualTest] Failed to instantiate ScoreCardUI scene")
		get_tree().quit(1)
		return
	canvas.add_child(scorecard_ui)

	await get_tree().process_frame

	var scorecard := Scorecard.new()
	scorecard_ui.bind_scorecard(scorecard)

	await get_tree().process_frame

	var highlight_applied = scorecard_ui.set_power_up_highlight(Scorecard.Section.UPPER, "ones")
	if not highlight_applied:
		push_error("[HighlightedScorePowerUpVisualTest] Could not apply highlight to Ones")
		get_tree().quit(1)
		return

	var ones_button = scorecard_ui.upper_section_buttons.get("ones") as Button
	if not ones_button or not ones_button.get_node_or_null("HighlightedScoreBorder"):
		push_error("[HighlightedScorePowerUpVisualTest] Highlight overlay missing from Ones button")
		get_tree().quit(1)
		return

	print("[HighlightedScorePowerUpVisualTest] Highlight overlay applied")

	await get_tree().create_timer(0.2).timeout
	scorecard_ui.play_power_up_highlight_trigger(Scorecard.Section.UPPER, "ones")
	print("[HighlightedScorePowerUpVisualTest] Trigger burst played")

	await get_tree().create_timer(1.8).timeout
	get_tree().quit(0)