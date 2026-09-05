extends Button
class_name ScorecardRow

## ScorecardRow
##
## One flat scorecard row: [level chip] [category name] ... [score].
## Parent (ScoreCardUI) pushes all state in; the row only emits
## row_hovered/row_pressed. Phases 1-3: structure, states, ghost display,
## power-up highlight pulse. Blinds/lock animations land in Phase 4.

signal row_hovered(key: String)
signal row_pressed(key: String)

enum State { AVAILABLE, HOVER, SCORED }

const NAME_COLOR := Color(0.94, 0.92, 0.98, 1.0)
const NAME_COLOR_SUMMARY := Color(1.0, 0.97, 1.0, 1.0)
const NAME_HOVER_MODULATE := Color(1.15, 1.12, 1.2, 1.0)
const NAME_SCORED_MODULATE := Color(1.0, 1.0, 1.0, 0.55)
const SCORE_COLOR := Color(1.0, 0.9, 0.6, 1.0)
const GHOST_COLOR := Color(0.51, 0.92, 0.92, 0.45)
const GHOST_BEST_COLOR := Color(0.51, 0.92, 0.92, 0.68)
const GHOST_HOVER_COLOR := Color(0.51, 0.92, 0.92, 1.0)
const HIGHLIGHT_PULSE_SHADER := preload("res://Scripts/Shaders/row_highlight_pulse.gdshader")
const BLINDS_SHADER := preload("res://Scripts/Shaders/row_blinds.gdshader")
const HIGHLIGHT_FADE_TIME := 0.25
const HIGHLIGHT_TRIGGER_STRENGTH := 2.0
const HIGHLIGHT_TRIGGER_TIME := 0.4
const BLINDS_COVER_COLOR := Color(0.12, 0.10, 0.17, 1.0)  # opaque, covers the row during wipes
const DOWNGRADE_DESAT := Color(0.6, 0.6, 0.65, 1.0)
const SCORE_LOCK_FLASH := Color(1.6, 1.4, 0.6, 1.0)
const BEST_PULSE_SCALE := Vector2(1.08, 1.08)
const BEST_PULSE_HALF_PERIOD := 0.6

var key: StringName
var is_summary := false
var interactive := true
var state: State = State.AVAILABLE
var highlight_active := false
var last_lock_intensity := 0.0  # computed intensity of the last play_score_lock() (test hook)

var _ghost_value: int = 0
var _has_ghost: bool = false
var _is_best: bool = false
var _last_score: int = 0
var _highlight_pulse: ColorRect = null
var _highlight_material: ShaderMaterial = null
var _highlight_tween: Tween = null
var _blinds_mask: ColorRect = null
var _blinds_material: ShaderMaterial = null
var _downgrade_tween: Tween = null
var _score_lock_tween: Tween = null
var _best_tween: Tween = null

@onready var level_chip: LevelChip = $RowMargin/RowHBox/LevelChip
@onready var name_label: Label = $RowMargin/RowHBox/NameLabel
@onready var score_label: Label = $RowMargin/RowHBox/ScoreLabel

# Draw order (child index): 0 = HighlightPulse, 1 = RowMargin (labels),
# last = BlindsMask. The blinds MUST be the topmost child — when it sat at
# index 1 the cover stripes drew UNDER the labels and populate looked instant.
# Pop/lock/pulse tweens only touch scale/rotation, never z_index (risk #10).


## _ready()
##
## Wires hover/press signals and builds the highlight pulse overlay.
## All child Controls are mouse_filter IGNORE so the Button receives every
## hover/press event on the full row.
func _ready() -> void:
	_create_highlight_pulse()
	_create_blinds_mask()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)
	resized.connect(_center_score_pivot)


func _exit_tree() -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
		_highlight_tween = null
	if _downgrade_tween and _downgrade_tween.is_valid():
		_downgrade_tween.kill()
		_downgrade_tween = null
	if _score_lock_tween and _score_lock_tween.is_valid():
		_score_lock_tween.kill()
		_score_lock_tween = null
	if _best_tween and _best_tween.is_valid():
		_best_tween.kill()
		_best_tween = null


func _center_score_pivot() -> void:
	if score_label:
		score_label.pivot_offset = score_label.size / 2.0


## _create_highlight_pulse()
##
## Builds the HighlightPulse ColorRect (full-rect, child index 0 so it draws
## above the Button stylebox but under the labels) with this row's own
## ShaderMaterial instance, so rows fade effect_strength independently.
func _create_highlight_pulse() -> void:
	_highlight_material = ShaderMaterial.new()
	_highlight_material.shader = HIGHLIGHT_PULSE_SHADER
	_highlight_material.set_shader_parameter("effect_strength", 0.0)
	_highlight_pulse = ColorRect.new()
	_highlight_pulse.name = "HighlightPulse"
	_highlight_pulse.color = Color.WHITE
	_highlight_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_pulse.set_anchors_preset(Control.PRESET_FULL_RECT)
	_highlight_pulse.visible = false
	_highlight_pulse.material = _highlight_material
	add_child(_highlight_pulse)
	move_child(_highlight_pulse, 0)


## _create_blinds_mask()
##
## Builds the BlindsMask ColorRect (full-rect, TOPMOST child so the cover
## stripes hide the whole row — labels included) with this row's own
## ShaderMaterial instance. Starts fully revealed and hidden (idle cost: zero).
func _create_blinds_mask() -> void:
	_blinds_material = ShaderMaterial.new()
	_blinds_material.shader = BLINDS_SHADER
	_blinds_material.set_shader_parameter("progress", 1.0)
	_blinds_material.set_shader_parameter("cover_color", BLINDS_COVER_COLOR)
	_blinds_mask = ColorRect.new()
	_blinds_mask.name = "BlindsMask"
	_blinds_mask.color = Color.WHITE
	_blinds_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blinds_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blinds_mask.visible = false
	_blinds_mask.material = _blinds_material
	# add_child appends last = topmost. Do NOT move it under RowMargin.
	add_child(_blinds_mask)


## set_blinds_progress(p)
##
## Drives the blinds wipe: 0 = fully covered, 1 = fully revealed.
## The mask hides itself at 1.0 so idle rows cost no draw call (risk #3).
func set_blinds_progress(p: float) -> void:
	_blinds_material.set_shader_parameter("progress", p)
	_blinds_mask.visible = p < 1.0


## show_instant()
##
## Reveals the row immediately (no wipe).
func show_instant() -> void:
	set_blinds_progress(1.0)


## hide_instant()
##
## Covers the row immediately (no wipe).
func hide_instant() -> void:
	set_blinds_progress(0.0)


## setup(p_key, display_name, p_is_summary)
##
## Sets the row's category key and label. Summary rows hide the level chip,
## use a bolder name style, and are permanently non-interactive.
func setup(p_key: String, display_name: String, p_is_summary: bool = false) -> void:
	key = StringName(p_key)
	is_summary = p_is_summary
	name_label.text = display_name
	if is_summary:
		level_chip.visible = false
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", NAME_COLOR_SUMMARY)
		disabled = true
		interactive = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW


## set_display_name(display_name)
##
## Replaces the name label text (used for the Bonus row's progress label).
func set_display_name(display_name: String) -> void:
	name_label.text = display_name


## set_level(n)
##
## Forwards the category level to the level chip.
func set_level(n: int) -> void:
	level_chip.set_level(n)


## set_score(value)
##
## Pushes the committed score. null clears the slot (EMPTY, never "-");
## an int is formatted and shown solid gold/white, and stored so
## play_score_lock() can scale its celebration with the score size.
func set_score(value) -> void:
	if value == null:
		score_label.text = ""
		return
	_last_score = int(value)
	score_label.text = NumberFormatter.format_score(int(value))
	score_label.add_theme_color_override("font_color", SCORE_COLOR)


## set_ghost(value)
##
## Shows a projected score in teal (~45% opacity; ~68% when this row carries
## the best-hand pulse; full teal "+N" on hover).
func set_ghost(value: int) -> void:
	_ghost_value = value
	_has_ghost = true
	if state == State.HOVER:
		score_label.text = "+%d" % value
		score_label.add_theme_color_override("font_color", GHOST_HOVER_COLOR)
	else:
		score_label.text = NumberFormatter.format_score(value)
		score_label.add_theme_color_override("font_color", _ghost_rest_color())


func _ghost_rest_color() -> Color:
	if _is_best:
		return GHOST_BEST_COLOR
	return GHOST_COLOR


## set_best_ghost(on)
##
## Marks/unmarks this row as the single best projected score. The best row's
## ScoreLabel runs a continuous slow scale pulse (1.0 -> 1.08 -> 1.0, ~1.2s
## loop); unmarking kills the pulse and restores scale 1.0 + normal alpha.
func set_best_ghost(on: bool) -> void:
	if on == _is_best:
		return
	_is_best = on
	if _has_ghost and state != State.HOVER:
		score_label.add_theme_color_override("font_color", _ghost_rest_color())
	if on:
		_start_best_pulse()
	else:
		_stop_best_pulse()


func _start_best_pulse() -> void:
	_stop_best_pulse()
	_center_score_pivot()
	_best_tween = create_tween()
	_best_tween.set_loops()
	_best_tween.tween_property(score_label, "scale", BEST_PULSE_SCALE, BEST_PULSE_HALF_PERIOD).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_best_tween.tween_property(score_label, "scale", Vector2.ONE, BEST_PULSE_HALF_PERIOD).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_best_pulse() -> void:
	if _best_tween and _best_tween.is_valid():
		_best_tween.kill()
		_best_tween = null
	score_label.scale = Vector2.ONE


## clear_ghost()
##
## Removes the projected-score display and stops the best-hand pulse.
func clear_ghost() -> void:
	_has_ghost = false
	_is_best = false
	_stop_best_pulse()
	if state != State.SCORED:
		score_label.text = ""


## play_score_lock()
##
## Score-lock celebration scaled by score size: intensity =
## clamp(log(score+1)/log(500), 0.15, 1.0) drives the scale punch peak
## (1.15..1.4), the rotation wiggle (±0.5..±4.0 degrees, two wiggles) and the
## total duration (0.3..0.5s). A 12-pt score nods; a 960-pt score celebrates.
## Rotation settles at 0 so the label never rests crooked. Scale/rotation
## only, never z_index (plan risk #10). Tweens keep running while the Button
## is disabled, so callers may set_state_scored() right after.
##
## Skipped entirely when the label has not been laid out yet (size is zero):
## a tween started then would capture a stale position/pivot and overwrite the
## container's first sort, leaving the label permanently offset.
func play_score_lock() -> void:
	_stop_best_pulse()
	score_label.add_theme_color_override("font_color", SCORE_COLOR)
	if score_label.size == Vector2.ZERO or not is_inside_tree():
		return
	_center_score_pivot()
	if _score_lock_tween and _score_lock_tween.is_valid():
		_score_lock_tween.kill()
		_score_lock_tween = null
	var intensity := clampf(log(_last_score + 1.0) / log(500.0), 0.15, 1.0)
	last_lock_intensity = intensity
	var peak := lerpf(1.15, 1.4, intensity)
	var wiggle_deg := lerpf(0.5, 4.0, intensity)
	var duration := lerpf(0.3, 0.5, intensity)
	score_label.scale = Vector2(peak, peak)
	score_label.modulate = SCORE_LOCK_FLASH
	score_label.rotation_degrees = 0.0
	var hop_y := score_label.position.y
	_score_lock_tween = create_tween()
	_score_lock_tween.tween_property(score_label, "scale", Vector2.ONE, duration * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_score_lock_tween.parallel().tween_property(score_label, "modulate", Color.WHITE, duration)
	_score_lock_tween.parallel().tween_property(score_label, "rotation_degrees", wiggle_deg, duration * 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_score_lock_tween.parallel().tween_property(score_label, "rotation_degrees", -wiggle_deg, duration * 0.2).set_delay(duration * 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_score_lock_tween.parallel().tween_property(score_label, "rotation_degrees", 0.0, duration * 0.15).set_delay(duration * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_score_lock_tween.parallel().tween_property(score_label, "position:y", hop_y - 4.0, duration * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_score_lock_tween.parallel().tween_property(score_label, "position:y", hop_y, duration * 0.35).set_delay(duration * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## is_revealed() -> bool
##
## True when the blinds wipe has fully revealed this row. Used to suppress
## animations that are pointless under a covered row.
func is_revealed() -> bool:
	if _blinds_mask == null:
		return true
	return not _blinds_mask.visible


## play_downgrade()
##
## Plan §4.2 row half (t=150-550ms): desaturation flicker on the row
## (two quick alternations to a grey tint, back to white) while the chip
## runs its own downgrade chain.
func play_downgrade() -> void:
	level_chip.play_downgrade()
	if _downgrade_tween and _downgrade_tween.is_valid():
		_downgrade_tween.kill()
		_downgrade_tween = null
	_downgrade_tween = create_tween()
	_downgrade_tween.tween_interval(0.15)
	_downgrade_tween.tween_property(self, "modulate", DOWNGRADE_DESAT, 0.1)
	_downgrade_tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	_downgrade_tween.tween_property(self, "modulate", DOWNGRADE_DESAT, 0.1)
	_downgrade_tween.tween_property(self, "modulate", Color.WHITE, 0.1)


## set_state_scored()
##
## Terminal per-round state: row disabled, name dimmed, score solid.
## Force-clears the power-up highlight and the best-hand pulse
## (SCORED outranks both per plan §3).
func set_state_scored() -> void:
	state = State.SCORED
	disabled = true
	_has_ghost = false
	_is_best = false
	_stop_best_pulse()
	name_label.modulate = NAME_SCORED_MODULATE
	score_label.add_theme_color_override("font_color", SCORE_COLOR)
	if highlight_active:
		set_highlight(false)


## set_highlight(on)
##
## Fades the highlight pulse in/out (0.25s) via the shader's effect_strength
## master fade. The pulse lives entirely in shader alpha, so it never fights
## mode tints written to row modulate.
func set_highlight(on: bool) -> void:
	highlight_active = on
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
		_highlight_tween = null
	var from: float = _highlight_material.get_shader_parameter("effect_strength")
	if on:
		_highlight_pulse.visible = true
		_highlight_tween = create_tween()
		_highlight_tween.tween_method(_set_highlight_strength, from, 1.0, HIGHLIGHT_FADE_TIME)
	else:
		_highlight_tween = create_tween()
		_highlight_tween.tween_method(_set_highlight_strength, from, 0.0, HIGHLIGHT_FADE_TIME)
		_highlight_tween.tween_callback(_hide_highlight_pulse)


func _hide_highlight_pulse() -> void:
	if not highlight_active:
		_highlight_pulse.visible = false


func _set_highlight_strength(value: float) -> void:
	_highlight_material.set_shader_parameter("effect_strength", value)


## play_highlight_trigger()
##
## Celebratory burst when the highlighted score lands: spikes the shader's
## effect_strength to 2.0 and back over ~0.4s, settling at 1.0 while the
## highlight is active or fading out if it was already cleared.
func play_highlight_trigger() -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
		_highlight_tween = null
	_highlight_pulse.visible = true
	var from: float = _highlight_material.get_shader_parameter("effect_strength")
	var settle := 1.0
	if not highlight_active:
		settle = 0.0
	_highlight_tween = create_tween()
	_highlight_tween.tween_method(_set_highlight_strength, from, HIGHLIGHT_TRIGGER_STRENGTH, HIGHLIGHT_TRIGGER_TIME * 0.5)
	_highlight_tween.tween_method(_set_highlight_strength, HIGHLIGHT_TRIGGER_STRENGTH, settle, HIGHLIGHT_TRIGGER_TIME * 0.5)
	if not highlight_active:
		_highlight_tween.tween_callback(_hide_highlight_pulse)


## reset_to_available()
##
## Returns the row to its empty interactive state (round repopulate).
func reset_to_available() -> void:
	state = State.AVAILABLE
	disabled = is_summary
	interactive = not is_summary
	name_label.modulate = Color.WHITE
	_has_ghost = false
	_is_best = false
	_stop_best_pulse()
	score_label.text = ""


func _on_mouse_entered() -> void:
	if not interactive or disabled or state != State.AVAILABLE:
		return
	state = State.HOVER
	name_label.modulate = NAME_HOVER_MODULATE
	if _has_ghost:
		score_label.text = "+%d" % _ghost_value
		score_label.add_theme_color_override("font_color", GHOST_HOVER_COLOR)
	row_hovered.emit(String(key))


func _on_mouse_exited() -> void:
	if state != State.HOVER:
		return
	state = State.AVAILABLE
	name_label.modulate = Color.WHITE
	if _has_ghost:
		score_label.text = NumberFormatter.format_score(_ghost_value)
		score_label.add_theme_color_override("font_color", _ghost_rest_color())


func _on_pressed() -> void:
	if interactive and not disabled:
		row_pressed.emit(String(key))
