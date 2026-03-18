shader_type canvas_item;
// Nick Splat - 90s Nickelodeon chaos background
// Created for DiceRogue (Guhtzee)
// Inspired by early 90s Nickelodeon bumpers, promos, and interstitials (1991-1996)
// Bold orange background with scattered scribbles, squiggles, triangles, spirals

// Color system - classic Nick palette
uniform vec4 colour_1 : source_color = vec4(0.98, 0.55, 0.0, 1.0);   // Nick orange background
uniform vec4 colour_2 : source_color = vec4(0.6, 0.0, 0.85, 1.0);    // Purple scribbles
uniform vec4 colour_3 : source_color = vec4(0.0, 0.9, 0.75, 1.0);    // Teal/mint shapes
uniform vec4 colour_4 : source_color = vec4(0.95, 0.15, 0.5, 1.0);   // Hot pink accents
uniform vec4 colour_5 : source_color = vec4(0.95, 0.9, 0.0, 1.0);    // Yellow squiggles

// Controls
uniform float chaos_density : hint_range(3.0, 12.0) = 6.0;
uniform float drift_speed : hint_range(0.0, 0.5) = 0.08;
uniform float doodle_scale : hint_range(0.5, 2.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 450.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.05;

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

// Rotate 2D
vec2 rotate2d(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// Simple value noise for roughening edges
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

// Hand-drawn edge roughening
float rough_edge(vec2 p, float base_dist, float seed) {
	float noise = value_noise(p * 15.0 + seed * 10.0) * roughness * 0.04;
	float noise2 = value_noise(p * 30.0 + seed * 5.0) * roughness * 0.02;
	return base_dist + noise + noise2;
}

// Scribble cloud: large rough oval with hatching texture
float scribble_cloud(vec2 p, float size, float seed) {
	// Squash into oval
	vec2 sp = p * vec2(1.0, 1.4);
	float dist = length(sp);
	float rough_dist = rough_edge(p, dist, seed);
	float body = smoothstep(size, size * 0.85, rough_dist);

	// Hatching texture: diagonal lines inside
	float hatch1 = abs(sin((p.x + p.y) * 25.0 + seed * 5.0));
	float hatch2 = abs(sin((p.x - p.y) * 20.0 + seed * 3.0));
	float hatch = min(hatch1, hatch2);
	float hatch_mask = smoothstep(0.3, 0.5, hatch) * 0.3;

	// Rough outline
	float outline = smoothstep(size * 1.05, size, rough_dist) * (1.0 - smoothstep(size, size * 0.9, rough_dist));

	return max(body * (1.0 - hatch_mask), outline * 1.2);
}

// Zigzag chevron / arrow shape
float zigzag_arrow(vec2 p, float size, float seed) {
	// Triangle arrow with rough edges
	float noise = value_noise(p * 20.0 + seed * 8.0) * roughness * 0.02;

	// Arrow pointing right: two diagonal lines meeting at a point
	float arrow_body = 0.0;
	float line_w = 0.015 + noise;

	// Upper stroke
	float d1 = abs(p.y + p.x * 0.6) - line_w;
	float stroke1 = smoothstep(line_w, 0.0, abs(d1)) * step(-size, p.x) * step(p.x, size * 0.5);

	// Lower stroke
	float d2 = abs(p.y - p.x * 0.6) - line_w;
	float stroke2 = smoothstep(line_w, 0.0, abs(d2)) * step(-size, p.x) * step(p.x, size * 0.5);

	return max(stroke1, stroke2);
}

// Curvy S-squiggle
float s_squiggle(vec2 p, float size, float seed) {
	float curve = sin(p.y / size * 4.0 + seed * 3.0) * size * 0.4;
	float dist = abs(p.x - curve);
	float line_w = 0.012 + value_noise(p * 25.0 + seed * 7.0) * roughness * 0.008;

	float squig = smoothstep(line_w, line_w * 0.3, dist);
	// Limit length
	squig *= smoothstep(size * 1.5, size * 1.0, abs(p.y));

	return squig;
}

// Spiral doodle
float spiral_doodle(vec2 p, float size, float seed) {
	float angle = atan(p.y, p.x);
	float dist = length(p);

	// Archimedes spiral: r = a + b*theta
	float spiral_r = dist / size;
	float spiral_angle = angle + spiral_r * 8.0 + seed * 6.283;

	float line = abs(sin(spiral_angle * 1.5));
	line = smoothstep(0.15, 0.3, line);

	// Mask to circle
	float mask = smoothstep(size, size * 0.9, dist);

	// Center dot
	float center = smoothstep(size * 0.15, size * 0.08, dist);

	return (1.0 - line) * mask * 0.7 + center;
}

// Confetti triangle
float small_triangle(vec2 p, float size) {
	p.y += size * 0.3;
	float k = sqrt(3.0);
	p.x = abs(p.x) - size;
	p.y = p.y + size / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	}
	p.x -= clamp(p.x, -2.0 * size, 0.0);
	return smoothstep(0.005, -0.005, -length(p) * sign(p.y));
}

// Chevron wave band
float chevron_band(vec2 p, float freq, float amplitude, float thickness) {
	float wave = abs(fract(p.x * freq + 0.25) * 2.0 - 1.0) * amplitude;
	return smoothstep(thickness, thickness * 0.3, abs(p.y - wave));
}

void fragment() {
	// Pixelation
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// Bright orange background
	vec3 col = colour_1.rgb;

	// Subtle background texture (slight striped pattern for depth)
	float bg_stripe = sin((uv.x + uv.y) * 40.0) * 0.02;
	col += bg_stripe;

	// Drift offset
	vec2 scroll = vec2(t * drift_speed * 0.3, t * drift_speed * 0.2);

	// === Large shapes layer ===
	{
		vec2 grid_uv = (uv + scroll) * chaos_density;
		vec2 cell_id = floor(grid_uv);
		vec2 cell_fract = fract(grid_uv) - 0.5;

		for (int dx = -1; dx <= 1; dx++) {
			for (int dy = -1; dy <= 1; dy++) {
				vec2 neighbor = vec2(float(dx), float(dy));
				vec2 id = cell_id + neighbor;

				float presence = hash21(id);
				if (presence > 0.6) continue;

				vec2 offset = hash22(id + 100.0) * 0.5 - 0.25;
				vec2 p = (cell_fract - neighbor - offset) / doodle_scale;

				float angle = hash21(id + 5.0) * 6.283 + t * drift_speed * 0.5;
				p = rotate2d(p, angle * 0.3);

				float shape_type = hash21(id + 10.0);
				float color_pick = hash21(id + 15.0);
				float seed = hash21(id + 20.0);
				float element_size = 0.12 + hash21(id + 25.0) * 0.08;

				vec3 shape_col = colour_2.rgb;
				if (color_pick < 0.25) {
					shape_col = colour_2.rgb; // Purple
				} else if (color_pick < 0.5) {
					shape_col = colour_3.rgb; // Teal
				} else if (color_pick < 0.75) {
					shape_col = colour_4.rgb; // Pink
				} else {
					shape_col = colour_5.rgb; // Yellow
				}

				float shape = 0.0;

				if (shape_type < 0.25) {
					// Scribble cloud
					shape = scribble_cloud(p, element_size, seed);
				} else if (shape_type < 0.4) {
					// Zigzag arrow
					shape = zigzag_arrow(p, element_size, seed);
				} else if (shape_type < 0.55) {
					// S-squiggle
					shape = s_squiggle(p, element_size, seed);
				} else if (shape_type < 0.7) {
					// Spiral doodle
					shape = spiral_doodle(p, element_size, seed);
				} else if (shape_type < 0.85) {
					// Chevron wave
					shape = chevron_band(p, 4.0 + seed * 3.0, element_size * 0.4, 0.012);
					shape *= smoothstep(element_size * 1.5, element_size, abs(p.x));
				} else {
					// Small confetti triangles cluster
					for (int i = 0; i < 3; i++) {
						vec2 tri_off = hash22(id + vec2(float(i) * 7.0, float(i) * 3.0)) * 0.15 - 0.075;
						float tri_angle = hash11(id.x + float(i) * 5.0) * 6.283;
						vec2 tri_p = rotate2d(p - tri_off, tri_angle);
						float tri = small_triangle(tri_p, 0.03 + hash11(id.x + float(i)) * 0.02);
						shape = max(shape, tri);
					}
				}

				// Apply with slight outline effect (black edge for hand-drawn look)
				if (shape > 0.05) {
					// Dark outline behind
					col = mix(col, vec3(0.0, 0.0, 0.0), smoothstep(0.0, 0.15, shape) * 0.3);
					// Color fill on top
					col = mix(col, shape_col, shape * 0.85);
				}
			}
		}
	}

	// === Scattered small decorative elements layer ===
	{
		vec2 detail_uv = (uv + scroll * 1.3) * chaos_density * 2.0;
		vec2 detail_id = floor(detail_uv);
		vec2 detail_cell = fract(detail_uv) - 0.5;

		vec2 rand = hash22(detail_id + 300.0);

		if (rand.x < 0.25) {
			// Tiny dots / confetti
			float dot_size = 0.02 + rand.y * 0.02;
			float dot = smoothstep(dot_size, dot_size * 0.4, length(detail_cell));
			float c_pick = hash21(detail_id + 7.0);
			vec3 dot_col = colour_4.rgb;
			if (c_pick < 0.5) {
				dot_col = colour_5.rgb;
			}
			col = mix(col, dot_col, dot * 0.7);
		}

		if (rand.y < 0.15) {
			// Tiny squiggle accent
			float sq = s_squiggle(detail_cell * 1.5, 0.06, hash21(detail_id + 9.0));
			float c_pick2 = hash21(detail_id + 11.0);
			vec3 sq_col = colour_5.rgb;
			if (c_pick2 > 0.5) {
				sq_col = colour_4.rgb;
			}
			col = mix(col, sq_col, sq * 0.6);
		}
	}

	// Subtle scanlines
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.3;

	// Slight vignette
	vec2 vig_uv = uv - 0.5;
	float vignette = 1.0 - dot(vig_uv, vig_uv) * 0.2;
	col *= vignette;

	COLOR = vec4(col, 1.0);
}
