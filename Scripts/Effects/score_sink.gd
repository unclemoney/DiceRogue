extends Control
class_name ScoreSink

## ScoreSink
##
## The central "score sink" for the scoring animation sequence. Floating
## ScoreSpark numbers spiral into it; it displays the running score on an
## accelerating scale curve, wobbles on each arrival, blows up on the final
## score, then drains into the score labels and hides completely.
##
## All content is centered on the node origin (children use negative
## offsets), so global_position is always the visual center and scale/alpha
## tweens stay simple. The ScoreLabel NEVER rotates — the rotation wobble
## applies to the Chip and Glow only (owner redline).

const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

# --- Running-score scale curve ---
# scale = SINK_SCALE_MIN + (SINK_SCALE_MAX - SINK_SCALE_MIN)
#         * pow(clampf(score / SINK_SCALE_REF, 0, 1), SINK_SCALE_EXP)
# Slow growth at low scores, accelerating at high scores, hard cap.
const SINK_SCALE_MIN: float = 1.0
const SINK_SCALE_MAX: float = 1.8
const SINK_SCALE_REF: float = 60.0
const SINK_SCALE_EXP: float = 1.8

# --- Bounce/wobble ---
const WOBBLE_PUNCH_SCALE: float = 0.18  # scale overshoot per unit of intensity
const WOBBLE_PUNCH_T: float = 0.08
const WOBBLE_RETURN_T: float = 0.30
const WOBBLE_ROT_DEG: float = 6.0
const WOBBLE_CYCLES: float = 2.0
const WOBBLE_ROT_T: float = 0.35

# --- Blow-up ---
# Blow-up scale = current sink scale * BLOWUP_MULT, hard-capped at BLOWUP_CAP
# absolute, so small scores get a proportional climax and epic scores never
# push digits off screen (owner redline).
const BLOWUP_MULT: float = 1.5
const BLOWUP_CAP: float = 2.6
const BLOWUP_OUT: float = 0.18
const BLOWUP_HOLD: float = 0.12

# --- Pop-in ---
const POP_IN_T: float = 0.25
const SCORE_SETTLE_T: float = 0.12  # ease time when the running score changes

# --- Sink visuals (mall-core glass chip, VCR typography) ---
const CHIP_SIZE: Vector2 = Vector2(220, 120)
const SCORE_FONT_SIZE: int = 48
const CAPTION_FONT_SIZE: int = 14
const SCORE_OUTLINE_SIZE: int = 6
const CHIP_FILL: Color = Color(0.247059, 0.219608, 0.345098, 0.92)
const CHIP_BORDER: Color = Color(0.47451, 0.886275, 0.890196, 1.0)
const CHIP_SHADOW: Color = Color(0.070588, 0.062745, 0.101961, 0.45)
const GLOW_COLOR: Color = Color(0.137255, 0.411765, 0.415686, 0.35)
const TEXT_COLOR: Color = Color(0.968627, 0.941176, 1.0, 1.0)
const CAPTION_COLOR: Color = Color(0.968627, 0.941176, 1.0, 0.6)
const NEGATIVE_TINT: Color = Color(1.0, 0.470588, 0.576471, 1.0)
const FINAL_GOLD: Color = Color(1.0, 0.85, 0.3, 1.0)
const DRAIN_SCALE: float = 0.3

var chip: Panel
var glow: Panel
var caption_label: Label
var score_label: Label
var arrival_particles: CPUParticles2D
var final_particles: CPUParticles2D

var running_score: int = 0

var _rest_scale: float = SINK_SCALE_MIN
var _scale_tween: Tween
var _rot_tween: Tween
var _misc_tween: Tween

## _ready()
##
## Builds the chip/glow/labels/particles and starts hidden.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = RenderLayers.Z_SCREEN_FX

	# Glow halo behind the chip (rotates with the chip during wobble).
	glow = Panel.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_size = CHIP_SIZE + Vector2(24, 24)
	glow.size = glow_size
	glow.position = -glow_size / 2.0
	glow.pivot_offset = glow_size / 2.0
	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = GLOW_COLOR
	glow_style.set_corner_radius_all(28)
	glow_style.corner_detail = 8
	glow.add_theme_stylebox_override("panel", glow_style)
	add_child(glow)

	# Main glass chip.
	chip = Panel.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size = CHIP_SIZE
	chip.position = -CHIP_SIZE / 2.0
	chip.pivot_offset = CHIP_SIZE / 2.0
	var chip_style = StyleBoxFlat.new()
	chip_style.bg_color = CHIP_FILL
	chip_style.border_color = CHIP_BORDER
	chip_style.set_border_width_all(3)
	chip_style.set_corner_radius_all(18)
	chip_style.corner_detail = 8
	chip_style.shadow_color = CHIP_SHADOW
	chip_style.shadow_size = 8
	chip.add_theme_stylebox_override("panel", chip_style)
	add_child(chip)

	# Caption (never rotates).
	caption_label = Label.new()
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label.text = "SCORE"
	caption_label.add_theme_font_override("font", VCR_FONT)
	caption_label.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	caption_label.add_theme_color_override("font_color", CAPTION_COLOR)
	add_child(caption_label)

	# Running score (never rotates).
	score_label = Label.new()
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label.text = "0"
	score_label.add_theme_font_override("font", VCR_FONT)
	score_label.add_theme_font_size_override("font_size", SCORE_FONT_SIZE)
	score_label.add_theme_color_override("font_color", TEXT_COLOR)
	score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label.add_theme_constant_override("outline_size", SCORE_OUTLINE_SIZE)
	add_child(score_label)
	_layout_labels()

	# Small per-arrival burst.
	arrival_particles = _make_burst_particles(10, 0.35, 60.0, 140.0, 2.0, 4.0, Color(0.6, 0.95, 0.95, 1.0))
	add_child(arrival_particles)

	# Big golden burst for the final blow-up.
	final_particles = _make_burst_particles(36, 0.6, 120.0, 320.0, 3.0, 6.0, FINAL_GOLD)
	add_child(final_particles)

	visible = false
	modulate.a = 0.0

## _make_burst_particles(amount, lifetime, vel_min, vel_max, scale_min, scale_max, color)
##
## One-shot radial CPUParticles2D burst, emitting = false until restart().
func _make_burst_particles(amount: int, lifetime: float, vel_min: float, vel_max: float, scale_min: float, scale_max: float, color: Color) -> CPUParticles2D:
	var particles = CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = Vector2(0, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = vel_min
	particles.initial_velocity_max = vel_max
	particles.gravity = Vector2(0, 200)
	particles.scale_amount_min = scale_min
	particles.scale_amount_max = scale_max
	particles.color = color
	return particles

## _layout_labels()
##
## Re-centers caption and score text on the node origin after text changes.
func _layout_labels() -> void:
	var caption_min = caption_label.get_minimum_size()
	caption_label.position = Vector2(-caption_min.x / 2.0, -CHIP_SIZE.y / 2.0 + 10.0)
	var score_min = score_label.get_minimum_size()
	score_label.position = Vector2(-score_min.x / 2.0, -score_min.y / 2.0 + 8.0)

## get_sink_center() -> Vector2
##
## Visual center in canvas coordinates; spiral targets and bursts use this.
func get_sink_center() -> Vector2:
	return global_position

## get_blowup_duration() -> float
##
## Out + hold time so the controller can await the full climax.
func get_blowup_duration() -> float:
	return BLOWUP_OUT + BLOWUP_HOLD

## show_sink()
##
## Re-centers on the current viewport, zeroes the score, pops in.
func show_sink() -> void:
	_kill_tweens()
	position = get_viewport().get_visible_rect().size * 0.5
	running_score = 0
	_rest_scale = SINK_SCALE_MIN
	score_label.text = "0"
	score_label.add_theme_color_override("font_color", TEXT_COLOR)
	_layout_labels()
	chip.rotation = 0.0
	glow.rotation = 0.0
	visible = true
	scale = Vector2.ONE * _rest_scale * 0.5
	modulate.a = 0.0
	_misc_tween = create_tween()
	_misc_tween.set_parallel(true)
	_misc_tween.tween_property(self, "scale", Vector2.ONE * _rest_scale, POP_IN_T).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_misc_tween.tween_property(self, "modulate:a", 1.0, POP_IN_T)

## hide_sink()
##
## Fully hides the sink. It reappears only on the next scoring event.
func hide_sink() -> void:
	visible = false

## reset_sink()
##
## Kills all sink tweens and returns to the hidden, zeroed state.
func reset_sink() -> void:
	_kill_tweens()
	chip.rotation = 0.0
	glow.rotation = 0.0
	running_score = 0
	_rest_scale = SINK_SCALE_MIN
	modulate.a = 0.0
	visible = false

## set_running_score(value, animate)
##
## Updates the displayed number and eases the whole sink to the scale
## curve value for this score. Animate=false snaps (used for the final
## reconciliation to the authoritative score).
func set_running_score(value: int, animate: bool = true) -> void:
	running_score = value
	score_label.text = str(value)
	_layout_labels()
	_rest_scale = _scale_for_score(value)
	if not animate:
		if _scale_tween and _scale_tween.is_valid():
			_scale_tween.kill()
		scale = Vector2.ONE * _rest_scale
		return
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2.ONE * _rest_scale, SCORE_SETTLE_T).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## bounce_wobble(intensity, negative)
##
## Arrival feedback: scale punch on the whole sink (elastic return) plus a
## decaying-sine rotation wobble on Chip/Glow only. Negative arrivals tint
## the chip red for the duration.
func bounce_wobble(intensity: float, negative: bool = false) -> void:
	if not visible:
		return
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	var punch = _rest_scale * (1.0 + WOBBLE_PUNCH_SCALE * intensity)
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2.ONE * punch, WOBBLE_PUNCH_T).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE * _rest_scale, WOBBLE_RETURN_T).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	if _rot_tween and _rot_tween.is_valid():
		_rot_tween.kill()
	_rot_tween = create_tween()
	_rot_tween.tween_method(_apply_chip_rotation.bind(intensity), 0.0, 1.0, WOBBLE_ROT_T)

	if negative:
		chip.self_modulate = NEGATIVE_TINT
		var tint_tween = create_tween()
		tint_tween.tween_property(chip, "self_modulate", Color.WHITE, WOBBLE_ROT_T)

## arrival_burst()
##
## Small impact burst at the sink mouth for every spark arrival.
func arrival_burst() -> void:
	if visible:
		arrival_particles.restart()

## blow_up()
##
## Final-score climax: punch to current scale * BLOWUP_MULT (capped),
## golden text, big particle burst. The controller owns the hold timing.
func blow_up() -> void:
	var target_scale = minf(_rest_scale * BLOWUP_MULT, BLOWUP_CAP)
	_rest_scale = target_scale
	score_label.add_theme_color_override("font_color", FINAL_GOLD)
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2.ONE * target_scale, BLOWUP_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	final_particles.restart()

## drain(target_position, duration)
##
## The sink "empties into" the score labels: flies to the drain target
## while shrinking and fading out. Controller hides the sink afterwards.
func drain(target_position: Vector2, duration: float) -> void:
	_kill_tweens()
	_misc_tween = create_tween()
	_misc_tween.set_parallel(true)
	_misc_tween.tween_property(self, "global_position", target_position, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_misc_tween.tween_property(self, "scale", Vector2.ONE * DRAIN_SCALE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_misc_tween.tween_property(self, "modulate:a", 0.0, duration)

## _scale_for_score(value) -> float
##
## Accelerating (power > 1) capped scale curve for the running score.
func _scale_for_score(value: int) -> float:
	var t = clampf(float(maxi(value, 0)) / SINK_SCALE_REF, 0.0, 1.0)
	return SINK_SCALE_MIN + (SINK_SCALE_MAX - SINK_SCALE_MIN) * pow(t, SINK_SCALE_EXP)

## _apply_chip_rotation(progress, intensity)
##
## Decaying-sine rotation wobble. Chip and Glow only — digits never rotate.
func _apply_chip_rotation(progress: float, intensity: float) -> void:
	var angle = sin(progress * PI * WOBBLE_CYCLES) * deg_to_rad(WOBBLE_ROT_DEG) * intensity * (1.0 - progress)
	chip.rotation = angle
	glow.rotation = angle
	if progress >= 1.0:
		chip.rotation = 0.0
		glow.rotation = 0.0

## _kill_tweens()
##
## Stops all sink-owned tweens before state changes.
func _kill_tweens() -> void:
	for tween in [_scale_tween, _rot_tween, _misc_tween]:
		if tween and tween.is_valid():
			tween.kill()
	_scale_tween = null
	_rot_tween = null
	_misc_tween = null
