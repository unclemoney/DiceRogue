shader_type canvas_item;
// Plasma Screen - Classic demoscene plasma effect with organic color blobs
// Created for DiceRogue (Guhtzee)
// Inspired by Amiga/C64 demoscene plasma effects (1988-1992 era)

// Color system - matching game's purple/teal palette
uniform vec4 colour_1 : source_color = vec4(0.08, 0.04, 0.15, 1.0);  // Deep purple base
uniform vec4 colour_2 : source_color = vec4(0.6, 0.0, 0.9, 1.0);     // Vivid magenta/purple
uniform vec4 colour_3 : source_color = vec4(0.0, 0.75, 0.8, 1.0);    // Teal/cyan highlight

// Animation and appearance
uniform float plasma_speed : hint_range(0.0, 2.0) = 0.4;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float plasma_scale : hint_range(0.5, 3.0) = 1.5;
uniform float color_cycle_speed : hint_range(0.0, 3.0) = 0.8;
uniform float contrast : hint_range(0.5, 2.0) = 1.2;
uniform float warp_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	// Pixelation effect - chunky retro pixels
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME * plasma_speed;

	// Scale UV for pattern density
	vec2 p = uv * plasma_scale * 6.0;

	// === Multi-frequency sine plasma layers ===
	// Layer 1: Horizontal wave with time displacement
	float v1 = sin(p.x + t * 1.3);

	// Layer 2: Vertical wave with opposite phase
	float v2 = sin(p.y + t * 0.9);

	// Layer 3: Diagonal ripple (classic demoscene technique)
	float v3 = sin(p.x + p.y + t * 0.7);

	// Layer 4: Radial pulse from center
	float cx = p.x - plasma_scale * 3.0;
	float cy = p.y - plasma_scale * 3.0;
	float v4 = sin(sqrt(cx * cx + cy * cy + 1.0) - t * 1.1);

	// Layer 5: Swirling interference pattern
	float v5 = sin(p.x * sin(t * 0.3) + p.y * cos(t * 0.5));

	// Layer 6: Warped radial ring
	float angle = atan(cy, cx);
	float radius = length(vec2(cx, cy));
	float v6 = sin(radius * 2.0 - t + angle * 2.0);

	// Combine all layers into interference pattern
	float plasma = v1 + v2 + v3 + v4 + v5 * warp_intensity + v6 * warp_intensity;
	plasma *= 0.5; // Normalize roughly to -1..1 range

	// === Color mapping with smooth 3-color gradient ===
	// Shift plasma into color cycling domain
	float color_phase = plasma * contrast + t * color_cycle_speed;

	// Create smooth 3-way color blend using sine waves offset by 2PI/3
	float c1_weight = max(0.0, sin(color_phase) * 0.5 + 0.5);
	float c2_weight = max(0.0, sin(color_phase + 2.094) * 0.5 + 0.5);  // +2PI/3
	float c3_weight = max(0.0, sin(color_phase + 4.189) * 0.5 + 0.5);  // +4PI/3

	// Normalize weights
	float total = c1_weight + c2_weight + c3_weight + 0.001;
	c1_weight /= total;
	c2_weight /= total;
	c3_weight /= total;

	vec3 plasma_color = colour_1.rgb * c1_weight + colour_2.rgb * c2_weight + colour_3.rgb * c3_weight;

	// Add brightness variation from plasma intensity
	float brightness = 0.8 + 0.4 * sin(plasma * 3.14159);
	plasma_color *= brightness;

	// === Retro post-processing ===
	// Subtle scanlines for CRT feel
	float scanline = sin(uv.y * screen_size.y * 1.5) * 0.5 + 0.5;
	plasma_color *= 1.0 - (scanline * scanline_strength);

	// Slight vignette
	vec2 vig_dist = abs(uv - 0.5) * 1.5;
	float vignette = 1.0 - dot(vig_dist, vig_dist) * 0.4;
	plasma_color *= vignette;

	COLOR = vec4(plasma_color, 1.0);
}
