extends Control

var scorecard: Scorecard

func bind_scorecard(sc: Scorecard):
	scorecard = sc
	update_all()
	connect_buttons()

func update_all():
	for category in scorecard.upper_scores.keys():
		var label = get_node_or_null("HBoxContainer/UpperVBoxContainer/UpperGridContainer/" + category.capitalize() + "Container/" + category.capitalize() + "Label")
		if label:
			var value = scorecard.upper_scores[category]
			label.text = str(value if value != null else "-")

	for category in scorecard.lower_scores.keys():
		var label = get_node_or_null("HBoxContainer/LowerVBoxContainer/LowerGridContainer/" + category.capitalize() + "Container/" + category.capitalize() + "Label")
		if label:
			var value = scorecard.lower_scores[category]
			label.text = str(value if value != null else "-")

func connect_buttons():
	for category in scorecard.upper_scores.keys():
		var button = get_node_or_null("HBoxContainer/UpperVBoxContainer/UpperGridContainer/" + category.capitalize() + "Container/" + category.capitalize() + "Button")
		if button:
			button.pressed.connect(func(): on_category_selected(Scorecard.Section.UPPER, category))

	for category in scorecard.lower_scores.keys():
		var button = get_node_or_null("HBoxContainer/LowerVBoxContainer/LowerGridContainer/" + category.capitalize() + "Container/" + category.capitalize() + "Button")
		if button:
			button.pressed.connect(func(): on_category_selected(Scorecard.Section.LOWER, category))

func on_category_selected(section: Scorecard.Section, category: String):
	var values = DiceResults.values
	var score = ScoreEvaluatorSingleton.calculate_score_for_category(category, values)

	if score == -1:
		show_invalid_score_feedback(category)
		return


	scorecard.set_score(section, category, score)
	update_all()

func show_invalid_score_feedback(category: String):
	print("Invalid score: Dice do not match category '%s'" % category)

	# Optional: flash button red
	var button = get_node_or_null("HBoxContainer/.../" + category.capitalize() + "Button")
	if button:
		var tween := get_tree().create_tween()
		tween.tween_property(button, "modulate", Color.RED, 0.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(button, "modulate", Color.WHITE, 0.2).set_delay(0.2)
