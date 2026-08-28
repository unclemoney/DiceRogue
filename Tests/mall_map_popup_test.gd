extends Control
class_name MallMapPopupTest

## mall_map_popup_test.gd
##
## Verifies the in-game mall map popup (MallMapPopup):
## 1. Opening the popup builds the 4 mall zones and 6 store markers per zone.
## 2. Exactly one marker is flagged current (the store for the live round).
## 3. The current store's tooltip names the store and its pre-selected debuff.
## 4. Completed rounds show as completed.
##
## Run headless with `-- --auto-test` to quit with an exit code (0 = pass).

const MallMapPopupScene := preload("res://Scenes/UI/MallMapPopup.tscn")

## Minimal ChannelManager stand-in exposing what MallMapPopup calls:
## current_channel, get_store_name, get_round_config, get_mall_zone_label,
## get_selector_zone_name, zone_store_names, assign_stores_to_zones,
## get_scaled_target_score, get_selector_section_id + friends used by
## MallMapRenderer.build_zones.
class StubChannelManager extends RefCounted:
	var current_channel: int = 1
	var zone_store_names: Dictionary = {}

	func assign_stores_to_zones(_seed: int = 0) -> void:
		pass

	func get_store_name(zone: int, round_number: int) -> String:
		return "Stub Store %d-%d" % [zone, round_number]

	func get_round_config(_channel: int = -1, _round_number: int = 1):
		return null

	func get_mall_zone_label(channel: int = -1) -> String:
		return "Mall Zone %02d" % channel

	func get_selector_zone_name(channel: int = -1) -> String:
		return "Zone %d" % channel

	func get_selector_directory_label(channel: int = -1) -> String:
		return "%02d" % channel

	func get_selector_section_id(_channel: int = -1) -> String:
		return "specialty"

	func get_selector_tooltip_flavor(_channel: int = -1) -> String:
		return ""

	func get_channel_display_text(channel: int = -1) -> String:
		return "%02d" % channel

	func get_scaled_target_score(base_score: int, _channel: int = -1) -> int:
		return base_score


## Minimal DebuffManager stand-in: get_def returns an object with
## display_name.
class StubDebuffManager extends RefCounted:
	var defs: Dictionary = {}

	func get_def(id: String):
		return defs.get(id)


class StubDebuffDef extends RefCounted:
	var display_name: String = ""

	func _init(p_name: String) -> void:
		display_name = p_name


var _fail_count := 0
var _popup: MallMapPopup
var _channel_manager: StubChannelManager
var _round_manager: RoundManager
var _debuff_manager: StubDebuffManager


func _ready() -> void:
	print("=== Mall Map Popup Test ===")
	_setup_managers()
	_setup_popup()
	call_deferred("_run_test")


## _run_test() -> void
##
## Async test body; calls _finish() (and quits) at its end. Mirrors the
## MallMapSelectorTest pattern — quitting must happen here, not in _ready,
## because the awaits would otherwise let _ready fall through early.
func _run_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run_tests()
	await get_tree().create_timer(0.6).timeout
	_assert(not _popup.visible, "popup hidden after close()")
	_finish()


func _setup_managers() -> void:
	_channel_manager = StubChannelManager.new()
	_channel_manager.current_channel = 2

	_debuff_manager = StubDebuffManager.new()
	_debuff_manager.defs["window_shopping"] = StubDebuffDef.new("Window Shopping")

	# Real RoundManager, not added to the tree: references assigned directly,
	# rounds_data filled by hand so the test controls completed/debuffs.
	_round_manager = RoundManager.new()
	_round_manager.channel_manager = _channel_manager
	for i in range(6):
		var debuff_ids: Array[String] = []
		if i == 2:
			debuff_ids.append("window_shopping")
		_round_manager.rounds_data.append({
			"round_number": i + 1,
			"store_name": _channel_manager.get_store_name(2, i + 1),
			"dice_type": "d6",
			"target_score": 0,
			"completed": i == 0,
			"failed": false,
			"debuff_ids": debuff_ids,
		})
	_round_manager.current_round = 2  # third store is the live one


func _setup_popup() -> void:
	_popup = MallMapPopupScene.instantiate()
	add_child(_popup)
	_popup.setup(_channel_manager, _round_manager, _debuff_manager)


func _run_tests() -> void:
	print("--- Build ---")
	_popup.open()
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(_popup.visible, "popup visible after open()")
	_assert_equals(_popup._zones_by_channel.size(), 4, "popup builds 4 zones")

	var zones_with_six := 0
	for channel in _popup._store_markers:
		var markers: Array = _popup._store_markers[channel]
		_assert_equals(markers.size(), 6, "zone %d has 6 store markers" % channel)
		if markers.size() == 6:
			zones_with_six += 1
	_assert_equals(zones_with_six, 4, "all 4 zones have markers")

	print("--- Current store marker ---")
	var current_count := 0
	for channel in _popup._store_markers:
		for marker in _popup._store_markers[channel]:
			if marker.get_meta("is_current", false):
				current_count += 1
	_assert_equals(current_count, 1, "exactly one marker flagged current")

	var current_marker = _popup._store_markers[2][2]
	_assert_equals(str(current_marker.get_meta("state")), "current", "zone 2 store 3 is current")
	_assert_equals(str(_popup._store_markers[2][0].get_meta("state")), "completed", "zone 2 store 1 is completed")
	_assert_equals(str(_popup._store_markers[2][1].get_meta("state")), "upcoming", "zone 2 store 2 is upcoming (failed=false, not current)")
	_assert_equals(str(_popup._store_markers[1][0].get_meta("state")), "upcoming", "other zone markers stay neutral")

	print("--- Tooltip ---")
	var current_store_tooltip := _popup._build_store_tooltip_text(2, 2)
	_assert(current_store_tooltip.contains("Stub Store 2-3"), "tooltip contains store name")
	_assert(current_store_tooltip.contains("Window Shopping"), "tooltip contains pre-selected debuff display name")
	_assert(current_store_tooltip.contains("YOU ARE HERE"), "tooltip marks current store")

	var upcoming_text := _popup._build_store_tooltip_text(2, 1)
	_assert(not upcoming_text.contains("Grounding:"), "tooltip no longer shows a grounding line")

	var other_zone_text := _popup._build_store_tooltip_text(1, 0)
	_assert(other_zone_text.contains("unknown until reached"), "other zones show debuffs as unknown")

	print("--- Close ---")
	_popup.close()


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_fail_count += 1
		push_error("[MallMapPopupTest] FAIL: %s" % message)
		print("FAIL: %s" % message)


func _assert_equals(actual, expected, message: String) -> void:
	_assert(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _quit_with_result() -> void:
	if _fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


## _finish() -> void
##
## Prints the summary and quits (auto-test/headless) or waits for input.
func _finish() -> void:
	var result_text := "PASS"
	if _fail_count > 0:
		result_text = "FAIL"
	print("=== Mall Map Popup Test Complete: %s ===" % result_text)
	if "--auto-test" in OS.get_cmdline_user_args():
		_quit_with_result()
	elif DisplayServer.get_name() == "headless":
		_quit_with_result()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_quit_with_result()
