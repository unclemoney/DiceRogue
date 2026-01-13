shader_type canvas_item;
// Arcade Starfield - Multi-layer parallax stars with 80's color cycling
// Created for DiceRogue (Guhtzee)

// Color system - matching game's purple/teal palette  
uniform vec4 colour_1 : source_color = vec4(0.08, 0.04, 0.15, 1.0);  // Dark purple space
uniform vec4 colour_2 : source_color = vec4(0.8, 0.0, 1.0, 1.0);     // Purple/magenta stars
uniform vec4 colour_3 : source_color = vec4(0.0, 0.8, 0.8, 1.0);     // Teal/cyan stars

// Animation and appearance
uniform float star_speed : hint_range(0.0, 2.0) = 0.2;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float star_density : hint_range(50.0, 500.0) = 200.0;
uniform float twinkle_speed : hint_range(0.0, 5.0) = 2.0;
uniform float comet_trails : hint_range(0.0, 1.0) = 0.3;
uniform float color_cycle_speed : hint_range(0.0, 3.0) = 1.0;

// Hash function for pseudo-random star positions
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Star layer function
float star_layer(vec2 uv, float layer_speed, float time_offset, float density_mult) {
	vec2 star_uv = uv * star_density * density_mult;
	star_uv.y += time_offset * layer_speed;
	
	vec2 star_id = floor(star_uv);
	vec2 star_fract = fract(star_uv);
	
	// Random star position within cell
	float star_hash = hash(star_id);
	vec2 star_pos = vec2(
		hash(star_id + vec2(1.0, 0.0)),
		hash(star_id + vec2(0.0, 1.0))
	);
	
	// Distance to star
	float dist = length(star_fract - star_pos);
	
	// Star size varies by hash
	float star_size = 0.02 + hash(star_id + vec2(2.0, 3.0)) * 0.03;
	
	// Create star
	float star = smoothstep(star_size, 0.0, dist);
	
	// Twinkle effect
	float twinkle = sin(star_hash * 100.0 + time_offset * twinkle_speed) * 0.5 + 0.5;
	star *= 0.5 + twinkle * 0.5;
	
	return star * star_hash;  // Vary brightness
}

void fragment() {
	// Pixelation effect
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;
	
	float time_var = TIME * star_speed;
	
	// Create 4 parallax star layers with different speeds
	float layer1 = star_layer(uv, 1.0, time_var, 0.5);    // Fastest, smallest
	float layer2 = star_layer(uv, 0.6, time_var, 0.7);    // Medium-fast
	float layer3 = star_layer(uv, 0.3, time_var, 1.0);    // Medium-slow
	float layer4 = star_layer(uv, 0.1, time_var, 1.3);    // Slowest, largest
	
	// Combine layers
	float stars = layer1 * 0.6 + layer2 * 0.8 + layer3 * 1.0 + layer4 * 1.2;
	
	// Color cycling effect - stars shift between purple and teal
	float cycle = sin(time_var * color_cycle_speed + uv.x * 3.0) * 0.5 + 0.5;
	vec3 star_color = mix(colour_2.rgb, colour_3.rgb, cycle);
	
	// Add comet streaks
	float comet = 0.0;
	if (comet_trails > 0.0) {
		vec2 comet_uv = uv;
		comet_uv.y += time_var * 2.0;
		vec2 comet_id = floor(comet_uv * star_density * 0.3);
		float comet_hash = hash(comet_id);
		
		if (comet_hash > 0.95) {  // Only occasional comets
			vec2 comet_fract = fract(comet_uv * star_density * 0.3);
			float comet_trail = smoothstep(0.5, 0.0, abs(comet_fract.x - comet_hash));
			comet_trail *= smoothstep(0.0, 0.3, comet_fract.y);
			comet_trail *= smoothstep(1.0, 0.7, comet_fract.y);
			comet += comet_trail * comet_trails;
		}
	}
	
	// Base space color
	vec3 final_color = colour_1.rgb;
	
	// Add stars with color
	final_color += star_color * stars * 2.0;
	
	// Add comets with golden/white color
	final_color += vec3(1.0, 0.9, 0.6) * comet * 1.5;
	
	// Subtle nebula effect (color variations in background)
	float nebula = sin(uv.x * 3.0 + time_var * 0.1) * sin(uv.y * 2.0 + time_var * 0.15);
	nebula = nebula * 0.5 + 0.5;
	vec3 nebula_color = mix(colour_1.rgb, colour_2.rgb * 0.3, nebula * 0.3);
	final_color += nebula_color * 0.2;
	
	COLOR = vec4(final_color, 1.0);
}
