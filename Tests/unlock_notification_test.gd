extends Control

## UnlockNotificationTest
##
## Test scene for the refactored UnlockNotificationUI.
## Tests scrollable list, drop-bounce animations, hover tooltips, and OK dismiss.

var _unlock_ui: UnlockNotificationUI
var _output_label: RichTextLabel
var _output_lines: Array[String] = []

# Mix of item types for testing
const TEST_ITEMS_3 := ["extra_dice", "quick_cash", "even_only"]
const TEST_ITEMS_5 := ["extra_dice", "quick_cash", "even_only", "bonus_money", "any_score"]
const TEST_ITEMS_12 := [
	"extra_dice", "quick_cash", "even_only", "bonus_money", "any_score",
	"odd_only", "gold_six", "extra_rolls", "allowance", "melting_dice",
	"foursome", "score_reroll"
]


func _ready() -> void:
	_build_test_ui()
	
	# Instantiate the UnlockNotificationUI
	_unlock_ui = preload("res://Scenes/UI/UnlockNotificationUI.tscn").instantiate()
	add_child(_unlock_ui)
	_unlock_ui.all_items_acknowledged.connect(_on_all_acknowledged)
	
	_log("[color=gold]Unlock Notification UI Test[/color]")
	_log("Click a button to test with different item counts.")
	_log("")


func _build_test_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Control panel on the left
	var panel = PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(250, 400)
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Unlock Notification Test"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	vbox.add_child(title)
	
	# Buttons
	var btn_3 = Button.new()
	btn_3.text = "Test 3 Items"
	btn_3.pressed.connect(_test_3_items)
	vbox.add_child(btn_3)
	
	var btn_5 = Button.new()
	btn_5.text = "Test 5 Items"
	btn_5.pressed.connect(_test_5_items)
	vbox.add_child(btn_5)
	
	var btn_12 = Button.new()
	btn_12.text = "Test 12 Items (scroll)"
	btn_12.pressed.connect(_test_12_items)
	vbox.add_child(btn_12)
	
	var btn_1 = Button.new()
	btn_1.text = "Test 1 Item"
	btn_1.pressed.connect(_test_1_item)
	vbox.add_child(btn_1)
	
	var btn_0 = Button.new()
	btn_0.text = "Test 0 Items (edge)"
	btn_0.pressed.connect(_test_0_items)
	vbox.add_child(btn_0)
	
	# Separator
	vbox.add_child(HSeparator.new())
	
	# Output log
	_output_label = RichTextLabel.new()
	_output_label.bbcode_enabled = true
	_output_label.custom_minimum_size = Vector2(226, 200)
	_output_label.scroll_following = true
	_output_label.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(_output_label)


func _test_3_items() -> void:
	_log("Showing 3 items...")
	_unlock_ui.queue_items(TEST_ITEMS_3)


func _test_5_items() -> void:
	_log("Showing 5 items...")
	_unlock_ui.queue_items(TEST_ITEMS_5)


func _test_12_items() -> void:
	_log("Showing 12 items (should scroll)...")
	_unlock_ui.queue_items(TEST_ITEMS_12)


func _test_1_item() -> void:
	_log("Showing 1 item...")
	_unlock_ui.queue_items(["extra_dice"])


func _test_0_items() -> void:
	_log("Showing 0 items (empty array)...")
	_unlock_ui.queue_items([])


func _on_all_acknowledged() -> void:
	_log("[color=lime]✓ all_items_acknowledged signal received[/color]")


func _log(text: String) -> void:
	_output_lines.append(text)
	if _output_lines.size() > 50:
		_output_lines.pop_front()
	_output_label.text = "\n".join(_output_lines)
