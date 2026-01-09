shader_type canvas_item;
// Neon Grid - 80's/90's Tron-inspired perspective grid background
// Created for DiceRogue (Ghutzee)

// Color system - matching game's purple/teal palette
uniform vec4 colour_1 : source_color = vec4(0.15, 0.08, 0.25, 1.0);  // Dark purple base
uniform vec4 colour_2 : source_color = vec4(0.0, 0.8, 0.8, 1.0);     // Teal/cyan neon
uniform vec4 colour_3 : source_color = vec4(0.8, 0.0, 1.0, 1.0);     // Purple/magenta neon

// Animation and appearance
uniform float grid_speed : hint_range(0.0, 2.0) = 0.3;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float grid_density : hint_range(5.0, 50.0) = 20.0;
uniform float perspective_strength : hint_range(0.0, 2.0) = 1.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	// Pixelation effect
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;
	
	// Apply perspective - top compressed, bottom expanded
	vec2 grid_uv = uv;
	grid_uv.y = pow(grid_uv.y, 1.0 + perspective_strength * 0.5);
	
	// Animated grid movement
	float time_offset = TIME * grid_speed;
	grid_uv.y += time_offset * 0.5;
	
	// Create grid lines
	vec2 grid_pos = grid_uv * grid_density;
	vec2 grid_fract = fract(grid_pos);
	
	// Horizontal lines (stronger)
	float h_line = smoothstep(0.95, 1.0, grid_fract.y);
	
	// Vertical lines (subtler)
	float v_line = smoothstep(0.93, 0.98, grid_fract.x);
	
	// Combine grid lines
	float grid = max(h_line, v_line * 0.5);
	
	// Distance-based fading (perspective depth)
	float depth_fade = pow(uv.y, 2.0);
	grid *= depth_fade;
	
	// Add glow to grid lines
	float glow = grid * glow_intensity;
	
	// Color gradient based on depth
	vec3 grid_color = mix(colour_2.rgb, colour_3.rgb, uv.y);
	
	// Base color (dark background)
	vec3 base_color = colour_1.rgb;
	
	// Combine with glow
	vec3 final_color = base_color + grid_color * glow;
	
	// Add scanlines for CRT effect
	float scanline = sin(uv.y * screen_size.y * 2.0) * 0.5 + 0.5;
	final_color *= 1.0 - (scanline * scanline_strength * (1.0 - grid));
	
	// Horizon glow effect
	float horizon_glow = smoothstep(0.3, 0.6, uv.y) * smoothstep(0.9, 0.6, uv.y);
	final_color += grid_color * horizon_glow * 0.3;
	
	COLOR = vec4(final_color, 1.0);
}
