shader_type canvas_item;
// Laser Show - 80s Laser Light Show
// Created for DiceRogue (Guhtzee)
// Vivid laser beams sweeping across a dark smoky venue
// Inspired by 1980s arena rock concerts and planetarium laser shows (1985-1989)

// Color system - laser beam colors
uniform vec4 colour_1 : source_color = vec4(0.02, 0.01, 0.06, 1.0);  // Deep dark purple-black background
uniform vec4 colour_2 : source_color = vec4(0.0, 1.0, 0.15, 1.0);    // Green laser (argon)
uniform vec4 colour_3 : source_color = vec4(1.0, 0.0, 0.1, 1.0);     // Red laser (helium-neon)
uniform vec4 colour_4 : source_color = vec4(0.1, 0.3, 1.0, 1.0);     // Blue laser (krypton)
uniform vec4 colour_5 : source_color = vec4(0.95, 0.9, 0.1, 1.0);    // Yellow beam

// Controls
uniform float beam_count : hint_range(3.0, 12.0) = 7.0;
uniform float sweep_speed : hint_range(0.1, 2.0) = 0.6;
uniform float beam_width : hint_range(0.001, 0.01) = 0.004;
uniform float glow_intensity : hint_range(0.5, 4.0) = 2.0;
uniform float fog_density : hint_range(0.0, 1.0) = 0.5;
uniform float flare_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 550.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.1;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

// Value noise for volumetric fog
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM noise for fog volumes
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p *= 2.01;
		amp *= 0.5;
	}
	return v;
}

// Distance from a point to an infinite line through origin at angle theta
float line_dist(vec2 p, float theta) {
	vec2 dir = vec2(cos(theta), sin(theta));
	return abs(p.x * dir.y - p.y * dir.x);
}

void fragment() {
	// Pixelation
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// Dark background with slight gradient
	vec3 col = colour_1.rgb;
	col += vec3(0.01, 0.005, 0.02) * (1.0 - uv.y);

	// Volumetric fog layers
	float fog1 = fbm(uv * 3.0 + vec2(t * 0.05, t * 0.02)) * fog_density;
	float fog2 = fbm(uv * 5.0 - vec2(t * 0.03, t * 0.07)) * fog_density * 0.5;
	float fog = fog1 + fog2;

	// Fog adds subtle atmosphere
	col += vec3(0.03, 0.01, 0.05) * fog;

	// === Laser beams ===
	// Each beam originates from a point and sweeps back and forth
	float total_beams = floor(beam_count);
	vec3 beam_accumulator = vec3(0.0);
	float flare_accumulator = 0.0;

	for (float i = 0.0; i < 12.0; i++) {
		if (i >= total_beams) break;

		// Beam origin point (spread along top/bottom/sides)
		float origin_pick = hash11(i * 17.0);
		vec2 origin;
		if (origin_pick < 0.4) {
			// Top edge
			origin = vec2(hash11(i * 13.0 + 5.0), 0.0);
		} else if (origin_pick < 0.7) {
			// Bottom edge
			origin = vec2(hash11(i * 13.0 + 5.0), 1.0);
		} else if (origin_pick < 0.85) {
			// Left edge
			origin = vec2(0.0, hash11(i * 23.0 + 7.0));
		} else {
			// Right edge
			origin = vec2(1.0, hash11(i * 23.0 + 7.0));
		}

		// Sweep angle oscillation
		float sweep_phase = hash11(i * 7.0 + 3.0) * 6.283;
		float sweep_range = 0.6 + hash11(i * 11.0) * 0.8; // radians
		float base_angle = hash11(i * 19.0 + 9.0) * 6.283;
		float speed_var = 0.7 + hash11(i * 29.0) * 0.6;
		float angle = base_angle + sin(t * sweep_speed * speed_var + sweep_phase) * sweep_range;

		// Beam direction
		vec2 dir = vec2(cos(angle), sin(angle));
		vec2 p = uv - origin;

		// Distance to the beam ray (one-directional from origin)
		float along = dot(p, dir); // How far along the beam
		vec2 closest = p - dir * along;
		float d = length(closest);

		// Only render on the positive side of the beam direction
		float ray_mask = smoothstep(0.0, 0.05, along);

		// Core beam line
		float core = exp(-d * d / (beam_width * beam_width)) * ray_mask;

		// Wider glow halo
		float glow = exp(-d * d / (beam_width * beam_width * 25.0)) * ray_mask * 0.3;

		// Beam scattering through fog (brighter where fog is dense)
		float scatter = fog * core * 2.0;

		// Pick beam color
		float color_idx = hash11(i * 31.0 + 1.0);
		vec3 beam_color;
		if (color_idx < 0.3) {
			beam_color = colour_2.rgb; // Green
		} else if (color_idx < 0.55) {
			beam_color = colour_3.rgb; // Red
		} else if (color_idx < 0.8) {
			beam_color = colour_4.rgb; // Blue
		} else {
			beam_color = colour_5.rgb; // Yellow
		}

		beam_accumulator += beam_color * (core * glow_intensity + glow * glow_intensity + scatter);

		// Flare at beam origin
		float origin_dist = length(uv - origin);
		float flare = exp(-origin_dist * origin_dist * 400.0) * flare_intensity;
		beam_accumulator += beam_color * flare * 0.5;

		// Intersection flares: check this beam against previous beams
		// (Simple approximation — add bright spot near beam crossings)
		for (float j = 0.0; j < 12.0; j++) {
			if (j >= i) break;

			float j_origin_pick = hash11(j * 17.0);
			vec2 j_origin;
			if (j_origin_pick < 0.4) {
				j_origin = vec2(hash11(j * 13.0 + 5.0), 0.0);
			} else if (j_origin_pick < 0.7) {
				j_origin = vec2(hash11(j * 13.0 + 5.0), 1.0);
			} else if (j_origin_pick < 0.85) {
				j_origin = vec2(0.0, hash11(j * 23.0 + 7.0));
			} else {
				j_origin = vec2(1.0, hash11(j * 23.0 + 7.0));
			}

			float j_sweep_phase = hash11(j * 7.0 + 3.0) * 6.283;
			float j_sweep_range = 0.6 + hash11(j * 11.0) * 0.8;
			float j_base_angle = hash11(j * 19.0 + 9.0) * 6.283;
			float j_speed_var = 0.7 + hash11(j * 29.0) * 0.6;
			float j_angle = j_base_angle + sin(t * sweep_speed * j_speed_var + j_sweep_phase) * j_sweep_range;

			vec2 j_dir = vec2(cos(j_angle), sin(j_angle));
			vec2 j_p = uv - j_origin;
			float j_along = dot(j_p, j_dir);
			vec2 j_closest = j_p - j_dir * j_along;
			float j_d = length(j_closest);
			float j_ray_mask = smoothstep(0.0, 0.05, j_along);

			// Where both beams are close = intersection
			float intersection = exp(-d * d / (beam_width * 3.0)) * exp(-j_d * j_d / (beam_width * 3.0)) * ray_mask * j_ray_mask;
			flare_accumulator += intersection * flare_intensity * 3.0;
		}
	}

	// Add beams
	col += beam_accumulator;

	// Add intersection flares (white-hot)
	col += vec3(1.0, 0.95, 0.9) * flare_accumulator;

	// Subtle fan / cone scatter effect
	float fan = fbm(uv * 8.0 + vec2(t * 0.1, 0.0)) * 0.03 * fog_density;
	col += vec3(0.02, 0.01, 0.03) * fan;

	// Scanlines
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.3;

	// Slight chromatic bloom
	col = min(col, vec3(2.0));

	COLOR = vec4(col, 1.0);
}
