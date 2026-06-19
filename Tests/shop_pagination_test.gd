extends Control

## Test script for verifying paged single-row ShopUI behavior.
##
## Validates that:
## 1. Footer arrows appear only when a tab pool exceeds 3 items.
## 2. Page navigation advances by full pages.
## 3. PowerUps footer includes the shader-backed reroll shell.
## 4. Archive tabs still exist after the layout refactor.

var shop_ui: ShopUI
var test_completed := false

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
	print("--- Archive tab presence ---")
	var tab_container = shop_ui.get_node_or_null("TabContainer")
	if tab_container:
		var titles: Array[String] = []
		for i in range(tab_container.get_tab_count()):
			titles.append(tab_container.get_tab_title(i))
		print("Tabs: %s" % str(titles))
		if "Unlocked" in titles:
			print("✓ Unlocked tab present")
		else:
			print("✗ Unlocked tab missing")
	print("=== Pagination Test Complete ===")
	test_completed = true
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func _input(event):
	if test_completed and event.is_action_pressed("ui_accept"):
		get_tree().quit()
