extends Node

## _ui_polish_shot.gd (temporary visual verification)
##
## Drives DebuffTest through round start, a roll, and a score commit,
## saving screenshots to Tests/_layout_shots/ for the UI polish pass:
## title/challenge rebalance, powerup strip centering, ghost wipe on score.
## Run windowed (NOT headless):
##   godot --path . Tests/_ui_polish_shot.tscn

const DEBUFF_TEST := preload("res://Tests/DebuffTest.tscn")

var _game: Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_game = DEBUFF_TEST.instantiate()
	add_child(_game)

	# Let boot + store-select screen settle
	await get_tree().create_timer(4.0).timeout

	# Press START on the store-select screen so round 1 actually begins
	var store_selects := get_tree().root.find_children("*", "ChannelManagerUI", true, false)
	if not store_selects.is_empty():
		store_selects[0]._on_start_pressed()
		print("[PolishShot] START pressed")
	# Round intro: banner (~2s) + scorecard entrance + target setup.
	# Poll until the store is live (zone label + target) before proceeding.
	var game_controller := get_tree().get_first_node_in_group("game_controller")
	var intro_waited := 0.0
	while intro_waited < 40.0:
		var cui = game_controller.get("challenge_ui") if game_controller else null
		if cui and cui.get("_zone_label") and cui._zone_label.text != "" and game_controller.get("_current_round_target") > 0:
			break
		await get_tree().create_timer(0.5).timeout
		intro_waited += 0.5
	print("[PolishShot] intro settled after %.1fs" % intro_waited)

	var score_card_ui := get_tree().get_first_node_in_group("scorecard_ui")
	var power_up_ui := get_tree().get_first_node_in_group("power_up_ui")

	# Seed powerups so the strip has icons to center
	if game_controller and game_controller.get("pu_manager"):
		var available: Array = game_controller.pu_manager.get_available_power_ups()
		for i in range(mini(4, available.size())):
			game_controller.grant_power_up(available[i])
	await get_tree().create_timer(1.0).timeout

	_diag(game_controller, score_card_ui, power_up_ui, "round_start")
	await _shot("polish_1_round_start.png")

	# Roll: ghosts should appear, challenge bar should still be at 0.
	# Wait until the round intro has fully finished and rolling is allowed.
	var roll_button_ui := get_tree().get_first_node_in_group("roll_button_ui")
	var dice_hand := get_tree().get_first_node_in_group("dice_hand")
	var waited := 0.0
	while waited < 30.0:
		var turn_tracker = game_controller.get("turn_tracker") if game_controller else null
		if roll_button_ui and not roll_button_ui._roll_in_progress and turn_tracker and turn_tracker.rolls_left > 0:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if roll_button_ui:
		roll_button_ui._on_roll_button_pressed()
	if dice_hand:
		await dice_hand.roll_complete
	await get_tree().create_timer(1.0).timeout
	_diag(game_controller, score_card_ui, power_up_ui, "after_roll")
	await _shot("polish_2_after_roll.png")

	# Score Chance: ghosts must wipe, bar sweeps, total punches
	if score_card_ui and score_card_ui.scorecard:
		var chance_val = score_card_ui.scorecard.preview_base_score("chance", DiceResults.values)
		print("[PolishShot] scoring chance for ~", chance_val)
		score_card_ui.on_category_selected(Scorecard.Section.LOWER, "chance")
	await get_tree().create_timer(0.8).timeout
	_diag(game_controller, score_card_ui, power_up_ui, "after_score")
	await _shot("polish_3_after_score.png")

	# Force overflow on the challenge bar: hot variant + fast sheen, then frozen
	if game_controller and game_controller.get("challenge_ui"):
		var cui = game_controller.challenge_ui
		cui.set_store_score(int(cui._store_target * 1.2), cui._store_target)
		await get_tree().create_timer(0.5).timeout
		await _shot("polish_4_overflow_sheen.png")
		await get_tree().create_timer(2.4).timeout
		await _shot("polish_5_overflow_frozen.png")

	get_tree().quit(0)


func _diag(game_controller: Node, score_card_ui: Node, power_up_ui: Node, tag: String) -> void:
	print("[PolishShot] ---- %s ----" % tag)
	if score_card_ui:
		print("[PolishShot] turn_scored=%s _has_roll_context=%s" % [
			score_card_ui.turn_scored, score_card_ui._has_roll_context])
		var ghosts := 0
		for key in score_card_ui.rows.keys():
			var row = score_card_ui.rows[key]
			if row.score_label and row.score_label.text != "" and row.state != row.State.SCORED:
				ghosts += 1
		print("[PolishShot] visible ghost labels: %d" % ghosts)
	if power_up_ui:
		var slots: Array = power_up_ui.get("_slot_contents")
		if slots and not slots.is_empty():
			print("[PolishShot] slot0 size=%s global=%s" % [slots[0].size, slots[0].global_position])
		var spines: Dictionary = power_up_ui.get("_spines")
		for id in spines.keys():
			var spine = spines[id]
			if spine.visible:
				print("[PolishShot] spine %s pos=%s parent=%s" % [id, spine.position, spine.get_parent().name])
	if game_controller and game_controller.get("challenge_ui"):
		var cui = game_controller.challenge_ui
		if cui and cui.get("_panel"):
			print("[PolishShot] challenge panel rect=%s zone='%s' progress='%s' total='%s'" % [
				cui._panel.get_global_rect(), cui._zone_label.text,
				cui._progress_label.text, cui._total_label.text])


func _shot(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "res://Tests/_layout_shots/" + file_name
	var err := img.save_png(path)
	print("[PolishShot] saved %s (err=%d)" % [path, err])
