# game_progress_bar.gd
extends Control
class_name GameProgressBar

## GameProgressBar
##
## One progress bar for every context (Challenge = teal, Bonus = pink,
## resources = gold). TextureProgressBar is retired.
##
## Structure: this Control _draw()s only the rounded matte track, with
## clip_children = CLIP_CHILDREN_AND_DRAW so the child fill Controls are
## clipped to the track's drawn rounded shape — the fill is a plain rect and
## defines no corners of its own, so it cannot bulge past the end caps at
## low percentages (clip_contents alone only clips to the square rect).
##
##   GameProgressBar (clip children AND draw: the track)
##   ├─ Fill (ColorRect + progress_bar_fill shader, width = value ratio)
##   ├─ OverflowFill (same shader, heat = 1, width = excess ratio)
##   └─ NotchOverlay (draw signal: 10% ticks, threshold marker, over-wash)
##
## Fills tween ~250ms ease-out (never snap). A diagonal sheen sweeps the
## fill for ~2s after each value change, then freezes — motion means change.
## Overflow (value > max) runs the sheen ~1.5x faster on a hotter base.
##
## TextureProgressBar-compat props (tint_progress / tint_under / tint_over)
## are kept so existing callers drop in without changes.

const TWEEN_DURATION := 0.25
const TICK_ALPHA := 0.12
const SHEEN_START := -0.2
const SHEEN_END := 1.5
const SHEEN_DURATION := 2.4        # band speed ~0.7/s
const SHEEN_DURATION_HOT := 1.6    # ~1.5x speed on overflow
const SHEEN_FADE_OUT := 0.3
const FILL_SHADER := preload("res://Scripts/Shaders/progress_bar_fill.gdshader")

@export var min_value: float = 0.0:
	set(v):
		min_value = v
		_update_fills()
@export var max_value: float = 100.0:
	set(v):
		max_value = v
		_update_fills()
@export var value: float = 0.0:
	set(v):
		var was_hot := value > max_value
		value = v
		_sweep_to(v, v > max_value or was_hot)
@export var fill_color: Color = Color(0.549020, 0.729412, 0.662745, 1.0):
	set(v):
		fill_color = v
		_fill_draw_color = v
		_apply_fill_colors()
@export var track_color: Color = Color(0.02, 0.02, 0.03, 0.6):
	set(v):
		track_color = v
		_track_draw_color = v
		queue_redraw()
@export var overflow_color: Color = Color(0.75, 1.0, 0.9, 1.0):
	set(v):
		overflow_color = v
		_overflow_override = true
		_overflow_draw_color = v
		_apply_fill_colors()
@export var show_ticks: bool = false:
	set(v):
		show_ticks = v
		_redraw_overlay()
## Tick marker at an absolute value (e.g. the win threshold); < 0 hides it.
@export var threshold: float = -1.0:
	set(v):
		threshold = v
		_redraw_overlay()

# TextureProgressBar-compat tints. tint_under = WHITE restores the default
# track (texture bars treated white as "no tint"). tint_over is a translucent
# wash over the whole bar (the old frame-overlay slot); WHITE clears it.
var tint_progress: Color = Color.WHITE:
	set(v):
		tint_progress = v
		_fill_draw_color = v if v != Color.WHITE else fill_color
		_apply_fill_colors()
var tint_under: Color = Color.WHITE:
	set(v):
		tint_under = v
		_track_draw_color = v if v != Color.WHITE else track_color
		queue_redraw()
var tint_over: Color = Color.WHITE:
	set(v):
		tint_over = v
		_over_draw_color = Color.TRANSPARENT if v == Color.WHITE else v
		_redraw_overlay()

var _display_value: float = 0.0:
	set(v):
		_display_value = v
		_update_fills()
var _fill_tween: Tween
var _sheen_tween: Tween
var _instant_fill: bool = false
var _fill_draw_color: Color
var _track_draw_color: Color
var _overflow_draw_color: Color
var _overflow_override: bool = false
var _over_draw_color: Color = Color.TRANSPARENT
var _track_style: StyleBoxFlat
var _fill_rect: ColorRect
var _overflow_rect: ColorRect
var _notch_overlay: Control
var _fill_material: ShaderMaterial
var _overflow_material: ShaderMaterial


func _init() -> void:
	_fill_draw_color = fill_color
	_track_draw_color = track_color
	_overflow_draw_color = overflow_color
	_track_style = StyleBoxFlat.new()
	# Fully rounded ends: the renderer clamps radius to half the bar height
	_track_style.set_corner_radius_all(1000)
	_track_style.corner_detail = 8
	_track_style.anti_aliasing = true


func _ready() -> void:
	# Children clip to the track's drawn rounded shape (alpha mask), which is
	# what actually stops the fill bleeding past the rounded end caps
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_build_children()
	resized.connect(_on_resized)
	# Start at the current value; no opening sweep or sheen from zero
	_display_value = value


func _build_children() -> void:
	if _fill_rect and is_instance_valid(_fill_rect):
		return

	_fill_material = ShaderMaterial.new()
	_fill_material.shader = FILL_SHADER

	_overflow_material = ShaderMaterial.new()
	_overflow_material.shader = FILL_SHADER
	_overflow_material.set_shader_parameter("heat", 1.0)

	_fill_rect = ColorRect.new()
	_fill_rect.name = "Fill"
	_fill_rect.anchor_top = 0.0
	_fill_rect.anchor_bottom = 1.0
	_fill_rect.anchor_left = 0.0
	_fill_rect.anchor_right = 0.0
	_fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect.material = _fill_material
	add_child(_fill_rect)

	_overflow_rect = ColorRect.new()
	_overflow_rect.name = "OverflowFill"
	_overflow_rect.anchor_top = 0.0
	_overflow_rect.anchor_bottom = 1.0
	_overflow_rect.anchor_left = 0.0
	_overflow_rect.anchor_right = 0.0
	_overflow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overflow_rect.material = _overflow_material
	_overflow_rect.visible = false
	add_child(_overflow_rect)

	_notch_overlay = Control.new()
	_notch_overlay.name = "NotchOverlay"
	_notch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notch_overlay)
	_notch_overlay.draw.connect(_draw_overlay)

	_apply_fill_colors()
	_update_fills()


func _on_resized() -> void:
	queue_redraw()
	_redraw_overlay()


func _apply_fill_colors() -> void:
	# Overflow defaults to a hotter version of the context fill color;
	# overflow_color only wins when explicitly assigned
	if not _overflow_override:
		_overflow_draw_color = _fill_draw_color.lightened(0.35)
	if _fill_material:
		_fill_material.set_shader_parameter("base_color", _fill_draw_color)
	if _overflow_material:
		_overflow_material.set_shader_parameter("base_color", _overflow_draw_color)


func _redraw_overlay() -> void:
	if _notch_overlay and is_instance_valid(_notch_overlay):
		_notch_overlay.queue_redraw()


## _update_fills()
##
## Sizes the plain-rect fill children by anchor; clipping to the rounded
## track shape is done by the parent's clip_children_mode, not here.
func _update_fills() -> void:
	if not _fill_rect:
		return
	var span := maxf(max_value - min_value, 0.0001)
	_fill_rect.anchor_right = clampf((_display_value - min_value) / span, 0.0, 1.0)
	var excess := clampf((_display_value - max_value) / span, 0.0, 1.0)
	_overflow_rect.anchor_right = excess
	_overflow_rect.visible = excess > 0.0


## _sweep_to(target, hot)
##
## Every fill change tweens ~250ms ease-out; never snaps. Off-tree or
## instant assignments jump straight to the target. Each change also fires
## one sheen pass over the fill (hot = overflow pacing).
func _sweep_to(target: float, hot: bool = false) -> void:
	if not is_inside_tree():
		_display_value = target
		return
	if _instant_fill:
		_display_value = target
		return
	if _fill_tween and _fill_tween.is_valid():
		_fill_tween.kill()
	_fill_tween = create_tween()
	_fill_tween.tween_property(self, "_display_value", target, TWEEN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_start_sheen(hot)


## _start_sheen(hot)
##
## One diagonal sheen pass over the fill, ~2s, then fades out and freezes.
## The overflow layer runs the same pass ~1.5x faster on its hotter base.
func _start_sheen(hot: bool) -> void:
	if not _fill_material:
		return
	if _sheen_tween and _sheen_tween.is_valid():
		_sheen_tween.kill()
	_fill_material.set_shader_parameter("sheen_strength", 1.0)
	_fill_material.set_shader_parameter("sheen_phase", SHEEN_START)
	var duration := SHEEN_DURATION_HOT if hot else SHEEN_DURATION
	_sheen_tween = create_tween()
	_sheen_tween.set_parallel(true)
	_sheen_tween.tween_method(_set_fill_sheen_phase, SHEEN_START, SHEEN_END, duration)
	_sheen_tween.tween_method(_set_fill_sheen_strength, 1.0, 0.0, SHEEN_FADE_OUT).set_delay(duration)
	if hot and _overflow_material:
		_overflow_material.set_shader_parameter("sheen_strength", 1.0)
		_overflow_material.set_shader_parameter("sheen_phase", SHEEN_START)
		_sheen_tween.tween_method(_set_overflow_sheen_phase, SHEEN_START, SHEEN_END, SHEEN_DURATION_HOT)
		_sheen_tween.tween_method(_set_overflow_sheen_strength, 1.0, 0.0, SHEEN_FADE_OUT).set_delay(SHEEN_DURATION_HOT)


func _set_fill_sheen_phase(phase: float) -> void:
	_fill_material.set_shader_parameter("sheen_phase", phase)


func _set_fill_sheen_strength(strength: float) -> void:
	_fill_material.set_shader_parameter("sheen_strength", strength)


func _set_overflow_sheen_phase(phase: float) -> void:
	_overflow_material.set_shader_parameter("sheen_phase", phase)


func _set_overflow_sheen_strength(strength: float) -> void:
	_overflow_material.set_shader_parameter("sheen_strength", strength)


## set_value_instant(v)
##
## Jumps straight to v with no sweep and no sheen — for round/reset
## boundaries where a tween would read as leftover progress.
func set_value_instant(v: float) -> void:
	if _fill_tween and _fill_tween.is_valid():
		_fill_tween.kill()
	_instant_fill = true
	value = v
	_instant_fill = false
	_display_value = v


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	# Matte rounded track only — this drawn shape is also the clip mask
	_track_style.bg_color = _track_draw_color
	draw_style_box(_track_style, Rect2(0.0, 0.0, w, h))


## _draw_overlay()
##
## Runs on the NotchOverlay's draw signal: segment ticks, threshold marker,
## and the tint_over wash, all above the fill and clipped to the track.
func _draw_overlay() -> void:
	var w := _notch_overlay.size.x
	var h := _notch_overlay.size.y
	if w <= 0.0 or h <= 0.0:
		return
	var span := maxf(max_value - min_value, 0.0001)

	# Segment tick notches every 10%
	if show_ticks:
		var tick_color := Color(1.0, 1.0, 1.0, TICK_ALPHA)
		for i in range(1, 10):
			var tx := roundf(w * float(i) / 10.0)
			_notch_overlay.draw_rect(Rect2(tx, h * 0.3, 1.0, h * 0.4), tick_color)

	# Threshold marker
	if threshold >= 0.0:
		var thx := roundf(w * clampf((threshold - min_value) / span, 0.0, 1.0))
		_notch_overlay.draw_rect(Rect2(thx - 1.0, 0.0, 2.0, h), Color(1.0, 1.0, 1.0, 0.35))

	# Over-wash (tint_over compat slot): translucent layer over the whole bar
	if _over_draw_color.a > 0.0:
		_notch_overlay.draw_rect(Rect2(0.0, 0.0, w, h), _over_draw_color)
