extends Control

## logbook_display_test.gd
## Test to verify that logbook entries display correctly with rich text formatting

@onready var scorecard_ui = $ScoreCardUI
@onready var results_label = $VBoxContainer/ResultsLabel

func _ready():
	print("\n=== LOGBOOK DISPLAY TEST ===")
	await get_tree().process_frame
	test_logbook_display()

func test_logbook_display():
	print("\n--- Test: Logbook BBCode Display ---")
	
	if not scorecard_ui:
		update_results("FAIL: ScoreCardUI not found")
		return
	
	# Verify ExtraInfo label exists and is configured
	var extra_info_label = scorecard_ui.extra_info_label
	if not extra_info_label:
		update_results("FAIL: ExtraInfo label not found in ScoreCardUI")
		return
	
	if not extra_info_label is RichTextLabel:
		update_results("FAIL: ExtraInfo is not a RichTextLabel")
		return
	
	if not extra_info_label.bbcode_enabled:
		update_results("FAIL: BBCode not enabled on ExtraInfo label")
		return
	
	update_results("PASS: ExtraInfo label properly configured")
	
	# Test direct BBCode formatting
	print("Testing direct BBCode formatting...")
	var test_bbcode = "[color=#ff0000ff]Red text[/color]\n[color=#00ff0080]Green faded text[/color]\n[color=#0000ffff]Blue text[/color]"
	extra_info_label.text = test_bbcode
	extra_info_label.visible = true
	
	update_results("Test BBCode applied - check visually for colors")
	
	# Wait and then test logbook formatting
	await get_tree().create_timer(3.0).timeout
	
	# Test logbook function if Statistics is available
	if Statistics:
		print("Testing logbook formatting function...")
		# Create some fake logbook entries with correct parameters
		Statistics.log_hand_scored(
			[5,5,5,2,3],     # dice_values: Array[int]
			["Red","Red","Red","Green","Blue"],  # dice_colors: Array[String] 
			[],              # dice_mods: Array[String]
			"fives",         # category: String
			"upper",         # section: String
			[],              # consumables: Array[String]
			[],              # powerups: Array[String]
			15,              # base_score: int
			[],              # effects: Array[Dictionary]
			15               # final_score: int
		)
		Statistics.log_hand_scored(
			[4,4,4,4,4],     # dice_values: Array[int]
			["Purple","Purple","Purple","Purple","Purple"],  # dice_colors: Array[String]
			[],              # dice_mods: Array[String]
			"yahtzee",       # category: String
			"lower",         # section: String
			[],              # consumables: Array[String]
			["StepByStep"],  # powerups: Array[String]
			50,              # base_score: int
			[{"type": "multiplier", "value": 2}],  # effects: Array[Dictionary]
			100              # final_score: int
		)
		
		# Now test the actual logbook display function
		scorecard_ui.update_extra_info_with_logbook(2)
		update_results("Logbook function called - check for formatted entries")
	else:
		update_results("SKIP: Statistics manager not available")

func update_results(text: String):
	if results_label:
		if results_label.text == "":
			results_label.text = text
		else:
			results_label.text += "\n" + text