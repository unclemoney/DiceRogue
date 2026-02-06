shader_type canvas_item;
// Dramatic Burst - Multi-stage explosion with radial streaks and debris
// Created for DiceRogue (Guhtzee)
// Upgraded from basic circular fade to full retro explosion system

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float spread : hint_range(0.0, 1.0) = 0.5;
uniform float fade_speed : hint_range(0.1, 5.0) = 1.0;

// New dramatic parameters
uniform float explosion_stage : hint_range(0.0, 1.0) = 0.0;
uniform int streak_count : hint_range(4, 24) = 12;
uniform float debris_size : hint_range(0.01, 0.05) = 0.025;
uniform bool color_temp_shift = true;
uniform float shockwave_strength : hint_range(0.0, 1.0) = 0.5;
uniform float spark_intensity : hint_range(0.0, 1.0) = 0.6;

// Pseudo-random
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 23761.9134);
}

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 dir = UV - center;
	float dist = length(dir);
	float angle = atan(dir.y, dir.x);

	// Noise variation per-pixel
	float noise = hash(UV * 100.0);
	float noise2 = hash2(UV * 73.0);

	if (explosion_stage > 0.0) {
		// === MULTI-STAGE EXPLOSION ===

		// Stage boundaries
		float flash_end = 0.15;
		float burst_peak = 0.4;
		float streak_peak = 0.6;
		float fade_start = 0.7;

		// --- Stage 1: Initial white-hot flash ---
		float flash = smoothstep(0.0, 0.05, explosion_stage) * smoothstep(flash_end, 0.05, explosion_stage);
		float flash_radius = explosion_stage * 3.0;
		float flash_circle = smoothstep(flash_radius, flash_radius * 0.3, dist);

		// --- Stage 2: Main burst expansion ---
		float burst_radius = smoothstep(0.0, burst_peak, explosion_stage) * 0.6;
		float burst = smoothstep(burst_radius, burst_radius * 0.5, dist);
		burst *= smoothstep(1.0, fade_start, explosion_stage); // Fade out

		// --- Stage 3: Radial streaks ---
		float streak_val = 0.0;
		float streaks_f = float(streak_count);
		float angle_step = 6.28318 / streaks_f;
		for (int i = 0; i < 24; i++) {
			if (i >= streak_count) break;
			float fi = float(i);
			float streak_angle = fi * angle_step + hash(vec2(fi, 0.0)) * 0.3;
			float angle_diff = abs(mod(angle - streak_angle + 3.14159, 6.28318) - 3.14159);

			// Streak width narrows with distance
			float streak_width = 0.08 * (1.0 - dist * 1.5);
			float streak_mask = smoothstep(streak_width, 0.0, angle_diff);

			// Streak length grows then shrinks
			float streak_len = smoothstep(0.1, streak_peak, explosion_stage) * (0.3 + hash(vec2(fi, 1.0)) * 0.3);
			streak_len *= smoothstep(1.0, 0.7, explosion_stage);
			streak_mask *= smoothstep(streak_len, streak_len * 0.3, dist);
			streak_mask *= step(0.05, dist); // Hole in center

			streak_val += streak_mask;
		}
		streak_val = min(streak_val, 1.0);

		// --- Stage 4: Shockwave ring ---
		float ring_radius = explosion_stage * 0.7;
		float ring_width = 0.03 + 0.02 * (1.0 - explosion_stage);
		float ring = smoothstep(ring_width, 0.0, abs(dist - ring_radius));
		ring *= smoothstep(0.2, 0.35, explosion_stage); // Appears after flash
		ring *= smoothstep(1.0, 0.8, explosion_stage);  // Fades before end
		ring *= shockwave_strength;

		// --- Debris particles ---
		float debris = 0.0;
		for (int d = 0; d < 16; d++) {
			float fd = float(d);
			float d_angle = hash(vec2(fd, 5.0)) * 6.28318;
			float d_speed = 0.3 + hash(vec2(fd, 6.0)) * 0.5;
			float d_dist = explosion_stage * d_speed;

			vec2 d_pos = center + vec2(cos(d_angle), sin(d_angle)) * d_dist;
			float d_size = debris_size * (1.0 - explosion_stage * 0.8); // Shrink over time
			float d_mask = smoothstep(d_size, d_size * 0.3, length(UV - d_pos));
			d_mask *= smoothstep(0.15, 0.25, explosion_stage); // Appear after flash
			d_mask *= smoothstep(1.0, 0.6, explosion_stage);  // Fade out

			debris += d_mask;
		}
		debris = min(debris, 1.0);

		// --- Spark points (tiny bright dots) ---
		float sparks = 0.0;
		for (int s = 0; s < 20; s++) {
			float fs = float(s);
			float s_angle = hash(vec2(fs, 10.0)) * 6.28318;
			float s_speed = 0.4 + hash(vec2(fs, 11.0)) * 0.6;
			float s_dist = explosion_stage * s_speed * 0.8;
			float s_life = hash(vec2(fs, 12.0));

			vec2 s_pos = center + vec2(cos(s_angle), sin(s_angle)) * s_dist;
			float s_mask = smoothstep(0.008, 0.0, length(UV - s_pos));
			s_mask *= smoothstep(0.1, 0.2, explosion_stage);
			s_mask *= step(explosion_stage, 0.5 + s_life * 0.4); // Random lifetime

			sparks += s_mask;
		}
		sparks = min(sparks, 1.0) * spark_intensity;

		// === Color temperature shift ===
		vec3 base_col = color.rgb;
		if (color_temp_shift) {
			// White-hot -> color -> dark purple as explosion progresses
			vec3 hot_white = vec3(1.0, 0.95, 0.85);
			vec3 cool_purple = vec3(0.4, 0.0, 0.6);
			vec3 temp_col = mix(hot_white, base_col, smoothstep(0.0, 0.3, explosion_stage));
			temp_col = mix(temp_col, cool_purple, smoothstep(0.5, 1.0, explosion_stage));
			base_col = temp_col;
		}

		// === Composite all layers ===
		float combined = flash_circle * flash * 2.0 + burst + streak_val * 0.8 + ring + debris * 0.9 + sparks;
		combined = min(combined, 1.5); // Allow slight HDR bloom

		COLOR = vec4(base_col * combined, combined * (1.0 - explosion_stage * 0.3));
		// Add flash white overlay
		COLOR.rgb += vec3(flash * flash_circle * 0.8);
		COLOR.a = min(COLOR.a, 1.0);

	} else {
		// === LEGACY MODE (backward compatible) ===
		float circle = smoothstep(0.5, 0.3, dist);
		float fade = 1.0 - (TIME * fade_speed * 0.5);
		COLOR = color * 1.5;
		COLOR.a *= circle * fade * (0.8 + (noise * 0.2));
	}
}