extends PanelContainer
class_name LevelChip

## LevelChip
##
## Small rounded chip showing a scorecard category's upgrade level numeral.
## play_upgrade()/play_downgrade() run the plan §4.1/§4.2 animations:
## scale punch with the numeral ticking at the apex, modulate flash, and
## particle bursts for the juice/shard variants.

signal upgrade_flash_finished
signal downgrade_finished

const UPGRADE_PARTICLES := preload("res://Scenes/Effects/ScorecardUpgradeParticles.tscn")
const DOWNGRADE_PARTICLES := preload("res://Scenes/Effects/ScorecardDowngradeParticles.tscn")

const UPGRADE_PUNCH_SCALE := Vector2(1.35, 1.35)
const UPGRADE_GOLD_FLASH := Color(1.6, 1.4, 0.6, 1.0)
const DOWNGRADE_RED_FLASH := Color(1.6, 0.5, 0.5, 1.0)
const DOWNGRADE_DIP_SCALE := Vector2(0.85, 0.85)
const DOWNGRADE_OVERSHOOT_SCALE := Vector2(1.05, 1.05)

# Fill ramp: Lv.1 keeps the original flat grey; the fill warps toward gold on
# a log scale (Lv.20+ is fully hot). The numeral darkens for contrast at the
# hot end. Flashes write modulate, not bg_color, so they never fight the ramp.
const CHIP_LOW := Color(0.16, 0.14, 0.22, 1.0)
const CHIP_HIGH := Color(0.85, 0.65, 0.25, 1.0)
const CHIP_TEXT_LOW := Color(1.0, 1.0, 1.0, 1.0)
const CHIP_TEXT_HIGH := Color(0.12, 0.08, 0.04, 1.0)

@export var level: int = 1: set = set_level

var chip_label: Label = null
var _anim_tween: Tween = null
var _mod_tween: Tween = null
var _stylebox: StyleBoxFlat = null


## _ready()
##
## Caches the label, centers the pivot for the scale tweens, and keeps the
## pivot centered whenever the chip is resized. Duplicates the panel
## StyleBoxFlat: rows share the same .tscn, so the fill ramp needs a
## per-instance stylebox.
func _ready() -> void:
	chip_label = $ChipLabel
	var shared := get_theme_stylebox("panel") as StyleBoxFlat
	if shared:
		_stylebox = shared.duplicate()
		add_theme_stylebox_override("panel", _stylebox)
	_center_pivot()
	resized.connect(_center_pivot)
	_update_label()
	_apply_level_color()


func _exit_tree() -> void:
	_kill_tweens()


func _center_pivot() -> void:
	pivot_offset = size / 2.0


func _kill_tweens() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
		_anim_tween = null
	if _mod_tween and _mod_tween.is_valid():
		_mod_tween.kill()
		_mod_tween = null


## set_level(value)
##
## Sets the displayed level, clamped to 1-99. Safe to call before _ready()
## (falls back to a direct child lookup while @onready vars are unset).
## Also drives the fill ramp (grey -> gold on a log scale).
func set_level(value: int) -> void:
	level = clampi(value, 1, 99)
	_update_label()
	_apply_level_color()


func _update_label() -> void:
	var label: Label = chip_label
	if label == null:
		label = get_node_or_null("ChipLabel")
	if label:
		label.text = str(level)


## _apply_level_color()
##
## Ramps the chip fill and numeral color with level:
## t = clamp(log(level) / log(20), 0..1); Lv.1 is the flat grey, Lv.20+ gold.
func _apply_level_color() -> void:
	var t := clampf(log(level) / log(20.0), 0.0, 1.0)
	if _stylebox:
		_stylebox.bg_color = CHIP_LOW.lerp(CHIP_HIGH, t)
	var label: Label = chip_label
	if label == null:
		label = get_node_or_null("ChipLabel")
	if label:
		label.add_theme_color_override("font_color", CHIP_TEXT_LOW.lerp(CHIP_TEXT_HIGH, t))


## play_upgrade(with_juice)
##
## Plan §4.1 (~0.5s): scale punch 1.0 -> 1.35 (0.12s, TRANS_BACK), numeral
## ticks up at the apex, settle to 1.0 (0.25s; TRANS_ELASTIC when juiced),
## gold modulate flash decaying over the whole animation. The juice variant
## also bursts ScorecardUpgradeParticles at the chip's global center.
## The once-per-batch upgrade sound is handled by ScoreCardUI (it owns the
## batch counter); emits upgrade_flash_finished at completion.
func play_upgrade(with_juice: bool = false) -> void:
	_kill_tweens()
	_center_pivot()
	var target_level := mini(level + 1, 99)

	scale = Vector2.ONE
	modulate = UPGRADE_GOLD_FLASH

	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "scale", UPGRADE_PUNCH_SCALE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_callback(set_level.bind(target_level))
	if with_juice:
		_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_callback(upgrade_flash_finished.emit)

	# Gold flash decays across the full 0.37s
	_mod_tween = create_tween()
	_mod_tween.tween_property(self, "modulate", Color.WHITE, 0.37)

	if with_juice:
		_spawn_particles(UPGRADE_PARTICLES)


## play_downgrade()
##
## Plan §4.2 (<=600ms): t=0-80ms red flash; t=80-200ms numeral ticks down at
## the scale-punch apex (1.0 -> 0.85 -> 1.05 -> 1.0, TRANS_BACK); shard
## particles t=0-450ms; downgrade_finished emitted at t=600ms.
func play_downgrade() -> void:
	_kill_tweens()
	_center_pivot()
	var target_level := maxi(level - 1, 1)

	modulate = DOWNGRADE_RED_FLASH
	# TODO: downgrade SFX (design: handled separately)
	_spawn_particles(DOWNGRADE_PARTICLES)

	_anim_tween = create_tween()
	# t=0-80ms: scale dips under the red flash
	_anim_tween.tween_property(self, "scale", DOWNGRADE_DIP_SCALE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# t=80-200ms: numeral ticks down at the apex, overshoot, settle
	_anim_tween.tween_callback(set_level.bind(target_level))
	_anim_tween.tween_property(self, "scale", DOWNGRADE_OVERSHOOT_SCALE, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Hold to 600ms total, then signal completion
	_anim_tween.tween_interval(0.4)
	_anim_tween.tween_callback(downgrade_finished.emit)

	# Red flash decays by t=200ms
	_mod_tween = create_tween()
	_mod_tween.tween_property(self, "modulate", Color.WHITE, 0.2)


func _spawn_particles(scene: PackedScene) -> void:
	if not get_tree() or not get_tree().root:
		return
	var particles = scene.instantiate() as GPUParticles2D
	if not particles:
		return
	get_tree().root.add_child(particles)
	particles.global_position = get_global_transform_with_canvas().origin + size / 2.0
	particles.emitting = true
	var cleanup_delay = particles.lifetime + 0.5
	get_tree().create_timer(cleanup_delay).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)
