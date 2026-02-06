shader_type canvas_item;
// Enhanced Glow Overlay - Multi-radius glow with chromatic aberration & distortion
// Created for DiceRogue (Guhtzee)
// Upgraded from basic color mix to full retro effect system

// Original parameters (backward compatible)
uniform float glow_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.0, 0.5); // yellow glow

uniform float lock_overlay_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 lock_color : source_color = vec4(0.0, 0.0, 0.0, 0.5); // semi-transparent black

// New enhanced parameters
uniform float chromatic_offset : hint_range(0.0, 0.05) = 0.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 0.0;
uniform float edge_distortion : hint_range(0.0, 0.3) = 0.0;
uniform bool rainbow_mode = false;
uniform float multi_radius_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Pulsing glow strength modulation
	float pulse = 1.0;
	if (pulse_speed > 0.0) {
		pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	}
	float effective_glow = glow_strength * pulse;

	// Edge distortion: warp UV based on distance from center
	vec2 uv = UV;
	if (edge_distortion > 0.0 && effective_glow > 0.0) {
		vec2 center_offset = uv - 0.5;
		float dist = length(center_offset);
		float warp = sin(dist * 20.0 - TIME * 3.0) * edge_distortion * effective_glow;
		uv += normalize(center_offset + 0.001) * warp * dist;
		uv = clamp(uv, 0.0, 1.0);
	}

	// Base texture sample
	vec4 tex_color = texture(TEXTURE, uv);

	// Chromatic aberration: split RGB channels with offset
	if (chromatic_offset > 0.0 && effective_glow > 0.0) {
		vec2 center_dir = normalize(uv - 0.5 + 0.001);
		float offset = chromatic_offset * effective_glow;
		float r = texture(TEXTURE, uv + center_dir * offset).r;
		float g = tex_color.g;
		float b = texture(TEXTURE, uv - center_dir * offset).b;
		tex_color.rgb = vec3(r, g, b);
	}

	// Multi-radius glow: inner sharp + outer soft blend
	vec4 glow_result = tex_color;
	if (effective_glow > 0.0) {
		// Inner glow (sharp, direct color mix)
		vec4 inner_glow = mix(tex_color, glow_color, effective_glow * 0.8);

		if (multi_radius_strength > 0.0) {
			// Outer glow: edge-detection based bloom
			float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
			float edge_factor = 1.0 - smoothstep(0.0, 0.25, edge_dist);
			float luma = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
			float bright_factor = smoothstep(0.3, 0.8, luma);

			// Softer outer radius
			vec4 outer_glow_color = glow_color;

			// Rainbow mode: shift hue based on edge angle
			if (rainbow_mode) {
				float angle = atan(uv.y - 0.5, uv.x - 0.5);
				float hue = fract(angle / 6.28318 + TIME * 0.3);
				// Simple HSV to RGB for rainbow
				vec3 rainbow = vec3(
					abs(hue * 6.0 - 3.0) - 1.0,
					2.0 - abs(hue * 6.0 - 2.0),
					2.0 - abs(hue * 6.0 - 4.0)
				);
				rainbow = clamp(rainbow, 0.0, 1.0);
				outer_glow_color = vec4(rainbow, glow_color.a);
			}

			float outer_strength = (edge_factor + bright_factor * 0.5) * multi_radius_strength * effective_glow;
			inner_glow.rgb += outer_glow_color.rgb * outer_strength * 0.5;
		}

		glow_result = inner_glow;
	}

	// Lock overlay (unchanged behavior)
	vec4 locked = mix(glow_result, lock_color, lock_overlay_strength);
	COLOR = locked;
}