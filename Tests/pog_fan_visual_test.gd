extends Control

## Captures the real PowerUpUI fan at 1, 4, 5, and 7 items, then exercises the
## live debug-layer, shop-restoration, removal, expiry, and confiscation paths.

const SAMPLES := [
	"res://Scripts/PowerUps/Allowance.tres",
	"res://Scripts/PowerUps/ThePiggyBank.tres",
	"res://Scripts/PowerUps/MeltingDice.tres",
	"res://Scripts/PowerUps/HotStreak.tres",
	"res://Scripts/PowerUps/ExtraRainbow.tres",
	"res://Scripts/PowerUps/ExtraDice.tres",
	"res://Scripts/PowerUps/SnakeEyes.tres",
]
const SCREENSHOT_DIR := "res://Tests/_layout_shots"

var _failures := 0


class MockShop:
	extends Control

	func temporarily_minimize() -> void:
		visible = false

	func restore_from_minimize() -> void:
		visible = true


func _ready() -> void:
	call_deferred("_start")


func _start() -> void:
	DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR)
	var ui := load("res://Scenes/UI/power_up_ui.tscn").instantiate() as PowerUpUI
	ui.max_power_ups = 7
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	var shop := MockShop.new()
	add_child(shop)
	ui._shop_ui = shop
	await get_tree().process_frame
	for count in [1, 4, 5, 7]:
		for i in range(count):
			ui.add_power_up(load(SAMPLES[i]))
		ui._open_fan_view()
		await get_tree().create_timer(1.0).timeout
		if ui._compact_margin.visible:
			_fail("Compact row remained visible in fan-out")
		for spine in ui._spines.values():
			if spine.is_visible_in_tree():
				_fail("Compact spine remained visible in fan-out: %s" % spine.data.id)
		if shop.visible:
			_fail("Open shop was not minimized by fan-out")
		if count == 7:
			for id in ui.get_owned_power_up_ids():
				var icon := ui.get_power_up_icon(id)
				if id == "extra_dice":
					icon.set_synergy_halo(PowerUpData.SynergyHaloMode.RAINBOW)
				elif id == "allowance" or id == "hot_streak":
					icon.set_synergy_halo(PowerUpData.SynergyHaloMode.SET, PowerUpData.get_rating_color("PG"))
			await get_tree().process_frame
		var path := "%s/pog_foilsmith_fan_%d.png" % [SCREENSHOT_DIR, count]
		var image := get_viewport().get_texture().get_image()
		image.save_png(path)
		print("[PogFanVisualTest] screenshot saved: ", path)
		ui.fold_back()
		await get_tree().create_timer(0.5).timeout
		if not shop.visible:
			_fail("Shop was not restored after folding the fan")
		ui.clear_all()
		await get_tree().process_frame
	for i in range(2):
		ui.add_power_up(load(SAMPLES[i]))
	var layer := await ui.cycle_foil_debug_layer()
	if layer != FoilsmithCard.Layer.FOIL:
		_fail("PowerUpUI debug cycle did not reach FOIL")

	var removal := {"done": false}
	ui.animate_power_up_removal("allowance", func() -> void: removal.done = true)
	if not await _wait_for_flag(removal):
		_fail("PowerUp removal animation did not finish")
	else:
		await ui.remove_power_up("allowance")
		if ui.has_power_up("allowance"):
			_fail("Sold PowerUp remained in PowerUpUI")

	var confiscation := {"done": false}
	ui.animate_mom_confiscation(["the_piggy_bank"], Vector2(100, 100), func() -> void: confiscation.done = true)
	if not await _wait_for_flag(confiscation):
		_fail("Mom confiscation animation did not finish")

	var expiry := {"done": false}
	ui.animate_power_up_expiry("the_piggy_bank", func() -> void: expiry.done = true)
	if not await _wait_for_flag(expiry):
		_fail("PowerUp expiry animation did not finish")
	ui.queue_free()
	get_tree().quit(_failures)


func _wait_for_flag(state: Dictionary) -> bool:
	for _frame in range(360):
		if state.done:
			return true
		await get_tree().process_frame
	return false


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
