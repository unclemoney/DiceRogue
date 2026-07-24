extends Control

## Visual test: lay out PowerUpIcons (kiosk tiles) for a sample of PowerUps
## from each rating sheet, then screenshot and quit.
## Run: godot --path . Tests/PogFanVisualTest.tscn
## Screenshot lands in res://_pog_work/icons_shot.png

const SAMPLES := [
	"res://Scripts/PowerUps/Allowance.tres",
	"res://Scripts/PowerUps/ThePiggyBank.tres",
	"res://Scripts/PowerUps/MeltingDice.tres",
	"res://Scripts/PowerUps/HotStreak.tres",
	"res://Scripts/PowerUps/ExtraRainbow.tres",
	"res://Scripts/PowerUps/ExtraDice.tres",
	"res://Scripts/PowerUps/SnakeEyes.tres",
]


func _ready() -> void:
	call_deferred("_start")


func _start() -> void:
	await get_tree().process_frame
	var icon_scene: PackedScene = load("res://Scenes/PowerUp/power_up_icon.tscn")
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	for path in SAMPLES:
		var data: PowerUpData = load(path)
		var icon: PowerUpIcon = icon_scene.instantiate()
		row.add_child(icon)
		icon.set_data(data)

	await get_tree().create_timer(1.0).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_pog_work/icons_shot.png")
	print("[PogIconTest] screenshot saved")
	get_tree().quit()
