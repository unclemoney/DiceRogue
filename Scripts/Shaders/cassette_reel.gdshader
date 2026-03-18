shader_type canvas_item;
// Cassette Reel - 80s Cassette Tape / Walkman Chrome
// Created for DiceRogue (Guhtzee)
// Top-down view of a cassette tape with spinning reels and iridescent tape
// Inspired by the golden age of the Walkman and mixtapes (1984-1989)

// Color system
uniform vec4 colour_1 : source_color = vec4(0.12, 0.12, 0.14, 1.0);  // Dark shell plastic
uniform vec4 colour_2 : source_color = vec4(0.25, 0.12, 0.06, 1.0);  // Brown magnetic tape
uniform vec4 colour_3 : source_color = vec4(0.78, 0.80, 0.83, 1.0);  // Chrome/silver metallic
uniform vec4 colour_4 : source_color = vec4(0.92, 0.88, 0.75, 1.0);  // Cream label area
uniform vec4 colour_5 : source_color = vec4(0.9, 0.1, 0.1, 1.0);     // Red accents / REC LED

// Controls
uniform float reel_speed : hint_range(0.2, 3.0) = 1.2;
uniform float tape_shimmer : hint_range(0.0, 1.0) = 0.7;
uniform float iridescence_amount : hint_range(0.0, 1.0) = 0.6;
uniform float recording_blink : hint_range(0.0, 1.0) = 0.8;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;

// SDF rounded rectangle
float sdf_roundbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// SDF circle
float sdf_circle(vec2 p, float r) {
	return length(p) - r;
}

// Rotate 2D
vec2 rotate2d(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// Hash
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Thin-film iridescence approximation
vec3 iridescence(float angle, float thickness) {
	// Simulate thin-film interference colors
	float t = thickness * 2.0;
	vec3 col;
	col.r = 0.5 + 0.5 * cos(6.283 * (t + angle * 0.3 + 0.0));
	col.g = 0.5 + 0.5 * cos(6.283 * (t + angle * 0.3 + 0.33));
	col.b = 0.5 + 0.5 * cos(6.283 * (t + angle * 0.3 + 0.67));
	return col;
}

void fragment() {
	// Pixelation
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	// Aspect correction - keep 1:0.62 cassette ratio
	float aspect = screen_size.x / screen_size.y;
	vec2 p = uv - 0.5;
	p.x *= aspect;

	float t = TIME;

	// Background (outside cassette)
	vec3 col = vec3(0.08, 0.06, 0.1);

	// === Cassette Shell Outline ===
	float shell_w = 0.35;
	float shell_h = 0.22;
	float shell_r = 0.03;
	float shell_d = sdf_roundbox(p, vec2(shell_w, shell_h), shell_r);

	if (shell_d < 0.01) {
		// Inside the shell
		float shell_fill = smoothstep(0.003, -0.003, shell_d);
		vec3 shell_col = colour_1.rgb;

		// Subtle plastic texture
		float plastic_grain = hash21(floor(uv * 300.0)) * 0.02;
		shell_col += plastic_grain;

		col = mix(col, shell_col, shell_fill);

		// Shell edge highlight (chrome trim)
		float edge = smoothstep(0.006, 0.002, abs(shell_d));
		col = mix(col, colour_3.rgb, edge * 0.5);
	}

	// === Label Area (upper portion) ===
	vec2 label_center = vec2(0.0, -0.07);
	float label_w = 0.30;
	float label_h = 0.08;
	float label_d = sdf_roundbox(p - label_center, vec2(label_w, label_h), 0.01);

	if (label_d < 0.003 && shell_d < 0.0) {
		float label_fill = smoothstep(0.002, -0.002, label_d);
		vec3 label_col = colour_4.rgb;

		// Ruled lines on label
		float lines = abs(sin((p.y - label_center.y) * 120.0));
		lines = smoothstep(0.3, 0.4, lines);
		label_col *= 0.95 + lines * 0.05;

		// Label border
		float label_border = smoothstep(0.003, 0.001, abs(label_d));
		label_col = mix(label_col, colour_1.rgb, label_border * 0.5);

		col = mix(col, label_col, label_fill);
	}

	// === Tape Window (center - where tape is visible) ===
	vec2 window_center = vec2(0.0, 0.065);
	float window_w = 0.24;
	float window_h = 0.06;
	float window_d = sdf_roundbox(p - window_center, vec2(window_w, window_h), 0.015);

	if (window_d < 0.003 && shell_d < 0.0) {
		float window_fill = smoothstep(0.002, -0.002, window_d);

		// Dark tape interior
		vec3 tape_col = colour_2.rgb * 0.5;

		// Tape surface: moving horizontal streaks between reels
		float tape_x = p.x;

		// Tape is only visible between the reels (not behind them)
		float left_reel_x = -0.13;
		float right_reel_x = 0.13;
		float tape_mask = smoothstep(left_reel_x + 0.055, left_reel_x + 0.07, tape_x) * smoothstep(right_reel_x - 0.055, right_reel_x - 0.07, -tape_x);

		if (tape_mask > 0.01) {
			// Moving tape texture
			float tape_scroll = t * reel_speed * 0.5;
			float tape_streak = sin((p.x + tape_scroll) * 200.0 + p.y * 50.0);
			tape_streak = tape_streak * 0.5 + 0.5;
			tape_col = colour_2.rgb * (0.7 + tape_streak * 0.3 * tape_shimmer);

			// Iridescent rainbow (tape surface acts like thin film)
			float view_angle = atan(p.y - window_center.y, p.x) + t * 0.2;
			float film_thickness = (p.x + 0.3) * 1.5 + sin(t * 0.5) * 0.2;
			vec3 iri = iridescence(view_angle, film_thickness);
			tape_col = mix(tape_col, iri * 0.4 + tape_col * 0.6, iridescence_amount * tape_mask);
		}

		// Window frame edge
		float window_edge = smoothstep(0.004, 0.001, abs(window_d));
		tape_col = mix(tape_col, colour_1.rgb * 0.3, window_edge);

		col = mix(col, tape_col, window_fill);
	}

	// === Reel Hubs (two spinning reels) ===
	float reel_r = 0.045;
	vec2 reel_positions[2];
	reel_positions[0] = window_center + vec2(-0.13, 0.0);  // Left (supply) reel
	reel_positions[1] = window_center + vec2(0.13, 0.0);   // Right (take-up) reel

	for (int i = 0; i < 2; i++) {
		vec2 reel_p = p - reel_positions[i];
		float reel_d = length(reel_p);

		if (reel_d < reel_r + 0.01) {
			// Reel body (dark hub)
			float reel_body = smoothstep(reel_r + 0.002, reel_r - 0.002, reel_d);

			// Rotation speed: take-up reel spins faster
			float spin_speed = reel_speed;
			if (i == 1) {
				spin_speed = reel_speed * 1.4;
			}
			float angle = t * spin_speed;

			// Spoke pattern (6 spokes)
			vec2 rotated = rotate2d(reel_p, angle);
			float spoke_angle = atan(rotated.y, rotated.x);
			float spokes = abs(sin(spoke_angle * 3.0));
			spokes = smoothstep(0.12, 0.18, spokes);

			// Hub color with spokes
			vec3 hub_col = colour_1.rgb * 0.5;
			hub_col = mix(hub_col, colour_1.rgb * 0.8, spokes * step(0.012, reel_d));

			// Center hole (chrome)
			float center_d = smoothstep(0.012, 0.008, reel_d);
			hub_col = mix(hub_col, colour_3.rgb, center_d);

			// Chrome ring at edge
			float rim = smoothstep(0.004, 0.001, abs(reel_d - reel_r));
			hub_col = mix(hub_col, colour_3.rgb * 0.9, rim * 0.6);

			// Specular highlight sweeping across hub
			float spec_angle = atan(reel_p.y, reel_p.x);
			float spec = pow(max(0.0, cos(spec_angle - t * 0.5)), 12.0) * 0.3;
			hub_col += colour_3.rgb * spec;

			col = mix(col, hub_col, reel_body);
		}
	}

	// === Screw Holes (4 corners) ===
	vec2 screw_offsets[4];
	screw_offsets[0] = vec2(-0.30, -0.17);
	screw_offsets[1] = vec2(0.30, -0.17);
	screw_offsets[2] = vec2(-0.30, 0.17);
	screw_offsets[3] = vec2(0.30, 0.17);

	for (int s = 0; s < 4; s++) {
		vec2 screw_p = p - screw_offsets[s];
		float screw_d = length(screw_p);

		if (screw_d < 0.015 && shell_d < 0.0) {
			float screw_fill = smoothstep(0.012, 0.008, screw_d);
			vec3 screw_col = colour_3.rgb * 0.8;

			// Phillips head cross
			vec2 rot_screw = rotate2d(screw_p, 0.0);
			float cross = min(abs(rot_screw.x), abs(rot_screw.y));
			float phillips = smoothstep(0.002, 0.001, cross) * step(screw_d, 0.008);
			screw_col = mix(screw_col, colour_1.rgb, phillips * 0.5);

			col = mix(col, screw_col, screw_fill);
		}
	}

	// === Recording LED ===
	vec2 led_pos = vec2(-0.28, -0.18);
	float led_d = length(p - led_pos);
	if (led_d < 0.01 && shell_d < 0.0) {
		float blink = step(0.5, sin(t * 2.0)) * recording_blink;
		float led_glow = smoothstep(0.006, 0.002, led_d);
		vec3 led_col = colour_5.rgb * (0.2 + blink * 0.8);
		col = mix(col, led_col, led_glow);

		// LED glow halo
		float halo = exp(-led_d * led_d * 8000.0) * blink * 0.3;
		col += colour_5.rgb * halo;
	}

	// === Tape Guide Pins (small chrome cylinders on either side of window) ===
	vec2 pin_positions[2];
	pin_positions[0] = window_center + vec2(-0.20, 0.0);
	pin_positions[1] = window_center + vec2(0.20, 0.0);

	for (int pin = 0; pin < 2; pin++) {
		float pin_d = length(p - pin_positions[pin]);
		if (pin_d < 0.015 && shell_d < 0.0) {
			float pin_fill = smoothstep(0.008, 0.005, pin_d);
			vec3 pin_col = colour_3.rgb * 0.9;
			// Specular dot
			pin_col += vec3(0.2) * smoothstep(0.004, 0.002, pin_d);
			col = mix(col, pin_col, pin_fill);
		}
	}

	// Scanlines
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.3;

	// Slight vignette
	vec2 vig = uv - 0.5;
	col *= 1.0 - dot(vig, vig) * 0.3;

	COLOR = vec4(col, 1.0);
}
