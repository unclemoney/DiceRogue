shader_type canvas_item;
// Jazz Cup - Iconic 90s Solo Jazz paper cup design
// Created for DiceRogue (Guhtzee)
// Inspired by the famous teal splash & purple brush strokes on white paper cups (1991)
// Procedural recreation: layered sine/cosine swoosh curves with varying thickness

// Color system
uniform vec4 colour_1 : source_color = vec4(0.95, 0.95, 0.93, 1.0);  // Off-white background
uniform vec4 colour_2 : source_color = vec4(0.0, 0.75, 0.78, 1.0);   // Teal splash
uniform vec4 colour_3 : source_color = vec4(0.55, 0.0, 0.85, 1.0);   // Purple brush stroke

// Animation and appearance
uniform float drift_speed : hint_range(0.0, 1.0) = 0.08;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float swoosh_scale : hint_range(0.5, 3.0) = 1.0;
uniform float stroke_thickness : hint_range(0.5, 2.0) = 1.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;
uniform float speckle_amount : hint_range(0.0, 1.0) = 0.3;
uniform float teal_opacity : hint_range(0.5, 1.0) = 0.92;
uniform float purple_opacity : hint_range(0.5, 1.0) = 0.88;

// Simple hash for speckle texture (paint splatter effect)
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Smooth noise for organic brush edge
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractional Brownian Motion for natural brush edge
float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		val += amp * value_noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return val;
}

// Main teal swoosh shape - large sweeping curve
float teal_swoosh(vec2 uv, float t) {
	// Primary swoosh: large arc from bottom-left to upper-right
	float drift = t * drift_speed;
	vec2 p = uv * swoosh_scale;

	// Main curve: a wide sine arc
	float curve1 = sin(p.x * 2.5 - 1.2 + drift * 0.3) * 0.35 + 0.15;
	float dist1 = abs(p.y - curve1);
	float thickness1 = 0.12 * stroke_thickness;
	// Taper the swoosh: thicker in middle, thinner at edges
	float taper1 = smoothstep(0.0, 0.4, p.x) * smoothstep(1.0, 0.7, p.x);
	thickness1 *= (0.5 + taper1 * 0.8);
	// Add brush edge noise
	float edge_noise1 = fbm(p * 8.0 + vec2(drift * 0.5, 0.0)) * 0.04 * stroke_thickness;
	float swoosh1 = smoothstep(thickness1 + edge_noise1, thickness1 * 0.3 + edge_noise1, dist1);

	// Secondary upper teal swoosh: thinner, follows a higher arc
	float curve2 = sin(p.x * 3.0 - 0.5 + drift * 0.2) * 0.2 + 0.45;
	float dist2 = abs(p.y - curve2);
	float thickness2 = 0.06 * stroke_thickness;
	float taper2 = smoothstep(0.1, 0.5, p.x) * smoothstep(0.95, 0.6, p.x);
	thickness2 *= (0.4 + taper2 * 0.7);
	float edge_noise2 = fbm(p * 10.0 + vec2(0.0, drift * 0.4)) * 0.03 * stroke_thickness;
	float swoosh2 = smoothstep(thickness2 + edge_noise2, thickness2 * 0.2 + edge_noise2, dist2);

	// Third smaller teal accent near bottom
	float curve3 = sin(p.x * 4.0 + 0.8 + drift * 0.15) * 0.12 - 0.15;
	float dist3 = abs(p.y - curve3);
	float thickness3 = 0.04 * stroke_thickness;
	float taper3 = smoothstep(0.3, 0.6, p.x) * smoothstep(1.0, 0.8, p.x);
	thickness3 *= (0.3 + taper3 * 0.8);
	float edge_noise3 = fbm(p * 12.0 + vec2(drift, drift)) * 0.025 * stroke_thickness;
	float swoosh3 = smoothstep(thickness3 + edge_noise3, thickness3 * 0.15 + edge_noise3, dist3);

	return max(max(swoosh1, swoosh2), swoosh3);
}

// Purple brush strokes - thinner, more energetic
float purple_strokes(vec2 uv, float t) {
	float drift = t * drift_speed;
	vec2 p = uv * swoosh_scale;

	// Primary purple stroke: thinner, crosses through the teal swoosh
	float curve1 = sin(p.x * 3.5 + 0.4 + drift * 0.25) * 0.25 + 0.22;
	float dist1 = abs(p.y - curve1);
	float thickness1 = 0.035 * stroke_thickness;
	float taper1 = smoothstep(0.15, 0.45, p.x) * smoothstep(0.9, 0.55, p.x);
	thickness1 *= (0.3 + taper1 * 0.9);
	float edge_noise1 = fbm(p * 14.0 + vec2(drift * 0.7, 3.0)) * 0.02 * stroke_thickness;
	float stroke1 = smoothstep(thickness1 + edge_noise1, thickness1 * 0.15 + edge_noise1, dist1);

	// Secondary purple stroke: wild and thinner
	float curve2 = sin(p.x * 5.0 - 0.8 + drift * 0.35) * 0.15 + 0.05;
	float dist2 = abs(p.y - curve2);
	float thickness2 = 0.025 * stroke_thickness;
	float taper2 = smoothstep(0.25, 0.55, p.x) * smoothstep(0.85, 0.6, p.x);
	thickness2 *= (0.25 + taper2 * 0.85);
	float edge_noise2 = fbm(p * 16.0 + vec2(5.0, drift * 0.6)) * 0.018 * stroke_thickness;
	float stroke2 = smoothstep(thickness2 + edge_noise2, thickness2 * 0.1 + edge_noise2, dist2);

	return max(stroke1, stroke2);
}

void fragment() {
	// Pixelation effect - chunky retro pixels
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// Start with background color
	vec3 col = colour_1.rgb;

	// Paint speckle texture (subtle paper grain / paint splatter)
	float speckle = hash21(uv * 400.0);
	float speckle_mask = smoothstep(0.85, 0.95, speckle) * speckle_amount * 0.15;
	col -= vec3(speckle_mask);

	// Calculate swoosh shapes
	float teal = teal_swoosh(uv, t);
	float purple = purple_strokes(uv, t);

	// Layer teal splash (behind purple)
	col = mix(col, colour_2.rgb, teal * teal_opacity);

	// Add teal paint texture variation
	float teal_texture = fbm(uv * swoosh_scale * 20.0 + vec2(t * drift_speed * 0.3, 0.0));
	col = mix(col, col * (0.85 + teal_texture * 0.3), teal * 0.4);

	// Layer purple strokes on top
	col = mix(col, colour_3.rgb, purple * purple_opacity);

	// Add purple paint texture variation
	float purple_texture = fbm(uv * swoosh_scale * 25.0 + vec2(0.0, t * drift_speed * 0.2));
	col = mix(col, col * (0.8 + purple_texture * 0.4), purple * 0.35);

	// Subtle scanlines for retro feel
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.3;

	// Slight vignette
	vec2 vig_uv = uv - 0.5;
	float vignette = 1.0 - dot(vig_uv, vig_uv) * 0.3;
	col *= vignette;

	COLOR = vec4(col, 1.0);
}
