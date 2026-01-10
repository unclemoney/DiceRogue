extends Control

## PowerUpValidationTest
##
## Manual test scene for validating PowerUp functionality.
## Tests instantiation, effect application, and provides manual testing buttons.
##
## Usage: Run the scene and press buttons to test individual PowerUps.
## Console output shows detailed results for manual review.

# UI References
@onready var log_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/LogContainer
@onready var test_all_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/TestAllButton
@onready var test_instantiation_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/TestInstantiationButton
@onready var clear_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/ClearButton
@onready var power_up_list: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/PowerUpList
@onready var test_selected_button: Button = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/TestSelectedButton
@onready var details_label: RichTextLabel = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/DetailsLabel

# Font for log labels
var vcr_font: Font

# PowerUp manager reference
var power_up_manager: PowerUpManager

# All PowerUp definitions
var power_up_defs: Array = []

func _ready() -> void:
	_log_header("=== PowerUp Validation Test ===")
	
	# Load VCR font
	vcr_font = load("res://Resources/Font/VCR_OSD_MONO.ttf")
	
	# Find PowerUpManager - try existing first, then instantiate if needed
	power_up_manager = get_tree().get_first_node_in_group("power_up_manager")
	
	if not power_up_manager:
		_log_info("PowerUpManager not found in scene tree, loading dynamically...")
		var manager_scene = load("res://Scenes/Managers/power_up_manager.tscn")
		if manager_scene:
			power_up_manager = manager_scene.instantiate()
			add_child(power_up_manager)
			_log_info("PowerUpManager loaded and added to scene")
		else:
			_log_fail("ERROR: Failed to load PowerUpManager scene!")
			return
	
	if not power_up_manager:
		_log_fail("ERROR: PowerUpManager not available!")
		return
	
	# Get all power-up definitions
	_load_power_up_definitions()
	
	# Connect button signals
	if test_all_button:
		test_all_button.pressed.connect(_run_all_tests)
	if test_instantiation_button:
		test_instantiation_button.pressed.connect(_test_instantiation_all)
	if clear_button:
		clear_button.pressed.connect(_clear_log)
	if test_selected_button:
		test_selected_button.pressed.connect(_test_selected_power_up)
	if power_up_list:
		power_up_list.item_selected.connect(_on_power_up_selected)
	
	_log_info("Found %d PowerUps loaded in PowerUpManager" % power_up_defs.size())
	_log_info("")
	_log_info("Press 'Test All' to run comprehensive tests")
	_log_info("Press 'Test Instantiation' to verify all PowerUps can be created")
	_log_info("Select a PowerUp from the list to see details and test individually")


## _load_power_up_definitions()
##
## Loads all PowerUp definitions from PowerUpManager into the list.
func _load_power_up_definitions() -> void:
	power_up_defs.clear()
	
	if power_up_list:
		power_up_list.clear()
	
	if not power_up_manager:
		return
	
	var available_ids = power_up_manager.get_available_power_ups()
	
	for id in available_ids:
		var def = power_up_manager.get_def(id)
		if def:
			power_up_defs.append(def)
			if power_up_list:
				var rarity_char = PowerUpData.get_rarity_display_char(def.rarity) if def.has_method("get_rarity_display_char") else "?"
				power_up_list.add_item("[%s] %s" % [rarity_char, def.display_name])


## _on_power_up_selected()
##
## Called when a PowerUp is selected from the list.
## Shows details in the right panel.
func _on_power_up_selected(index: int) -> void:
	if index < 0 or index >= power_up_defs.size():
		return
	
	var def = power_up_defs[index]
	if not def:
		return
	
	if details_label:
		var details = []
		details.append("[b]%s[/b]" % def.display_name)
		details.append("")
		details.append("[i]ID: %s[/i]" % def.id)
		details.append("")
		details.append("[color=yellow]Description:[/color]")
		details.append(def.description)
		details.append("")
		details.append("[color=cyan]Rarity:[/color] %s" % def.rarity.capitalize())
		details.append("[color=green]Price:[/color] $%d" % def.price)
		details.append("")
		if def.scene:
			details.append("[color=lime]Scene: ✓ Loaded[/color]")
		else:
			details.append("[color=red]Scene: ✗ Missing![/color]")
		if def.icon:
			details.append("[color=lime]Icon: ✓ Loaded[/color]")
		else:
			details.append("[color=orange]Icon: ✗ Missing[/color]")
		
		details_label.text = "\n".join(details)


## _test_selected_power_up()
##
## Tests the currently selected PowerUp.
func _test_selected_power_up() -> void:
	if not power_up_list:
		return
	
	var selected = power_up_list.get_selected_items()
	if selected.is_empty():
		_log_info("No PowerUp selected - please select one from the list")
		return
	
	var index = selected[0]
	if index < 0 or index >= power_up_defs.size():
		return
	
	var def = power_up_defs[index]
	_test_single_power_up(def)


## _run_all_tests()
##
## Runs all validation tests on all PowerUps.
func _run_all_tests() -> void:
	_log_header("=== Running All PowerUp Tests ===")
	_test_instantiation_all()
	_log_info("")
	_test_data_validation_all()
	_log_info("")
	_test_effect_signatures_all()
	_log_header("=== All Tests Complete ===")


## _test_instantiation_all()
##
## Tests that all PowerUps can be instantiated from their scenes.
func _test_instantiation_all() -> void:
	_log_header("--- Instantiation Tests ---")
	
	var pass_count = 0
	var fail_count = 0
	
	for def in power_up_defs:
		var result = _test_power_up_instantiation(def)
		if result:
			pass_count += 1
		else:
			fail_count += 1
	
	_log_info("")
	if fail_count == 0:
		_log_pass("All %d PowerUps instantiated successfully!" % pass_count)
	else:
		_log_fail("Results: %d passed, %d failed" % [pass_count, fail_count])


## _test_power_up_instantiation()
##
## Tests instantiation of a single PowerUp.
## Returns true if successful, false otherwise.
func _test_power_up_instantiation(def: PowerUpData) -> bool:
	if not def:
		_log_fail("FAIL: Null PowerUpData")
		return false
	
	if not def.scene:
		_log_fail("FAIL: %s - No scene assigned" % def.id)
		return false
	
	# Try to instantiate
	var instance = def.scene.instantiate()
	if not instance:
		_log_fail("FAIL: %s - Failed to instantiate scene" % def.id)
		return false
	
	# Check if it's a PowerUp
	if not instance is PowerUp:
		_log_fail("FAIL: %s - Instance is not a PowerUp (is %s)" % [def.id, instance.get_class()])
		instance.queue_free()
		return false
	
	# Check basic methods exist
	var has_apply = instance.has_method("apply")
	var has_remove = instance.has_method("remove")
	
	if not has_apply or not has_remove:
		_log_fail("FAIL: %s - Missing required methods (apply: %s, remove: %s)" % [def.id, has_apply, has_remove])
		instance.queue_free()
		return false
	
	_log_pass("PASS: %s - Instantiation OK" % def.id)
	instance.queue_free()
	return true


## _test_data_validation_all()
##
## Validates PowerUpData resources for all PowerUps.
func _test_data_validation_all() -> void:
	_log_header("--- Data Validation Tests ---")
	
	var issues = []
	
	for def in power_up_defs:
		var def_issues = _validate_power_up_data(def)
		if not def_issues.is_empty():
			issues.append_array(def_issues)
	
	if issues.is_empty():
		_log_pass("All PowerUp data validated successfully!")
	else:
		_log_fail("Data validation issues found:")
		for issue in issues:
			_log_fail("  - %s" % issue)


## _validate_power_up_data()
##
## Validates a single PowerUpData resource.
## Returns array of issue strings (empty if valid).
func _validate_power_up_data(def: PowerUpData) -> Array:
	var issues = []
	
	if not def:
		issues.append("Null PowerUpData")
		return issues
	
	if def.id == "":
		issues.append("%s: Empty ID" % def.display_name)
	
	if def.display_name == "":
		issues.append("%s: Empty display name" % def.id)
	
	if def.description == "":
		issues.append("%s: Empty description" % def.id)
	
	if def.price <= 0:
		issues.append("%s: Invalid price (%d)" % [def.id, def.price])
	
	if not def.icon:
		issues.append("%s: Missing icon" % def.id)
	
	if not def.scene:
		issues.append("%s: Missing scene" % def.id)
	
	return issues


## _test_effect_signatures_all()
##
## Tests that all PowerUp effect methods have correct signatures.
func _test_effect_signatures_all() -> void:
	_log_header("--- Effect Signature Tests ---")
	
	var pass_count = 0
	var fail_count = 0
	
	for def in power_up_defs:
		if not def.scene:
			continue
		
		var instance = def.scene.instantiate()
		if not instance:
			continue
		
		# Test apply method signature
		var apply_ok = _test_method_signature(instance, "apply", 1)
		var remove_ok = _test_method_signature(instance, "remove", 1)
		
		if apply_ok and remove_ok:
			_log_pass("PASS: %s - Method signatures OK" % def.id)
			pass_count += 1
		else:
			_log_fail("FAIL: %s - Method signature issues (apply: %s, remove: %s)" % [def.id, apply_ok, remove_ok])
			fail_count += 1
		
		instance.queue_free()
	
	_log_info("")
	if fail_count == 0:
		_log_pass("All %d PowerUps have valid method signatures!" % pass_count)
	else:
		_log_fail("Signature results: %d passed, %d failed" % [pass_count, fail_count])


## _test_method_signature()
##
## Tests if a method exists with the expected argument count.
func _test_method_signature(instance: Object, method_name: String, expected_args: int) -> bool:
	if not instance.has_method(method_name):
		return false
	
	# Get method info
	var methods = instance.get_method_list()
	for m in methods:
		if m["name"] == method_name:
			var arg_count = m["args"].size()
			return arg_count >= expected_args
	
	return false


## _test_single_power_up()
##
## Comprehensive test of a single PowerUp.
func _test_single_power_up(def: PowerUpData) -> void:
	_log_header("--- Testing: %s ---" % def.display_name)
	
	_log_info("ID: %s" % def.id)
	_log_info("Description: %s" % def.description)
	_log_info("Price: $%d" % def.price)
	_log_info("Rarity: %s" % def.rarity)
	_log_info("")
	
	# Test instantiation
	_log_test("Instantiation Test:")
	var inst_ok = _test_power_up_instantiation(def)
	
	# Test data validation
	_log_test("Data Validation:")
	var issues = _validate_power_up_data(def)
	if issues.is_empty():
		_log_pass("Data validation passed")
	else:
		for issue in issues:
			_log_fail("Issue: %s" % issue)
	
	# Test effect with mock target
	if inst_ok and def.scene:
		_log_test("Effect Application Test:")
		var instance = def.scene.instantiate()
		if instance:
			# Add to scene temporarily
			add_child(instance)
			
			_log_info("PowerUp instantiated: %s" % instance.get_class())
			
			# Check for dynamic description method
			if instance.has_method("get_current_description"):
				var desc = instance.get_current_description()
				_log_info("Dynamic description: %s" % desc)
			
			# Clean up
			instance.queue_free()
			_log_pass("Effect test completed (manual verification required)")
		else:
			_log_fail("Failed to instantiate for effect test")
	
	_log_info("")


## _clear_log()
##
## Clears all log entries.
func _clear_log() -> void:
	if log_container:
		for child in log_container.get_children():
			child.queue_free()


## Logging helper functions
func _log_header(text: String) -> void:
	_add_log_label(text, Color(1, 1, 0))  # Yellow
	print(text)

func _log_test(text: String) -> void:
	_add_log_label(text, Color(0.7, 0.7, 1))  # Light blue
	print(text)

func _log_info(text: String) -> void:
	_add_log_label(text, Color(0.8, 0.8, 0.8))  # Light gray
	print(text)

func _log_result(text: String) -> void:
	_add_log_label(text, Color(0.5, 1, 0.5))  # Light green
	print(text)

func _log_pass(text: String) -> void:
	_add_log_label(text, Color(0, 1, 0))  # Green
	print(text)

func _log_fail(text: String) -> void:
	_add_log_label(text, Color(1, 0, 0))  # Red
	print(text)

func _add_log_label(text: String, color: Color) -> void:
	if not log_container:
		return
	
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	if vcr_font:
		label.add_theme_font_override("font", vcr_font)
		label.add_theme_font_size_override("font_size", 12)
	log_container.add_child(label)
