extends Node2D

## RoundTransitionTest
##
## Minimal test scene for the round transition visuals.
## Tests TV turn-on/off and New Round Panel independently.

@onready var crt_manager: CRTManager = $CRTTV/CRTManager
@onready var tv_power: TVPowerController = $CRTTV/TVPowerOverlay

func _ready() -> void:
	$TestButtons/TVOnButton.pressed.connect(_on_tv_on)
	$TestButtons/TVOffButton.pressed.connect(_on_tv_off)
	$TestButtons/ShowPanelButton.pressed.connect(_on_show_panel)
	$TestButtons/WaveButton.pressed.connect(_on_wave)

func _on_tv_on() -> void:
	if crt_manager:
		crt_manager.turn_on_tv()

func _on_tv_off() -> void:
	if crt_manager:
		crt_manager.turn_off_tv()

func _on_show_panel() -> void:
	var panel = preload("res://Scenes/UI/new_round_panel.tscn").instantiate()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.setup({
		"channel": 3,
		"round_number": 2,
		"challenge_name": "Test Challenge",
		"challenge_desc": "This is a test challenge for the round panel.",
		"debuffs": [],
		"chore_name": "Test Chore"
	})
	panel.show_panel()
	await panel.panel_dismissed
	panel.queue_free()

func _on_wave() -> void:
	var buttons = [$TestButtons/TVOnButton, $TestButtons/TVOffButton, $TestButtons/ShowPanelButton, $TestButtons/WaveButton]
	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.pivot_offset = btn.size / 2.0
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.15, 0.85), 0.08).set_delay(i * 0.06)
		tween.tween_property(btn, "scale", Vector2(0.95, 1.05), 0.08)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
