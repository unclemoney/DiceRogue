extends Control

## ScorecardBlindsTest
## Isolation test for the scorecard row-list visuals: blinds populate/
## depopulate, chip fill ramp, score-lock dance scaling, best-hand pulse.
## Drives the REAL scenes (Scenes/UI/Scorecard/scorecard.tscn +
## Scenes/ScoreCard/score_card.tscn) with seeded mock data. No mock rows.

@onready var score_card: Scorecard = $ScoreCard
@onready var score_card_ui: ScoreCardUI = $ScoreCardUI


func _ready() -> void:
	score_card_ui.bind_scorecard(score_card)
	_seed_mock_data()


## _seed_mock_data()
##
## Mixed levels (1-25), a few pre-scored rows, and a simulated dice hand so
## ghosts and the best-hand pulse are visible.
func _seed_mock_data() -> void:
	# Levels: upgrade_category raises by 1, so N-1 calls for level N
	_set_level("ones", Scorecard.Section.UPPER, 1)
	_set_level("threes", Scorecard.Section.UPPER, 8)
	_set_level("sixes", Scorecard.Section.UPPER, 20)
	_set_level("full_house", Scorecard.Section.LOWER, 12)
	_set_level("yahtzee", Scorecard.Section.LOWER, 25)
	_set_level("chance", Scorecard.Section.LOWER, 5)

	# Pre-scored rows (set_score takes an optional snapshot dict, unused here)
	score_card.set_score(Scorecard.Section.UPPER, "threes", 12)
	score_card.set_score(Scorecard.Section.LOWER, "full_house", 300)
	score_card.set_score(Scorecard.Section.LOWER, "yahtzee", 960)

	# Simulated hand: straights + chance qualify for ghosts
	DiceResults.set_values([2, 3, 4, 5, 6])
	score_card_ui.update_all()


func _set_level(category: String, section: Scorecard.Section, target: int) -> void:
	for i in target - 1:
		score_card.upgrade_category(section, category)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P:
				_on_populate_pressed()
			KEY_D:
				_on_depopulate_pressed()
			KEY_U:
				_on_upgrade_random_pressed()
			KEY_W:
				_on_downgrade_random_pressed()
			KEY_S:
				_on_score_random_pressed()


func _on_populate_pressed() -> void:
	score_card_ui.play_populate()
	print("[BlindsTest] populate")


func _on_depopulate_pressed() -> void:
	score_card_ui.play_depopulate()
	print("[BlindsTest] depopulate")


func _on_upgrade_random_pressed() -> void:
	var def: Dictionary = ScoreCardUI.CATEGORY_DEFS[randi() % ScoreCardUI.CATEGORY_DEFS.size()]
	score_card.upgrade_category(def["section"], def["key"])
	print("[BlindsTest] upgrade %s -> Lv.%d" % [def["key"], score_card.get_category_level_by_name(def["key"])])


func _on_downgrade_random_pressed() -> void:
	var def: Dictionary = ScoreCardUI.CATEGORY_DEFS[randi() % ScoreCardUI.CATEGORY_DEFS.size()]
	score_card.downgrade_category(def["section"], def["key"])
	print("[BlindsTest] downgrade %s -> Lv.%d" % [def["key"], score_card.get_category_level_by_name(def["key"])])


func _on_score_random_pressed() -> void:
	var open: Array = []
	for def in ScoreCardUI.CATEGORY_DEFS:
		var scores: Dictionary
		if def["section"] == Scorecard.Section.UPPER:
			scores = score_card.upper_scores
		else:
			scores = score_card.lower_scores
		if scores[def["key"]] == null:
			open.append(def)
	if open.is_empty():
		print("[BlindsTest] no open categories")
		return
	var pick: Dictionary = open[randi() % open.size()]
	var value := randi_range(50, 1000)
	score_card.set_score(pick["section"], pick["key"], value)
	print("[BlindsTest] scored %s for %d" % [pick["key"], value])
