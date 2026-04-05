extends Control

## DiceAnimationTest
##
## Interactive test scene for verifying all juicy dice animations:
## hover tilt, squash/stretch roll, bouncy entry, explosion exit,
## anticipation, shockwave, idle breathing, celebration, screen shake,
## and intensity scaling.

const DiceHandScene = preload("res://Scenes/Dice/dice_hand.tscn")

var dice_hand: DiceHand
var simulated_score: int = 0
var simulated_progress: float = 0.0

@onready var spawn_btn: Button = $UI/Buttons/SpawnBtn
@onready var roll_btn: Button = $UI/Buttons/RollBtn
@onready var exit_btn: Button = $UI/Buttons/ExitBtn
@onready var celebrate_btn: Button = $UI/Buttons/CelebrateBtn
@onready var shake_btn: Button = $UI/Buttons/ShakeBtn
@onready var flash_btn: Button = $UI/Buttons/FlashBtn
@onready var score_slider: HSlider = $UI/Sliders/ScoreSlider
@onready var score_label: Label = $UI/Sliders/ScoreLabel
@onready var progress_slider: HSlider = $UI/Sliders/ProgressSlider
@onready var progress_label: Label = $UI/Sliders/ProgressLabel
@onready var intensity_label: Label = $UI/IntensityLabel


func _ready() -> void:
	# Spawn DiceHand as child
	dice_hand = DiceHandScene.instantiate() as DiceHand
	dice_hand.position = Vector2.ZERO
	add_child(dice_hand)
	# Move DiceHand behind UI
	move_child(dice_hand, 0)

	spawn_btn.pressed.connect(_on_spawn)
	roll_btn.pressed.connect(_on_roll)
	exit_btn.pressed.connect(_on_exit)
	celebrate_btn.pressed.connect(_on_celebrate)
	shake_btn.pressed.connect(_on_shake)
	flash_btn.pressed.connect(_on_flash)
	score_slider.value_changed.connect(_on_score_changed)
	progress_slider.value_changed.connect(_on_progress_changed)

	score_slider.min_value = 0
	score_slider.max_value = 1500
	score_slider.step = 10
	progress_slider.min_value = 0.0
	progress_slider.max_value = 1.0
	progress_slider.step = 0.05

	_update_intensity_display()


func _on_spawn() -> void:
	dice_hand.spawn_dice()
	# Apply current intensity after spawn
	_apply_intensity()


func _on_roll() -> void:
	dice_hand.roll_all()


func _on_exit() -> void:
	dice_hand.animate_all_dice_exit()


func _on_celebrate() -> void:
	var params = DiceAnimationIntensity.calculate(simulated_progress, simulated_score)
	dice_hand.animate_celebration_cascade(params.get("bounce_height_mult", 1.0))


func _on_shake() -> void:
	var params = DiceAnimationIntensity.calculate(simulated_progress, simulated_score)
	dice_hand.animate_screen_shake(params.get("bounce_height_mult", 1.0))


func _on_flash() -> void:
	for die in dice_hand.dice_list:
		if is_instance_valid(die):
			die.animate_critical_flash()


func _on_score_changed(val: float) -> void:
	simulated_score = int(val)
	score_label.text = "Score: %d" % simulated_score
	_apply_intensity()
	_update_intensity_display()


func _on_progress_changed(val: float) -> void:
	simulated_progress = val
	progress_label.text = "Progress: %.0f%%" % (val * 100.0)
	_apply_intensity()
	_update_intensity_display()


func _apply_intensity() -> void:
	var params = DiceAnimationIntensity.calculate(simulated_progress, simulated_score)
	for die in dice_hand.dice_list:
		if is_instance_valid(die):
			die.intensity_params = params


func _update_intensity_display() -> void:
	var params = DiceAnimationIntensity.calculate(simulated_progress, simulated_score)
	var text = "Intensity: bounce=%.2f speed=%.2f rot=%.2f shock=%.2f idle=%.2f" % [
		params.get("bounce_height_mult", 1.0),
		params.get("speed_mult", 1.0),
		params.get("rotation_mult", 1.0),
		params.get("shockwave_scale", 1.0),
		params.get("idle_intensity", 1.0),
	]
	intensity_label.text = text
