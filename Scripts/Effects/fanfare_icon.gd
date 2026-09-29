extends Control
class_name FanfareIcon

## FanfareIcon
##
## The flying icon for the Mom buff/debuff arrival fanfare. Spawns off-screen
## right, overshoot-flies to its spine slot, then lands with a scale punch,
## a tinted ConsumableExplosion burst, and an expanding ring. Buffs show the
## power-up icon in a mall-core chip; debuffs embed a real DebuffIcon glyph
## chip plus a red "-" flash. All timings come from JuiceProfile.

signal landed

const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const ExplosionScene = preload("res://Scenes/Effects/ConsumableExplosion.tscn")

const CHIP_SIZE: Vector2 = Vector2(64, 64)
const CHIP_FILL: Color = Color(0.247059, 0.219608, 0.345098, 0.92)
const CHIP_SHADOW: Color = Color(0.070588, 0.062745, 0.101961, 0.45)
const TEXT_COLOR: Color = Color(0.968627, 0.941176, 1.0, 1.0)
const TEXT_OUTLINE: Color = Color(0.129412, 0.121569, 0.2, 1.0)
const RING_START_RADIUS: float = 4.0
const RING_END_RADIUS: float = 46.0
const RING_TIME: float = 0.25
const MINUS_FLASH_TIME: float = 0.3
const DISSOLVE_TIME: float = 0.1
const EXPLOSION_CLEANUP_DELAY: float = 1.5

var _tint: Color = Color.WHITE
var _is_debuff: bool = false
var _minus_flash: Label = null

## Expanding ring drawn at the landing point (the "ring" half of the
## landing explosion, matching the ConsumableExplosion particle burst).
class RingFlash extends Node2D:
	var ring_radius: float = 4.0
	var ring_alpha: float = 0.9
	var ring_color: Color = Color.WHITE
	var ring_width: float = 3.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48,
			ring_color * Color(1.0, 1.0, 1.0, ring_alpha), ring_width, true)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = RenderLayers.Z_SCREEN_FX
	size = CHIP_SIZE
	custom_minimum_size = CHIP_SIZE
	pivot_offset = CHIP_SIZE / 2.0


## setup_buff(icon_texture, name_text, tint)
##
## Buff variant: mall-core chip with the power-up icon and name, green tint.
func setup_buff(icon_texture: Texture2D, name_text: String, tint: Color) -> void:
	_tint = tint
	_is_debuff = false
	_build_shell(tint)

	var content := Control.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("Shell").add_child(content)

	var icon_rect := TextureRect.new()
	icon_rect.name = "IconRect"
	icon_rect.anchor_left = 0.0
	icon_rect.anchor_top = 0.0
	icon_rect.anchor_right = 1.0
	icon_rect.anchor_bottom = 1.0
	icon_rect.offset_left = 8.0
	icon_rect.offset_top = 6.0
	icon_rect.offset_right = -8.0
	icon_rect.offset_bottom = -18.0
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture = icon_texture
	content.add_child(icon_rect)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.anchor_left = 0.0
	name_label.anchor_top = 1.0
	name_label.anchor_right = 1.0
	name_label.anchor_bottom = 1.0
	name_label.offset_left = 2.0
	name_label.offset_top = -16.0
	name_label.offset_right = -2.0
	name_label.offset_bottom = -2.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_override("font", VCR_FONT)
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	name_label.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.text = name_text.to_upper()
	content.add_child(name_label)


## setup_debuff(debuff_data, tint)
##
## Debuff variant: embeds a real DebuffIcon glyph chip, red tint, and a
## hidden "-" flash label shown on landing.
func setup_debuff(debuff_data: DebuffData, tint: Color) -> void:
	_tint = tint
	_is_debuff = true
	_build_shell(tint)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("Shell").add_child(center)

	var glyph := DebuffIcon.new()
	glyph.name = "DebuffGlyph"
	center.add_child(glyph)
	# DebuffIcon's per-frame hover response requires non-null data; fall back
	# to a default glyph when the def lookup fails (test mocks, missing def).
	if debuff_data == null:
		debuff_data = DebuffData.new()
	glyph.set_data(debuff_data)
	glyph.set_active(true)

	_minus_flash = Label.new()
	_minus_flash.name = "MinusFlash"
	_minus_flash.text = "-"
	_minus_flash.set_anchors_preset(Control.PRESET_CENTER)
	_minus_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_minus_flash.grow_vertical = Control.GROW_DIRECTION_BOTH
	_minus_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minus_flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_minus_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minus_flash.add_theme_font_override("font", VCR_FONT)
	_minus_flash.add_theme_font_size_override("font_size", 28)
	_minus_flash.add_theme_color_override("font_color", tint)
	_minus_flash.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	_minus_flash.add_theme_constant_override("outline_size", 2)
	_minus_flash.modulate.a = 0.0
	add_child(_minus_flash)


func _build_shell(border_tint: Color) -> void:
	var shell := PanelContainer.new()
	shell.name = "Shell"
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CHIP_FILL
	style.border_color = border_tint
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.corner_detail = 8
	style.shadow_color = CHIP_SHADOW
	style.shadow_size = 6
	shell.add_theme_stylebox_override("panel", style)
	add_child(shell)


## play_flight(target_position, profile)
##
## Full flight chain: spawn off-screen right at the slot's height, overshoot
## fly-in with a settling rotation wobble, then the landing sequence.
## target_position is in the parent (scene-root) coordinate space.
func play_flight(target_position: Vector2, profile: JuiceProfile) -> void:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var start_position := Vector2(viewport_width + profile.fanfare_spawn_offset_x, target_position.y)

	rotation_degrees = profile.fanfare_spawn_rotation_deg
	scale = Vector2.ONE * profile.fanfare_spawn_scale
	modulate.a = 1.0

	var flight: Tween = null
	var tfx = get_node_or_null("/root/TweenFXHelper")
	if tfx:
		position = target_position
		flight = tfx.fly_in_overshoot(self, start_position, profile.fanfare_fly_time)
	if flight == null:
		position = start_position
		flight = create_tween()
		flight.tween_property(self, "position", target_position, profile.fanfare_fly_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var rot := create_tween()
	rot.tween_property(self, "rotation_degrees", -4.0, profile.fanfare_fly_time * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rot.tween_property(self, "rotation_degrees", 0.0, profile.fanfare_fly_time * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await flight.finished
	_land(profile)


## _land(profile)
##
## Landing: scale punch to 1.0 (bounce-out), tinted explosion + ring at the
## slot, debuff "-" flash, then the icon dissolves and frees itself. The
## caller handles the slot hop and the real spine reveal.
func _land(profile: JuiceProfile) -> void:
	landed.emit()

	var punch := create_tween()
	punch.tween_property(self, "scale", Vector2.ONE, profile.fanfare_land_punch_time).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	_spawn_explosion()
	_spawn_ring()
	if _is_debuff and _minus_flash:
		var flash := create_tween()
		flash.tween_property(_minus_flash, "modulate:a", 1.0, MINUS_FLASH_TIME * 0.4)
		flash.tween_property(_minus_flash, "modulate:a", 0.0, MINUS_FLASH_TIME * 0.6)

	var dissolve := create_tween()
	dissolve.tween_interval(profile.fanfare_land_punch_time)
	dissolve.tween_property(self, "modulate:a", 0.0, DISSOLVE_TIME)
	dissolve.tween_callback(queue_free)


## _spawn_explosion()
##
## Instances the shared ConsumableExplosion and re-tints a duplicated
## process material (particles keep the original shape/count/curves — only
## the palette changes to the buff/debuff tint).
func _spawn_explosion() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var explosion := ExplosionScene.instantiate() as GPUParticles2D
	if explosion == null:
		return
	parent.add_child(explosion)
	explosion.global_position = global_position + pivot_offset * scale

	var source_material := explosion.process_material as ParticleProcessMaterial
	if source_material:
		var material := source_material.duplicate(true) as ParticleProcessMaterial
		material.color = _tint
		var ramp := material.color_ramp as GradientTexture1D
		if ramp and ramp.gradient:
			var gradient := ramp.gradient
			var tinted := PackedColorArray()
			for i in range(gradient.get_point_count()):
				var original := gradient.colors[i]
				tinted.append(Color(_tint.r, _tint.g, _tint.b, original.a))
			gradient.colors = tinted
		explosion.process_material = material

	explosion.emitting = true
	get_tree().create_timer(EXPLOSION_CLEANUP_DELAY).timeout.connect(
		func():
			if is_instance_valid(explosion):
				explosion.queue_free()
	)


## _spawn_ring()
##
## Expanding ring flash at the landing point.
func _spawn_ring() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ring := RingFlash.new()
	ring.ring_color = _tint
	ring.z_index = z_index
	parent.add_child(ring)
	ring.global_position = global_position + pivot_offset * scale

	var tween := create_tween()
	tween.tween_method(
		func(progress: float):
			ring.ring_radius = lerpf(RING_START_RADIUS, RING_END_RADIUS, progress)
			ring.ring_alpha = lerpf(0.9, 0.0, progress)
			ring.queue_redraw(),
		0.0, 1.0, RING_TIME)
	tween.tween_callback(ring.queue_free)
