shader_type canvas_item;
// Paint Splatter - Animated neon paint canvas with accumulating splatters
// Created for DiceRogue (Guhtzee)
// Inspired by late 80s / early 90s neon paint splatter Trapper Keeper art
// Splatters appear over time, accumulate for ~20 seconds, then fade-dissolve and restart

// Color system - 5 neon splat colors on dark canvas
uniform vec4 colour_1 : source_color = vec4(0.06, 0.04, 0.08, 1.0);  // Dark canvas
uniform vec4 colour_2 : source_color = vec4(1.0, 0.1, 0.55, 1.0);    // Hot pink
uniform vec4 colour_3 : source_color = vec4(0.0, 0.9, 0.85, 1.0);    // Cyan
uniform vec4 colour_4 : source_color = vec4(0.6, 0.0, 0.95, 1.0);    // Purple
uniform vec4 colour_5 : source_color = vec4(0.95, 0.85, 0.0, 1.0);   // Yellow

// Controls
uniform float splat_rate : hint_range(0.5, 4.0) = 1.5;
uniform float splat_size : hint_range(0.5, 2.0) = 1.0;
uniform float drip_amount : hint_range(0.0, 1.0) = 0.6;
uniform float spray_density : hint_range(0.0, 1.0) = 0.5;
uniform float cycle_duration : hint_range(10.0, 40.0) = 20.0;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.5;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.06;

// Hash functions
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

// Value noise
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM for organic splat edges
float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		val += amp * value_noise(p);
		p *= 2.2;
		amp *= 0.48;
	}
	return val;
}

// Choose splat color by index
vec3 splat_color(float idx) {
	float i = mod(idx, 4.0);
	if (i < 1.0) return colour_2.rgb;
	if (i < 2.0) return colour_3.rgb;
	if (i < 3.0) return colour_4.rgb;
	return colour_5.rgb;
}

// Render a single paint splat blob with noisy edges
// splat_center: world position, splat_radius: base size
// appear_time: when this splat appears (0..1 in cycle)
// Returns: vec2(coverage, color_index)
float render_splat(vec2 uv, vec2 splat_center, float splat_radius, float seed) {
	vec2 delta = uv - splat_center;
	float dist = length(delta);

	if (dist > splat_radius * 2.5) return 0.0;

	// Noisy edge (organic blob shape)
	float angle = atan(delta.y, delta.x);
	float noise_offset = fbm(vec2(angle * 2.0 + seed * 10.0, seed * 5.0)) * splat_radius * 0.7;
	float noise_offset2 = fbm(vec2(angle * 4.0 + seed * 7.0, seed * 3.0 + 100.0)) * splat_radius * 0.35;
	float effective_radius = splat_radius + noise_offset - noise_offset2 * 0.5;

	float body = smoothstep(effective_radius, effective_radius * 0.7, dist);

	return body;
}

// Paint drip running down from a splat
float render_drip(vec2 uv, vec2 drip_start, float drip_length, float drip_width, float seed) {
	vec2 delta = uv - drip_start;

	// Drip goes downward
	if (delta.y < 0.0 || delta.y > drip_length) return 0.0;

	// Width tapers toward bottom, with wobble
	float progress = delta.y / drip_length;
	float width = drip_width * (1.0 - progress * 0.7);
	width += sin(delta.y * 30.0 + seed * 20.0) * drip_width * 0.15;

	float drip = smoothstep(width, width * 0.3, abs(delta.x));

	// Rounded end (bulge at bottom tip)
	float tip_dist = length(delta - vec2(0.0, drip_length)) / (drip_width * 0.8);
	float tip = smoothstep(1.0, 0.5, tip_dist);

	drip = max(drip, tip * step(delta.y, drip_length + drip_width));

	// Fade from start
	drip *= smoothstep(0.0, 0.05, progress);

	return drip;
}

// Spray particles around a splat impact
float render_spray(vec2 uv, vec2 center, float radius, float seed) {
	float coverage = 0.0;

	// Scatter 8-12 tiny dots around the center
	for (int i = 0; i < 10; i++) {
		float fi = float(i);
		float angle = hash11(seed + fi * 3.7) * 6.283;
		float dist = radius * (1.2 + hash11(seed + fi * 5.3 + 1.0) * 2.0);
		vec2 dot_pos = center + vec2(cos(angle), sin(angle)) * dist;
		float dot_size = 0.003 + hash11(seed + fi * 7.1 + 2.0) * 0.006;
		dot_size *= splat_size;

		float dot = smoothstep(dot_size, dot_size * 0.3, length(uv - dot_pos));
		coverage = max(coverage, dot);
	}

	return coverage * spray_density;
}

void fragment() {
	// Pixelation
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// Cycle timing: splatters accumulate, then fade and restart
	float cycle_time = mod(t * splat_rate, cycle_duration);
	float cycle_progress = cycle_time / cycle_duration;

	// Fade phase: last 15% of cycle is fade-out, first 5% is fade-in
	float fade_out = smoothstep(0.85, 1.0, cycle_progress);
	float fade_in = smoothstep(0.0, 0.05, cycle_progress);
	float master_alpha = fade_in * (1.0 - fade_out);

	// Canvas background with subtle texture
	vec3 col = colour_1.rgb;
	float canvas_tex = value_noise(uv * 80.0) * 0.04;
	col += canvas_tex;

	// === Render splatters ===
	// Number of splats that have appeared so far in this cycle
	float total_splats = 16.0;
	float splats_visible = floor(cycle_progress * total_splats);

	// Cycle seed (changes each full cycle to get different splat patterns)
	float cycle_seed = floor(t * splat_rate / cycle_duration);

	for (float i = 0.0; i < 16.0; i++) {
		if (i >= splats_visible) break;

		// Splat properties (deterministic per cycle + index)
		float seed = hash11(i * 13.0 + cycle_seed * 7.0 + 0.5);
		vec2 splat_pos = vec2(
			hash11(i * 7.0 + cycle_seed * 3.0 + 1.0) * 0.8 + 0.1,
			hash11(i * 11.0 + cycle_seed * 5.0 + 2.0) * 0.8 + 0.1
		);
		float splat_radius = (0.04 + seed * 0.06) * splat_size;
		float color_idx = floor(hash11(i * 3.0 + cycle_seed * 11.0) * 4.0);

		// When this splat appears (fraction of cycle)
		float appear_frac = i / total_splats;
		// Individual splat fade-in (appears with an impact expansion)
		float splat_age = (cycle_progress - appear_frac) * total_splats;
		float splat_scale = smoothstep(0.0, 0.8, splat_age);
		float effective_radius = splat_radius * splat_scale;

		if (effective_radius < 0.001) continue;

		vec3 s_col = splat_color(color_idx);

		// Main blob
		float blob = render_splat(uv, splat_pos, effective_radius, seed);

		// Glow halo
		float glow_dist = length(uv - splat_pos) / (effective_radius * 2.0);
		float glow = exp(-glow_dist * glow_dist * 2.5) * glow_amount * 0.3 * blob;

		// Spray particles (appear with splat)
		float spray = render_spray(uv, splat_pos, effective_radius, seed) * splat_scale;

		// Drip streaks (appear after slight delay)
		float drip = 0.0;
		if (drip_amount > 0.0 && splat_age > 1.5) {
			float drip_progress = smoothstep(1.5, 4.0, splat_age);
			float drip_len = effective_radius * (3.0 + seed * 5.0) * drip_amount * drip_progress;
			float drip_w = effective_radius * 0.2;
			vec2 drip_start = splat_pos + vec2((seed - 0.5) * effective_radius * 0.5, effective_radius * 0.6);
			drip = render_drip(uv, drip_start, drip_len, drip_w, seed);

			// Second drip for larger splats
			if (seed > 0.4) {
				vec2 drip2_start = splat_pos + vec2((seed - 0.3) * effective_radius * -0.8, effective_radius * 0.5);
				float drip2 = render_drip(uv, drip2_start, drip_len * 0.7, drip_w * 0.8, seed + 5.0);
				drip = max(drip, drip2);
			}
		}

		// Compose this splat onto canvas
		float total_coverage = max(max(blob, spray), drip);
		col = mix(col, s_col, total_coverage * master_alpha);
		col += s_col * glow * master_alpha;
	}

	// Subtle scanlines
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.3;

	// Vignette
	vec2 vig_uv = uv - 0.5;
	float vignette = 1.0 - dot(vig_uv, vig_uv) * 0.4;
	col *= vignette;

	COLOR = vec4(col, 1.0);
}
