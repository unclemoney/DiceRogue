shader_type canvas_item;
// Zigzag Bolts - Saved By The Bell style bold geometric patterns
// Created for DiceRogue (Guhtzee)
// Inspired by early 90s teen pop culture: bold zigzag stripes, confetti triangles,
// and neon color blocking (Saved By The Bell, Fresh Prince, 90s Trapper Keeper art)

// Color system - 4 bold neon colors
uniform vec4 colour_1 : source_color = vec4(0.95, 0.95, 0.1, 1.0);   // Neon yellow background
uniform vec4 colour_2 : source_color = vec4(0.55, 0.0, 0.9, 1.0);    // Bold purple
uniform vec4 colour_3 : source_color = vec4(0.0, 0.85, 0.8, 1.0);    // Teal
uniform vec4 colour_4 : source_color = vec4(1.0, 0.15, 0.5, 1.0);    // Hot pink

// Animation and appearance
uniform float scroll_speed : hint_range(0.0, 1.0) = 0.1;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float bolt_count : hint_range(2.0, 8.0) = 4.0;
uniform float bolt_thickness : hint_range(0.5, 2.0) = 1.0;
uniform float confetti_density : hint_range(0.0, 1.0) = 0.5;
uniform float color_block_strength : hint_range(0.0, 1.0) = 0.4;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;

// Hash functions
float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Zigzag bolt shape: horizontal zigzag stripe
// Returns distance to the zigzag band center
float zigzag_bolt(vec2 p, float y_center, float freq, float amplitude, float thickness) {
	// Zigzag wave: sawtooth/triangle wave pattern
	float wave = abs(fract(p.x * freq + 0.25) * 2.0 - 1.0) * amplitude;
	float dist = abs(p.y - y_center - wave);
	return smoothstep(thickness, thickness * 0.4, dist);
}

// Triangle confetti
float triangle_shape(vec2 p, float size) {
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

// Circle confetti
float circle_shape(vec2 p, float r) {
	return smoothstep(r, r * 0.5, length(p));
}

// Star shape (4-pointed)
float star_shape(vec2 p, float size) {
	float d1 = abs(p.x) + abs(p.y);
	float d2 = max(abs(p.x), abs(p.y)) * 1.414;
	float d = min(d1, d2);
	return smoothstep(size, size * 0.6, d);
}

void fragment() {
	// Pixelation effect - chunky retro pixels
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;
	float scroll = t * scroll_speed;

	// Start with background color
	vec3 col = colour_1.rgb;

	// === Color blocking: diagonal bands of lighter/darker background ===
	{
		float band = sin((uv.x + uv.y) * 3.0 + scroll * 0.5) * 0.5 + 0.5;
		float block = smoothstep(0.4, 0.6, band);
		vec3 alt_bg = mix(colour_1.rgb, colour_3.rgb, 0.15);
		col = mix(col, alt_bg, block * color_block_strength);
	}

	// === Bold zigzag lightning bolts ===
	vec2 bolt_uv = vec2(uv.x + scroll, uv.y);

	for (float i = 0.0; i < 8.0; i++) {
		if (i >= bolt_count) break;

		// Distribute bolts across vertical space
		float y_pos = (i + 0.5) / bolt_count - 0.5;
		y_pos += sin(t * 0.2 + i * 1.5) * 0.02; // Subtle breathing

		// Vary zigzag parameters per bolt
		float freq = 2.0 + hash11(i * 7.0 + 1.0) * 3.0;
		float amp = 0.06 + hash11(i * 13.0 + 5.0) * 0.08;

		// Alternate bolt thickness
		float thick = (0.025 + hash11(i * 3.0 + 2.0) * 0.025) * bolt_thickness;

		// Calculate bolt
		float bolt = zigzag_bolt(bolt_uv, y_pos, freq, amp, thick);

		// Choose bolt color (cycle through colours 2-4)
		vec3 bolt_col = colour_2.rgb;
		float color_idx = mod(i, 3.0);
		if (color_idx < 1.0) {
			bolt_col = colour_2.rgb;
		} else if (color_idx < 2.0) {
			bolt_col = colour_3.rgb;
		} else {
			bolt_col = colour_4.rgb;
		}

		// Apply bolt with hard edge (90s style)
		col = mix(col, bolt_col, bolt * 0.95);

		// Bold outline effect: slightly larger version behind
		float outline_thick = thick + 0.008;
		float outline = zigzag_bolt(bolt_uv, y_pos, freq, amp, outline_thick);
		float outline_only = max(outline - bolt, 0.0);
		col = mix(col, bolt_col * 0.4, outline_only * 0.6);
	}

	// === Confetti layer: scattered triangles, circles, and stars ===
	{
		vec2 conf_uv = (uv + vec2(scroll * 0.5, scroll * 0.3)) * 20.0;
		vec2 conf_id = floor(conf_uv);
		vec2 conf_cell = fract(conf_uv) - 0.5;

		// Check neighboring cells
		for (int dx = -1; dx <= 1; dx++) {
			for (int dy = -1; dy <= 1; dy++) {
				vec2 neighbor = vec2(float(dx), float(dy));
				vec2 id = conf_id + neighbor;
				vec2 rand = hash22(id);

				// Density control
				if (rand.x > confetti_density * 0.6) continue;

				vec2 offset = hash22(id + 200.0) * 0.6 - 0.3;
				vec2 p = conf_cell - neighbor - offset;

				// Rotation
				float angle = hash11(id.x * 5.0 + id.y * 9.0) * 6.283 + t * 0.3;
				float c = cos(angle);
				float s = sin(angle);
				p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);

				// Choose shape and color
				float shape_type = hash11(id.x * 11.0 + id.y * 3.0);
				float color_pick = hash11(id.x * 7.0 + id.y * 13.0);
				vec3 conf_col = colour_2.rgb;
				if (color_pick < 0.33) {
					conf_col = colour_2.rgb;
				} else if (color_pick < 0.66) {
					conf_col = colour_3.rgb;
				} else {
					conf_col = colour_4.rgb;
				}

				float conf_size = 0.06 + hash11(id.x + id.y * 7.0) * 0.06;
				float shape = 0.0;

				if (shape_type < 0.35) {
					shape = triangle_shape(p, conf_size);
				} else if (shape_type < 0.65) {
					shape = circle_shape(p, conf_size);
				} else {
					shape = star_shape(p, conf_size);
				}

				col = mix(col, conf_col, shape * 0.85);
			}
		}
	}

	// === Thin accent lines (90s squiggle decoration) ===
	{
		float line1 = abs(sin(uv.x * 25.0 + scroll * 2.0 + uv.y * 3.0));
		float line_mask = smoothstep(0.98, 0.99, line1);
		col = mix(col, colour_4.rgb, line_mask * 0.3);
	}

	// Subtle scanlines
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.3;

	// Slight vignette
	vec2 vig_uv = uv - 0.5;
	float vignette = 1.0 - dot(vig_uv, vig_uv) * 0.25;
	col *= vignette;

	COLOR = vec4(col, 1.0);
}
