shader_type canvas_item;
// Pinball Machine - 80s Arcade Pinball Playfield
// Created for DiceRogue (Guhtzee)
// Top-down view of a pinball playfield with bumpers, rails, arrows, and flashing inserts
// Inspired by classic 80s pins like Gorgar, Black Knight, High Speed (1984-1989)

// Color system - classic pinball palette
uniform vec4 colour_1 : source_color = vec4(0.04, 0.02, 0.15, 1.0);  // Deep playfield blue
uniform vec4 colour_2 : source_color = vec4(1.0, 0.15, 0.1, 1.0);    // Red bumper
uniform vec4 colour_3 : source_color = vec4(1.0, 0.75, 0.0, 1.0);    // Orange/gold bumper
uniform vec4 colour_4 : source_color = vec4(0.75, 0.78, 0.82, 1.0);  // Chrome silver rails
uniform vec4 colour_5 : source_color = vec4(0.0, 0.95, 0.3, 1.0);    // Green inserts/arrows

// Controls
uniform float bumper_density : hint_range(3.0, 8.0) = 5.0;
uniform float flash_speed : hint_range(0.5, 3.0) = 1.5;
uniform float rail_count : hint_range(2.0, 6.0) = 4.0;
uniform float glow_intensity : hint_range(0.5, 3.0) = 1.8;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;

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

// SDF circle
float sdf_circle(vec2 p, float r) {
	return length(p) - r;
}

// SDF rounded box
float sdf_roundbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// SDF equilateral triangle (used for arrow heads)
float sdf_triangle(vec2 p, float r) {
	float k = sqrt(3.0);
	p.x = abs(p.x) - r;
	p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	}
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}

// Chrome specular highlight (fake metallic reflection)
float chrome_highlight(vec2 p, vec2 normal, float time) {
	vec2 light_dir = normalize(vec2(sin(time * 0.3), cos(time * 0.2)));
	float spec = max(0.0, dot(normal, light_dir));
	return pow(spec, 8.0) * 0.6;
}

void fragment() {
	// Pixelation
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// Playfield background with subtle radial gradient
	vec2 center_off = uv - vec2(0.5, 0.55);
	float radial = dot(center_off, center_off);
	vec3 col = colour_1.rgb + vec3(0.02, 0.01, 0.04) * (1.0 - radial * 2.0);

	// Playfield art: subtle diamond pattern printed on surface
	float diamond = abs(fract(uv.x * 12.0) - 0.5) + abs(fract(uv.y * 12.0) - 0.5);
	col += colour_1.rgb * 0.15 * smoothstep(0.55, 0.50, diamond);

	// === Chrome Rails (curved guide rails) ===
	float total_rails = floor(rail_count);
	for (float i = 0.0; i < 6.0; i++) {
		if (i >= total_rails) break;

		// Each rail is a curved path (arc segment)
		float rail_y_start = 0.15 + hash11(i * 7.0 + 1.0) * 0.6;
		float rail_x_center = 0.2 + hash11(i * 11.0 + 3.0) * 0.6;
		float rail_radius = 0.15 + hash11(i * 13.0 + 5.0) * 0.2;
		float rail_arc_start = hash11(i * 17.0 + 7.0) * 3.14159;
		float rail_arc_end = rail_arc_start + 1.5 + hash11(i * 19.0 + 9.0) * 1.5;

		vec2 rail_center = vec2(rail_x_center, rail_y_start);
		vec2 to_center = uv - rail_center;
		float dist_to_center = length(to_center);
		float angle_to_point = atan(to_center.y, to_center.x);

		// Arc distance
		float ring_dist = abs(dist_to_center - rail_radius);
		float rail_w = 0.006;

		// Angle mask for arc segment
		float angle_norm = angle_to_point;
		if (angle_norm < 0.0) {
			angle_norm += 6.283;
		}
		float arc_start = mod(rail_arc_start, 6.283);
		float arc_end = mod(rail_arc_end, 6.283);

		float angle_mask = 1.0;
		if (arc_start < arc_end) {
			if (angle_norm < arc_start || angle_norm > arc_end) {
				angle_mask = 0.0;
			}
		} else {
			if (angle_norm < arc_start && angle_norm > arc_end) {
				angle_mask = 0.0;
			}
		}

		float rail = smoothstep(rail_w, rail_w * 0.3, ring_dist) * angle_mask;

		if (rail > 0.01) {
			// Chrome coloring with specular
			vec2 rail_normal = normalize(to_center);
			float spec = chrome_highlight(to_center, rail_normal, t);
			vec3 rail_col = colour_4.rgb + vec3(spec);
			col = mix(col, rail_col, rail);
		}
	}

	// === Round Bumpers ===
	{
		vec2 grid_uv = uv * bumper_density;
		vec2 cell_id = floor(grid_uv);
		vec2 cell_fract = fract(grid_uv) - 0.5;

		for (int dx = -1; dx <= 1; dx++) {
			for (int dy = -1; dy <= 1; dy++) {
				vec2 neighbor = vec2(float(dx), float(dy));
				vec2 id = cell_id + neighbor;

				// Only some cells have bumpers
				float present = hash21(id);
				if (present > 0.35) continue;

				// Skip bumpers too close to edges
				vec2 world_pos = id / bumper_density;
				if (world_pos.x < 0.1 || world_pos.x > 0.9 || world_pos.y < 0.1 || world_pos.y > 0.9) continue;

				vec2 offset = hash22(id + 100.0) * 0.3 - 0.15;
				vec2 p = cell_fract - neighbor - offset;
				float bumper_size = 0.08 + hash21(id + 5.0) * 0.06;

				float d = sdf_circle(p, bumper_size);

				// Activation flash: each bumper fires at different times
				float fire_phase = hash21(id + 10.0) * 6.283;
				float fire_speed = 1.0 + hash21(id + 15.0) * 2.0;
				float activation = pow(max(0.0, sin(t * flash_speed * fire_speed + fire_phase)), 8.0);

				if (d < 0.02) {
					// Bumper body
					vec3 bumper_col = colour_2.rgb;
					if (hash21(id + 20.0) > 0.5) {
						bumper_col = colour_3.rgb;
					}

					// Bright flash on activation
					bumper_col = mix(bumper_col, vec3(1.0), activation * 0.7);

					// Cap ring (chrome)
					float ring = smoothstep(0.003, 0.0, abs(d + bumper_size * 0.2));
					vec3 cap_col = mix(bumper_col, colour_4.rgb, ring);

					// Center dot
					float center_dot = smoothstep(bumper_size * 0.3, bumper_size * 0.2, length(p));
					cap_col = mix(cap_col, vec3(1.0), center_dot * activation);

					float fill = smoothstep(0.005, -0.005, d);
					col = mix(col, cap_col, fill);

					// Glow on activation
					float glow = exp(-d * d * 600.0) * activation * glow_intensity;
					col += bumper_col * glow * 0.4;
				}
			}
		}
	}

	// === Arrow Lane Inserts ===
	// 3 lanes at bottom pointing up (classic ball-return arrows)
	for (int lane = 0; lane < 3; lane++) {
		float lane_x = 0.3 + float(lane) * 0.2;
		for (int arrow = 0; arrow < 3; arrow++) {
			float arrow_y = 0.82 - float(arrow) * 0.06;
			vec2 arrow_pos = vec2(lane_x, arrow_y);
			vec2 p = uv - arrow_pos;

			// Flip y so triangle points up
			p.y = -p.y;

			float d = sdf_triangle(p, 0.018);
			float fill = smoothstep(0.003, -0.003, d);

			// Chase animation up the lane
			float chase_phase = float(arrow) * 0.4 + float(lane) * 1.5;
			float on = step(0.5, fract(t * flash_speed * 0.8 + chase_phase));

			vec3 arrow_col = colour_5.rgb * (0.3 + on * 0.7);

			col = mix(col, arrow_col, fill);

			// Glow for active arrows
			float glow = exp(-d * d * 3000.0) * on * glow_intensity * 0.3;
			col += colour_5.rgb * glow;
		}
	}

	// === Star Rollover Inserts ===
	// Scattered small star/diamond inserts that light up
	for (int s = 0; s < 5; s++) {
		float sx = 0.15 + hash11(float(s) * 7.0 + 50.0) * 0.7;
		float sy = 0.2 + hash11(float(s) * 11.0 + 50.0) * 0.45;
		vec2 star_pos = vec2(sx, sy);
		vec2 p = uv - star_pos;

		// Diamond shape (rotated square)
		vec2 rp = vec2(abs(p.x) + abs(p.y), abs(p.x - p.y));
		float d = rp.x - 0.012;
		float fill = smoothstep(0.002, -0.002, d);

		// Blink pattern
		float blink = step(0.5, sin(t * flash_speed * 1.5 + float(s) * 1.3));
		vec3 star_col = colour_3.rgb * (0.3 + blink * 0.7);

		col = mix(col, star_col, fill);
	}

	// === Playfield border ===
	float border_dist = sdf_roundbox(uv - vec2(0.5), vec2(0.46, 0.46), 0.03);
	float border = smoothstep(0.005, 0.0, abs(border_dist)) * 0.6;
	col = mix(col, colour_4.rgb, border);

	// === Tilt flash (occasional red pulse) ===
	float tilt_flash = pow(max(0.0, sin(t * 0.3 + 1.5)), 30.0) * 0.15;
	col += vec3(tilt_flash, 0.0, 0.0);

	// Scanlines
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.3;

	// Slight vignette
	vec2 vig = uv - 0.5;
	col *= 1.0 - dot(vig, vig) * 0.4;

	COLOR = vec4(col, 1.0);
}
