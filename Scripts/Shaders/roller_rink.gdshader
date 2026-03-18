shader_type canvas_item;
// Roller Rink - 80s Roller Rink Floor with Disco Lights
// Created for DiceRogue (Guhtzee)
// Perspective hardwood floor with sweeping disco ball light spots
// Inspired by classic 80s roller rinks and skating culture (1984-1988)

// Color system
uniform vec4 colour_1 : source_color = vec4(0.45, 0.28, 0.12, 1.0);  // Warm wood base
uniform vec4 colour_2 : source_color = vec4(0.55, 0.35, 0.16, 1.0);  // Light wood grain
uniform vec4 colour_3 : source_color = vec4(1.0, 0.2, 0.6, 1.0);     // Pink disco light
uniform vec4 colour_4 : source_color = vec4(0.2, 0.5, 1.0, 1.0);     // Blue disco light
uniform vec4 colour_5 : source_color = vec4(0.7, 0.15, 0.9, 1.0);    // Purple disco light

// Controls
uniform float disco_speed : hint_range(0.1, 2.0) = 0.5;
uniform float light_count : hint_range(3.0, 12.0) = 8.0;
uniform float specular_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float fog_amount : hint_range(0.0, 1.0) = 0.3;
uniform float perspective_strength : hint_range(0.5, 2.0) = 1.2;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;

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

// Value noise for wood grain
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

void fragment() {
	// Pixelation
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// === Perspective Floor Projection ===
	// Y maps from horizon line (top) to near floor (bottom)
	// Map UV to perspective floor coordinates
	float y_norm = uv.y; // 0 at top, 1 at bottom
	float horizon = 0.15; // Horizon line position

	vec3 col = vec3(0.0);

	if (y_norm > horizon) {
		// Below horizon — floor visible
		float depth = (y_norm - horizon) / (1.0 - horizon); // 0 at horizon, 1 at bottom
		float persp = pow(depth, perspective_strength); // Non-linear depth for perspective feel

		// Floor UV (perspective-corrected)
		float floor_x = (uv.x - 0.5) / (persp + 0.01) + 0.5;
		float floor_y = 1.0 / (persp + 0.001) * 0.1; // Depth into floor

		vec2 floor_uv = vec2(floor_x, floor_y);

		// === Wood Grain ===
		// Plank structure — long horizontal planks
		float plank_id = floor(floor_uv.y * 4.0);
		float plank_fract = fract(floor_uv.y * 4.0);

		// Plank-to-plank color variation
		float plank_var = hash11(plank_id * 7.0 + 3.0) * 0.15;

		// Wood grain: wavy horizontal lines
		float grain1 = sin(floor_uv.x * 30.0 + sin(floor_uv.y * 8.0 + plank_id * 5.0) * 2.0) * 0.5 + 0.5;
		float grain2 = value_noise(floor_uv * vec2(50.0, 15.0) + plank_id * 10.0);
		float grain = grain1 * 0.6 + grain2 * 0.4;

		// Wood color: mix between two wood tones
		vec3 wood = mix(colour_1.rgb, colour_2.rgb, grain * 0.5 + plank_var);

		// Plank gap lines
		float gap1 = smoothstep(0.02, 0.01, plank_fract);
		float gap2 = smoothstep(0.98, 0.99, plank_fract);
		wood *= 1.0 - (gap1 + gap2) * 0.5;

		// Stagger horizontal joints between planks
		float joint_offset = hash11(plank_id * 13.0) * 0.3;
		float joint_x = fract(floor_uv.x * 2.0 + joint_offset);
		float joint_line = smoothstep(0.01, 0.005, joint_x) + smoothstep(0.99, 0.995, joint_x);
		wood *= 1.0 - joint_line * 0.3;

		// Floor glossiness (brighter near horizon = more reflection angle)
		float gloss = (1.0 - persp) * 0.15;
		wood += gloss;

		col = wood;

		// === Lane Stripes (roller rink markings) ===
		// Center rink line
		float center_stripe = smoothstep(0.006, 0.002, abs(uv.x - 0.5) / (persp + 0.01));
		col = mix(col, vec3(1.0), center_stripe * 0.4);

		// Lane boundaries
		for (int lane = 0; lane < 2; lane++) {
			float lane_x = 0.3 + float(lane) * 0.4;
			float stripe_d = abs(uv.x - lane_x) / (persp + 0.01);
			float stripe = smoothstep(0.004, 0.001, stripe_d);
			col = mix(col, vec3(0.9, 0.9, 0.95), stripe * 0.3);
		}

		// === Disco Ball Light Spots ===
		float total_lights = floor(light_count);
		for (float i = 0.0; i < 12.0; i++) {
			if (i >= total_lights) break;

			// Each light spot follows a circular/elliptical path
			float orbit_speed = disco_speed * (0.5 + hash11(i * 7.0 + 1.0) * 1.0);
			float orbit_rx = 0.15 + hash11(i * 11.0 + 3.0) * 0.3; // x radius
			float orbit_ry = 0.08 + hash11(i * 13.0 + 5.0) * 0.15; // y radius
			float orbit_phase = hash11(i * 17.0 + 7.0) * 6.283;

			// Center of orbit
			float orbit_cx = 0.2 + hash11(i * 19.0 + 9.0) * 0.6;
			float orbit_cy_screen = horizon + 0.2 + hash11(i * 23.0 + 11.0) * 0.5;

			// Light position on screen (not perspective-corrected)
			float light_x = orbit_cx + cos(t * orbit_speed + orbit_phase) * orbit_rx;
			float light_y = orbit_cy_screen + sin(t * orbit_speed + orbit_phase * 1.3) * orbit_ry;

			// Distance in screen space (accounts for perspective — spots appear larger near bottom)
			vec2 light_p = uv - vec2(light_x, light_y);
			float light_persp = (light_y - horizon) / (1.0 - horizon);
			float spot_size = 0.03 + light_persp * 0.04; // Bigger spots closer to camera

			float spot_d = length(light_p / vec2(spot_size, spot_size * 0.7)); // Elliptical

			if (spot_d < 3.0) {
				// Soft disc of light
				float spot = exp(-spot_d * spot_d * 2.0);

				// Pick color
				float c_pick = hash11(i * 31.0);
				vec3 light_col;
				if (c_pick < 0.33) {
					light_col = colour_3.rgb; // Pink
				} else if (c_pick < 0.66) {
					light_col = colour_4.rgb; // Blue
				} else {
					light_col = colour_5.rgb; // Purple
				}

				// Intensity varies (disco ball facet flicker)
				float flicker = 0.5 + 0.5 * sin(t * 3.0 + i * 2.5);

				// Add light spot (additive)
				col += light_col * spot * specular_intensity * flicker * 0.4;

				// Specular highlight in center (bright white-ish)
				float spec = exp(-spot_d * spot_d * 12.0);
				col += vec3(0.8) * spec * specular_intensity * flicker * 0.2;
			}
		}

		// === Color wash from overhead gels ===
		float wash_pink = sin(uv.x * 2.0 + t * 0.1) * 0.5 + 0.5;
		float wash_blue = sin(uv.x * 2.0 + t * 0.1 + 2.1) * 0.5 + 0.5;
		col += colour_3.rgb * wash_pink * 0.03;
		col += colour_4.rgb * wash_blue * 0.03;

	} else {
		// Above horizon — dark ceiling/wall with fog
		float dist_from_horizon = (horizon - y_norm) / horizon;
		col = vec3(0.03, 0.02, 0.05);

		// Fog glow near horizon
		float fog_glow = exp(-dist_from_horizon * dist_from_horizon * 10.0) * fog_amount;
		col += vec3(0.15, 0.08, 0.2) * fog_glow;

		// Disco ball hint at top center
		float ball_d = length(uv - vec2(0.5, 0.05));
		float ball = smoothstep(0.03, 0.02, ball_d);
		col += colour_3.rgb * ball * 0.1;
		// Chrome sparkle
		float sparkle = pow(max(0.0, cos(atan(uv.y - 0.05, uv.x - 0.5) * 8.0 + t * 2.0)), 8.0);
		col += vec3(0.3) * sparkle * ball * 0.4;
	}

	// Fog haze at horizon line
	float horizon_fog = exp(-pow((uv.y - horizon) / 0.05, 2.0)) * fog_amount;
	col += vec3(0.12, 0.06, 0.18) * horizon_fog;

	// Scanlines
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.3;

	// Vignette
	vec2 vig = uv - 0.5;
	col *= 1.0 - dot(vig, vig) * 0.3;

	COLOR = vec4(col, 1.0);
}
