extends Node2D

## NumberFormatterTest
##
## Standalone test scene for verifying NumberFormatter output.
## Displays a grid of test values with their formatted results.
## Buttons toggle between metric suffixes and scientific notation.

var _test_values := [0, 999, 1000, 99999, 99999999, 100000000, 1500000000, -5000000, -150000000]
var _result_labels: Array[Label] = []
var _mode_label: Label

func _ready() -> void:
	_display_test_ui()
	_refresh_display()

func _display_test_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(100, 50)
	vbox.add_theme_constant_override("separation", 8)
	root.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "NumberFormatter Test"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# Mode label
	_mode_label = Label.new()
	_mode_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_mode_label)

	# Button row
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)

	var metric_btn := Button.new()
	metric_btn.text = "Metric Suffixes"
	metric_btn.pressed.connect(_on_metric_pressed)
	hbox.add_child(metric_btn)

	var sci_btn := Button.new()
	sci_btn.text = "Scientific Notation"
	sci_btn.pressed.connect(_on_scientific_pressed)
	hbox.add_child(sci_btn)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_display)
	hbox.add_child(refresh_btn)

	# Grid header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	vbox.add_child(header)

	var raw_header := Label.new()
	raw_header.text = "Raw Value"
	raw_header.custom_minimum_size = Vector2(120, 0)
	header.add_child(raw_header)

	var int_header := Label.new()
	int_header.text = "format_int()"
	int_header.custom_minimum_size = Vector2(160, 0)
	header.add_child(int_header)

	var money_header := Label.new()
	money_header.text = "format_money()"
	money_header.custom_minimum_size = Vector2(160, 0)
	header.add_child(money_header)

	# Result rows
	for val in _test_values:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		vbox.add_child(row)

		var raw := Label.new()
		raw.text = str(val)
		raw.custom_minimum_size = Vector2(120, 0)
		row.add_child(raw)

		var int_label := Label.new()
		int_label.custom_minimum_size = Vector2(160, 0)
		row.add_child(int_label)
		_result_labels.append(int_label)

		var money_label := Label.new()
		money_label.custom_minimum_size = Vector2(160, 0)
		row.add_child(money_label)
		_result_labels.append(money_label)

func _refresh_display() -> void:
	var mode_str := "Metric Suffixes" if NumberFormatter.format_mode == NumberFormatter.FormatMode.METRIC_SUFFIXES else "Scientific Notation"
	_mode_label.text = "Mode: " + mode_str

	var idx := 0
	for val in _test_values:
		_result_labels[idx].text = NumberFormatter.format_int(val)
		_result_labels[idx + 1].text = NumberFormatter.format_money(val)
		idx += 2

func _on_metric_pressed() -> void:
	NumberFormatter.format_mode = NumberFormatter.FormatMode.METRIC_SUFFIXES
	_refresh_display()

func _on_scientific_pressed() -> void:
	NumberFormatter.format_mode = NumberFormatter.FormatMode.SCIENTIFIC_NOTATION
	_refresh_display()
