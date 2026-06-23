shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.9, 0.35, 0.6, 1.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.3;
uniform float proximity_strength : hint_range(0.0, 1.0) = 0.0;
uniform float active_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_strength : hint_range(0.0, 1.5) = 0.0;
uniform float fill_brightness : hint_range(0.0, 1.5) = 0.72;
uniform float fill_expand_scale : hint_range(0.0, 2.5) = 1.24;
uniform float spread_plateau_scale : hint_range(0.0, 2.5) = 0.86;
uniform float glyph_tint_strength : hint_range(0.0, 0.5) = 0.08;
uniform vec2 mouse_uv = vec2(0.5, 0.5);
uniform float inner_ring_radius : hint_range(1.0, 8.0) = 1.55;
uniform float mid_ring_radius : hint_range(1.0, 12.0) = 3.2;
uniform float outer_ring_radius : hint_range(1.0, 16.0) = 5.8;
uniform float outer_glow_scale : hint_range(0.5, 3.0) = 1.45;
uniform float rim_glow_scale : hint_range(0.5, 3.0) = 1.48;
uniform float pointer_focus_falloff : hint_range(1.0, 20.0) = 9.5;
uniform float pointer_glow_scale : hint_range(0.0, 1.0) = 0.32;
uniform float pulse_speed : hint_range(0.0, 20.0) = 8.0;
uniform float pulse_wobble : hint_range(0.0, 0.3) = 0.08;
uniform float final_alpha_scale : hint_range(0.0, 2.0) = 0.95;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float base_alpha = source.a;
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 near_x = vec2(texel.x * inner_ring_radius, 0.0);
	vec2 near_y = vec2(0.0, texel.y * inner_ring_radius);
	vec2 mid_x = vec2(texel.x * mid_ring_radius, 0.0);
	vec2 mid_y = vec2(0.0, texel.y * mid_ring_radius);
	vec2 far_x = vec2(texel.x * outer_ring_radius, 0.0);
	vec2 far_y = vec2(0.0, texel.y * outer_ring_radius);

	float halo_near = 0.0;
	halo_near += texture(TEXTURE, clamp(UV + near_x, vec2(0.0), vec2(1.0))).a;
	halo_near += texture(TEXTURE, clamp(UV - near_x, vec2(0.0), vec2(1.0))).a;
	halo_near += texture(TEXTURE, clamp(UV + near_y, vec2(0.0), vec2(1.0))).a;
	halo_near += texture(TEXTURE, clamp(UV - near_y, vec2(0.0), vec2(1.0))).a;
	halo_near += texture(TEXTURE, clamp(UV + near_x + near_y, vec2(0.0), vec2(1.0))).a;
	halo_near += texture(TEXTURE, clamp(UV - near_x + near_y, vec2(0.0), vec2(1.0))).a;
	halo_near += texture(TEXTURE, clamp(UV + near_x - near_y, vec2(0.0), vec2(1.0))).a;
	halo_near += texture(TEXTURE, clamp(UV - near_x - near_y, vec2(0.0), vec2(1.0))).a;
	halo_near /= 8.0;

	float halo_mid = 0.0;
	halo_mid += texture(TEXTURE, clamp(UV + mid_x, vec2(0.0), vec2(1.0))).a;
	halo_mid += texture(TEXTURE, clamp(UV - mid_x, vec2(0.0), vec2(1.0))).a;
	halo_mid += texture(TEXTURE, clamp(UV + mid_y, vec2(0.0), vec2(1.0))).a;
	halo_mid += texture(TEXTURE, clamp(UV - mid_y, vec2(0.0), vec2(1.0))).a;
	halo_mid += texture(TEXTURE, clamp(UV + mid_x + mid_y, vec2(0.0), vec2(1.0))).a;
	halo_mid += texture(TEXTURE, clamp(UV - mid_x + mid_y, vec2(0.0), vec2(1.0))).a;
	halo_mid += texture(TEXTURE, clamp(UV + mid_x - mid_y, vec2(0.0), vec2(1.0))).a;
	halo_mid += texture(TEXTURE, clamp(UV - mid_x - mid_y, vec2(0.0), vec2(1.0))).a;
	halo_mid /= 8.0;

	float halo_far = 0.0;
	halo_far += texture(TEXTURE, clamp(UV + far_x, vec2(0.0), vec2(1.0))).a;
	halo_far += texture(TEXTURE, clamp(UV - far_x, vec2(0.0), vec2(1.0))).a;
	halo_far += texture(TEXTURE, clamp(UV + far_y, vec2(0.0), vec2(1.0))).a;
	halo_far += texture(TEXTURE, clamp(UV - far_y, vec2(0.0), vec2(1.0))).a;
	halo_far += texture(TEXTURE, clamp(UV + far_x + far_y, vec2(0.0), vec2(1.0))).a;
	halo_far += texture(TEXTURE, clamp(UV - far_x + far_y, vec2(0.0), vec2(1.0))).a;
	halo_far += texture(TEXTURE, clamp(UV + far_x - far_y, vec2(0.0), vec2(1.0))).a;
	halo_far += texture(TEXTURE, clamp(UV - far_x - far_y, vec2(0.0), vec2(1.0))).a;
	halo_far /= 8.0;

	float expanded_fill = clamp(
		base_alpha + max(halo_near - 0.05, 0.0) * fill_expand_scale + max(halo_mid - 0.12, 0.0) * fill_expand_scale * 0.38,
		0.0,
		1.0
	);
	float plateau = smoothstep(0.10, 0.34, halo_mid) * (1.0 - smoothstep(0.46, 0.92, halo_far)) * spread_plateau_scale;
	float rim = clamp((halo_mid - expanded_fill * 0.34) * rim_glow_scale + plateau, 0.0, 1.0);
	float outer_glow = clamp((halo_far * 0.82 + halo_mid * 0.40 - expanded_fill * 0.30) * outer_glow_scale, 0.0, 1.0);

	vec2 pointer_delta = UV - mouse_uv;
	float pointer_focus = exp(-dot(pointer_delta, pointer_delta) * pointer_focus_falloff) * proximity_strength;
	float pulse_wave = 1.0 + sin(TIME * pulse_speed + UV.y * 11.0) * pulse_wobble * (active_strength + pulse_strength);

	float glow_drive = glow_intensity + proximity_strength * 0.30 + active_strength * 0.42 + pulse_strength * 0.76;
	float halo_strength = outer_glow * glow_drive * pulse_wave;
	float highlight_strength = pointer_focus * 0.40 + pulse_strength * 0.18;

	vec3 glyph_fill = glow_color.rgb * (fill_brightness + active_strength * 0.08 + pulse_strength * 0.06);
	vec3 glyph_core = glyph_fill * expanded_fill;
	vec3 rim_color = glow_color.rgb * rim * (0.34 + glyph_tint_strength + highlight_strength * 0.18);
	vec3 halo_color = glow_color.rgb * (halo_strength + pointer_focus * outer_glow * pointer_glow_scale);
	vec3 highlight_color = mix(glow_color.rgb, vec3(1.0, 0.92, 0.74), 0.28) * highlight_strength * expanded_fill;
	float final_alpha = clamp(expanded_fill + halo_strength * final_alpha_scale, 0.0, 1.0);
	COLOR = vec4(glyph_core + rim_color + halo_color + highlight_color, final_alpha);
}