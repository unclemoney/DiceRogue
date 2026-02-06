shader_type canvas_item;
// Arcade Carpet - Geometric 90s mall/arcade carpet patterns
// Created for DiceRogue (Guhtzee)
// Inspired by iconic 90s arcade/bowling alley carpet designs

// Color system - expanded 5-color palette for authentic pattern variety
uniform vec4 colour_1 : source_color = vec4(0.06, 0.02, 0.12, 1.0);  // Deep purple-black base
uniform vec4 colour_2 : source_color = vec4(0.5, 0.0, 0.8, 1.0);     // Electric purple
uniform vec4 colour_3 : source_color = vec4(0.0, 0.75, 0.75, 1.0);   // Teal
uniform vec4 colour_4 : source_color = vec4(1.0, 0.2, 0.5, 1.0);     // Hot pink
uniform vec4 colour_5 : source_color = vec4(0.0, 0.9, 0.4, 1.0);     // Neon green accent

// Animation and appearance
uniform float scroll_speed : hint_range(0.0, 1.5) = 0.15;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 450.0;
uniform float tile_size : hint_range(5.0, 30.0) = 12.0;
uniform int pattern_style : hint_range(0, 2) = 0;
uniform float fabric_texture : hint_range(0.0, 1.0) = 0.25;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.4;

// Hash function for tile color randomization
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 23761.9134211);
}

// Diamond shape signed distance
float diamond_sdf(vec2 p, float size) {
	return abs(p.x) + abs(p.y) - size;
}

// Triangle shape
float triangle_sdf(vec2 p, float size) {
	p.y += size * 0.3;
	float k = sqrt(3.0);
	p.x = abs(p.x) - size;
	p.y = p.y + size / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	}
	p.x -= clamp(p.x, -2.0 * size, 0.0);
	return -length(p) * sign(p.y);
}

// Zigzag wave pattern
float zigzag(float x, float freq) {
	return abs(fract(x * freq) * 2.0 - 1.0);
}

// Star burst pattern
float starburst(vec2 p, float rays, float size) {
	float angle = atan(p.y, p.x);
	float r = length(p);
	float star = cos(angle * rays) * 0.5 + 0.5;
	star = smoothstep(size * 0.5, size, star * size / max(r, 0.001));
	return star;
}

// === Pattern generators ===

// Pattern 0: Classic diamond & zigzag (most common 90s carpet)
vec3 pattern_diamonds(vec2 uv, vec2 tile_id, vec2 tile_fract, float time_offset) {
	float h = hash(tile_id);
	float h2 = hash2(tile_id);

	// Background swirl per tile
	vec3 bg = mix(colour_1.rgb, colour_1.rgb * 1.5, h * 0.3);

	// Diamond shape in center
	float diamond = diamond_sdf(tile_fract - 0.5, 0.25);
	float diamond_mask = smoothstep(0.02, -0.02, diamond);

	// Zigzag border lanes
	float zz = zigzag(uv.y + time_offset, tile_size * 0.5) * 0.3;
	float lane = smoothstep(0.05, 0.0, abs(tile_fract.x - zz - 0.5) - 0.35);

	// Assign colors from palette based on tile hash
	vec3 diamond_col = colour_2.rgb;
	if (h > 0.66) {
		diamond_col = colour_3.rgb;
	} else if (h > 0.33) {
		diamond_col = colour_4.rgb;
	}

	vec3 lane_col = colour_5.rgb;
	if (h2 > 0.5) {
		lane_col = colour_3.rgb;
	}

	vec3 result = bg;
	result = mix(result, lane_col * 0.6, lane * 0.4);
	result = mix(result, diamond_col, diamond_mask);

	return result;
}

// Pattern 1: Starburst & circles (bowling alley style)
vec3 pattern_starbursts(vec2 uv, vec2 tile_id, vec2 tile_fract, float time_offset) {
	float h = hash(tile_id);
	float h2 = hash2(tile_id);

	vec3 bg = mix(colour_1.rgb, colour_1.rgb * 1.3, h2 * 0.4);

	// Starburst in alternating tiles
	vec2 center = tile_fract - 0.5;
	float star = starburst(center, 6.0, 0.3);

	// Concentric rings in other tiles
	float r = length(center);
	float rings = smoothstep(0.02, 0.0, abs(sin(r * 20.0)) - 0.8);

	// Choose which element based on tile position
	float is_star_tile = step(0.5, fract((tile_id.x + tile_id.y) * 0.5));

	vec3 star_col = mix(colour_2.rgb, colour_4.rgb, h);
	vec3 ring_col = mix(colour_3.rgb, colour_5.rgb, h2);

	vec3 result = bg;
	result = mix(result, star_col, star * is_star_tile);
	result = mix(result, ring_col, rings * (1.0 - is_star_tile) * 0.8);

	// Dot grid overlay
	vec2 dot_uv = fract(tile_fract * 3.0) - 0.5;
	float dot_pattern = smoothstep(0.15, 0.1, length(dot_uv));
	result += colour_2.rgb * dot_pattern * 0.15;

	return result;
}

// Pattern 2: Squiggly lines & triangles (Memphis design style)
vec3 pattern_memphis(vec2 uv, vec2 tile_id, vec2 tile_fract, float time_offset) {
	float h = hash(tile_id);
	float h2 = hash2(tile_id);

	vec3 bg = mix(colour_1.rgb, colour_1.rgb * 1.4, h * 0.3);

	// Squiggly sine lines
	float squiggle1 = sin(uv.y * tile_size * 2.0 + time_offset * 3.0 + h * 6.28) * 0.15;
	float squiggle_line = smoothstep(0.02, 0.0, abs(tile_fract.x - 0.5 - squiggle1) - 0.02);

	float squiggle2 = sin(uv.x * tile_size * 2.0 + time_offset * 2.0 + h2 * 6.28) * 0.15;
	float squiggle_line2 = smoothstep(0.02, 0.0, abs(tile_fract.y - 0.5 - squiggle2) - 0.02);

	// Small triangles scattered
	vec2 tri_center = tile_fract - 0.5;
	float tri = triangle_sdf(tri_center * 2.0, 0.3);
	float tri_mask = smoothstep(0.02, -0.02, tri);
	float show_tri = step(0.6, h); // Only some tiles get triangles

	// Color assignment
	vec3 squiggle_col1 = mix(colour_4.rgb, colour_3.rgb, h);
	vec3 squiggle_col2 = mix(colour_5.rgb, colour_2.rgb, h2);
	vec3 tri_col = mix(colour_2.rgb, colour_4.rgb, h2);

	vec3 result = bg;
	result = mix(result, squiggle_col1, squiggle_line * 0.8);
	result = mix(result, squiggle_col2, squiggle_line2 * 0.6);
	result = mix(result, tri_col, tri_mask * show_tri);

	return result;
}

void fragment() {
	// Pixelation effect
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	// Slow diagonal scroll animation
	float t = TIME * scroll_speed;
	vec2 scroll_uv = uv + vec2(t * 0.3, t * 0.2);

	// Tile coordinates
	vec2 scaled = scroll_uv * tile_size;
	vec2 tile_id = floor(scaled);
	vec2 tile_fract = fract(scaled);

	// Select pattern
	vec3 pattern_color = vec3(0.0);
	if (pattern_style == 0) {
		pattern_color = pattern_diamonds(scroll_uv, tile_id, tile_fract, t);
	} else if (pattern_style == 1) {
		pattern_color = pattern_starbursts(scroll_uv, tile_id, tile_fract, t);
	} else {
		pattern_color = pattern_memphis(scroll_uv, tile_id, tile_fract, t);
	}

	// === Fabric texture overlay ===
	// Woven texture using alternating scanlines
	float weave_h = sin(uv.y * screen_size.y * 2.0) * 0.5 + 0.5;
	float weave_v = sin(uv.x * screen_size.x * 2.0) * 0.5 + 0.5;
	float weave = weave_h * weave_v;
	pattern_color *= 1.0 - (weave * fabric_texture * 0.3);

	// === Subtle UV-reactive glow ===
	// Blacklight glow effect mimicking UV-reactive carpet dyes
	float glow_pulse = sin(TIME * 0.8) * 0.1 + 0.9;
	float glow_mask = max(pattern_color.r, max(pattern_color.g, pattern_color.b));
	glow_mask = smoothstep(0.3, 0.8, glow_mask);
	pattern_color += pattern_color * glow_mask * glow_amount * glow_pulse;

	// Slight vignette
	vec2 vig = abs(uv - 0.5) * 1.8;
	float vignette = 1.0 - dot(vig, vig) * 0.25;
	pattern_color *= vignette;

	COLOR = vec4(pattern_color, 1.0);
}
