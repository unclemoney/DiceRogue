shader_type canvas_item;
// Holographic Energy Field - Sci-fi energy shield with scanlines & hex grid
// Created for DiceRogue (Guhtzee)
// For power-up card art overlays with animated hologram projection feel

uniform vec4 hologram_color : source_color = vec4(0.0, 0.85, 0.9, 1.0); // Teal energy
uniform vec4 secondary_color : source_color = vec4(0.7, 0.0, 1.0, 1.0); // Purple accent
uniform float energy_speed : hint_range(0.0, 3.0) = 1.5;
uniform float scanline_frequency : hint_range(5.0, 30.0) = 15.0;
uniform float grid_scale : hint_range(0.1, 1.0) = 0.4;
uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.5;
uniform float edge_glow_width : hint_range(0.0, 0.2) = 0.08;
uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;

// Hexagonal grid distance function
float hex_dist(vec2 p) {
	p = abs(p);
	float c = dot(p, normalize(vec2(1.0, 1.73)));
	c = max(c, p.x);
	return c;
}

// Simple noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	if (effect_strength <= 0.0) {
		COLOR = tex_color;
	} else {
		float t = TIME * energy_speed;

		// === Edge glow ===
		float edge_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		float edge_glow = smoothstep(edge_glow_width, 0.0, edge_dist);

		// Animate edge glow with flowing energy
		float edge_flow = sin(UV.y * 20.0 - t * 4.0) * 0.5 + 0.5;
		float edge_flow2 = sin(UV.x * 20.0 + t * 3.0) * 0.5 + 0.5;
		edge_glow *= 0.6 + 0.4 * edge_flow * edge_flow2;

		// === Scanline sweep (hologram projection) ===
		float scan_pos = fract(t * 0.4);
		float scan_line = smoothstep(0.04, 0.0, abs(UV.y - scan_pos)) * 0.6;

		// Horizontal scanlines (persistent)
		float h_scanlines = sin(UV.y * scanline_frequency * 6.28) * 0.5 + 0.5;
		h_scanlines = pow(h_scanlines, 4.0) * 0.3; // Sharp thin lines

		// === Hexagonal grid overlay ===
		vec2 hex_uv = UV * 20.0 * grid_scale;
		// Offset every other row
		float row = floor(hex_uv.y / 1.73);
		float row_offset = mod(row, 2.0) * 0.5;
		hex_uv.x += row_offset;

		vec2 hex_id = floor(hex_uv);
		vec2 hex_fract = fract(hex_uv) - 0.5;

		float hex_d = hex_dist(hex_fract);
		float hex_border = smoothstep(0.45, 0.42, hex_d); // Hex interior
		float hex_edge = smoothstep(0.42, 0.38, hex_d) - hex_border; // Just the border line

		// Animated hex glow - random cells pulse
		float hex_pulse = hash(hex_id);
		float hex_active = step(0.7, sin(t * 2.0 + hex_pulse * 6.28) * 0.5 + 0.5);
		float hex_brightness = hex_border * hex_active * 0.2;

		// === Color shimmer (energy fluctuation) ===
		float shimmer = sin(UV.x * 10.0 + UV.y * 8.0 + t * 3.0) * 0.5 + 0.5;
		shimmer *= sin(UV.y * 15.0 - t * 2.0) * 0.5 + 0.5;

		// Combine hologram effects
		vec3 holo_col = hologram_color.rgb;
		// Color shift toward secondary based on shimmer
		holo_col = mix(holo_col, secondary_color.rgb, shimmer * 0.4);

		// Build the hologram overlay
		float holo_intensity = 0.0;
		holo_intensity += edge_glow * 0.8;
		holo_intensity += scan_line;
		holo_intensity += h_scanlines;
		holo_intensity += hex_edge * 0.5;
		holo_intensity += hex_brightness;
		holo_intensity *= shimmer_strength;

		// Transparency modulation for shimmer
		float alpha_shimmer = sin(t * 1.5 + UV.y * 5.0) * 0.1;

		// Final composite - blend hologram over texture
		vec3 final_rgb = mix(tex_color.rgb, tex_color.rgb + holo_col * holo_intensity, effect_strength);
		float final_alpha = tex_color.a + (holo_intensity * 0.15 + alpha_shimmer) * effect_strength;
		final_alpha = min(final_alpha, 1.0);

		COLOR = vec4(final_rgb, final_alpha);
	}
}
