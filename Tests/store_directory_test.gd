extends Control

## store_directory_test.gd
##
## Verifies the 24-store directory and ChannelManager store assignment:
## count, uniqueness, 6 stores per zone, seeded reproducibility,
## get_store_name lookup/fallback, and save/load round-trip.

@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel

var _failures: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	print("\n=== STORE DIRECTORY TEST ===")
	await get_tree().process_frame
	_run_tests()
	_finish()


func _check(condition: bool, label: String) -> void:
	var status := "PASS" if condition else "FAIL"
	if not condition:
		_failures += 1
	var line := "%s: %s" % [status, label]
	print(line)
	_lines.append(line)


func _run_tests() -> void:
	# 1. Directory data
	var directory: StoreDirectoryData = load("res://Resources/Data/Stores/store_directory.tres")
	_check(directory != null, "store_directory.tres loads as StoreDirectoryData")
	if not directory:
		return
	_check(directory.store_names.size() == 24, "directory has 24 stores")
	var unique := {}
	for store_name in directory.store_names:
		unique[store_name] = true
	_check(unique.size() == 24, "all 24 store names are unique")

	# 2. Assignment
	var manager := ChannelManager.new()
	add_child(manager)
	manager.assign_stores_to_zones(12345)
	var expected_zones: int = mini(ChannelManager.MAX_CHANNEL, 24 / ChannelManager.STORES_PER_ZONE)
	_check(manager.zone_store_names.size() == expected_zones, "assignment covers every playable zone (%d)" % expected_zones)
	var per_zone_ok := true
	var assigned := {}
	for zone in manager.zone_store_names:
		var names: Array = manager.zone_store_names[zone]
		if names.size() != ChannelManager.STORES_PER_ZONE:
			per_zone_ok = false
		for store_name in names:
			assigned[store_name] = true
	_check(per_zone_ok, "every zone gets exactly 6 stores")
	_check(assigned.size() == 24, "all 24 stores assigned exactly once across zones")

	# 3. Seeded reproducibility
	var first: Dictionary = manager.zone_store_names.duplicate(true)
	manager.assign_stores_to_zones(12345)
	_check(manager.zone_store_names == first, "same seed reproduces the same assignment")
	manager.assign_stores_to_zones(99999)
	_check(manager.zone_store_names != first, "different seed changes the assignment")

	# 4. Lookup and fallback
	manager.assign_stores_to_zones(12345)
	var expected: String = first[1][0]
	_check(manager.get_store_name(1, 1) == expected, "get_store_name(1, 1) matches assignment")
	_check(manager.get_store_name(4, 6) == first[4][5], "get_store_name(4, 6) matches assignment")
	_check(manager.get_store_name(1, 99) == "Store 1-99", "out-of-range round falls back")
	var empty_manager := ChannelManager.new()
	add_child(empty_manager)
	_check(empty_manager.get_store_name(2, 3) == "Store 2-3", "unassigned manager falls back")

	# 5. Save/load round-trip (int zone keys survive serialization)
	var state: Dictionary = manager.get_state()
	var restored := ChannelManager.new()
	add_child(restored)
	restored.load_state(state)
	_check(restored.zone_store_names == manager.zone_store_names, "load_state restores store assignment")
	_check(restored.get_store_name(4, 6) == manager.get_store_name(4, 6), "restored lookup matches")
	_check(restored.store_assignment_seed == 12345, "assignment seed persists")

	manager.queue_free()
	empty_manager.queue_free()
	restored.queue_free()


func _finish() -> void:
	var summary := ""
	if _failures == 0:
		summary = "ALL TESTS PASSED"
	else:
		summary = "%d TEST(S) FAILED" % _failures
	print("[StoreDirectoryTest] " + summary)
	_lines.append("")
	_lines.append(summary)
	if results_label:
		results_label.text = "\n".join(_lines)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(_failures)
