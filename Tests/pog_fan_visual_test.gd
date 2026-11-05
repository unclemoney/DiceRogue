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
		if count == 1:
			var tile := ui.get_power_up_icon("allowance").get_node("KioskTile") as KioskTile
			tile.foilsmith_card._target = Vector2(0.5, 0.35)
			await get_tree().create_timer(0.35).timeout
			var tilted_image := get_viewport().get_texture().get_image()
			tilted_image.save_png("%s/pog_rarity_tilt.png" % SCREENSHOT_DIR)
			tile.foilsmith_card._target = Vector2.ZERO
		if count > 1:
			var previous_mode: bool = GameSettings.power_up_static_descriptions
			GameSettings.power_up_static_descriptions = true
			GameSettings.settings_saved.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			for icon in ui._fanned_icons.values():
				var tile := icon.get_node("KioskTile") as KioskTile
				if not tile.description_panel.visible or tile.size != Vector2(200, 300):
					_fail("Static fan layout failed at %d items" % count)
			var static_image := get_viewport().get_texture().get_image()
			static_image.save_png("%s/pog_static_fan_%d.png" % [SCREENSHOT_DIR, count])
			GameSettings.power_up_static_descriptions = previous_mode
			GameSettings.settings_saved.emit()
			await get_tree().process_frame
			await get_tree().process_frame
		ui.fold_back()
		await get_tree().create_timer(0.5).timeout
		if not shop.visible:
			_fail("Shop was not restored after folding the fan")
		ui.clear_all()
		await get_tree().process_frame
	await _test_description_modes(ui)
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


func _test_description_modes(ui: PowerUpUI) -> void:
	var previous_mode: bool = GameSettings.power_up_static_descriptions
	var previous_follow: bool = TweenFX.follow_cursor
	TweenFX.follow_cursor = false
	GameSettings.power_up_static_descriptions = false
	ui.add_power_up(load(SAMPLES[2]))
	ui._open_fan_view()
	await get_tree().create_timer(1.0).timeout
	var icon := ui.get_power_up_icon("melting_dice")
	if not icon:
		_fail("Description test did not create its fanned icon")
		return
	var tile := icon.get_node("KioskTile") as KioskTile
	Input.warp_mouse(tile.get_global_rect().get_center())
	ui._on_fan_icon_hovered("melting_dice")
	if not await _wait_for_tooltip_visible(ui):
		_fail("Fan hover did not show the description tooltip")
	await get_tree().create_timer(0.4).timeout
	if not ui._spine_tooltip is Tooltip or not ui._spine_tooltip.tint_border_by_rarity:
		_fail("PowerUp description does not use the shared Mom tooltip styling")
	ui._on_fan_icon_unhovered("allowance")
	if not ui._spine_tooltip.visible:
		_fail("A stale PowerUp exit hid the active tooltip")
	ui.update_power_up_description("melting_dice", "Current bonus: +72")
	await get_tree().process_frame
	await get_tree().process_frame
	if not _tooltip_contains(ui, "Current bonus: +72"):
		_fail("Visible tooltip did not refresh its live description")
	var tooltip_image := get_viewport().get_texture().get_image()
	tooltip_image.save_png("%s/pog_description_tooltip.png" % SCREENSHOT_DIR)
	ui._on_fan_icon_unhovered("melting_dice")
	await get_tree().create_timer(0.3).timeout
	if ui._spine_tooltip.visible:
		_fail("Owning PowerUp exit did not hide the tooltip")
	ui._on_fan_icon_hovered("melting_dice")
	ui._on_fan_icon_unhovered("melting_dice")
	await get_tree().create_timer(0.4).timeout
	if ui._spine_tooltip.visible:
		_fail("A delayed tooltip show survived its hover exit")

	GameSettings.power_up_static_descriptions = true
	GameSettings.settings_saved.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if not tile.description_panel.visible:
		_fail("Static setting did not show the inline description")
	if ui._spine_tooltip.visible:
		_fail("Static setting left the hover tooltip visible")
	if tile.sticker_badge.scale.x >= 1.0:
		_fail("Static mode did not shrink the Mom badge")
	ui._on_fan_icon_hovered("melting_dice")
	await get_tree().create_timer(0.3).timeout
	if ui._spine_tooltip.visible:
		_fail("Static mode allowed a hover tooltip")
	ui.update_power_up_description("melting_dice", "Current bonus: +64")
	if tile.description_label.text != "Current bonus: +64":
		_fail("Static description did not refresh its live value")
	var static_image := get_viewport().get_texture().get_image()
	static_image.save_png("%s/pog_description_static.png" % SCREENSHOT_DIR)

	GameSettings.power_up_static_descriptions = false
	GameSettings.settings_saved.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if tile.description_panel.visible:
		_fail("Hover setting did not hide the inline description")
	var pointer := InputEventMouseMotion.new()
	pointer.position = tile.get_global_rect().get_center()
	pointer.global_position = pointer.position
	get_viewport().push_input(pointer, true)
	if not await _wait_for_tooltip_visible(ui):
		_fail("Real GUI pointer input did not show the fan tooltip")
	tile.description_unhovered.emit("melting_dice")
	ui.fold_back()
	await get_tree().create_timer(0.5).timeout
	ui.clear_all()
	GameSettings.power_up_static_descriptions = previous_mode
	TweenFX.follow_cursor = previous_follow
	GameSettings.settings_saved.emit()
	await get_tree().process_frame


func _tooltip_contains(ui: PowerUpUI, expected: String) -> bool:
	for child in ui._spine_tooltip.find_children("*", "RichTextLabel", true, false):
		var label := child as RichTextLabel
		if expected in label.text:
			return true
	return false


func _wait_for_tooltip_visible(ui: PowerUpUI) -> bool:
	for _frame in range(120):
		if ui._spine_tooltip.visible:
			return true
		await get_tree().process_frame
	print("[PogFanVisualTest] tooltip diagnostic: size=", ui._spine_tooltip.size, " min=", ui._spine_tooltip.get_combined_minimum_size(), " mouse=", ui._spine_tooltip.get_global_mouse_position(), " gen=", ui._spine_tooltip._show_gen)
	return false


func _wait_for_flag(state: Dictionary) -> bool:
	for _frame in range(360):
		if state.done:
			return true
		await get_tree().process_frame
	return false


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
