extends Control

const DICE_SCENE := preload("res://Scenes/Dice/dice.tscn")
const D6_DICE_DATA := preload("res://Scripts/Dice/d6_dice.tres")
const DiceColorClass := preload("res://Scripts/Core/dice_color.gd")

var _quit_after_run := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_parse_cmdline_args()
	print("=== Dice Visual Smoke Test ===")
	call_deferred("_run_smoke_test")


func _parse_cmdline_args() -> void:
	var user_args := OS.get_cmdline_user_args()
	_quit_after_run = user_args.has("--quit-after")


func _run_smoke_test() -> void:
	var specs := [
		{
			"label": "rolled_green",
			"position": Vector2(160, 180),
			"value": 3,
			"color": DiceColorClass.Type.GREEN,
			"state": "rolled"
		},
		{
			"label": "locked_red",
			"position": Vector2(280, 180),
			"value": 5,
			"color": DiceColorClass.Type.RED,
			"state": "locked"
		},
		{
			"label": "lockout_blue",
			"position": Vector2(400, 180),
			"value": 4,
			"color": DiceColorClass.Type.BLUE,
			"state": "lockout"
		},
		{
			"label": "disabled_purple",
			"position": Vector2(520, 180),
			"value": 6,
			"color": DiceColorClass.Type.PURPLE,
			"state": "disabled"
		},
		{
			"label": "debuff_two_yellow",
			"position": Vector2(640, 180),
			"value": 2,
			"color": DiceColorClass.Type.YELLOW,
			"state": "debuff"
		}
	]

	var spawned: Array = []
	for spec in specs:
		var die = DICE_SCENE.instantiate() as Dice
		if not die:
			push_error("[DiceVisualSmokeTest] Failed to instantiate dice scene")
			if _quit_after_run:
				get_tree().quit(1)
			return
		die.dice_data = D6_DICE_DATA
		add_child(die)
		spawned.append({
			"die": die,
			"spec": spec
		})

	await get_tree().process_frame

	for entry in spawned:
		var die: Dice = entry["die"]
		var spec: Dictionary = entry["spec"]
		var home_position: Vector2 = spec["position"]
		die.home_position = home_position
		die.position = home_position
		die.reset_visual_for_spawn()
		die.value = spec["value"]
		die.set_state(Dice.DiceState.ROLLED)
		die.force_color(spec["color"])

		match spec["state"]:
			"locked":
				die.set_state(Dice.DiceState.LOCKED)
			"lockout":
				die.set_dice_input_enabled(false)
				die.set_lock_shader_enabled(false)
			"disabled":
				die.make_disabled()
			"debuff":
				die.set_debuff_disabled_face_enabled(true)

		die.update_visual()
		print("[DiceVisualSmokeTest] Configured %s color=%s state=%s value=%d" % [
			spec["label"],
			DiceColorClass.get_color_name(spec["color"]),
			die.get_state_name(),
			die.value
		])

	await get_tree().create_timer(0.8).timeout
	print("[DiceVisualSmokeTest] Smoke test completed")

	if _quit_after_run:
		get_tree().quit()