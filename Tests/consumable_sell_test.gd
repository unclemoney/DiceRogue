extends Control

## ConsumableSellTest
##
## Comprehensive test scene to debug the consumable sell flow.
## Tests: spine creation, fan-out, sell animation, removal, and cleanup.
## Shows real-time debug output of every step in the pipeline.

const ConsumableUIScene = preload("res://Scenes/UI/consumable_ui.tscn")

var consumable_ui: ConsumableUI
var output_label: RichTextLabel
var state_label: RichTextLabel
var log_lines: Array[String] = []
var _test_consumable_datas: Array[ConsumableData] = []
var _btn_container: HBoxContainer
var _state_timer: Timer

# ── Lifecycle ──────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	_load_test_data()
	_create_consumable_ui()
	_start_state_polling()
	_log("=== Consumable Sell Test Ready ===")
	_log("Step 1: Click [color=yellow]Add 3 Consumables[/color]")
	_log("Step 2: Click a spine to fan out cards")
	_log("Step 3: Hover a card, then click SELL")
	_log("Watch the debug output below for every signal and state change.")


# ── UI Construction ────────────────────────────────────────

func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Left panel (state inspector) — 320px wide
	var state_panel := PanelContainer.new()
	state_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	state_panel.offset_right = 340.0
	state_panel.offset_top = 10.0
	state_panel.offset_bottom = -10.0
	state_panel.offset_left = 10.0
	add_child(state_panel)

	var state_vbox := VBoxContainer.new()
	state_panel.add_child(state_vbox)

	var state_title := Label.new()
	state_title.text = "LIVE STATE INSPECTOR"
	state_title.add_theme_font_size_override("font_size", 18)
	state_title.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
	state_vbox.add_child(state_title)

	state_label = RichTextLabel.new()
	state_label.bbcode_enabled = true
	state_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	state_label.scroll_following = true
	state_label.add_theme_font_size_override("normal_font_size", 13)
	state_vbox.add_child(state_label)

	# Bottom panel (debug log) — 240px tall
	var log_panel := PanelContainer.new()
	log_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	log_panel.offset_top = -260.0
	log_panel.offset_left = 350.0
	log_panel.offset_right = -10.0
	log_panel.offset_bottom = -10.0
	add_child(log_panel)

	var log_vbox := VBoxContainer.new()
	log_panel.add_child(log_vbox)

	var log_title := Label.new()
	log_title.text = "DEBUG LOG"
	log_title.add_theme_font_size_override("font_size", 16)
	log_title.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	log_vbox.add_child(log_title)

	output_label = RichTextLabel.new()
	output_label.bbcode_enabled = true
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.scroll_following = true
	output_label.add_theme_font_size_override("normal_font_size", 13)
	log_vbox.add_child(output_label)

	# Button bar beneath state panel
	_btn_container = HBoxContainer.new()
	_btn_container.position = Vector2(10, 560)
	_btn_container.add_theme_constant_override("separation", 8)
	add_child(_btn_container)

	_add_btn("Add 3 Consumables", _on_add_consumables)
	_add_btn("Force Fan-Out", _on_force_fan)
	_add_btn("Simulate Sell #1", _on_simulate_sell)
	_add_btn("Direct remove_consumable", _on_direct_remove)
	_add_btn("Direct animate_removal", _on_direct_animate)
	_add_btn("Check Cleanup State", _on_check_cleanup)
	_add_btn("Reset", _on_reset)


func _add_btn(label_text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.pressed.connect(callback)
	btn.add_theme_font_size_override("font_size", 13)
	_btn_container.add_child(btn)


# ── Data Setup ─────────────────────────────────────────────

func _load_test_data() -> void:
	var paths := [
		"res://Scripts/Consumable/QuickCashConsumable.tres",
		"res://Scripts/Consumable/ThreeMoreRollsConsumable.tres",
		"res://Scripts/Consumable/ScoreAmplifierConsumable.tres",
	]
	for p in paths:
		var d := load(p) as ConsumableData
		if d:
			_test_consumable_datas.append(d)
			_log("Loaded test data: [color=cyan]%s[/color] (id=%s, price=%d)" % [d.display_name, d.id, d.price])
		else:
			_log("[color=red]FAILED to load: %s[/color]" % p)

	if _test_consumable_datas.size() < 3:
		_log("[color=red]WARNING: Need 3 consumable .tres files for full test[/color]")


func _create_consumable_ui() -> void:
	consumable_ui = ConsumableUIScene.instantiate() as ConsumableUI
	if not consumable_ui:
		_log("[color=red]FAILED to instantiate ConsumableUI scene[/color]")
		return

	# Position it in the center-right area
	consumable_ui.position = Vector2(350, 0)
	consumable_ui.size = Vector2(920, 500)
	add_child(consumable_ui)

	# Connect the signals exactly as GameController does
	if not consumable_ui.is_connected("consumable_sold", _on_consumable_sold):
		consumable_ui.consumable_sold.connect(_on_consumable_sold)
	if not consumable_ui.is_connected("consumable_used", _on_consumable_used):
		consumable_ui.consumable_used.connect(_on_consumable_used)

	_log("ConsumableUI created and signals connected.")


# ── State Polling ──────────────────────────────────────────

func _start_state_polling() -> void:
	_state_timer = Timer.new()
	_state_timer.wait_time = 0.1
	_state_timer.autostart = true
	_state_timer.timeout.connect(_refresh_state_display)
	add_child(_state_timer)


func _refresh_state_display() -> void:
	if not consumable_ui or not is_instance_valid(consumable_ui):
		state_label.text = "[color=red]ConsumableUI is null/freed[/color]"
		return

	var lines: Array[String] = []
	lines.append("[color=yellow]── ConsumableUI State ──[/color]")
	var state_name: String = "SPINES" if consumable_ui._current_state == ConsumableUI.State.SPINES else "FANNED"
	var state_color: String = "gray" if state_name == "SPINES" else "green"
	lines.append("_current_state: [color=%s]%s[/color]" % [state_color, state_name])
	lines.append("_is_animating: %s" % str(consumable_ui._is_animating))
	lines.append("_active_consumable_count: %d" % consumable_ui._active_consumable_count)
	lines.append("_overflow_mode: %s" % str(consumable_ui._overflow_mode))
	lines.append("_selected_spine_id: '%s'" % consumable_ui._selected_spine_id)
	lines.append("")

	lines.append("[color=yellow]── _consumable_data ──[/color]")
	if consumable_ui._consumable_data.size() == 0:
		lines.append("  (empty)")
	else:
		for cid in consumable_ui._consumable_data.keys():
			var cd: ConsumableData = consumable_ui._consumable_data[cid]
			lines.append("  [color=cyan]%s[/color]: %s" % [cid, cd.display_name if cd else "null"])
	lines.append("")

	lines.append("[color=yellow]── _consumable_spines ──[/color]")
	if consumable_ui._consumable_spines.size() == 0:
		lines.append("  (empty)")
	else:
		for sid in consumable_ui._consumable_spines.keys():
			var spine = consumable_ui._consumable_spines[sid]
			var valid: bool = spine != null and is_instance_valid(spine)
			var in_tree: bool = valid and spine.is_inside_tree()
			var vis: String = "visible" if valid and spine.visible else "hidden"
			var alpha: String = "a=%.2f" % spine.modulate.a if valid else "n/a"
			var col: String = "green" if valid and in_tree else "red"
			lines.append("  [color=%s]%s[/color]: valid=%s in_tree=%s %s %s" % [col, sid, valid, in_tree, vis, alpha])
	lines.append("")

	lines.append("[color=yellow]── _fanned_icons ──[/color]")
	if consumable_ui._fanned_icons.size() == 0:
		lines.append("  (empty)")
	else:
		for fid in consumable_ui._fanned_icons.keys():
			var icon = consumable_ui._fanned_icons[fid]
			var valid: bool = icon != null and is_instance_valid(icon)
			var in_tree: bool = valid and icon.is_inside_tree()
			var vis: String = "visible" if valid and icon.visible else "hidden"
			var alpha: String = "a=%.2f" % icon.modulate.a if valid else "n/a"
			var gpos: String = str(icon.global_position) if valid else "n/a"
			var col: String = "green" if valid and in_tree else "red"
			lines.append("  [color=%s]%s[/color]: valid=%s in_tree=%s %s %s pos=%s" % [col, fid, valid, in_tree, vis, alpha, gpos])
	lines.append("")

	lines.append("[color=yellow]── Idle Tweens ──[/color]")
	var active_tweens: int = 0
	for t in consumable_ui._idle_tweens:
		if t and t.is_valid() and t.is_running():
			active_tweens += 1
	lines.append("  Active: %d / Total tracked: %d" % [active_tweens, consumable_ui._idle_tweens.size()])

	state_label.clear()
	state_label.append_text("\n".join(lines))


# ── Signal Handlers (mimicking GameController) ─────────────

func _on_consumable_sold(consumable_id: String) -> void:
	_log("[color=orange]SIGNAL: consumable_sold[/color] → id='%s'" % consumable_id)
	_log("  PlayerEconomy.add_money would run here (skipped in test)")

	# Check state BEFORE calling animate
	var state_name: String = "SPINES" if consumable_ui._current_state == ConsumableUI.State.SPINES else "FANNED"
	_log("  _current_state = [color=yellow]%s[/color]" % state_name)
	_log("  _fanned_icons.has('%s') = %s" % [consumable_id, consumable_ui._fanned_icons.has(consumable_id)])
	if consumable_ui._fanned_icons.has(consumable_id):
		var icon = consumable_ui._fanned_icons[consumable_id]
		_log("  icon valid = %s" % str(is_instance_valid(icon)))
		if is_instance_valid(icon):
			_log("  icon in_tree = %s, visible = %s, modulate.a = %.2f" % [icon.is_inside_tree(), icon.visible, icon.modulate.a])
			_log("  icon global_pos = %s, scale = %s" % [icon.global_position, icon.scale])
	_log("  _consumable_spines.has('%s') = %s" % [consumable_id, consumable_ui._consumable_spines.has(consumable_id)])

	_log("[color=orange]Calling animate_consumable_removal...[/color]")
	consumable_ui.animate_consumable_removal(consumable_id, func():
		_log("[color=lime]CALLBACK: animate_consumable_removal finished[/color]")
		_log("  Now calling remove_consumable('%s')..." % consumable_id)
		consumable_ui.remove_consumable(consumable_id)
		_log("[color=lime]  remove_consumable completed[/color]")
		_log("  _consumable_data.has('%s') = %s" % [consumable_id, consumable_ui._consumable_data.has(consumable_id)])
		_log("  _consumable_spines.has('%s') = %s" % [consumable_id, consumable_ui._consumable_spines.has(consumable_id)])
		_log("  _fanned_icons.has('%s') = %s" % [consumable_id, consumable_ui._fanned_icons.has(consumable_id)])
		_log("  _active_consumable_count = %d" % consumable_ui._active_consumable_count)
	)


func _on_consumable_used(consumable_id: String) -> void:
	_log("[color=orange]SIGNAL: consumable_used[/color] → id='%s'" % consumable_id)


# ── Test Buttons ───────────────────────────────────────────

func _on_add_consumables() -> void:
	_log("[color=white]── Adding %d test consumables ──[/color]" % _test_consumable_datas.size())
	for data in _test_consumable_datas:
		if consumable_ui._consumable_data.has(data.id):
			_log("  Skipping '%s' — already added" % data.id)
			continue
		var result = consumable_ui.add_consumable(data)
		if result:
			_log("  Added [color=cyan]%s[/color] (id=%s)" % [data.display_name, data.id])
		else:
			_log("  [color=red]FAILED to add %s[/color]" % data.id)
	_log("  Total consumables: %d" % consumable_ui._consumable_data.size())
	_log("  Total spines: %d" % consumable_ui._consumable_spines.size())


func _on_force_fan() -> void:
	_log("[color=white]── Force fan-out ──[/color]")
	if consumable_ui._consumable_data.size() == 0:
		_log("[color=red]  No consumables to fan[/color]")
		return
	var first_id: String = consumable_ui._consumable_data.keys()[0]
	_log("  Selecting spine '%s' and fanning..." % first_id)
	consumable_ui._selected_spine_id = first_id
	consumable_ui._fan_out_cards()


func _on_simulate_sell() -> void:
	_log("[color=white]── Simulating sell of first consumable ──[/color]")
	if consumable_ui._consumable_data.size() == 0:
		_log("[color=red]  No consumables to sell[/color]")
		return

	var first_id: String = consumable_ui._consumable_data.keys()[0]
	_log("  Target: '%s'" % first_id)

	# Replicate exact signal chain
	_log("  Emitting consumable_sold signal (as ConsumableUI._on_consumable_sell_requested does)...")
	consumable_ui.emit_signal("consumable_sold", first_id)


func _on_direct_remove() -> void:
	_log("[color=white]── Direct remove_consumable (no animation) ──[/color]")
	if consumable_ui._consumable_data.size() == 0:
		_log("[color=red]  No consumables to remove[/color]")
		return
	var first_id: String = consumable_ui._consumable_data.keys()[0]
	_log("  Calling remove_consumable('%s') directly..." % first_id)
	consumable_ui.remove_consumable(first_id)
	_log("  Done. _consumable_data.has('%s') = %s" % [first_id, consumable_ui._consumable_data.has(first_id)])
	_log("  _consumable_spines.has('%s') = %s" % [first_id, consumable_ui._consumable_spines.has(first_id)])
	_log("  _fanned_icons.has('%s') = %s" % [first_id, consumable_ui._fanned_icons.has(first_id)])
	_log("  _active_consumable_count = %d" % consumable_ui._active_consumable_count)


func _on_direct_animate() -> void:
	_log("[color=white]── Direct animate_consumable_removal ──[/color]")
	if consumable_ui._consumable_data.size() == 0:
		_log("[color=red]  No consumables to animate[/color]")
		return
	var first_id: String = consumable_ui._consumable_data.keys()[0]
	var state_name: String = "SPINES" if consumable_ui._current_state == ConsumableUI.State.SPINES else "FANNED"
	_log("  Target: '%s', state: %s" % [first_id, state_name])
	_log("  _fanned_icons.has: %s, _consumable_spines.has: %s" % [
		consumable_ui._fanned_icons.has(first_id),
		consumable_ui._consumable_spines.has(first_id)
	])

	consumable_ui.animate_consumable_removal(first_id, func():
		_log("[color=lime]  Direct animate callback fired[/color]")
		consumable_ui.remove_consumable(first_id)
		_log("[color=lime]  remove_consumable done — data.has: %s, spines.has: %s[/color]" % [
			consumable_ui._consumable_data.has(first_id),
			consumable_ui._consumable_spines.has(first_id)
		])
	)


func _on_check_cleanup() -> void:
	_log("[color=white]── Cleanup State Check ──[/color]")
	_log("  _consumable_data keys: %s" % str(consumable_ui._consumable_data.keys()))
	_log("  _consumable_spines keys: %s" % str(consumable_ui._consumable_spines.keys()))
	_log("  _fanned_icons keys: %s" % str(consumable_ui._fanned_icons.keys()))
	_log("  _active_consumable_count: %d" % consumable_ui._active_consumable_count)
	_log("  _current_state: %s" % ("SPINES" if consumable_ui._current_state == ConsumableUI.State.SPINES else "FANNED"))

	# Check for orphaned nodes
	var child_count: int = consumable_ui.get_child_count()
	_log("  ConsumableUI child count: %d" % child_count)
	for i in range(child_count):
		var child := consumable_ui.get_child(i)
		var cname: String = child.name
		var cclass: String = child.get_class()
		if child is ConsumableSpine:
			_log("    [color=yellow]SPINE[/color] '%s' — visible=%s alpha=%.2f" % [cname, child.visible, child.modulate.a])
		elif child is ConsumableIcon:
			_log("    [color=yellow]ICON[/color] '%s' — visible=%s alpha=%.2f" % [cname, child.visible, child.modulate.a])
		else:
			_log("    %s '%s'" % [cclass, cname])


func _on_reset() -> void:
	_log("[color=white]── Resetting ──[/color]")
	if consumable_ui and is_instance_valid(consumable_ui):
		consumable_ui.queue_free()
	await get_tree().process_frame
	_create_consumable_ui()
	_log("ConsumableUI recreated.")


# ── Logging ────────────────────────────────────────────────

func _log(msg: String) -> void:
	var timestamp := "%.2f" % (Time.get_ticks_msec() / 1000.0)
	var line := "[color=gray][%s][/color] %s" % [timestamp, msg]
	log_lines.append(line)
	# Keep log manageable
	if log_lines.size() > 200:
		log_lines = log_lines.slice(log_lines.size() - 150)
	output_label.clear()
	output_label.append_text("\n".join(log_lines))
	# Also print to Godot console
	print("[ConsumableSellTest] ", msg.replace("[color=", "").replace("[/color]", "").replace("]", ""))
