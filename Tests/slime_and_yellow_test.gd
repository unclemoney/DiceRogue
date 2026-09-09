extends Node

## slime_and_yellow_test.gd
##
## Covers:
##   1. Parameterized SlimePowerUp: each slime scene sets the correct exported
##      DiceColor.Type, and apply()/remove() register/unregister the color
##      chance modifier against DiceColorManager.
##   2. YellowSlime.tres loads with correct id/color/price/rarity.
##   3. ExtremeCouponingPowerUp registers/unregisters its additive against
##      ScoreModifierManager and cleans up on tree exit.
##
## Scene-based test (autoloads must be compiled first).
## Run headless:
##   godot --headless --path . Tests/slime_and_yellow_test.tscn --quit-after 60
## Exit code 0 = all checks passed, 1 = at least one failure.

const SlimePowerUpScript := preload("res://Scripts/PowerUps/slime_power_up.gd")
const ExtremeCouponingScript := preload("res://Scripts/PowerUps/extreme_couponing_power_up.gd")

const SLIME_SCENES := {
	"res://Scenes/PowerUp/GreenSlime.tscn": DiceColor.Type.GREEN,
	"res://Scenes/PowerUp/RedSlime.tscn": DiceColor.Type.RED,
	"res://Scenes/PowerUp/PurpleSlime.tscn": DiceColor.Type.PURPLE,
	"res://Scenes/PowerUp/BlueSlime.tscn": DiceColor.Type.BLUE,
	"res://Scenes/PowerUp/YellowSlimePowerUp.tscn": DiceColor.Type.YELLOW,
}

var _failures: int = 0


func _ready() -> void:
	print("[SlimeAndYellowTest] Starting")

	_test_slime_scenes_exported_color()
	_test_slime_register_unregister()
	_test_yellow_slime_data()
	_test_extreme_couponing()
	await _test_extreme_couponing_tree_exit()

	if _failures == 0:
		print("[SlimeAndYellowTest] PASS - all checks passed")
	else:
		print("[SlimeAndYellowTest] FAIL - %d check(s) failed" % _failures)

	get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[SlimeAndYellowTest] OK: " + label)
	else:
		push_error("[SlimeAndYellowTest] FAILED: " + label)
		_failures += 1


func _test_slime_scenes_exported_color() -> void:
	for scene_path in SLIME_SCENES.keys():
		var packed: PackedScene = load(scene_path)
		_check("scene loads: " + scene_path, packed != null)
		if not packed:
			continue
		var slime = packed.instantiate()
		_check("instance is SlimePowerUp: " + scene_path, slime is SlimePowerUpScript)
		var expected: DiceColor.Type = SLIME_SCENES[scene_path]
		_check("%s has exported color %s" % [scene_path, DiceColor.get_color_name(expected)],
			slime.dice_color_type == expected)
		_check("%s has default modifier 0.5" % scene_path,
			is_equal_approx(slime.color_modifier, 0.5))
		slime.free()


func _test_slime_register_unregister() -> void:
	var slime = load("res://Scenes/PowerUp/GreenSlime.tscn").instantiate()
	add_child(slime)

	var base_chance: int = DiceColorManager.get_modified_color_chance(DiceColor.Type.GREEN)
	_check("green base chance is 25 before apply", base_chance == 25)

	slime.apply(null)
	var modified_chance: int = DiceColorManager.get_modified_color_chance(DiceColor.Type.GREEN)
	_check("green chance halved after apply (25 -> 12)", modified_chance == 12)

	slime.remove(null)
	var restored_chance: int = DiceColorManager.get_modified_color_chance(DiceColor.Type.GREEN)
	_check("green chance restored to 25 after remove", restored_chance == 25)

	# Live-odds description still reports both values
	var desc: String = slime.get_current_description()
	_check("description mentions 1 in 25", desc.find("1 in 25") != -1)

	slime.free()


func _test_yellow_slime_data() -> void:
	var data: PowerUpData = load("res://Scripts/PowerUps/YellowSlime.tres")
	_check("YellowSlime.tres loads", data != null)
	if not data:
		return
	_check("yellow_slime id", data.id == "yellow_slime")
	_check("yellow_slime display_name", data.display_name == "Yellow Slime")
	_check("yellow_slime price 300", data.price == 300)
	_check("yellow_slime rarity legendary", data.rarity == "legendary")
	_check("yellow_slime scene set", data.scene != null)

	if data.scene:
		var slime = data.scene.instantiate()
		_check("yellow_slime scene color is YELLOW", slime.dice_color_type == DiceColor.Type.YELLOW)
		_check("yellow base chance is 120", DiceColor.get_color_chance(DiceColor.Type.YELLOW) == 120)
		slime.free()


func _test_extreme_couponing() -> void:
	var packed: PackedScene = load("res://Scenes/PowerUp/ExtremeCouponingPowerUp.tscn")
	_check("ExtremeCouponingPowerUp.tscn loads", packed != null)
	if not packed:
		return

	var couponing = packed.instantiate()
	_check("instance is ExtremeCouponingPowerUp", couponing is ExtremeCouponingScript)
	add_child(couponing)
	couponing.apply(null)

	_check("no additive registered before any grant",
		not ScoreModifierManager.has_additive("extreme_couponing"))

	couponing.on_consumable_granted("quick_cash")
	_check("+5 after first grant", ScoreModifierManager.get_additive("extreme_couponing") == 5)

	couponing.on_consumable_granted("half_price")
	_check("+10 after second grant", ScoreModifierManager.get_additive("extreme_couponing") == 10)
	_check("grant count tracked", couponing.consumables_granted == 2)

	couponing.remove(null)
	_check("additive unregistered after remove",
		not ScoreModifierManager.has_additive("extreme_couponing"))
	_check("total additive back to 0", ScoreModifierManager.get_total_additive() == 0)

	couponing.free()


func _test_extreme_couponing_tree_exit() -> void:
	var couponing = load("res://Scenes/PowerUp/ExtremeCouponingPowerUp.tscn").instantiate()
	add_child(couponing)
	couponing.apply(null)
	couponing.on_consumable_granted("any_score")
	_check("tree-exit setup: additive +5", ScoreModifierManager.get_additive("extreme_couponing") == 5)

	couponing.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	_check("additive unregistered on tree exit",
		not ScoreModifierManager.has_additive("extreme_couponing"))
