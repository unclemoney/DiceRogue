extends Control

## bbcode_test.gd
## Test to diagnose BBCode formatting issues in RichTextLabel

@onready var test_label: RichTextLabel = $VBoxContainer/TestLabel
@onready var results_label: Label = $VBoxContainer/ResultsLabel

func _ready():
	print("\n=== BBCODE TEST ===")
	await get_tree().process_frame
	test_bbcode_formatting()

func test_bbcode_formatting():
	print("\n--- Test: BBCode Formatting ---")
	
	if not test_label:
		update_results("FAIL: Test label not found")
		return
	
	# Test 1: Simple BBCode
	print("Test 1: Simple color formatting")
	test_label.text = "[color=red]This should be red[/color]"
	update_results("Test 1: Simple color - " + ("PASS" if test_label.text.contains("[color=red]") else "FAIL"))
	
	await get_tree().create_timer(2.0).timeout
	
	# Test 2: Complex BBCode with alpha
	print("Test 2: Complex formatting with alpha")
	var complex_text = "[color=green][alpha=0.8]This should be green and faded[/alpha][/color]"
	test_label.text = complex_text
	update_results("Test 2: Complex formatting - Set")
	
	await get_tree().create_timer(2.0).timeout
	
	# Test 3: Multiple lines with BBCode
	print("Test 3: Multiple lines with formatting")
	var multi_line = "[color=blue]Line 1: Blue text[/color]\n[color=yellow][alpha=0.6]Line 2: Yellow faded[/alpha][/color]\n[color=red]Line 3: Red text[/color]"
	test_label.text = multi_line
	update_results("Test 3: Multi-line formatting - Set")
	
	await get_tree().create_timer(2.0).timeout
	
	# Test 4: Simulate the logbook format
	print("Test 4: Logbook-style formatting")
	var logbook_style = simulate_logbook_format()
	test_label.text = logbook_style
	update_results("Test 4: Logbook style - Set")
	
	print("BBCode parsing enabled:", test_label.bbcode_enabled)
	update_results("BBCode enabled: " + str(test_label.bbcode_enabled))

func simulate_logbook_format() -> String:
	# Simulate what the logbook function creates
	var sample_logs = [
		"Roll 1 → Fives [2,5,5,5,6] = 20pts",
		"Roll 2 → Chance [1,2,3,4,5] = 15pts",
		"Roll 3 → Yahtzee [4,4,4,4,4] = 50pts"
	]
	
	var bbcode_lines: Array[String] = []
	
	for i in range(sample_logs.size()):
		var line = sample_logs[i]
		var alpha = 1.0 - (i * 0.2)
		alpha = max(alpha, 0.4)
		
		# Color based on score effectiveness with fading
		var base_color = Color.WHITE
		if "=" in line:
			var score_part = line.split("=")[-1].strip_edges()
			var score_str = score_part.replace("pts", "").strip_edges()
			var score = score_str.to_int()
			if score >= 20:
				base_color = Color.GREEN
			elif score >= 10:
				base_color = Color.YELLOW
			else:
				base_color = Color.ORANGE
		
		# Apply alpha to the base color
		var faded_color = Color(base_color.r, base_color.g, base_color.b, alpha)
		
		# Convert to hex for BBCode (including alpha)
		var hex_color = "#%02x%02x%02x%02x" % [int(faded_color.r * 255), int(faded_color.g * 255), int(faded_color.b * 255), int(faded_color.a * 255)]
		
		bbcode_lines.append("[color=%s]%s[/color]" % [hex_color, line])
	
	return "\n".join(bbcode_lines)

func update_results(text: String):
	if results_label:
		if results_label.text == "":
			results_label.text = text
		else:
			results_label.text += "\n" + text