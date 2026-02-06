shader_type canvas_item;
// Marquee Lights - Theater/casino chasing bulb border patterns
// Created for DiceRogue (Guhtzee)
// Inspired by vintage theater marquees, casino signage, and arcade cabinet borders

// Color system
uniform vec4 colour_1 : source_color = vec4(0.05, 0.02, 0.1, 1.0);   // Dark background
uniform vec4 colour_2 : source_color = vec4(1.0, 0.85, 0.2, 1.0);     // Warm bulb lit (gold)
uniform vec4 colour_3 : source_color = vec4(0.15, 0.08, 0.05, 1.0);   // Bulb off (dim amber)

// Secondary bulb colors for variety
uniform vec4 bulb_alt_1 : source_color = vec4(0.0, 0.9, 0.8, 1.0);    // Teal bulbs
uniform vec4 bulb_alt_2 : source_color = vec4(0.8, 0.0, 1.0, 1.0);    // Purple bulbs

// Animation and appearance
uniform float chase_speed : hint_range(0.0, 3.0) = 1.0;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float bulb_size : hint_range(0.01, 0.08) = 0.035;
uniform float bulb_spacing : hint_range(0.03, 0.15) = 0.07;
uniform float glow_radius : hint_range(0.5, 3.0) = 1.8;
uniform int frame_count : hint_range(1, 4) = 3;
uniform float inner_pattern : hint_range(0.0, 1.0) = 0.5;

// Hash for pseudo-random
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Single bulb with glow falloff
// Returns: x = bulb core, y = glow halo
vec2 bulb(vec2 uv, vec2 pos, float size, float is_lit) {
	float dist = length(uv - pos);
	float core = smoothstep(size, size * 0.6, dist) * is_lit;
	float glow = (1.0 / (1.0 + dist * dist * 800.0 / (glow_radius * glow_radius))) * is_lit;
	// Dim filament glow when off
	float off_glow = smoothstep(size, size * 0.3, dist) * (1.0 - is_lit) * 0.15;
	return vec2(core + off_glow, glow);
}

// Calculate bulbs along a rectangular frame border
// frame_inset: how far from edge (0 = outer edge)
// chase_offset: animation phase offset for this frame
vec3 render_frame(vec2 uv, float frame_inset, float chase_offset, vec4 lit_color, float time_val) {
	vec3 result = vec3(0.0);
	float total_glow = 0.0;

	float margin = frame_inset;
	float inner = 1.0 - margin;

	// Calculate position along border perimeter
	// Map UV to distance along the rectangular border
	float border_dist = -1.0;
	vec2 nearest_border_pos = vec2(0.0);
	float perimeter_pos = 0.0;

	// Width and height of this frame
	float w = inner - margin;
	float h = inner - margin;
	float perim = 2.0 * (w + h);

	// Check if we're near a border edge and compute perimeter position
	float d_left = abs(uv.x - margin);
	float d_right = abs(uv.x - inner);
	float d_top = abs(uv.y - margin);
	float d_bottom = abs(uv.y - inner);

	float min_d = min(min(d_left, d_right), min(d_top, d_bottom));

	// Only render bulbs if we're close enough to a border
	if (min_d < bulb_spacing * 2.0) {
		// Top edge: left to right
		float num_bulbs_h = floor(w / bulb_spacing);
		float num_bulbs_v = floor(h / bulb_spacing);
		float total_bulbs = 2.0 * (num_bulbs_h + num_bulbs_v);

		// Place bulbs along all four edges
		for (float i = 0.0; i < 80.0; i += 1.0) {
			if (i >= total_bulbs) break;

			vec2 bpos = vec2(0.0);
			float t_norm = i / total_bulbs;

			if (i < num_bulbs_h) {
				// Top edge
				bpos = vec2(margin + (i + 0.5) * bulb_spacing, margin);
			} else if (i < num_bulbs_h + num_bulbs_v) {
				// Right edge
				float j = i - num_bulbs_h;
				bpos = vec2(inner, margin + (j + 0.5) * bulb_spacing);
			} else if (i < 2.0 * num_bulbs_h + num_bulbs_v) {
				// Bottom edge (right to left)
				float j = i - num_bulbs_h - num_bulbs_v;
				bpos = vec2(inner - (j + 0.5) * bulb_spacing, inner);
			} else {
				// Left edge (bottom to top)
				float j = i - 2.0 * num_bulbs_h - num_bulbs_v;
				bpos = vec2(margin, inner - (j + 0.5) * bulb_spacing);
			}

			// Chase pattern: sequential lighting
			float chase_phase = fract(t_norm + time_val * chase_speed * 0.3 + chase_offset);

			// Create chase pattern groups (3 lit, 2 off repeating)
			float group = fract(chase_phase * 5.0);
			float is_lit = step(group, 0.6); // 60% on, 40% off

			vec2 b = bulb(uv, bpos, bulb_size, is_lit);
			result += lit_color.rgb * b.x;
			total_glow += b.y;
		}
	}

	result += lit_color.rgb * total_glow * 0.15;
	return result;
}

void fragment() {
	// Pixelation effect
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// Dark background with subtle gradient
	vec3 bg = colour_1.rgb;
	float center_dist = length(uv - 0.5);
	bg += colour_1.rgb * 0.3 * (1.0 - center_dist);

	vec3 final_color = bg;

	// === Render marquee frames ===
	if (frame_count >= 1) {
		// Outer frame - warm gold bulbs
		final_color += render_frame(uv, 0.04, 0.0, colour_2, t);
	}
	if (frame_count >= 2) {
		// Second frame - teal bulbs, opposite chase direction
		final_color += render_frame(uv, 0.12, 0.5, bulb_alt_1, -t);
	}
	if (frame_count >= 3) {
		// Third frame - purple bulbs
		final_color += render_frame(uv, 0.20, 0.25, bulb_alt_2, t * 1.3);
	}
	if (frame_count >= 4) {
		// Innermost frame - gold again, fast chase
		final_color += render_frame(uv, 0.28, 0.75, colour_2, t * 0.7);
	}

	// === Inner fill pattern ===
	if (inner_pattern > 0.0) {
		// Diamond tile pattern in the center space
		float inner_margin = 0.04 + float(frame_count) * 0.08 + 0.04;
		vec2 inner_uv = (uv - inner_margin) / (1.0 - 2.0 * inner_margin);

		if (inner_uv.x > 0.0 && inner_uv.x < 1.0 && inner_uv.y > 0.0 && inner_uv.y < 1.0) {
			// Rotating diamond grid
			vec2 diam_uv = inner_uv * 8.0;
			diam_uv = vec2(diam_uv.x + diam_uv.y, diam_uv.x - diam_uv.y) * 0.707;
			vec2 diam_id = floor(diam_uv);
			vec2 diam_fract = fract(diam_uv) - 0.5;

			float diam_dist = abs(diam_fract.x) + abs(diam_fract.y);
			float diam_pattern = smoothstep(0.5, 0.45, diam_dist);

			// Pulsing color based on cell hash
			float h = hash(diam_id);
			vec3 diam_col = mix(colour_2.rgb, bulb_alt_1.rgb, h) * 0.15;
			float pulse = sin(t * 1.5 + h * 6.28) * 0.3 + 0.7;

			final_color += diam_col * diam_pattern * inner_pattern * pulse;
		}
	}

	// === Screen-wide ambient glow from all bulbs ===
	float ambient_pulse = sin(t * chase_speed * 2.0) * 0.05 + 0.95;
	final_color *= ambient_pulse;

	// Vignette
	float vig = 1.0 - center_dist * 0.5;
	final_color *= vig;

	COLOR = vec4(final_color, 1.0);
}
