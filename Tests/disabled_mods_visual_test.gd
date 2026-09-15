extends Node

const DiceHandScene := preload("res://Scenes/Dice/dice_hand.tscn")
const DisabledModsDebuffScript := preload("res://Scripts/Debuff/disabled_mods_debuff.gd")
const DISABLED_SHADER_PATH := "res://Scripts/Shaders/disabled_powerup_overlay.gdshader"

var _odd_mod_data: ModData = preload("res://Scripts/Mods/OddOnlyMod.tres")
var _even_mod_data: ModData = preload("res://Scripts/Mods/EvenOnlyMod.tres")
var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("[DisabledModsVisualTest] Starting")
	await _run_test()
	_finish()


func _run_test() -> void:
	var hand := DiceHandScene.instantiate() as DiceHand
	add_child(hand)
	hand.spawn_dice()
	await hand.dice_spawned
	_check("dice hand spawned", hand.dice_list.size() > 0)
	if hand.dice_list.is_empty():
		return

	var die: Dice = hand.dice_list[0]
	die.add_mod(_odd_mod_data)
	await get_tree().process_frame
	var odd_icon := _find_mod_icon(die, _odd_mod_data.id)
	_check("odd mod icon created", odd_icon != null)
	if odd_icon == null:
		return
	_check("odd mod starts enabled", not _is_disabled_overlay(odd_icon.modicon.material))

	var debuff = DisabledModsDebuffScript.new()
	add_child(debuff)
	debuff.target = hand
	debuff.start()
	await get_tree().process_frame
	_check("odd mod removed from active set while debuff runs", not die.has_mod(_odd_mod_data.id))
	_check("existing odd mod icon shows disabled overlay", _is_disabled_overlay(odd_icon.modicon.material))

	die.add_mod(_even_mod_data)
	await get_tree().process_frame
	var even_icon := _find_mod_icon(die, _even_mod_data.id)
	_check("even mod icon created while debuff runs", even_icon != null)
	_check("newly added even mod stays functionally disabled", not die.has_mod(_even_mod_data.id))
	if even_icon:
		_check("newly added even mod icon shows disabled overlay", _is_disabled_overlay(even_icon.modicon.material))

	debuff.end()
	await get_tree().process_frame
	_check("odd mod restored after debuff ends", die.has_mod(_odd_mod_data.id))
	_check("even mod restored after debuff ends", die.has_mod(_even_mod_data.id))
	_check("odd mod icon restored after debuff ends", not _is_disabled_overlay(odd_icon.modicon.material))
	if even_icon:
		_check("even mod icon restored after debuff ends", not _is_disabled_overlay(even_icon.modicon.material))

	hand.queue_free()
	debuff.queue_free()


## _find_mod_icon(die, mod_id)
##
## Returns the ModIcon for the given mod id on the target die.
func _find_mod_icon(die: Dice, mod_id: String) -> ModIcon:
	for child in die.mod_container.get_children():
		if child is ModIcon and child.data and child.data.id == mod_id:
			return child
	return null


## _is_disabled_overlay(material)
##
## Detects whether the mod icon is currently using the disabled overlay shader.
func _is_disabled_overlay(material: Material) -> bool:
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		return shader_material.shader != null and shader_material.shader.resource_path == DISABLED_SHADER_PATH
	return false


func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("OK: " + label)
	else:
		_fail_count += 1
		push_error("FAILED: " + label)


func _finish() -> void:
	print("[DisabledModsVisualTest] RESULTS: %d passed, %d failed" % [_pass_count, _fail_count])
	if _fail_count == 0:
		print("[DisabledModsVisualTest] OK - all checks passed")
		get_tree().quit(0)
	else:
		print("[DisabledModsVisualTest] FAILED - %d check(s) failed" % _fail_count)
		get_tree().quit(1)