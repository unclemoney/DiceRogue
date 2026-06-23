extends Control
class_name DebuffGlowTest

const TEST_DEBUFF_PATHS: Array[String] = [
	"res://Scripts/Debuff/CostlyRollDebuff.tres",
	"res://Scripts/Debuff/TheDivisionDebuff.tres",
	"res://Scripts/Debuff/TooGreedyDebuff.tres",
]

var _debuff_ui: DebuffUI
var _status_label: Label
var _demo_timer: Timer
var _test_ids: Array[String] = []
var _test_debuffs: Dictionary = {}
var _demo_index: int = 0


func _ready() -> void:
	_build_ui()
	await get_tree().process_frame
	_populate_test_debuffs()
	_start_demo_cycle()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.04, 0.05, 0.08, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_preset(Control.PRESET_CENTER)
	layout.offset_left = -280
	layout.offset_top = -190
	layout.offset_right = 280
	layout.offset_bottom = 190
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 16)
	add_child(layout)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Debuff Glow Test"
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)

	var instructions := Label.new()
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.text = "Click the debuff row to open the fan-out cards. Move the mouse near chips and cards to test proximity glow. The timer will pulse one debuff at a time."
	instructions.custom_minimum_size = Vector2(520, 0)
	layout.add_child(instructions)

	_debuff_ui = DebuffUI.new()
	_debuff_ui.custom_minimum_size = Vector2(360, 86)
	_debuff_ui.size = Vector2(360, 86)
	layout.add_child(_debuff_ui)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 10)
	layout.add_child(button_row)

	button_row.add_child(_create_button("Pulse All", _pulse_all_debuffs))
	button_row.add_child(_create_button("Pulse Costly", _pulse_costly_roll))
	button_row.add_child(_create_button("Reset Demo", _reset_demo_cycle))

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(520, 0)
	_status_label.text = "Waiting for debuffs..."
	layout.add_child(_status_label)

	_demo_timer = Timer.new()
	_demo_timer.wait_time = 1.5
	_demo_timer.autostart = false
	_demo_timer.one_shot = false
	_demo_timer.timeout.connect(_on_demo_timer_timeout)
	add_child(_demo_timer)


func _create_button(text: String, pressed_callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed_callable)
	return button


func _populate_test_debuffs() -> void:
	for resource_path in TEST_DEBUFF_PATHS:
		var data := load(resource_path) as DebuffData
		if not data:
			push_error("[DebuffGlowTest] Failed to load DebuffData at %s" % resource_path)
			continue
		var debuff_instance: Debuff = null
		if data.scene:
			debuff_instance = data.scene.instantiate() as Debuff
		var icon := _debuff_ui.add_debuff(data, debuff_instance)
		if icon:
			if debuff_instance:
				_test_debuffs[data.id] = debuff_instance
				debuff_instance.emit_signal("debuff_started")
			else:
				icon.set_active(true)
			_test_ids.append(data.id)

	if _test_ids.is_empty():
		_status_label.text = "Failed to load test debuffs."
	else:
		_status_label.text = "Loaded debuffs: %s" % ", ".join(_test_ids)


func _start_demo_cycle() -> void:
	if _test_ids.is_empty():
		return
	_demo_index = 0
	_demo_timer.start()
	_on_demo_timer_timeout()


func _reset_demo_cycle() -> void:
	_status_label.text = "Resetting pulse cycle"
	_start_demo_cycle()


func _pulse_all_debuffs() -> void:
	if _test_ids.is_empty():
		return
	for debuff_id in _test_ids:
		_request_test_pulse(debuff_id, 1.0, 0.55)
	_status_label.text = "Pulsed all debuffs"


func _pulse_costly_roll() -> void:
	if not _test_ids.has("costly_roll"):
		_status_label.text = "Costly Roll debuff not loaded"
		return
	_request_test_pulse("costly_roll", 1.12, 0.6)
	_status_label.text = "Pulsed costly_roll"


func _on_demo_timer_timeout() -> void:
	if _test_ids.is_empty():
		_demo_timer.stop()
		return
	var debuff_id: String = _test_ids[_demo_index % _test_ids.size()]
	_request_test_pulse(debuff_id, 0.92, 0.52)
	_status_label.text = "Demo pulse: %s" % debuff_id
	_demo_index += 1


func _request_test_pulse(debuff_id: String, strength: float, duration: float) -> void:
	var debuff_instance := _test_debuffs.get(debuff_id) as Debuff
	if debuff_instance:
		debuff_instance.request_visual_pulse(strength, duration)
		return
	_debuff_ui.trigger_debuff_visual_pulse(debuff_id, strength, duration)