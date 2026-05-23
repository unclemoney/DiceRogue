extends Control

## ScorecardUpgradeJuiceTest
## Test scene for verifying scorecard level upgrade juice (bounce, flash, particles, sound).

@onready var scorecard: Scorecard = $ScoreCard
@onready var score_card_ui: ScoreCardUI = $ScoreCardUI
@onready var test_output: RichTextLabel = $VBoxContainer/TestOutput

func _ready() -> void:
	score_card_ui.scorecard = scorecard
	scorecard.category_upgraded.connect(score_card_ui._on_category_upgraded)
	scorecard.score_changed.connect(score_card_ui._on_score_changed)
	scorecard.total_score_changed.connect(score_card_ui._on_total_score_changed)
	scorecard.upper_bonus_changed.connect(score_card_ui._on_upper_bonus_changed)
	scorecard.yahtzee_bonus_changed.connect(score_card_ui._on_yahtzee_bonus_changed)
	scorecard.bonus_changed.connect(score_card_ui._on_bonus_changed)
	score_card_ui.update_all()
	add_log("Scorecard Upgrade Juice Test Ready")
	add_log("Click buttons to test juice FX")

func add_log(text: String) -> void:
	test_output.text += text + "\n"

func _on_upgrade_single_juice() -> void:
	score_card_ui.enable_upgrade_juice(1)
	scorecard.upgrade_category(Scorecard.Section.UPPER, "ones")
	add_log("Upgraded 'ones' with juice")

func _on_upgrade_all_juice() -> void:
	score_card_ui.enable_upgrade_juice(13)
	for cat in scorecard.upper_scores.keys():
		scorecard.upgrade_category(Scorecard.Section.UPPER, cat)
	for cat in scorecard.lower_scores.keys():
		scorecard.upgrade_category(Scorecard.Section.LOWER, cat)
	add_log("Upgraded all categories with juice")

func _on_upgrade_single_no_juice() -> void:
	scorecard.upgrade_category(Scorecard.Section.UPPER, "twos")
	add_log("Upgraded 'twos' without juice (basic flash)")
