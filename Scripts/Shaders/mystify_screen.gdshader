shader_type canvas_item;
// Mystify Screen - Windows 3.1 "Mystify Your Mind" screensaver
// Created for DiceRogue (Guhtzee)
// Bouncing polygon shapes with color trails on black background
// Classic early 90s Windows screensaver aesthetic (1992)

// Color system - classic Win 3.1 Mystify colors
uniform vec4 colour_1 : source_color = vec4(0.0, 0.0, 0.0, 1.0);     // Black background
uniform vec4 colour_2 : source_color = vec4(0.0, 0.95, 0.95, 1.0);   // Cyan polygon
uniform vec4 colour_3 : source_color = vec4(0.95, 0.0, 0.95, 1.0);   // Magenta polygon

// Controls
uniform float move_speed : hint_range(0.1, 2.0) = 0.7;
uniform float trail_length : hint_range(3.0, 16.0) = 10.0;
uniform float line_thickness : hint_range(0.001, 0.008) = 0.003;
uniform float glow_width : hint_range(0.5, 3.0) = 1.5;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 600.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.05;

// Deterministic bounce: a vertex position at time t that bounces within [0,1]
// Uses triangle wave (linear bounce off walls)
float bounce(float speed, float phase, float t) {
	float val = fract(speed * t * 0.1 + phase) * 2.0;
	if (val > 1.0) {
		val = 2.0 - val;
	}
	// Keep away from edges slightly
	return val * 0.9 + 0.05;
}

// Get vertex position for a polygon vertex at a given time
vec2 get_vertex(int poly, int vertex, float t) {
	// Each vertex has unique speed and phase (deterministic, no hash needed)
	float base = float(poly) * 17.0 + float(vertex) * 7.0;
	float sx = 0.11 + float(vertex) * 0.037 + float(poly) * 0.023;
	float sy = 0.13 + float(vertex) * 0.029 + float(poly) * 0.031;
	float px = fract(base * 0.1234);
	float py = fract(base * 0.5678);

	float x = bounce(sx * move_speed, px, t);
	float y = bounce(sy * move_speed, py, t);
	return vec2(x, y);
}

// Distance from point to line segment
float dist_to_segment(vec2 p, vec2 a, vec2 b) {
	vec2 ba = b - a;
	vec2 pa = p - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Render one polygon (quadrilateral) as 4 line segments with glow
float render_polygon(vec2 uv, vec2 v0, vec2 v1, vec2 v2, vec2 v3, float thickness) {
	float d0 = dist_to_segment(uv, v0, v1);
	float d1 = dist_to_segment(uv, v1, v2);
	float d2 = dist_to_segment(uv, v2, v3);
	float d3 = dist_to_segment(uv, v3, v0);
	float min_d = min(min(d0, d1), min(d2, d3));

	// Core line
	float core = smoothstep(thickness, thickness * 0.3, min_d);
	// Wider glow
	float glow = exp(-min_d * min_d * 8000.0 / (glow_width * glow_width)) * 0.6;

	return core + glow;
}

void fragment() {
	// Pixelation
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// Black background
	vec3 col = colour_1.rgb;

	// Render 2 polygon groups with trails
	for (int poly = 0; poly < 2; poly++) {
		// Choose polygon color
		vec3 poly_color = colour_2.rgb;
		if (poly == 1) {
			poly_color = colour_3.rgb;
		}

		// Render trail: ghost copies from past positions
		float trail_steps = floor(trail_length);
		for (float trail = 0.0; trail < 16.0; trail++) {
			if (trail >= trail_steps) break;

			// Time offset for this trail ghost
			float trail_time = t - trail * 0.12 / move_speed;

			// Get 4 vertices of the quadrilateral at this past time
			vec2 v0 = get_vertex(poly, 0, trail_time);
			vec2 v1 = get_vertex(poly, 1, trail_time);
			vec2 v2 = get_vertex(poly, 2, trail_time);
			vec2 v3 = get_vertex(poly, 3, trail_time);

			// Trail fade: most recent = brightest, oldest = dimmest
			float trail_alpha = 1.0 - trail / trail_steps;
			trail_alpha = trail_alpha * trail_alpha; // Quadratic falloff

			// Thinner lines for older ghosts
			float ghost_thickness = line_thickness * (0.5 + trail_alpha * 0.5);

			float poly_shape = render_polygon(uv, v0, v1, v2, v3, ghost_thickness);

			// Additive blending for glow buildup
			col += poly_color * poly_shape * trail_alpha * 0.35;
		}
	}

	// Clamp to prevent over-bright
	col = min(col, vec3(1.5));

	// Subtle scanlines (very period-appropriate for CRT monitors)
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.4;

	COLOR = vec4(col, 1.0);
}
