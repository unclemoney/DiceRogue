extends Control
class_name InteractiveGameTitleTest

## InteractiveGameTitleTest
##
## Manual test harness for the in-game reactive title. Provides bounded preview
## controls for each event family plus a burst mode for stress testing.

@onready var interactive_title: Node = $MarginContainer/VBoxContainer/TitlePanel/InteractiveGameTitle
@onready var intensity_slider: HSlider = $MarginContainer/VBoxContainer/ControlsPanel/MarginContainer/ControlsVBox/IntensityRow/IntensitySlider
@onready var intensity_value_label: Label = $MarginContainer/VBoxContainer/ControlsPanel/MarginContainer/ControlsVBox/IntensityRow/IntensityValueLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusPanel/MarginContainer/StatusLabel

var _autorun_all: bool = false
var _quit_after_run: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_parse_cmdline_args()
	if intensity_slider:
		intensity_slider.value_changed.connect(_on_intensity_slider_changed)
		_on_intensity_slider_changed(intensity_slider.value)
	_connect_button("RollButton", _on_roll_button_pressed)
	_connect_button("ScoreButton", _on_score_button_pressed)
	_connect_button("PowerButton", _on_power_button_pressed)
	_connect_button("ConsumableButton", _on_consumable_button_pressed)
	_connect_button("DebuffButton", _on_debuff_button_pressed)
	_connect_button("ChallengeButton", _on_challenge_button_pressed)
	_connect_button("ChallengeWinButton", _on_challenge_win_button_pressed)
	_connect_button("ChallengeFailButton", _on_challenge_fail_button_pressed)
	_connect_button("RandomButton", _on_random_button_pressed)
	_connect_button("BurstButton", _on_burst_button_pressed)
	if interactive_title and interactive_title.has_signal("debug_effect_played"):
		interactive_title.debug_effect_played.connect(_on_title_effect_played)
	status_label.text = "Ready. Trigger previews with the buttons below."
	if _autorun_all:
		call_deferred("_autorun_suite")
	else:
		_preview("score")


func _parse_cmdline_args() -> void:
	var user_args := OS.get_cmdline_user_args()
	_autorun_all = user_args.has("--run-all")
	_quit_after_run = user_args.has("--quit-after")


func _autorun_suite() -> void:
	var families = ["roll", "score", "power", "consumable", "debuff", "challenge"]
	for family in families:
		_preview(family)
		await get_tree().create_timer(0.12).timeout
	_on_random_button_pressed()
	await get_tree().create_timer(0.12).timeout
	await _on_burst_button_pressed()
	if _quit_after_run:
		get_tree().quit()


func _connect_button(node_name: String, handler: Callable) -> void:
	var button = get_node_or_null("MarginContainer/VBoxContainer/ControlsPanel/MarginContainer/ControlsVBox/ButtonGrid/%s" % node_name)
	if button:
		button.pressed.connect(handler)


func _on_intensity_slider_changed(value: float) -> void:
	if intensity_value_label:
		intensity_value_label.text = "%.2f" % value


func _on_roll_button_pressed() -> void:
	_preview("roll")


func _on_score_button_pressed() -> void:
	_preview("score")


func _on_power_button_pressed() -> void:
	_preview("power")


func _on_consumable_button_pressed() -> void:
	_preview("consumable")


func _on_debuff_button_pressed() -> void:
	_preview("debuff")


func _on_challenge_button_pressed() -> void:
	_preview("challenge")


func _on_challenge_win_button_pressed() -> void:
	_preview("challenge_complete")


func _on_challenge_fail_button_pressed() -> void:
	_preview("challenge_fail")


func _on_random_button_pressed() -> void:
	if not interactive_title or not interactive_title.has_method("debug_play_random_event"):
		status_label.text = "InteractiveGameTitle missing debug_play_random_event()."
		return
	var chosen = interactive_title.debug_play_random_event(_current_intensity())
	status_label.text = "Random preview: %s @ %.2f" % [chosen, _current_intensity()]


func _on_burst_button_pressed() -> void:
	var families = ["roll", "score", "power", "consumable", "debuff", "challenge"]
	for i in range(families.size()):
		await get_tree().create_timer(0.08).timeout
		_preview(families[i], false)
	status_label.text = "Burst preview finished @ %.2f" % _current_intensity()


func _preview(event_name: String, update_status: bool = true) -> void:
	if not interactive_title or not interactive_title.has_method("debug_preview_event"):
		status_label.text = "InteractiveGameTitle missing debug_preview_event()."
		return
	interactive_title.debug_preview_event(event_name, _current_intensity())
	if update_status:
		status_label.text = "Previewed %s @ %.2f" % [event_name, _current_intensity()]


func _current_intensity() -> float:
	if intensity_slider:
		return float(intensity_slider.value)
	return 0.6


func _on_title_effect_played(effect_name: String, intensity: float) -> void:
	status_label.text = "Effect played: %s @ %.2f" % [effect_name, intensity]