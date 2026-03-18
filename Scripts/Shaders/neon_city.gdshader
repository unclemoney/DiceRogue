shader_type canvas_item;
// Neon City - Retro pixel-art scrolling cityscape silhouette
// Created for DiceRogue (Guhtzee)
// Inspired by 80s/90s cyberpunk and synthwave cityscapes: neon signs,
// parallax building silhouettes against a gradient night sky

// Color system
uniform vec4 colour_1 : source_color = vec4(0.02, 0.01, 0.08, 1.0);  // Sky top (deep dark)
uniform vec4 colour_2 : source_color = vec4(0.12, 0.04, 0.25, 1.0);  // Sky bottom (purple horizon)
uniform vec4 colour_3 : source_color = vec4(0.04, 0.03, 0.06, 1.0);  // Building silhouette
uniform vec4 neon_color_1 : source_color = vec4(0.0, 0.9, 0.85, 1.0);  // Teal neon
uniform vec4 neon_color_2 : source_color = vec4(0.85, 0.0, 1.0, 1.0);  // Purple neon
uniform vec4 neon_color_3 : source_color = vec4(1.0, 0.2, 0.5, 1.0);   // Pink neon

// Animation and appearance
uniform float scroll_speed : hint_range(0.0, 1.0) = 0.12;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 450.0;
uniform float building_density : hint_range(5.0, 25.0) = 12.0;
uniform float neon_flicker_speed : hint_range(0.5, 5.0) = 2.0;
uniform float neon_glow_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float star_density : hint_range(50.0, 500.0) = 150.0;
uniform float horizon_glow : hint_range(0.0, 1.0) = 0.5;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.12;

// Hash functions
float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

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

// Generate building height for a given x position
float building_height(float x, float density, float seed) {
	float id = floor(x * density);
	float h = hash11(id * 7.0 + seed) * 0.4 + 0.15;
	// Some buildings are taller (skyscrapers)
	if (hash11(id * 13.0 + seed + 3.0) > 0.75) {
		h += 0.15;
	}
	return h;
}

// Building edge: determine if we're at a building boundary
float building_edge(float x, float density, float seed) {
	float scaled = x * density;
	float cell_pos = fract(scaled);
	// Narrow gap between buildings
	float gap = 0.03 + hash11(floor(scaled) * 11.0 + seed) * 0.04;
	if (cell_pos < gap || cell_pos > (1.0 - gap)) {
		return 0.0; // Gap between buildings
	}
	return 1.0;
}

// Building silhouette layer
// Returns: 0.0 = sky visible, 1.0 = inside building
float building_layer(vec2 uv, float speed_mult, float density, float seed, float base_height) {
	float x = uv.x + TIME * scroll_speed * speed_mult;
	float h = building_height(x, density, seed);
	float edge = building_edge(x, density, seed);

	// Building top line
	float y_threshold = 1.0 - base_height - h;
	float in_building = step(y_threshold, uv.y) * edge;

	return in_building;
}

// Window pattern on buildings
float window_pattern(vec2 uv, float density, float speed_mult, float seed) {
	float x = uv.x + TIME * scroll_speed * speed_mult;
	vec2 wuv = vec2(x, uv.y);

	// Window grid
	vec2 grid = fract(wuv * vec2(density * 4.0, 20.0));
	float window = step(0.2, grid.x) * step(grid.x, 0.7) * step(0.15, grid.y) * step(grid.y, 0.75);

	// Some windows are lit, some dark
	vec2 win_id = floor(wuv * vec2(density * 4.0, 20.0));
	float lit = step(0.55, hash21(win_id + seed));

	// Flickering: some windows turn on/off
	float flicker = step(0.92, sin(TIME * neon_flicker_speed * hash11(win_id.x * 3.0 + win_id.y * 7.0) + hash11(win_id.y * 5.0) * 6.0) * 0.5 + 0.5);
	lit = max(lit, flicker * 0.3);

	return window * lit;
}

// Neon sign on a building
float neon_sign(vec2 uv, float density, float speed_mult, float seed) {
	float x = uv.x + TIME * scroll_speed * speed_mult;
	float building_id = floor(x * density);

	// Only some buildings have neon signs
	if (hash11(building_id * 17.0 + seed) > 0.35) return 0.0;

	// Sign position within building
	float bx = fract(x * density);
	float sign_left = 0.15 + hash11(building_id * 7.0 + seed + 10.0) * 0.2;
	float sign_right = sign_left + 0.2 + hash11(building_id * 11.0 + seed + 20.0) * 0.3;
	float sign_y = 1.0 - (0.35 + hash11(building_id * 3.0 + seed) * 0.3);
	float sign_height = 0.03 + hash11(building_id * 9.0 + seed + 5.0) * 0.03;

	float in_sign_x = step(sign_left, bx) * step(bx, sign_right);
	float in_sign_y = step(sign_y, uv.y) * step(uv.y, sign_y + sign_height);

	// Flicker effect
	float flicker = 0.7 + 0.3 * sin(TIME * neon_flicker_speed * (1.0 + hash11(building_id * 5.0 + seed) * 2.0));
	// Occasional full off-blink
	float blink = step(0.05, fract(sin(TIME * neon_flicker_speed * 0.3 + building_id) * 43758.5453));

	return in_sign_x * in_sign_y * flicker * blink;
}

// Stars in the sky
float stars(vec2 uv) {
	vec2 star_uv = uv * star_density;
	vec2 star_id = floor(star_uv);
	vec2 star_cell = fract(star_uv) - 0.5;

	float rand = hash21(star_id);
	if (rand > 0.04) return 0.0; // Only 4% of cells have stars

	// Star position jitter
	vec2 offset = hash22(star_id + 100.0) * 0.8 - 0.4;
	float dist = length(star_cell - offset);

	// Star size
	float size = 0.02 + hash11(star_id.x * 7.0 + star_id.y * 3.0) * 0.03;

	// Twinkle
	float twinkle = 0.5 + 0.5 * sin(TIME * (1.0 + hash11(star_id.x + star_id.y * 5.0) * 3.0) + hash11(star_id.x * 3.0) * 6.283);

	return smoothstep(size, 0.0, dist) * twinkle;
}

void fragment() {
	// Pixelation effect - chunky retro pixels
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// === Sky gradient ===
	// Top = colour_1 (dark), bottom = colour_2 (purple horizon)
	float sky_blend = uv.y;
	vec3 col = mix(colour_1.rgb, colour_2.rgb, sky_blend * sky_blend);

	// Horizon glow band
	float glow_y = smoothstep(0.7, 1.0, uv.y);
	vec3 glow_col = mix(neon_color_2.rgb, neon_color_1.rgb, 0.3);
	col += glow_col * glow_y * horizon_glow * 0.3;

	// === Stars ===
	float star = stars(uv);
	vec3 star_col = mix(vec3(1.0), neon_color_1.rgb, 0.2);
	col += star_col * star * 0.8;

	// === Building layers (back to front, far to near) ===

	// Layer 3: Far background buildings (darkest, slowest)
	float b3 = building_layer(uv, 0.3, building_density * 0.6, 42.0, 0.0);
	vec3 b3_col = colour_3.rgb * 0.6;
	col = mix(col, b3_col, b3 * 0.85);
	// Faint window glow on far buildings
	float w3 = window_pattern(uv, building_density * 0.6, 0.3, 42.0) * b3;
	col += vec3(0.4, 0.35, 0.2) * w3 * 0.15;

	// Layer 2: Mid buildings
	float b2 = building_layer(uv, 0.6, building_density * 0.8, 99.0, -0.05);
	vec3 b2_col = colour_3.rgb * 0.8;
	col = mix(col, b2_col, b2 * 0.9);
	// Windows on mid buildings
	float w2 = window_pattern(uv, building_density * 0.8, 0.6, 99.0) * b2;
	vec3 w2_color = mix(vec3(0.6, 0.5, 0.2), neon_color_1.rgb * 0.3, 0.3);
	col += w2_color * w2 * 0.25;
	// Neon signs on mid buildings
	float n2 = neon_sign(uv, building_density * 0.8, 0.6, 99.0) * b2;
	float n2_id = floor((uv.x + TIME * scroll_speed * 0.6) * building_density * 0.8);
	vec3 n2_col = neon_color_1.rgb;
	if (hash11(n2_id * 5.0 + 99.0) > 0.5) {
		n2_col = neon_color_2.rgb;
	}
	col += n2_col * n2 * neon_glow_intensity * 0.5;

	// Layer 1: Foreground buildings (nearest, fastest, darkest silhouette)
	float b1 = building_layer(uv, 1.0, building_density, 7.0, -0.12);
	vec3 b1_col = colour_3.rgb;
	col = mix(col, b1_col, b1 * 0.95);
	// Bright windows on foreground
	float w1 = window_pattern(uv, building_density, 1.0, 7.0) * b1;
	vec3 w1_color = mix(vec3(0.8, 0.7, 0.3), neon_color_1.rgb * 0.5, 0.4);
	col += w1_color * w1 * 0.35;
	// Neon signs on foreground buildings
	float n1 = neon_sign(uv, building_density, 1.0, 7.0) * b1;
	float n1_id = floor((uv.x + TIME * scroll_speed) * building_density);
	vec3 n1_col = neon_color_1.rgb;
	float n1_color_pick = hash11(n1_id * 5.0 + 7.0);
	if (n1_color_pick < 0.33) {
		n1_col = neon_color_1.rgb;
	} else if (n1_color_pick < 0.66) {
		n1_col = neon_color_2.rgb;
	} else {
		n1_col = neon_color_3.rgb;
	}
	col += n1_col * n1 * neon_glow_intensity * 0.7;
	// Neon glow bleed around signs
	float n1_glow_x = neon_sign(uv + vec2(0.005, 0.0), building_density, 1.0, 7.0) * b1;
	float n1_glow_y = neon_sign(uv + vec2(0.0, 0.005), building_density, 1.0, 7.0) * b1;
	float n1_glow = max(n1_glow_x, n1_glow_y);
	col += n1_col * max(n1_glow - n1, 0.0) * neon_glow_intensity * 0.3;

	// === Ground line ===
	float ground = smoothstep(0.98, 1.0, uv.y);
	col = mix(col, colour_3.rgb * 1.2, ground);

	// === CRT scanlines ===
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.4;

	// Vignette
	vec2 vig_uv = uv - 0.5;
	float vignette = 1.0 - dot(vig_uv, vig_uv) * 0.4;
	col *= vignette;

	COLOR = vec4(col, 1.0);
}
