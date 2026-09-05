extends Control

## ScorecardUpgradeJuiceTest
## Test scene for verifying scorecard level upgrade animations on the new
## row-list scorecard: chip punch (no juice) and elastic settle + particles
## + once-per-batch sound (juice).

@onready var scorecard: Scorecard = $ScoreCard
@onready var score_card_ui: ScoreCardUI = $ScoreCardUI
@onready var test_output: RichTextLabel = $VBoxContainer/TestOutput

func _ready() -> void:
	score_card_ui.bind_scorecard(scorecard)
	# Rows start covered (blinds) by design; reveal them for this visual test
	score_card_ui.play_populate()
	add_log("Scorecard Upgrade Juice Test Ready")
	add_log("Click buttons to test upgrade animations")

func add_log(text: String) -> void:
	test_output.text += text + "\n"

func _on_upgrade_single_juice() -> void:
	score_card_ui.enable_upgrade_juice(1)
	scorecard.upgrade_category(Scorecard.Section.UPPER, "ones")
	add_log("Upgraded 'ones' with juice")
	await get_tree().create_timer(0.6).timeout
	var chip: LevelChip = score_card_ui.rows[&"ones"].level_chip
	if chip.level == 2:
		add_log("PASS: ones chip numeral is 2")
	else:
		push_error("[ScorecardUpgradeJuiceTest] ones chip numeral is %d, expected 2" % chip.level)
		add_log("FAIL: ones chip numeral is %d" % chip.level)

func _on_upgrade_all_juice() -> void:
	score_card_ui.enable_upgrade_juice(13)
	for cat in scorecard.upper_scores.keys():
		scorecard.upgrade_category(Scorecard.Section.UPPER, cat)
	for cat in scorecard.lower_scores.keys():
		scorecard.upgrade_category(Scorecard.Section.LOWER, cat)
	add_log("Upgraded all categories with juice")

func _on_upgrade_single_no_juice() -> void:
	scorecard.upgrade_category(Scorecard.Section.UPPER, "twos")
	add_log("Upgraded 'twos' without juice (base punch)")
	await get_tree().create_timer(0.6).timeout
	var chip: LevelChip = score_card_ui.rows[&"twos"].level_chip
	if chip.level == 2:
		add_log("PASS: twos chip numeral is 2")
	else:
		push_error("[ScorecardUpgradeJuiceTest] twos chip numeral is %d, expected 2" % chip.level)
		add_log("FAIL: twos chip numeral is %d" % chip.level)
