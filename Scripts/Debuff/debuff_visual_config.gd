extends RefCounted
class_name DebuffVisualConfig

## Shared neon-danger palette for debuff UI.
var difficulty_tints: Array[Color] = [
	Color(1.0, 0.95, 0.86),
	Color(1.0, 0.86, 0.20),
	Color(1.0, 0.67, 0.14),
	Color(1.0, 0.45, 0.08),
	Color(1.0, 0.18, 0.12),
	Color(1.0, 0.07, 0.28),
]

## Compact chip tuning.
var compact_icon_size: Vector2 = Vector2(38, 38)
var compact_proximity_distance_multiplier: float = 1.48
var compact_proximity_lerp_speed: float = 10.0
var compact_bg_base_color: Color = Color(0.08, 0.07, 0.11, 0.08)
var compact_bg_tint_strength: float = 0.04
var compact_bg_alpha_gain: float = 0.06
var compact_glow_intensity_base: float = 0.34
var compact_glow_intensity_tier_gain: float = 0.24
var compact_fill_brightness: float = 0.72
var compact_fill_expand_scale: float = 1.24
var compact_spread_plateau_scale: float = 0.86
var compact_glyph_tint_base: float = 0.09
var compact_glyph_tint_tier_gain: float = 0.13
var compact_bg_proximity_weight: float = 0.40
var compact_bg_active_weight: float = 0.54
var compact_bg_pulse_weight: float = 0.64
var compact_active_glow: float = 0.62
var compact_active_pulse_strength: float = 1.10
var compact_active_pulse_duration: float = 0.48

## Compact glyph shader tuning.
var compact_glyph_inner_ring: float = 0.55
var compact_glyph_mid_ring: float = 3.9
var compact_glyph_outer_ring: float = 7.2
var compact_glyph_outer_scale: float = 1.78
var compact_glyph_rim_scale: float = 1.64
var compact_glyph_pointer_falloff: float = 9.5
var compact_glyph_pointer_scale: float = 0.32
var compact_glyph_pulse_speed: float = 8.0
var compact_glyph_pulse_wobble: float = 0.08
var compact_glyph_final_alpha_scale: float = 0.95

## Fan-out detail card tuning.
var detail_card_size: Vector2 = Vector2(248, 340)
var detail_icon_size: Vector2 = Vector2(150, 150)
var detail_content_separation: int = 8
var detail_proximity_distance_multiplier: float = 2.0
var detail_proximity_lerp_speed: float = 7.0
var detail_glow_intensity_base: float = 0.30
var detail_glow_intensity_tier_gain: float = 0.30
var detail_fill_brightness: float = 0.76
var detail_fill_expand_scale: float = 1.28
var detail_spread_plateau_scale: float = 0.94
var detail_glyph_tint_base: float = 0.10
var detail_glyph_tint_tier_gain: float = 0.12
var detail_active_glow: float = 0.46
var detail_inactive_glow: float = 0.12
var detail_panel_border_width: int = 5
var detail_panel_corner_radius: int = 22
var detail_panel_margin_h: int = 16
var detail_panel_margin_v: int = 14
var detail_fan_spacing: float = 272.0
var detail_viewport_padding: float = 56.0
var detail_entry_offset_y: float = 320.0
var detail_overlay_dim_alpha: float = 0.62

## Detail card shell shader tuning.
var detail_card_glow_base: float = 0.22
var detail_card_glow_tier_gain: float = 0.24
var detail_card_spread: float = 34.0
var detail_card_corner_radius: float = 26.0
var detail_card_rim_width: float = 8.0
var detail_card_outer_halo_scale: float = 0.92
var detail_card_rim_halo_scale: float = 0.54
var detail_card_pointer_scale: float = 0.34
var detail_card_pulse_speed: float = 4.8
var detail_card_pulse_wobble: float = 0.09

## Fan-out screen glow pass tuning.
var detail_screen_glow_strength: float = 4.45
var detail_screen_glow_threshold: float = 0.12
var detail_screen_glow_saturation_threshold: float = 0.10
var detail_screen_glow_radius_steps: int = 12
var detail_screen_glow_spread: float = 3.5
var detail_screen_glow_lod_bias_scale: float = 0.96
var detail_screen_glow_source_boost: float = 0.92
var detail_screen_glow_alpha_strength: float = 1.98

## Large glyph shader tuning.
var detail_glyph_inner_ring: float = 0.8
var detail_glyph_mid_ring: float = 2.9
var detail_glyph_outer_ring: float = 2.8
var detail_glyph_outer_scale: float = 1.92
var detail_glyph_rim_scale: float = 1.82
var detail_glyph_pointer_falloff: float = 8.4
var detail_glyph_pointer_scale: float = 0.38
var detail_glyph_pulse_speed: float = 6.4
var detail_glyph_pulse_wobble: float = 0.09
var detail_glyph_final_alpha_scale: float = 0.98