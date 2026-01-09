shader_type canvas_item;
// VHS Static Wave - Analog TV interference with chromatic drift
// Created for DiceRogue (Ghutzee)

// Color system - matching game's purple/teal palette
uniform vec4 colour_1 : source_color = vec4(0.08, 0.04, 0.15, 1.0);  // Very dark purple
uniform vec4 colour_2 : source_color = vec4(0.25, 0.12, 0.35, 1.0);  // Medium purple
uniform vec4 colour_3 : source_color = vec4(0.0, 0.6, 0.7, 1.0);     // Teal accent

// Animation and appearance
uniform float wave_speed : hint_range(0.0, 3.0) = 0.5;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float wave_density : hint_range(3.0, 20.0) = 8.0;
uniform float wave_amplitude : hint_range(0.0, 0.2) = 0.05;
uniform float chromatic_drift : hint_range(0.0, 0.1) = 0.02;
uniform float noise_strength : hint_range(0.0, 0.5) = 0.15;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.4;

// Pseudo-random noise function
float random(vec2 st) {
	return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453);
}

// Noise function with time variation
float noise(vec2 st, float time) {
	vec2 i = floor(st);
	vec2 f = fract(st);
	float a = random(i + time);
	float b = random(i + vec2(1.0, 0.0) + time);
	float c = random(i + vec2(0.0, 1.0) + time);
	float d = random(i + vec2(1.0, 1.0) + time);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	// Pixelation effect
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;
	
	float time_var = TIME * wave_speed;
	
	// Multi-frequency wave displacement
	float wave1 = sin(uv.y * wave_density * 2.0 + time_var * 2.0) * wave_amplitude;
	float wave2 = sin(uv.y * wave_density * 0.5 + time_var * 1.5) * wave_amplitude * 0.7;
	float wave3 = sin(uv.y * wave_density * 3.5 + time_var * 0.8) * wave_amplitude * 0.4;
	
	float total_wave = wave1 + wave2 + wave3;
	
	// Apply chromatic drift (VHS color separation)
	vec2 uv_r = vec2(uv.x + total_wave + chromatic_drift, uv.y);
	vec2 uv_g = vec2(uv.x + total_wave, uv.y);
	vec2 uv_b = vec2(uv.x + total_wave - chromatic_drift, uv.y);
	
	// Sample colors with drift
	float r_channel = fract(uv_r.x + uv_r.y * 0.3 + time_var * 0.1);
	float g_channel = fract(uv_g.x + uv_g.y * 0.3 + time_var * 0.1);
	float b_channel = fract(uv_b.x + uv_b.y * 0.3 + time_var * 0.1);
	
	// Create wave pattern from color system
	vec3 wave_color = mix(colour_1.rgb, colour_2.rgb, r_channel);
	wave_color = mix(wave_color, colour_3.rgb, g_channel * 0.5);
	
	// Add noise (TV static)
	float noise_val = noise(uv * 100.0, floor(time_var * 10.0) * 0.1);
	wave_color += vec3(noise_val * noise_strength);
	
	// Rolling interference bars
	float bar_pos = mod(uv.y + time_var * 0.2, 1.0);
	float bar = smoothstep(0.0, 0.02, bar_pos) * smoothstep(0.1, 0.08, bar_pos);
	wave_color += colour_3.rgb * bar * 0.5;
	
	// Scanlines
	float scanline = sin(uv.y * screen_size.y * 1.5) * 0.5 + 0.5;
	wave_color *= 1.0 - (scanline * scanline_intensity * 0.5);
	
	// Vignette effect
	vec2 center_dist = abs(uv - vec2(0.5));
	float vignette = 1.0 - length(center_dist) * 0.8;
	wave_color *= vignette;
	
	COLOR = vec4(wave_color, 1.0);
}
