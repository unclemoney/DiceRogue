extends Control

## Test script for verifying paged single-row ShopUI behavior.
##
## Validates that:
## 1. Footer arrows appear only when a tab pool exceeds 3 items.
## 2. Page navigation advances by full pages.
## 3. POGS footer includes the shader-backed reroll shell.
## 4. PowerUp shop expansions clamp at 6 items.
## 5. Mods and Colors tabs get the embedded ownership stock board.
## 6. Archive tabs still exist after the layout refactor.

var shop_ui: ShopUI
var test_completed := false
var _fail_count := 0

func _ready() -> void:
	print("=== Shop Pagination Test ===")
	_setup_managers()
	_setup_shop_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	_run_tests()

func _setup_managers() -> void:
	var power_up_manager = preload("res://Scripts/Managers/PowerUpManager.gd").new()
	power_up_manager.name = "PowerUpManager"
	add_child(power_up_manager)
	var consumable_manager = preload("res://Scripts/Managers/ConsumableManager.gd").new()
	consumable_manager.name = "ConsumableManager"
	add_child(consumable_manager)
	var mod_manager = preload("res://Scripts/Managers/ModManager.gd").new()
	mod_manager.name = "ModManager"
	add_child(mod_manager)

func _setup_shop_ui() -> void:
	var shop_scene = preload("res://Scenes/UI/shop_ui.tscn")
	shop_ui = shop_scene.instantiate()
	shop_ui.power_up_manager_path = get_node("PowerUpManager").get_path()
	shop_ui.consumable_manager_path = get_node("ConsumableManager").get_path()
	shop_ui.mod_manager_path = get_node("ModManager").get_path()
	add_child(shop_ui)
	shop_ui.show()

func _run_tests() -> void:
	if not shop_ui:
		print("✗ ShopUI missing")
		return
	print("--- Forcing paged item pools ---")
	var power_pool: Array = [
		load("res://Scripts/PowerUps/Allowance.tres"),
		load("res://Scripts/PowerUps/BonusMoneyPowerUp.tres"),
		load("res://Scripts/PowerUps/ChoreSprintPowerUp.tres"),
		load("res://Scripts/PowerUps/WildDotsPowerUp.tres"),
	]
	power_pool = power_pool.filter(func(item): return item != null)
	if power_pool.size() < 4:
		print("! Not enough test power-up resources to force multi-page test; found %d" % power_pool.size())
	else:
		print("--- 3 item threshold check ---")
		var threshold_pool = power_pool.duplicate()
		threshold_pool.resize(3)
		shop_ui._set_tab_item_pool("power_up", threshold_pool)
		shop_ui._set_page_index("power_up", 0)
		shop_ui._render_current_page("power_up")
		await get_tree().process_frame
		var threshold_footer = shop_ui._footer_controls.get("power_up", {})
		var threshold_left = threshold_footer.get("left_button") as Button
		var threshold_right = threshold_footer.get("right_button") as Button
		print("3-item left arrow visible: %s" % str(threshold_left and threshold_left.visible))
		print("3-item right arrow visible: %s" % str(threshold_right and threshold_right.visible))

		print("--- 4 item pagination check ---")
		shop_ui._set_tab_item_pool("power_up", power_pool)
		shop_ui._set_page_index("power_up", 0)
		shop_ui._render_current_page("power_up")
		await get_tree().process_frame
		var footer = shop_ui._footer_controls.get("power_up", {})
		var left_button = footer.get("left_button") as Button
		var right_button = footer.get("right_button") as Button
		var center_control = footer.get("center_control") as Control
		print("Power-up page count: %d" % shop_ui._get_page_count("power_up"))
		print("Left arrow visible: %s" % str(left_button and left_button.visible))
		print("Right arrow visible: %s" % str(right_button and right_button.visible))
		if center_control and center_control.get_node_or_null("ShaderRect"):
			print("✓ Shader-backed reroll shell found")
		else:
			print("✗ Shader-backed reroll shell missing")
		if right_button:
			right_button.emit_signal("pressed")
			await get_tree().create_timer(0.45).timeout
			print("Current power-up page index after next: %d" % shop_ui._tab_page_indices.get("power_up", -1))
		if left_button:
			left_button.emit_signal("pressed")
			await get_tree().create_timer(0.45).timeout
			print("Current power-up page index after previous: %d" % shop_ui._tab_page_indices.get("power_up", -1))

	print("--- Power-up expansion cap check ---")
	shop_ui.reset_shop_expansions()
	shop_ui.increase_power_up_items(1)
	shop_ui.increase_power_up_items(1)
	shop_ui.increase_power_up_items(2)
	shop_ui.increase_power_up_items(3)
	print("Power-up item count after cap test: %d" % shop_ui.power_up_items)
	print("--- Ownership panel placement ---")
	var mod_panel = shop_ui._ownership_panels.get("mod")
	var color_panel = shop_ui._ownership_panels.get("colored_dice")
	print("Mod ownership panel present: %s" % str(is_instance_valid(mod_panel)))
	print("Color ownership panel present: %s" % str(is_instance_valid(color_panel)))
	var powerup_panel = shop_ui.get_node_or_null("TabContainer/Pogs/MarginContainer/CenteredContainer/ContentRow/OwnershipPanel")
	if powerup_panel:
		print("✗ POGS tab unexpectedly has an ownership panel")
	else:
		print("✓ POGS tab remains full-width")
	print("--- Archive tab presence ---")
	var tab_container = shop_ui.get_node_or_null("TabContainer")
	if tab_container:
		var titles: Array[String] = []
		for i in range(tab_container.get_tab_count()):
			titles.append(tab_container.get_tab_title(i))
		print("Tabs: %s" % str(titles))
		if "UNDISCOVERED" in titles:
			print("✓ Undiscovered tab present")
		else:
			print("✗ Undiscovered tab missing")
	await _test_fixed_shop_titles()
	await _test_smooth_archive_scroll()
	await _test_live_rep_meter()
	print("--- Animated close ---")
	var close_finished := [false]
	shop_ui.shop_close_finished.connect(func(): close_finished[0] = true)
	var close_tween: Tween = shop_ui.play_close_animation()
	if close_tween:
		await close_tween.finished
	await get_tree().process_frame
	print("Shop hidden after close: %s" % str(not shop_ui.visible))
	print("shop_close_finished emitted: %s" % str(close_finished[0]))
	shop_ui.show()
	await get_tree().create_timer(0.7).timeout
	print("Shop visible after reopen: %s" % str(shop_ui.visible))
	var tab_cont = shop_ui.get_node_or_null("TabContainer")
	if tab_cont:
		print("TabContainer alpha after reopen: %.2f" % tab_cont.modulate.a)
	print("=== Pagination Test Complete ===")
	test_completed = true
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if _fail_count == 0 else 1)


func _test_fixed_shop_titles() -> void:
	var items := shop_ui._get_shop_items(shop_ui.power_up_container)
	_check(not items.is_empty(), "Shop title test has a power-up card")
	if items.is_empty():
		return
	var item := items[0] as ShopItem
	_check(item.name_label.get_theme_font_size("font_size") == 12, "Shop power-up title starts at 12 px")
	item._on_shop_item_resized()
	item._set_title_text("A Much Longer Purchased Power-Up Title")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(item.name_label.get_theme_font_size("font_size") == 12, "Purchase/resize path cannot enlarge the shop title")
	_check(item.name_label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "Shop title clips without ellipsis")


func _test_smooth_archive_scroll() -> void:
	shop_ui.tab_container.current_tab = 6
	for i in range(24):
		var filler := Control.new()
		filler.custom_minimum_size = Vector2(100, 180)
		shop_ui.unlocked_container.add_child(filler)
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := shop_ui.get_node_or_null("TabContainer/Unlocked/ScrollContainer") as SmoothScrollContainer
	_check(scroll != null, "Undiscovered uses SmoothScrollContainer")
	if not scroll:
		return
	var bar := scroll.get_v_scroll_bar()
	_check(scroll._max_scroll() > bar.page, "Archive test has a scrollable page")
	scroll._set_target_scroll(minf(scroll._max_scroll(), bar.page))
	_check(scroll.scroll_vertical == 0, "Full-page scroll does not jump on input")
	await get_tree().create_timer(0.08).timeout
	_check(scroll.scroll_vertical > 0 and scroll.scroll_vertical < int(bar.page), "Scroll eases through an intermediate position")
	scroll._set_target_scroll(minf(scroll._max_scroll(), bar.page * 2.0))
	await get_tree().create_timer(0.4).timeout
	_check(absi(scroll.scroll_vertical - int(scroll._target_scroll)) <= 1, "Interrupted scroll reaches its retargeted position")

	scroll._set_target_scroll(0.0)
	await get_tree().create_timer(0.4).timeout
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	scroll._gui_input(wheel)
	var first_target := scroll._target_scroll
	await get_tree().create_timer(0.05).timeout
	scroll._gui_input(wheel)
	_check(scroll._target_scroll > first_target, "Rapid wheel ticks accumulate without snapping")
	await get_tree().create_timer(0.4).timeout
	_check(absi(scroll.scroll_vertical - int(scroll._target_scroll)) <= 1, "Wheel scroll settles at its target")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = scroll.get_global_rect().get_center()
	scroll._gui_input(press)
	var drag_start := scroll._target_scroll
	var motion := InputEventMouseMotion.new()
	motion.global_position = press.global_position - Vector2(0, 40)
	scroll._gui_input(motion)
	_check(scroll._target_scroll > drag_start, "Drag input retargets the smooth scroll")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	scroll._input(release)
	await get_tree().create_timer(0.4).timeout
	_check(absi(scroll.scroll_vertical - int(scroll._target_scroll)) <= 1, "Drag scroll settles at its target")


func _test_live_rep_meter() -> void:
	_check(shop_ui._rep_meter != null and shop_ui._rep_value_label != null, "POGS tab has a meter and numeric REP label")
	if not shop_ui._rep_meter:
		return
	var old_rep := ProgressManager.get_rep()
	ProgressManager.cumulative_stats["rep"] = 30
	ProgressManager.rep_changed.emit(30)
	_check(is_equal_approx(shop_ui._rep_meter.value, 30.0), "REP meter updates from rep_changed")
	_check(shop_ui._rep_value_label.text == "REP 30/100", "REP numeric label updates live")
	_check(shop_ui._rep_meter.tint_progress == ShopUI.REP_STAGE_COLORS[2], "REP meter uses the HUD stage color")
	shop_ui.tab_container.current_tab = 0
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("res://Tests/_layout_shots/ui_polish_shop.png")
	ProgressManager.cumulative_stats["rep"] = old_rep
	ProgressManager.rep_changed.emit(old_rep)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail_count += 1
		push_error("[ShopPaginationTest] FAIL: " + message)


func _input(event):
	if test_completed and event.is_action_pressed("ui_accept"):
		get_tree().quit()
