shader_type canvas_item;
// Neon Energy Plasma - Electric arc / plasma tendril effect for score labels
// Created for DiceRogue (Guhtzee)
// Used on additive (gold) and multiplier (cyan) score breakdown labels
// Inspired by Balatro fire but reimagined as neon electric plasma

uniform vec4 energy_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);  // Primary energy color
uniform vec4 accent_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);   // Secondary accent
uniform float energy_speed : hint_range(0.0, 5.0) = 1.5;
uniform float intensity : hint_range(0.0, 2.0) = 0.8;
uniform float arc_density : hint_range(1.0, 8.0) = 4.0;
uniform float pulse_rate : hint_range(0.0, 4.0) = 1.2;
uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;
uniform float edge_glow_width : hint_range(0.0, 0.3) = 0.12;
uniform float spark_amount : hint_range(0.0, 1.0) = 0.5;

// Hash functions for noise generation
float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Smooth noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);  // Smoothstep interpolation
	
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM (Fractal Brownian Motion) for layered noise
float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	
	for (int i = 0; i < octaves; i++) {
		value += amplitude * noise(p * frequency);
		amplitude *= 0.5;
		frequency *= 2.2;
		p += vec2(1.7, 9.2);  // Domain rotation to reduce axis-aligned artifacts
	}
	return value;
}

// Electric arc function - creates bright tendril-like patterns
float electric_arc(vec2 uv, float time_offset) {
	float t = TIME * energy_speed + time_offset;
	
	// Multiple flowing noise layers that create arc-like patterns
	vec2 flow = vec2(t * 0.7, t * 0.3);
	float n1 = fbm(uv * arc_density + flow, 3);
	float n2 = fbm(uv * arc_density * 1.5 - flow * 0.8 + vec2(5.0, 3.0), 3);
	
	// Create sharp arc ridges by using abs of sine of noise
	float arc = sin(n1 * 6.28 + t * 2.0) * 0.5 + 0.5;
	arc *= sin(n2 * 4.0 - t * 1.5) * 0.5 + 0.5;
	
	// Sharpen the arcs to create defined tendril lines  
	arc = pow(arc, 2.5);
	
	return arc;
}

void fragment() {
	if (effect_strength <= 0.001) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		vec2 uv = UV;
		float t = TIME * energy_speed;
		
		// Pulsing intensity modulation
		float pulse = 1.0;
		if (pulse_rate > 0.0) {
			pulse = 0.7 + 0.3 * sin(TIME * pulse_rate);
		}
		float eff_intensity = intensity * pulse * effect_strength;
		
		// === ELECTRIC ARC LAYERS ===
		float arc1 = electric_arc(uv, 0.0);
		float arc2 = electric_arc(uv * 1.3 + vec2(3.7, 1.2), 2.5);
		float arcs = max(arc1, arc2 * 0.7);
		
		// === EDGE GLOW ===
		// Bright neon-tube border emission
		float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
		float edge = smoothstep(edge_glow_width, 0.0, edge_dist);
		
		// Animate edge with flowing energy
		float edge_flow1 = sin(uv.y * 15.0 - t * 3.0) * 0.5 + 0.5;
		float edge_flow2 = sin(uv.x * 12.0 + t * 2.5) * 0.5 + 0.5;
		float edge_anim = edge * (0.5 + 0.5 * edge_flow1 * edge_flow2);
		
		// === CRACKLING SPARKS ===
		float sparks = 0.0;
		if (spark_amount > 0.0) {
			// Grid-based random sparks that flicker on/off
			vec2 spark_grid = floor(uv * 12.0);
			float spark_rand = hash21(spark_grid + floor(t * 8.0) * 0.01);
			float spark_threshold = 1.0 - spark_amount * 0.15;
			if (spark_rand > spark_threshold) {
				// Bright point spark with falloff from cell center
				vec2 spark_center = (spark_grid + 0.5) / 12.0;
				float spark_dist = length(uv - spark_center) * 12.0;
				sparks = smoothstep(0.5, 0.0, spark_dist) * (spark_rand - spark_threshold) * 20.0;
				sparks = min(sparks, 1.0);
			}
		}
		
		// === COMBINE ===
		// Mix primary and accent colors based on arc position
		float color_mix = fbm(uv * 2.0 + vec2(t * 0.2, 0.0), 2);
		vec3 base_energy = mix(energy_color.rgb, accent_color.rgb, color_mix * 0.4);
		
		// Arcs are colored, edges are brighter (more white/saturated)
		vec3 arc_color = base_energy * arcs * eff_intensity;
		vec3 edge_color = mix(base_energy, vec3(1.0), 0.4) * edge_anim * eff_intensity * 1.2;
		vec3 spark_color = vec3(1.0, 0.98, 0.9) * sparks * eff_intensity;
		
		vec3 final_color = arc_color + edge_color + spark_color;
		
		// Overall alpha - arcs + edges + sparks contribute
		float alpha = (arcs * 0.6 + edge_anim * 0.8 + sparks) * eff_intensity;
		alpha = clamp(alpha, 0.0, 1.0) * effect_strength;
		
		COLOR = vec4(final_color, alpha);
	}
}
