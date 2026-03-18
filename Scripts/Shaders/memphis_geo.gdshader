shader_type canvas_item;
// Memphis Geo - 90s Memphis design scattered geometric shapes
// Created for DiceRogue (Guhtzee)
// Inspired by Memphis Group postmodern design (late 80s/early 90s)
// Features circles, triangles, diamonds, rings, grid-spheres on bright teal field

// Color system - 5 colors for authentic Memphis variety
uniform vec4 colour_1 : source_color = vec4(0.0, 0.9, 0.82, 1.0);    // Bright teal background
uniform vec4 colour_2 : source_color = vec4(0.55, 0.0, 0.85, 1.0);   // Purple
uniform vec4 colour_3 : source_color = vec4(1.0, 0.2, 0.55, 1.0);    // Hot pink
uniform vec4 colour_4 : source_color = vec4(1.0, 0.85, 0.1, 1.0);    // Yellow
uniform vec4 colour_5 : source_color = vec4(0.95, 0.95, 0.95, 1.0);  // White accents

// Animation and appearance
uniform float scroll_speed : hint_range(0.0, 1.0) = 0.06;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float shape_density : hint_range(3.0, 15.0) = 7.0;
uniform float shape_scale : hint_range(0.5, 2.0) = 1.0;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.3;
uniform float rotation_speed : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.05;

// Hash functions for deterministic random placement
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

// Rotate a 2D point
vec2 rotate2d(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// SDF: Circle
float sdf_circle(vec2 p, float r) {
	return length(p) - r;
}

// SDF: Ring (circle outline)
float sdf_ring(vec2 p, float r, float thickness) {
	return abs(length(p) - r) - thickness;
}

// SDF: Triangle (equilateral)
float sdf_triangle(vec2 p, float size) {
	p.y += size * 0.3; // Center the triangle
	float k = sqrt(3.0);
	p.x = abs(p.x) - size;
	p.y = p.y + size / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	}
	p.x -= clamp(p.x, -2.0 * size, 0.0);
	return -length(p) * sign(p.y);
}

// SDF: Diamond (rotated square)
float sdf_diamond(vec2 p, float size) {
	p = abs(p);
	return (p.x + p.y - size) * 0.707;
}

// SDF: Rounded rectangle
float sdf_rounded_rect(vec2 p, vec2 size, float r) {
	vec2 d = abs(p) - size + vec2(r);
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

// Grid sphere pattern (crosshatch on a circle)
float grid_sphere(vec2 p, float r, float grid_size) {
	float circle = sdf_circle(p, r);
	if (circle > 0.02) return 1.0; // Outside circle, skip grid calc

	// Grid lines inside the circle
	vec2 gp = p / grid_size;
	float grid_x = abs(fract(gp.x) - 0.5);
	float grid_y = abs(fract(gp.y) - 0.5);
	float grid = min(grid_x, grid_y);
	float grid_line = smoothstep(0.05, 0.02, grid);

	// Combine: fill circle, then overlay grid
	float fill = smoothstep(0.01, -0.01, circle);
	return 1.0 - fill + grid_line * fill * 0.6;
}

// Zigzag line decoration
float zigzag_line(vec2 p, float freq, float amp, float thickness) {
	float wave = abs(fract(p.x * freq) - 0.5) * amp * 2.0;
	return smoothstep(thickness, thickness * 0.3, abs(p.y - wave));
}

// Confetti dot
float confetti_dot(vec2 p, float r) {
	return smoothstep(r, r * 0.5, length(p));
}

void fragment() {
	// Pixelation effect - chunky retro pixels
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// Background color
	vec3 col = colour_1.rgb;

	// Scrolling offset
	vec2 scroll = vec2(t * scroll_speed * 0.3, t * scroll_speed * 0.2);

	// === Large shapes layer (background) ===
	{
		vec2 grid_uv = (uv + scroll) * shape_density;
		vec2 cell_id = floor(grid_uv);
		vec2 cell_uv = fract(grid_uv) - 0.5;

		// Iterate neighboring cells for overlap
		for (int dx = -1; dx <= 1; dx++) {
			for (int dy = -1; dy <= 1; dy++) {
				vec2 neighbor = vec2(float(dx), float(dy));
				vec2 id = cell_id + neighbor;
				vec2 rand = hash22(id);

				// Skip some cells for variety (not every cell has a shape)
				if (rand.x > 0.65) continue;

				// Shape position within cell (centered with jitter)
				vec2 offset = hash22(id + 100.0) * 0.5 - 0.25;
				vec2 p = cell_uv - neighbor - offset;
				p /= shape_scale;

				// Rotation
				float angle = hash11(id.x * 7.0 + id.y * 13.0) * 6.283 + t * rotation_speed;
				p = rotate2d(p, angle);

				// Choose shape type based on hash
				float shape_type = hash11(id.x * 3.0 + id.y * 5.0 + 0.5);
				// Choose color based on hash
				float color_choice = hash11(id.x * 11.0 + id.y * 17.0);
				vec3 shape_color = colour_2.rgb;
				if (color_choice < 0.25) {
					shape_color = colour_2.rgb; // Purple
				} else if (color_choice < 0.5) {
					shape_color = colour_3.rgb; // Hot pink
				} else if (color_choice < 0.75) {
					shape_color = colour_4.rgb; // Yellow
				} else {
					shape_color = colour_5.rgb; // White
				}

				float shape_size = 0.12 + hash11(id.x * 9.0 + id.y) * 0.1;
				float d = 1.0;

				if (shape_type < 0.15) {
					// Filled circle
					d = sdf_circle(p, shape_size);
					float fill = smoothstep(0.01, -0.01, d);
					col = mix(col, shape_color, fill);
					// Glow
					float glow = smoothstep(shape_size + 0.08, shape_size, length(p)) * glow_amount * 0.3;
					col += shape_color * glow;
				} else if (shape_type < 0.3) {
					// Ring
					d = sdf_ring(p, shape_size, 0.015);
					float fill = smoothstep(0.01, -0.005, d);
					col = mix(col, shape_color, fill);
				} else if (shape_type < 0.45) {
					// Triangle
					d = sdf_triangle(p, shape_size);
					float fill = smoothstep(0.01, -0.01, d);
					col = mix(col, shape_color, fill);
				} else if (shape_type < 0.55) {
					// Diamond
					d = sdf_diamond(p, shape_size);
					float fill = smoothstep(0.01, -0.01, d);
					col = mix(col, shape_color, fill);
				} else if (shape_type < 0.65) {
					// Grid sphere (crosshatch circle)
					float gs = grid_sphere(p, shape_size, shape_size * 0.35);
					col = mix(col, shape_color, (1.0 - gs) * 0.9);
				} else {
					// Small confetti dots cluster
					for (int i = 0; i < 3; i++) {
						vec2 dot_off = hash22(id + vec2(float(i) * 7.0, float(i) * 11.0)) * 0.3 - 0.15;
						float dot_r = 0.02 + hash11(id.x + float(i) * 3.0) * 0.02;
						float dot = confetti_dot(p - dot_off, dot_r);
						col = mix(col, shape_color, dot);
					}
				}
			}
		}
	}

	// === Small decorative elements layer (foreground details) ===
	{
		vec2 detail_uv = (uv + scroll * 0.7) * shape_density * 2.0;
		vec2 detail_id = floor(detail_uv);
		vec2 detail_cell = fract(detail_uv) - 0.5;

		vec2 rand = hash22(detail_id + 500.0);
		if (rand.x < 0.2) {
			// Small zigzag decorations
			vec2 p = detail_cell;
			float angle = hash11(detail_id.x * 5.0 + detail_id.y * 3.0) * 3.14159;
			p = rotate2d(p, angle);
			float zz = zigzag_line(p, 6.0, 0.08, 0.015);
			float zz_color_pick = hash11(detail_id.x * 13.0 + detail_id.y * 7.0 + 2.0);
			vec3 zz_col = colour_5.rgb;
			if (zz_color_pick < 0.5) {
				zz_col = colour_5.rgb;
			} else {
				zz_col = colour_3.rgb;
			}
			col = mix(col, zz_col, zz * 0.7);
		}

		if (rand.y < 0.15) {
			// Tiny triangles scattered
			vec2 p = detail_cell;
			float angle = hash11(detail_id.x + detail_id.y * 9.0) * 6.283;
			p = rotate2d(p, angle);
			float tri = sdf_triangle(p * 1.5, 0.04);
			float tri_fill = smoothstep(0.005, -0.005, tri);
			float tri_color_pick = hash11(detail_id.x * 7.0 + detail_id.y * 11.0 + 5.0);
			vec3 tri_col = colour_4.rgb;
			if (tri_color_pick > 0.5) {
				tri_col = colour_5.rgb;
			}
			col = mix(col, tri_col, tri_fill * 0.8);
		}
	}

	// === Subtle stripes in background (adds depth) ===
	{
		vec2 stripe_uv = uv + scroll * 0.1;
		float stripe = abs(fract((stripe_uv.x + stripe_uv.y) * 30.0) - 0.5);
		float stripe_mask = smoothstep(0.48, 0.5, stripe);
		col = mix(col, col * 0.92, stripe_mask * 0.15);
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
