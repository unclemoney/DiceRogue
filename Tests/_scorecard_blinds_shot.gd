extends Node

## _scorecard_blinds_shot.gd (temporary visual verification)
##
## Drives the real ScorecardBlindsTest scene through populate, a score-lock
## dance, and depopulate, saving screenshots at key frames for review.
## Saves to Tests/_layout_shots/. Run windowed (NOT headless):
##   godot --path . Tests/_scorecard_blinds_shot.tscn

const BLINDS_TEST := preload("res://Tests/ScorecardBlindsTest.tscn")

var _test: Control


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test = BLINDS_TEST.instantiate()
	add_child(_test)

	# Let bind + mock seeding settle; rows start covered.
	await get_tree().create_timer(0.5).timeout
	await _shot("blinds_0_covered.png")

	# Populate: catch the mid-wipe stagger, then the settled card.
	_test._on_populate_pressed()
	await get_tree().create_timer(0.35).timeout
	await _shot("blinds_1_populate_mid.png")
	await get_tree().create_timer(0.9).timeout
	await _shot("blinds_2_populate_done.png")

	# Score a random open row (50-1000) and catch the dance mid-flight.
	_test._on_score_random_pressed()
	await get_tree().create_timer(0.15).timeout
	await _shot("blinds_3_dance_mid.png")
	await get_tree().create_timer(0.6).timeout
	await _shot("blinds_4_dance_done.png")

	# Depopulate: mid-wipe (bottom-to-top), then fully covered.
	_test._on_depopulate_pressed()
	await get_tree().create_timer(0.3).timeout
	await _shot("blinds_5_depopulate_mid.png")
	await get_tree().create_timer(0.8).timeout
	await _shot("blinds_6_depopulate_done.png")

	get_tree().quit(0)


func _shot(file_name: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "res://Tests/_layout_shots/" + file_name
	var err := img.save_png(path)
	print("[BlindsShot] saved %s (err=%d)" % [path, err])
