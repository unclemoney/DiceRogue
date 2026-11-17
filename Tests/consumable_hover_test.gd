extends Control

## Simple test to create a ConsumableIcon and check its hover tooltip

@onready var test_label: Label = $TestLabel

func _ready() -> void:
	test_label = Label.new()
	test_label.text = "Testing Consumable Coupon Hover - Hover over the coupon below"
	test_label.position = Vector2(10, 10)
	add_child(test_label)
	
	_create_test_consumable()
	if "--auto-test" in OS.get_cmdline_user_args():
		call_deferred("_run_title_test")

func _create_test_consumable() -> void:
	# Load test consumable data
	var test_consumable_data = load("res://Scripts/Consumable/QuickCashConsumable.tres") as ConsumableData
	
	if test_consumable_data:
		var consumable_icon = preload("res://Scenes/Consumable/consumable_coupon.tscn").instantiate() as ConsumableIcon
		consumable_icon.position = Vector2(60, 100)
		consumable_icon.data = test_consumable_data
		add_child(consumable_icon)
		print("[ConsumableHoverTest] Created consumable icon: ", test_consumable_data.display_name)
	else:
		print("[ConsumableHoverTest] Failed to load consumable data")
		test_label.text = "ERROR: Failed to load consumable data"


func _run_title_test() -> void:
	await get_tree().process_frame
	var icon := get_child(get_child_count() - 1) as ConsumableIcon
	var failures := 0
	if not icon or not icon.coupon_title_label:
		failures += 1
	else:
		var label := icon.coupon_title_label
		if label.get_theme_font_size("font_size") != 12 or not label.clip_text or label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			failures += 1
		if not is_equal_approx(label.custom_minimum_size.y, 34.0):
			failures += 1
	print("[ConsumableHoverTest] Fixed title: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("res://Tests/_layout_shots/ui_polish_consumable.png")
	get_tree().quit(0 if failures == 0 else 1)