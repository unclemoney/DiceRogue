shader_type canvas_item;
// Neon Raindrop - Teal-to-pink gradient with procedural 3D water droplets
// Created for DiceRogue (Guhtzee)
// Inspired by late 80s / early 90s airbrush Trapper Keeper art
// Features parallax droplet layers, fake refraction, specular highlights, drip streaks

// Color system - neon gradient palette
uniform vec4 colour_1 : source_color = vec4(0.0, 0.75, 0.72, 1.0);   // Teal gradient start
uniform vec4 colour_2 : source_color = vec4(0.85, 0.15, 0.65, 1.0);  // Pink gradient end
uniform vec4 colour_3 : source_color = vec4(0.95, 0.95, 1.0, 1.0);   // Specular highlight white

// Droplet controls
uniform float drop_density : hint_range(3.0, 15.0) = 7.0;
uniform float drift_speed : hint_range(0.0, 1.0) = 0.12;
uniform float drop_size : hint_range(0.5, 2.0) = 1.0;
uniform float refraction_strength : hint_range(0.0, 0.15) = 0.06;
uniform float highlight_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float streak_amount : hint_range(0.0, 1.0) = 0.4;
uniform float iridescence : hint_range(0.0, 1.0) = 0.3;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;

// Hash functions
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

// Simple value noise
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Neon gradient background
vec3 neon_gradient(vec2 uv, float t) {
	// Diagonal gradient with subtle animation
	float grad = uv.x * 0.6 + uv.y * 0.4 + sin(t * 0.15) * 0.08;
	grad = clamp(grad, 0.0, 1.0);
	vec3 col = mix(colour_1.rgb, colour_2.rgb, grad);

	// Add subtle noise variation for airbrush feel
	float noise = value_noise(uv * 6.0 + t * 0.05) * 0.08;
	col += noise * mix(colour_1.rgb, colour_2.rgb, 0.5);

	return col;
}

// Render a single water droplet
// Returns vec4: rgb = color contribution, a = coverage mask
vec4 render_droplet(vec2 uv, vec2 drop_pos, float radius, float seed, vec3 bg_color, float t) {
	vec2 delta = uv - drop_pos;
	float dist = length(delta);

	if (dist > radius * 1.8) return vec4(0.0);

	// Normalized distance within droplet
	float nd = dist / radius;

	// Droplet body - smooth circle with slightly squashed bottom
	float squash = 1.0 + delta.y * 0.15 / radius; // Gravity makes bottom heavier
	float body = smoothstep(1.0, 0.92, nd * squash);

	if (body < 0.001) return vec4(0.0);

	// Shadow underneath (offset down-right)
	vec2 shadow_offset = vec2(0.003, 0.005) * drop_size;
	float shadow_dist = length(uv - drop_pos - shadow_offset) / radius;
	float shadow = smoothstep(1.1, 0.8, shadow_dist) * 0.25;

	// Fake refraction: offset UV to sample "background" through droplet lens
	vec2 refract_offset = delta / radius * refraction_strength;
	// Magnification effect near center, inversion near edge
	float lens_factor = 1.0 - nd * nd;
	vec2 refracted_uv = uv - refract_offset * lens_factor;
	vec3 refracted_bg = neon_gradient(refracted_uv, t);

	// Darken the refracted interior slightly (glass absorption)
	refracted_bg *= 0.92 + 0.08 * lens_factor;

	// Specular highlight - small bright dot upper-left of center
	vec2 spec_pos = drop_pos + vec2(-0.25, -0.32) * radius;
	float spec_dist = length(uv - spec_pos) / (radius * 0.22);
	float specular = exp(-spec_dist * spec_dist * 3.0) * highlight_intensity;

	// Secondary smaller highlight
	vec2 spec2_pos = drop_pos + vec2(-0.12, -0.18) * radius;
	float spec2_dist = length(uv - spec2_pos) / (radius * 0.1);
	float specular2 = exp(-spec2_dist * spec2_dist * 4.0) * highlight_intensity * 0.5;

	// Edge highlight ring (fresnel-like)
	float edge_ring = smoothstep(0.7, 0.95, nd) * smoothstep(1.0, 0.95, nd);
	edge_ring *= 0.4;

	// Iridescent rainbow edge (thin-film interference simulation)
	float iris_angle = atan(delta.y, delta.x);
	float iris = sin(nd * 12.0 + iris_angle * 2.0 + t * 0.5 + seed * 6.283) * 0.5 + 0.5;
	vec3 iris_color = vec3(
		sin(iris * 6.283) * 0.5 + 0.5,
		sin(iris * 6.283 + 2.094) * 0.5 + 0.5,
		sin(iris * 6.283 + 4.189) * 0.5 + 0.5
	);
	float iris_mask = edge_ring * iridescence;

	// Compose droplet color
	vec3 drop_col = refracted_bg;
	drop_col += colour_3.rgb * specular;
	drop_col += colour_3.rgb * specular2;
	drop_col += colour_3.rgb * edge_ring * 0.5;
	drop_col = mix(drop_col, iris_color, iris_mask);

	// Combine with shadow
	float alpha = body;
	vec3 final_col = mix(bg_color * (1.0 - shadow), drop_col, body);

	return vec4(final_col, max(alpha, shadow));
}

// Drip streak trailing below a droplet
float drip_streak(vec2 uv, vec2 drop_pos, float radius, float streak_len, float seed) {
	// Streak goes straight down from drop bottom
	vec2 streak_start = drop_pos + vec2(0.0, radius * 0.7);
	vec2 delta = uv - streak_start;

	if (delta.y < 0.0 || delta.y > streak_len) return 0.0;

	// Narrow streak that tapers
	float width = radius * 0.18 * (1.0 - delta.y / streak_len);
	width += sin(delta.y * 40.0 + seed * 10.0) * radius * 0.03; // Wobble

	float streak = smoothstep(width, width * 0.3, abs(delta.x));
	// Fade out along length
	streak *= smoothstep(streak_len, streak_len * 0.3, delta.y);
	// Fade in from top
	streak *= smoothstep(0.0, streak_len * 0.1, delta.y);

	return streak * 0.6;
}

void fragment() {
	// Pixelation
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// Background gradient
	vec3 col = neon_gradient(uv, t);

	// === Render 3 parallax droplet layers ===
	for (int layer = 0; layer < 3; layer++) {
		float layer_f = float(layer);
		float layer_speed = (0.4 + layer_f * 0.3) * drift_speed;
		float layer_scale = drop_density * (0.7 + layer_f * 0.25);
		float layer_size_mult = 1.3 - layer_f * 0.25;
		float layer_alpha = 0.7 + layer_f * 0.15;

		// Scrolling offset for this layer
		vec2 scroll = vec2(
			sin(t * 0.1 + layer_f * 2.0) * 0.02,
			t * layer_speed
		);

		vec2 grid_uv = (uv + scroll) * layer_scale;
		vec2 cell_id = floor(grid_uv);
		vec2 cell_uv = fract(grid_uv);

		// Check neighboring cells for droplets that overlap
		for (int dx = -1; dx <= 1; dx++) {
			for (int dy = -1; dy <= 1; dy++) {
				vec2 neighbor = vec2(float(dx), float(dy));
				vec2 id = cell_id + neighbor;

				float presence = hash21(id + layer_f * 100.0);
				// Not every cell has a droplet
				if (presence > 0.55) continue;

				// Droplet position within cell
				vec2 pos_rand = hash22(id + vec2(layer_f * 50.0, 0.0));
				vec2 drop_center = neighbor + pos_rand;
				vec2 local_uv = cell_uv;

				// Drop radius
				float base_radius = 0.08 + hash21(id + vec2(7.0, 3.0)) * 0.12;
				float radius = base_radius * drop_size * layer_size_mult / layer_scale;

				// World-space positions for rendering
				vec2 world_drop = (cell_id + drop_center + scroll * layer_scale) / layer_scale - scroll;
				vec2 world_uv = uv;

				float seed = hash21(id + vec2(13.0, 17.0));

				// Render droplet
				vec4 drop = render_droplet(world_uv, world_drop, radius, seed, col, t);
				if (drop.a > 0.001) {
					col = mix(col, drop.rgb, drop.a * layer_alpha);
				}

				// Drip streak below some droplets
				if (streak_amount > 0.0 && seed > 0.6) {
					float streak_len = radius * (2.0 + seed * 4.0) * streak_amount;
					float streak = drip_streak(world_uv, world_drop, radius, streak_len, seed);
					vec3 streak_col = mix(col, colour_3.rgb, 0.3);
					col = mix(col, streak_col, streak * layer_alpha);
				}
			}
		}
	}

	// Subtle scanlines
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.3;

	// Slight vignette
	vec2 vig_uv = uv - 0.5;
	float vignette = 1.0 - dot(vig_uv, vig_uv) * 0.3;
	col *= vignette;

	COLOR = vec4(col, 1.0);
}
