extends Control

## round_transition_test.gd
##
## Test scene for RoundTransitionOverlay. Provides buttons to trigger
## the overlay with different configurations: normal round, final round.

const OverlayScript := preload("res://Scripts/UI/round_transition_overlay.gd")
var _overlay: CanvasLayer = null

@onready var _output_label: RichTextLabel = $VBox/OutputLabel


func _ready() -> void:
	_log("Round Transition Overlay Test Ready")
	_log("Click a button to test the overlay.")


func _log(msg: String) -> void:
	print("[RoundTransitionTest] %s" % msg)
	if _output_label:
		_output_label.append_text(msg + "\n")


func _on_normal_round_pressed() -> void:
	_log("Showing overlay: Normal Round (Round 3)")
	_show_overlay({
		"round_number": 3,
		"challenge_name": "Score 200 Points",
		"next_challenge_name": "Full House Frenzy",
		"next_challenge_target": 300,
		"is_final_round": false,
	})


func _on_final_round_pressed() -> void:
	_log("Showing overlay: Final Round (Round 6)")
	_show_overlay({
		"round_number": 6,
		"challenge_name": "Yahtzee Master",
		"next_challenge_name": "",
		"next_challenge_target": 0,
		"is_final_round": true,
	})


func _on_early_round_pressed() -> void:
	_log("Showing overlay: Early Round (Round 1)")
	_show_overlay({
		"round_number": 1,
		"challenge_name": "Warm Up",
		"next_challenge_name": "Three of a Kind Scramble",
		"next_challenge_target": 150,
		"is_final_round": false,
	})


func _show_overlay(data: Dictionary) -> void:
	# Clean up existing overlay
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null

	_overlay = OverlayScript.new()
	add_child(_overlay)

	_overlay.keep_playing_pressed.connect(_on_keep_playing)
	_overlay.enter_shop_pressed.connect(_on_enter_shop)

	_overlay.show_transition(data)


func _on_keep_playing() -> void:
	_log(">> Signal received: keep_playing_pressed")
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null


func _on_enter_shop() -> void:
	_log(">> Signal received: enter_shop_pressed")
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
