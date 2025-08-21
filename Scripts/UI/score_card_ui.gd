extends Control

var scorecard: Scorecard
var category_buttons := {}
var category_labels := {}
var turn_scored := false
var upper_section_buttons := {}
var lower_section_buttons := {}

signal hand_scored

const LOWER_CATEGORY_NODE_NAMES := {
	"three_of_a_kind": "Threeofakind",
	"four_of_a_kind": "Fourofakind",
	"full_house": "Fullhouse",
	"small_straight": "Smallstraight",
	"large_straight": "Largestraight",
	"yahtzee": "Yahtzee",
	"chance": "Chance"
}

func _ready():
	for key in LOWER_CATEGORY_NODE_NAMES.keys():
		var node_name = LOWER_CATEGORY_NODE_NAMES[key]
		var button_path = "HBoxContainer/LowerVBoxContainer/LowerGridContainer/%s/%sButton" % [node_name, node_name]
		var label_path = "HBoxContainer/LowerVBoxContainer/LowerGridContainer/%s/%sLabel" % [node_name, node_name]

		var button = get_node_or_null(button_path)
		var label = get_node_or_null(label_path)

		if button:
			category_buttons[key] = button
		else:
			print("❌ Button not found for:", key, "→", button_path)

		if label:
			category_labels[key] = label
		else:
			print("❌ Label not found for:", key, "→", label_path)

func bind_scorecard(sc: Scorecard):
	scorecard = sc
	update_all()
	connect_buttons()

func update_all():
	for category in scorecard.upper_scores.keys():
		var label_path = "HBoxContainer/UpperVBoxContainer/UpperGridContainer/" + category.capitalize() + "Container/" + category.capitalize() + "Label"
		var label = get_node_or_null(label_path)
		if label:
			var value = scorecard.upper_scores[category]
			label.text = str(value if value != null else "-")

	for category in scorecard.lower_scores.keys():
		var node_name = LOWER_CATEGORY_NODE_NAMES.get(category, category.capitalize())
		var label_path = "HBoxContainer/LowerVBoxContainer/LowerGridContainer/" + node_name + "/" + node_name + "Label"
		var label = get_node_or_null(label_path)
		if label:
			var value = scorecard.lower_scores[category]
			label.text = str(value if value != null else "-")


func connect_buttons():
	# Upper section
	for category in scorecard.upper_scores.keys():
		var button_path = "HBoxContainer/UpperVBoxContainer/UpperGridContainer/" + category.capitalize() + "Container/" + category.capitalize() + "Button"
		var button = get_node_or_null(button_path)
		if button:
			button.pressed.connect(func(): on_category_selected(Scorecard.Section.UPPER, category))
			#print("Connected upper button for:", button)
			upper_section_buttons[category] = button

	# Lower section
	for category in scorecard.lower_scores.keys():
		var node_name = LOWER_CATEGORY_NODE_NAMES.get(category, category.capitalize())
		var button_path = "HBoxContainer/LowerVBoxContainer/LowerGridContainer/" + node_name + "/" + node_name + "Button"
		var button = get_node_or_null(button_path)
		if button:
			button.pressed.connect(func(): on_category_selected(Scorecard.Section.LOWER, category))
			#print("Connected lower button for:", button)
			lower_section_buttons[category] = button
		else:
			print("❌ Lower button not found for:", category, "→", button_path)

func on_category_selected(section: Scorecard.Section, category: String):
	if turn_scored:
		print("⚠️ Score already assigned this turn.")
		return

	var values = DiceResults.values
	var score = ScoreEvaluatorSingleton.calculate_score_for_category(category, values)
	print("Category selected:", section, category, "→", score)

	if score == null:
		show_invalid_score_feedback(category)
		return

	scorecard.set_score(section, category, score)
	update_all()
	turn_scored = true
	disable_all_score_buttons()
	emit_signal("hand_scored")

func disable_all_score_buttons():
	for button in upper_section_buttons.values():
		button.disabled = true
	for button in lower_section_buttons.values():
		button.disabled = true

func enable_all_score_buttons():
	for button in upper_section_buttons.values():
		button.disabled = false
	for button in lower_section_buttons.values():
		button.disabled = false

func allow_extra_score():
	turn_scored = false
	print("🔓 Extra score allowed this turn.")

func show_invalid_score_feedback(category: String):
	print("Invalid score: Dice do not match category '%s'" % category)

	# Optional: flash button red
	var button = get_node_or_null("HBoxContainer/.../" + category.capitalize() + "Button")
	if button:
		var tween := get_tree().create_tween()
		tween.tween_property(button, "modulate", Color.RED, 0.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(button, "modulate", Color.WHITE, 0.2).set_delay(0.2)
